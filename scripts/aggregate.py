#!/usr/bin/env python3
"""Collect fuel prices for EU countries (EU Weekly Oil Bulletin), NL daily (CBS) and US weekly (EIA).
Writes v1/latest.json and v1/history/{CC}.json. A failing source keeps its previous data."""
import datetime as dt, io, json, os, re, sys, urllib.parse, urllib.request
import openpyxl

OUT = os.environ.get("OUT_DIR") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "v1")
UA = {"User-Agent": "TankGo-data/1.0"}
WOB_PAGE = "https://energy.ec.europa.eu/data-and-analysis/weekly-oil-bulletin_en"
CBS = "https://opendata.cbs.nl/ODataApi/odata/80416ned/TypedDataSet"
EIA = "https://api.eia.gov/v2/petroleum/pri/gnd/data/"
ECB_FX = "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist-90d.xml"
EU27 = "AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE".split()
FUELS = {"euro95": "e95", "diesel": "diesel", "LPG": "lpg"}
HIST_WEEKS, HIST_DAYS = 104, 400


def get(url, headers=None, timeout=120, retries=4):
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={**UA, **(headers or {})})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except Exception as e:  # noqa: BLE001
            last = e
    raise RuntimeError(f"{url}: {last}")


def load_json(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:  # noqa: BLE001
        return default


def save_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)


def eu_bulletin():
    html = get(WOB_PAGE).decode("utf-8", "replace")
    m = re.search(r'href="([^"]*Prices_History[^"]*\.xlsx)"', html)
    if not m:
        raise RuntimeError("history file link not found on bulletin page")
    url = urllib.parse.urljoin(WOB_PAGE, m.group(1).replace("&amp;", "&"))
    wb = openpyxl.load_workbook(io.BytesIO(get(url, timeout=300)), read_only=True, data_only=True)
    rows = list(wb["Prices with taxes"].iter_rows(values_only=True))
    cols = {}
    for i, h in enumerate(rows[0]):
        mm = re.fullmatch(r"([A-Z]{2})_price_with_tax_(euro95|diesel|LPG)", h or "")
        if mm:
            cols[(mm.group(1), FUELS[mm.group(2)])] = i
    out = {}
    for r in rows[3:]:
        d = r[0]
        if not isinstance(d, dt.datetime):
            continue
        for cc in EU27:
            vals = {}
            for f in FUELS.values():
                i = cols.get((cc, f))
                v = r[i] if i is not None and i < len(r) else None
                if isinstance(v, (int, float)) and 500 < v < 4000:  # EUR per 1000 L
                    vals[f] = round(v / 1000, 3)
            if vals:
                out.setdefault(cc, {})[d.strftime("%Y-%m-%d")] = vals
    return out


def cbs_nl():
    frm = (dt.date.today() - dt.timedelta(days=HIST_DAYS)).strftime("%Y%m%d")
    q = urllib.parse.urlencode({"$filter": f"Perioden ge '{frm}'", "$select": "Perioden,BenzineEuro95_1,Diesel_2,Lpg_3", "$format": "json"}, quote_via=urllib.parse.quote)
    data = json.loads(get(f"{CBS}?{q}"))["value"]
    out = {}
    for r in data:
        p = r["Perioden"]
        if not re.fullmatch(r"\d{8}", p) or not (r["BenzineEuro95_1"] or 0) > 0:
            continue
        out[f"{p[:4]}-{p[4:6]}-{p[6:]}"] = {"e95": r["BenzineEuro95_1"], "diesel": r["Diesel_2"], "lpg": r["Lpg_3"]}
    return out


def eia_us():
    key = os.environ.get("EIA_API_KEY", "")
    series = {"e95": "EMM_EPMR_PTE_NUS_DPG", "diesel": "EMD_EPD2D_PTE_NUS_DPG"}  # regular gasoline, diesel; USD/gal
    out = {}
    for f, s in series.items():
        q = urllib.parse.urlencode({"frequency": "weekly", "data[0]": "value", "facets[series][]": s,
                                    "sort[0][column]": "period", "sort[0][direction]": "desc", "length": HIST_WEEKS})
        j = json.loads(get(f"{EIA}?{q}", headers={"X-Api-Key": key}))
        for r in j["response"]["data"]:
            if r.get("value") not in (None, ""):
                out.setdefault(r["period"], {})[f] = round(float(r["value"]), 3)
    return out


