// Store screenshots: node store/screenshots/make.js  (from the repo root; Playwright + Chromium)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const dir = __dirname, fonts = path.resolve(dir, '../../assets/fonts');
const texts = JSON.parse(fs.readFileSync(path.join(dir, 'texts.json'), 'utf8'));
const f = (n) => 'file://' + path.join(fonts, n);
const pattern = encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="150" height="150"><g fill="none" stroke="#E0B860" stroke-opacity=".10" stroke-width="2"><circle cx="75" cy="75" r="34"/><circle cx="75" cy="75" r="20"/><circle cx="0" cy="0" r="10"/><circle cx="150" cy="0" r="10"/><circle cx="0" cy="150" r="10"/><circle cx="150" cy="150" r="10"/></g></svg>`);
const page = (lang, title, sub, img) => `<!doctype html><html lang="${lang}" dir="${lang === 'ar' ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><style>
@font-face{font-family:NS;src:url(${f('NotoSans-800.ttf')});font-weight:800}
@font-face{font-family:NS;src:url(${f('NotoSans-500.ttf')});font-weight:500}
@font-face{font-family:NK;src:url(${f('NotoKufiArabic-800.ttf')});font-weight:800}
@font-face{font-family:NK;src:url(${f('NotoKufiArabic-500.ttf')});font-weight:500}
*{margin:0;box-sizing:border-box}
body{width:1080px;height:1920px;overflow:hidden;display:flex;flex-direction:column;font-family:${lang === 'ar' ? 'NK,NS' : 'NS,NK'};
 background:url("data:image/svg+xml,${pattern}"),radial-gradient(120% 75% at 50% 18%,#9E2F42 0%,#7d2236 45%,#5a1526 100%)}
.head{padding:84px 50px 0;text-align:center}
h1{color:#fff;font-weight:800;font-size:${lang === "ar" ? 88 : 84}px;line-height:1.2;text-shadow:0 4px 18px rgba(0,0,0,.25)}
.div{display:flex;align-items:center;justify-content:center;gap:14px;margin:26px 0 22px}
.div i{display:block;width:120px;height:3px;background:linear-gradient(90deg,transparent,#E0B860)}
.div i:last-child{transform:scaleX(-1)}
.div b{width:14px;height:14px;background:#E0B860;transform:rotate(45deg)}
p{color:#E0B860;font-weight:500;font-size:${lang === "ar" ? 44 : 42}px;line-height:1.35}
.phone{margin:56px auto 0;width:780px;flex:none;border-radius:84px;background:#1d1311;padding:20px;
 box-shadow:0 0 0 4px #c9a24f,0 30px 80px rgba(0,0,0,.45)}
.screen{width:100%;border-radius:66px;overflow:hidden;background:#F5F1F0}
.screen img{width:100%;display:block}
</style></head><body><div class="head"><h1>${title}</h1><div class="div"><i></i><b></b><i></i></div><p>${sub}</p></div>
<div class="phone"><div class="screen"><img src="file://${path.join(dir, 'src', img + '.png')}"></div></div></body></html>`;
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
  for (const [lang, list] of Object.entries(texts)) {
    fs.mkdirSync(path.join(dir, lang), { recursive: true });
    for (const [i, [img, title, sub]] of list.entries()) {
      const html = path.join(dir, '.tmp.html');
      fs.writeFileSync(html, page(lang, title, sub, img));
      await p.goto('file://' + html);
      await p.evaluate(() => document.fonts.ready);
      await p.screenshot({ path: path.join(dir, lang, `${String(i + 1).padStart(2, '0')}_${img}.png`) });
    }
  }
  fs.unlinkSync(path.join(dir, '.tmp.html'));
  await b.close();
})();
