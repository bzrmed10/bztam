"""Builds the App Store screenshots (1320x2868) from the CI captures, in Bztam's own look:
light lime surface, forest-green type, the lime accent, the app screen in an iPhone frame.

usage: python3 scripts/appstore/compose.py RAW_DIR [OUT_DIR]
RAW_DIR holds the CI captures (en-01-home.png, fr-07-scan-review.png, ar-25-split.png…).
OUT_DIR defaults to docs/appstore/screenshots; files are <lang>/iphone-01.png…
"""
import asyncio
import base64
import os
import sys

from playwright.async_api import async_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
RAW = sys.argv[1] if len(sys.argv) > 1 else "/tmp/shots"
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "docs", "appstore", "screenshots")


def b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


FONTS = "".join(
    f"@font-face {{ font-family: Inter; src: url(data:font/woff2;base64,{b64(os.path.join(HERE, f'inter-latin-{w}-normal.woff2'))}) format('woff2'); font-weight: {w}; }}"
    for w in (600, 800, 900)
) + "".join(
    f"@font-face {{ font-family: Taj; src: url(data:font/woff2;base64,{b64(os.path.join(HERE, f'tajawal-arabic-{w}-normal.woff2'))}) format('woff2'); font-weight: {w}; }}"
    for w in (500, 800)
)

# Slide → CI capture name.
RAWS = {"home": "01-home", "scan": "07-scan-review", "goals": "32-goals", "split": "25-split",
        "insights": "09-insights", "ask": "10-ask", "dart": "11-dart"}
ORDER = ["home", "scan", "goals", "split", "insights", "ask", "dart"]

TEXT = {
    "en": {
        "home": ("Home", "Know what's left<br>to spend.", "Your month starts on payday."),
        "scan": ("Scan", "Snap it.<br>It's added.", "Receipts are read on your iPhone."),
        "goals": ("Goals", "Save for<br>what matters.", "A trip, Eid, a new phone."),
        "split": ("Split", "Split the bill<br>in seconds.", "Send each share on WhatsApp."),
        "insights": ("Insights", "See where<br>it goes.", "This month against the last."),
        "ask": ("Ask Bztam", "Just ask.", "In English, French or Darija."),
        "dart": ("Dart", "Your dart,<br>sorted.", "Turns, payments and reminders."),
        "privacy": ("Private<br>by design.", ["No account", "No bank login", "No ads"],
                    ["Widgets and the Action button", "Siri, without opening the app", "Sync to your own iCloud", "English, French and Arabic"]),
    },
    "fr": {
        "home": ("Accueil", "Sachez ce qu'il<br>vous reste.", "Votre mois commence le jour de paie."),
        "scan": ("Scan", "Une photo.<br>C'est ajouté.", "Les tickets sont lus sur votre iPhone."),
        "goals": ("Objectifs", "Épargnez pour<br>ce qui compte.", "Un voyage, l'Aïd, un téléphone."),
        "split": ("Partage", "Partagez l'addition<br>en un instant.", "Envoyez chaque part sur WhatsApp."),
        "insights": ("Analyses", "Voyez où<br>part l'argent.", "Ce mois-ci face au précédent."),
        "ask": ("Demandez", "Posez la<br>question.", "En français, anglais ou darija."),
        "dart": ("Dart", "Votre dart,<br>bien rangée.", "Tours, paiements et rappels."),
        "privacy": ("Privé<br>par conception.", ["Sans compte", "Sans banque", "Sans pub"],
                    ["Widgets et bouton Action", "Siri, sans ouvrir l'app", "Synchro vers votre iCloud", "Français, anglais et arabe"]),
    },
    "ar": {
        "home": ("الرئيسية", "اعرف كم تبقى<br>لك للصرف.", "يبدأ شهرك يوم الراتب."),
        "scan": ("المسح", "صوّرها.<br>وتُضاف.", "التذاكر تُقرأ على جهاز iPhone."),
        "goals": ("الأهداف", "ادّخر لما<br>يهمك.", "سفر، العيد، هاتف جديد."),
        "split": ("القسمة", "قسّم الحساب<br>في ثوانٍ.", "أرسل لكل واحد نصيبه على واتساب."),
        "insights": ("التحليلات", "اعرف أين<br>يذهب مالك.", "هذا الشهر مقارنة بالسابق."),
        "ask": ("اسأل بزطام", "فقط اسأل.", "بالعربية أو الفرنسية أو الدارجة."),
        "dart": ("الدارت", "دارتك<br>منظمة.", "الأدوار والدفعات والتذكيرات."),
        "privacy": ("خصوصيتك<br>أولًا.", ["بدون حساب", "بدون ربط بنكي", "بدون إعلانات"],
                    ["أدوات وزر الإجراء", "Siri دون فتح التطبيق", "مزامنة مع iCloud الخاص بك", "العربية والفرنسية والإنجليزية"]),
    },
}

