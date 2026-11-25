#!/usr/bin/env python3
"""Build per-station fuel price files (FR, ES, IT). Stdlib only.
Output: $OUT_DIR/stations/{CC}.json and index.json (never committed; deployed only)."""
import csv, gzip, io, json, os, sys, time, zipfile, urllib.request
import xml.etree.ElementTree as ET
from zoneinfo import ZoneInfo
from datetime import datetime, timezone

OUT = os.path.join(os.environ.get("OUT_DIR", "site/v1"), "stations")
LIVE = os.environ.get("LIVE_BASE", "https://tankgo.nashwanadil.com/v1/stations")
UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/124.0 Safari/537.36")
BBOX = {"FR": (41.0, 51.5, -5.5, 10.0), "ES": (27.0, 44.0, -19.0, 5.0), "IT": (35.0, 47.5, 6.0, 19.0)}


def log(*a):
    print(*a, flush=True)


def _ctx():
    import ssl
    c = ssl.create_default_context()
    c.set_ciphers("DEFAULT:@SECLEVEL=0")
    c.options |= getattr(ssl, "OP_LEGACY_SERVER_CONNECT", 0x4)
    return c


def _curl(url, accept, timeout):
    import subprocess
    r = subprocess.run(["curl", "-sS", "-L", "--compressed", "--connect-timeout", "30",
                        "--max-time", str(timeout), "-A", UA, "-H", "Accept: " + accept,
                        "-H", "Accept-Language: it-IT,it;q=0.9,en;q=0.8", url],
                       capture_output=True, timeout=timeout + 10)
    if r.returncode != 0 or not r.stdout:
        raise RuntimeError(f"curl rc={r.returncode}: {r.stderr.decode(errors='replace')[:200]}")
    return r.stdout


def fetch(url, accept="*/*", timeout=120, retries=3):
    err = None
    for i in range(retries):
        for how in ("urllib", "curl"):
            try:
                if how == "curl":
                    return _curl(url, accept, timeout)
                req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": accept})
                with urllib.request.urlopen(req, timeout=timeout, context=_ctx()) as r:
                    data = r.read()
                if r.headers.get("Content-Encoding") == "gzip":
                    data = gzip.decompress(data)
                return data
            except Exception as e:
                err = e
                log(f"  fetch {url} [{how}] attempt {i+1}/{retries} failed: {e}")
        time.sleep(3 * (i + 1))
    raise err


def num(s):
    if s is None:
        return None
    s = str(s).strip().replace(",", ".")
    if not s:
        return None
    try:
        return float(s)
    except ValueError:
        return None


def price(v):
    v = num(v)
    return round(v, 3) if v is not None and 0.5 <= v <= 4.0 else None


def coord(v, cc, kind):
    v = num(v)
    if v is None:
        return None
    if abs(v) > 1000:
        v /= 100000.0
    la0, la1, lo0, lo1 = BBOX[cc]
    lo, hi = (la0, la1) if kind == "lat" else (lo0, lo1)
    if not lo <= v <= hi or v == 0:
        return None
    return round(v, 5)


def stamp(s, tz):
    """Price report time -> 'YYYY-MM-DDTHH:MMZ' (UTC) when the source gives a time, else 'YYYY-MM-DD'; '' if unparseable."""
    s = (s or "").strip().replace("T", " ")
    for f in ("%Y-%m-%d %H:%M:%S", "%d/%m/%Y %H:%M:%S", "%Y-%m-%d %H:%M", "%d/%m/%Y %H:%M"):
        try:
            d = datetime.strptime(s[:19] if "%S" in f else s[:16], f)
            return d.replace(tzinfo=ZoneInfo(tz)).astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%MZ")
        except Exception:
            pass
    for f in ("%Y-%m-%d", "%d/%m/%Y"):
        try:
            return datetime.strptime(s[:10], f).strftime("%Y-%m-%d")
        except ValueError:
            pass
    return ""


def row(i, name, addr, city, lat, lon, e95, dsl, lpg, date):
    if lat is None or lon is None or (e95 is None and dsl is None and lpg is None):
        return None
    return [str(i), (name or "Station").strip(), (addr or "").strip(), (city or "").strip(),
            lat, lon, e95, dsl, lpg, date]


def fr():
    data = fetch("https://donnees.roulez-eco.fr/opendata/instantane", timeout=180)
    z = zipfile.ZipFile(io.BytesIO(data))
    xml = z.read(next(n for n in z.namelist() if n.lower().endswith(".xml")))
    out = []
    for pdv in ET.fromstring(xml).iter("pdv"):
        p, dates = {}, []
        for pr in pdv.findall("prix"):
            v = price(pr.get("valeur"))
            if v is None:
                continue
            p[pr.get("nom")] = v
            if pr.get("maj"):
                dates.append(stamp(pr.get("maj"), "Europe/Paris"))
        if not p:
            continue
        addr = (pdv.findtext("adresse") or "").strip()
        city = (pdv.findtext("ville") or "").strip()
        r = row(pdv.get("id"), addr.title() if addr else "Station", addr, city.title(),
                coord(pdv.get("latitude"), "FR", "lat"), coord(pdv.get("longitude"), "FR", "lon"),
                p.get("E10", p.get("SP95")), p.get("Gazole"), p.get("GPLc"),
                max(dates) if dates else "")
        if r:
            out.append(r)
    return out, "prix-carburants.gouv.fr (Licence Ouverte)"