def crude_signal():
    """Indicative outlook: change in crude cost (Brent, EUR/L) now vs ~2 weeks ago.
    Retail prices follow crude with a lag of one to two weeks, so this hints at the next move."""
    key = os.environ.get("EIA_API_KEY", "")
    q = urllib.parse.urlencode({"frequency": "daily", "data[0]": "value", "facets[series][]": "RBRTE",
                                "sort[0][column]": "period", "sort[0][direction]": "desc", "length": 30})
    brent = {r["period"]: float(r["value"]) for r in json.loads(get(f"{EIA}".replace("/gnd/", "/spt/") + "?" + q, headers={"X-Api-Key": key}))["response"]["data"]
             if r.get("value") not in (None, "")}
    xml = get(ECB_FX).decode("utf-8", "replace")
    fx = {}
    for m in re.finditer(r"<Cube time=\"(\d{4}-\d{2}-\d{2})\">(.*?)</Cube>", xml, re.S):
        u = re.search(r"currency=\"USD\" rate=\"([\d.]+)\"", m.group(2))
        if u:
            fx[m.group(1)] = float(u.group(1))
    days = sorted(brent, reverse=True)
    if len(days) < 15 or not fx:
        raise RuntimeError("not enough crude/fx data")

    def eur_l(d):
        rate = fx.get(d) or fx[max(k for k in fx if k <= d)]
        return brent[d] / rate / 158.987

    now = sum(eur_l(d) for d in days[:5]) / 5
    ref = sum(eur_l(d) for d in days[10:15]) / 5
    delta = round((now - ref) * 100, 2)
    direction = "up" if delta >= 1.0 else "down" if delta <= -1.0 else "flat"
    # Daily crude cost per pump unit, used by the app to estimate today's price from the weekly one.
    crude = {d: {"eur_l": round(eur_l(d), 4), "usd_gal": round(brent[d] / 42, 4)} for d in sorted(days)}
    return {"direction": direction, "delta_ct_l": delta, "brent_date": days[0], "crude": crude,
            "generated": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}


def merge_series(old, new, limit):
    merged = {**old, **new}
    return dict(sorted(merged.items())[-limit:])


def main():
    latest_path = os.path.join(OUT, "latest.json")
    latest = load_json(latest_path, {"countries": {}})
    countries = latest.setdefault("countries", {})
    status = {}
    series = {}  # cc -> (freq, {date: vals}, source, currency, unit)

    for name, fn in (("eu_bulletin", eu_bulletin), ("cbs", cbs_nl), ("eia", eia_us)):
        try:
            series[name] = fn()
            status[name] = "ok"
        except Exception as e:  # noqa: BLE001
            status[name] = f"failed: {e}"
            print(f"[{name}] FAILED: {e}", file=sys.stderr)

    jobs = []
    for cc, s in series.get("eu_bulletin", {}).items():
        jobs.append((cc, s, "weekly", "EU Weekly Oil Bulletin", "EUR", "L", HIST_WEEKS))
    if "cbs" in series:
        jobs.append(("NL", series["cbs"], "daily", "CBS", "EUR", "L", HIST_DAYS))
    if "eia" in series:
        jobs.append(("US", series["eia"], "weekly", "EIA", "USD", "gal", HIST_WEEKS))

    for cc, s, freq, src, cur, unit, limit in jobs:
        hp = os.path.join(OUT, "history", f"{cc}.json")
        hist = load_json(hp, {}).get("points", {})
        merged = merge_series(hist, s, limit)
        save_json(hp, {"cc": cc, "currency": cur, "unit": unit, "frequency": freq, "source": src, "points": merged})
        d = max(merged)
        prev = sorted(merged)[-2] if len(merged) > 1 else None
        countries[cc] = {"date": d, "prices": merged[d], "prev": merged[prev] if prev else None,
                         "currency": cur, "unit": unit, "frequency": freq, "source": src}

    latest["generated"] = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    latest["status"] = status
    save_json(latest_path, latest)
    try:
        save_json(os.path.join(OUT, "signal.json"), crude_signal())
        status["signal"] = "ok"
    except Exception as e:  # noqa: BLE001 - keeps previous signal.json on failure
        status["signal"] = f"failed: {e}"
        print(f"[signal] FAILED: {e}", file=sys.stderr)
    print(json.dumps(status, indent=1))
    if all(v != "ok" for k, v in status.items() if k != "signal"):
        sys.exit(1)


if __name__ == "__main__":
    main()