CSS = """
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { width: 1320px; height: 2868px; overflow: hidden; background: #EEF2EA; }
body { font-family: Inter, Taj, sans-serif; color: #14290B; -webkit-font-smoothing: antialiased; position: relative; }
body[dir=rtl] { font-family: Taj, Inter, sans-serif; }
.head { position: absolute; top: 170px; left: 100px; right: 100px; text-align: center; }
.eyebrow { display: inline-block; padding: 16px 38px; border-radius: 999px; background: #A6E36F; color: #14290B; font-size: 40px; font-weight: 800; }
h1 { margin-top: 44px; font-size: 128px; line-height: 1.0; font-weight: 900; letter-spacing: -.045em; }
body[dir=rtl] h1 { letter-spacing: 0; line-height: 1.3; font-size: 116px; font-weight: 800; }
.sub { margin-top: 36px; font-size: 50px; line-height: 1.3; font-weight: 600; color: #586452; }
body[dir=rtl] .sub { font-weight: 500; }
.phone { position: absolute; left: 50%; top: 930px; width: 1020px; height: 2150px; transform: translateX(-50%);
  border-radius: 150px; padding: 24px; background: #14290B; box-shadow: 0 60px 140px -50px rgba(20,41,11,.45); }
.screen { position: relative; width: 100%; height: 100%; border-radius: 128px; overflow: hidden; background: #fff; }
.screen img { position: absolute; left: 0; top: 0; width: 100%; }
.island { position: absolute; top: 30px; left: 50%; transform: translateX(-50%); width: 290px; height: 92px; border-radius: 46px; background: #000; z-index: 2; }
.bottomfade { position: absolute; left: 0; right: 0; bottom: 0; height: 300px; background: linear-gradient(rgba(238,242,234,0), #EEF2EA 80%); z-index: 3; }
.wrap { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 0 110px; text-align: center; }
.icon { width: 260px; height: 260px; border-radius: 62px; box-shadow: 0 30px 80px -30px rgba(20,41,11,.5); }
.wrap h1 { margin-top: 90px; font-size: 160px; }
body[dir=rtl] .wrap h1 { font-size: 132px; }
.strikes { margin-top: 100px; display: flex; flex-direction: column; gap: 40px; align-items: center; }
.strikes span { position: relative; font-size: 92px; font-weight: 900; color: #586452; letter-spacing: -.03em; }
body[dir=rtl] .strikes span { letter-spacing: 0; font-weight: 800; }
.strikes span::after { content: ""; position: absolute; left: -6%; right: -6%; top: 52%; height: 10px; border-radius: 5px; background: #14290B; }
.plus { margin-top: 120px; width: 100%; border-radius: 64px; padding: 64px 70px; text-align: start; background: #fff; }
.plus ul { list-style: none; display: grid; gap: 34px; }
.plus li { display: flex; align-items: center; gap: 30px; font-size: 56px; font-weight: 800; }
body[dir=rtl] .plus li { font-weight: 500; }
.plus li::before { content: ""; flex: none; width: 26px; height: 26px; border-radius: 50%; background: #A6E36F; box-shadow: 0 0 0 10px rgba(166,227,111,.35); }
"""


def page(body, lang):
    rtl = ' dir="rtl"' if lang == "ar" else ""
    return f'<!doctype html><html><head><meta charset="utf-8"><style>{FONTS}{CSS}</style></head><body{rtl}>{body}</body></html>'


def phone_slide(lang, key, raw):
    eyebrow, title, sub = TEXT[lang][key]
    return page(f"""<div class="head"><span class="eyebrow">{eyebrow}</span><h1>{title}</h1><p class="sub">{sub}</p></div>
<div class="phone"><div class="screen"><div class="island"></div><img src="data:image/png;base64,{b64(raw)}"></div></div><div class="bottomfade"></div>""", lang)


def privacy_slide(lang):
    title, strikes, items = TEXT[lang]["privacy"]
    icon = os.path.join(ROOT, "website", "icon.png")
    return page(f"""<div class="wrap"><img class="icon" src="data:image/png;base64,{b64(icon)}"><h1>{title}</h1>
<div class="strikes">{''.join(f'<span>{s}</span>' for s in strikes)}</div>
<div class="plus"><ul>{''.join(f'<li>{i}</li>' for i in items)}</ul></div></div>""", lang)


async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        for lang in ("en", "fr", "ar"):
            folder = os.path.join(OUT, lang)
            os.makedirs(folder, exist_ok=True)
            for old in os.listdir(folder):
                if old.startswith("iphone-"):
                    os.remove(os.path.join(folder, old))
            pg = await browser.new_page(viewport={"width": 1320, "height": 2868})
            n = 0
            for key in ORDER:
                raw = os.path.join(RAW, f"{lang}-{RAWS[key]}.png")
                if not os.path.exists(raw):
                    print("skip", lang, key)
                    continue
                n += 1
                await pg.set_content(phone_slide(lang, key, raw), wait_until="load")
                await pg.wait_for_timeout(250)
                await pg.screenshot(path=os.path.join(folder, f"iphone-{n:02d}.png"))
            n += 1
            await pg.set_content(privacy_slide(lang), wait_until="load")
            await pg.wait_for_timeout(250)
            await pg.screenshot(path=os.path.join(folder, f"iphone-{n:02d}.png"))
            await pg.close()
            print(lang, n, "slides")
        await browser.close()


if __name__ == "__main__":
    asyncio.run(main())
