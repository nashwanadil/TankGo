// Feature graphics 1024x500 per language: node store/graphics/feature.js
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const dir = __dirname, fonts = path.resolve(dir, '../../assets/fonts');
const f = (n) => 'file://' + path.join(fonts, n);
const logo = fs.readFileSync(path.resolve(dir, '../../assets/logo.svg'), 'utf8');
const T = {
  en: ['Fuel prices across the EU', ['27 EU', '+ USA', 'Trip planner']],
  de: ['Spritpreise in ganz Europa', ['27 EU-Länder', '+ USA', 'Reiseplaner']],
  ar: ['أسعار الوقود في أوروبا كلها', ['27 دولة أوروبية', '+ أمريكا', 'مخطط الرحلات']],
};
const page = (lang, sub, chips) => `<!doctype html><html dir="${lang === 'ar' ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><style>
@font-face{font-family:NS;src:url(${f('NotoSans-800.ttf')});font-weight:800}
@font-face{font-family:NS;src:url(${f('NotoSans-500.ttf')});font-weight:500}
@font-face{font-family:NS;src:url(${f('NotoSans-700.ttf')});font-weight:700}
@font-face{font-family:NK;src:url(${f('NotoKufiArabic-500.ttf')});font-weight:500}
@font-face{font-family:NK;src:url(${f('NotoKufiArabic-700.ttf')});font-weight:700}
*{margin:0;box-sizing:border-box}
body{width:1024px;height:500px;overflow:hidden;display:flex;align-items:center;gap:64px;padding:0 90px;
 font-family:${lang === 'ar' ? 'NK,NS' : 'NS,NK'};background:radial-gradient(70% 120% at ${lang === 'ar' ? '72%' : '28%'} 45%,#a3334a 0%,#7d2236 40%,#4e1220 80%,#3a0d18 100%)}
.disc{flex:none;width:290px;height:290px;border-radius:50%;box-shadow:0 0 80px rgba(224,184,96,.45)}
.disc svg{width:100%;height:100%;display:block}
h1{font-family:NS;font-weight:800;font-size:96px;line-height:1;color:#fff;direction:ltr;text-align:${lang === 'ar' ? 'right' : 'left'}}
h1 b{color:#E0B860}
p{color:#F5ECE0;font-weight:500;font-size:${lang === 'ar' ? 34 : 36}px;margin:22px 0 26px;white-space:nowrap}
.chips{display:flex;gap:12px}
.chips span{border:2px solid #E0B860;color:#E0B860;border-radius:14px;padding:6px 14px;font-weight:700;font-size:22px;white-space:nowrap}
</style></head><body><div class="disc">${logo}</div><div><h1>Tank<b>Go</b></h1><p>${sub}</p><div class="chips">${chips.map((c) => `<span>${c}</span>`).join('')}</div></div></body></html>`;
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1024, height: 500 } });
  for (const [lang, [sub, chips]] of Object.entries(T)) {
    const html = path.join(dir, '.tmp.html');
    fs.writeFileSync(html, page(lang, sub, chips));
    await p.goto('file://' + html);
    await p.evaluate(() => document.fonts.ready);
    await p.screenshot({ path: path.join(dir, `feature_graphic_${lang}.png`) });
  }
  fs.unlinkSync(path.join(dir, '.tmp.html'));
  await b.close();
})();