def es():
    url = ("https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/"
           "PreciosCarburantes/EstacionesTerrestres/")
    d = json.loads(fetch(url, accept="application/json", timeout=240, retries=3).decode("utf-8-sig"))
    try:
        date = datetime.strptime(d.get("Fecha", "")[:10], "%d/%m/%Y").strftime("%Y-%m-%d")
    except ValueError:
        date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    out = []
    for e in d["ListaEESSPrecio"]:
        r = row(e.get("IDEESS"), (e.get("Rótulo") or "").title(), e.get("Dirección"),
                (e.get("Localidad") or "").title(),
                coord(e.get("Latitud"), "ES", "lat"), coord(e.get("Longitud (WGS84)"), "ES", "lon"),
                price(e.get("Precio Gasolina 95 E5")), price(e.get("Precio Gasoleo A")),
                price(e.get("Precio Gases licuados del petróleo")), date)
        if r:
            out.append(r)
    return out, "Ministerio para la Transición Ecológica"


def it_rows(url, retries=2, timeout=60):
    raw = fetch(url, timeout=timeout, retries=retries)
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        text = raw.decode("latin-1")
    lines = text.splitlines()[1:]  # first line: extraction date
    sep = ";" if lines[0].count(";") > lines[0].count("|") else "|"
    rd = csv.reader(lines, delimiter=sep, quoting=csv.QUOTE_NONE)
    header = [h.strip() for h in next(rd)]
    return [dict(zip(header, r)) for r in rd if len(r) >= len(header) - 1]


def it():
    bases = ["https://www.mimit.gov.it/images/exportCSV/", "http://www.mimit.gov.it/images/exportCSV/",
             "https://www.mise.gov.it/images/exportCSV/", "http://www.mise.gov.it/images/exportCSV/"]
    base = None
    for b in bases:
        try:
            reg_rows = it_rows(b + "anagrafica_impianti_attivi.csv", retries=1, timeout=10)
            base = b
            break
        except Exception as e:
            log(f"  IT base {b} unusable: {e}")
    if base is None:
        raise RuntimeError("no reachable MIMIT host")
    reg = {r["idImpianto"].strip(): r for r in reg_rows}
    best = {}  # id -> {fuel: {self_flag: min price}}, dates
    dates = {}
    fuels = {"Benzina": "e95", "Gasolio": "diesel", "GPL": "lpg"}
    for r in it_rows(base + "prezzo_alle_8.csv"):
        f = fuels.get((r.get("descCarburante") or "").strip())
        v = price(r.get("prezzo"))
        i = (r.get("idImpianto") or "").strip()
        if not f or v is None or i not in reg:
            continue
        s = (r.get("isSelf") or "").strip() == "1"
        slot = best.setdefault(i, {}).setdefault(f, {})
        slot[s] = min(v, slot.get(s, v))
        d = stamp(r.get("dtComu"), "Europe/Rome")
        if d:
            dates[i] = max(dates.get(i, ""), d)
    out = []
    for i, fp in best.items():
        a = reg[i]
        pick = lambda f: (fp.get(f, {}).get(True) or fp.get(f, {}).get(False)) if f in fp else None
        name = (a.get("Bandiera") or "").strip() or (a.get("Nome Impianto") or "").strip()
        r = row(i, name, a.get("Indirizzo"), a.get("Comune"),
                coord(a.get("Latitudine"), "IT", "lat"), coord(a.get("Longitudine"), "IT", "lon"),
                pick("e95"), pick("diesel"), pick("lpg"), dates.get(i, ""))
        if r:
            out.append(r)
    return out, "MIMIT Osservaprezzi (IODL 2.0)"


def write(cc, rows, source, now):
    s = json.dumps({"cc": cc, "updated": now, "source": source, "s": rows},
                   separators=(",", ":"), ensure_ascii=False)
    path = os.path.join(OUT, cc + ".json")
    with open(path, "w", encoding="utf-8") as f:
        f.write(s)
    log(f"  {cc}: {len(rows)} stations, raw {len(s.encode())/1e6:.2f} MB, "
        f"gzip {len(gzip.compress(s.encode()))/1e6:.2f} MB")
    log(f"  {cc} sample: {json.dumps(rows[len(rows)//2], ensure_ascii=False)}")


def main():
    t0 = time.time()
    os.makedirs(OUT, exist_ok=True)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    countries = {}
    for cc, fn in (("FR", fr), ("ES", es), ("IT", it)):
        log(f"== {cc}")
        try:
            rows, source = fn()
            if len(rows) < 1000:
                raise RuntimeError(f"only {len(rows)} rows, refusing")
            write(cc, rows, source, now)
            countries[cc] = {"updated": now, "count": len(rows), "source": source}
        except Exception as e:
            log(f"::warning::{cc} source FAILED: {type(e).__name__}: {e}")
            try:  # fallback: previously deployed file
                data = fetch(f"{LIVE}/{cc}.json", timeout=60, retries=1)
                d = json.loads(data)
                with open(os.path.join(OUT, cc + ".json"), "wb") as f:
                    f.write(data)
                countries[cc] = {"updated": d["updated"], "count": len(d["s"]), "source": d["source"]}
                log(f"  {cc}: using live fallback ({len(d['s'])} stations, from {d['updated']})")
            except Exception as e2:
                log(f"::warning::{cc} has NO file in this deployment (no fallback: {e2})")
    if countries:
        with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as f:
            json.dump({"updated": now, "countries": countries}, f, separators=(",", ":"),
                      ensure_ascii=False)
    log(f"done in {time.time()-t0:.1f}s; countries: {list(countries)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
