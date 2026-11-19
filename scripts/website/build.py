#!/usr/bin/env python3
"""Builds the Bztam website (English at /, French at /fr/) from the strings below.

Run: python3 scripts/website/build.py [support@email]
Legal pages come from scripts/website/content/<lang>-<page>.html. Screens come from scripts/website/screens.py.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SITE = ROOT / "website"
CONTENT = pathlib.Path(__file__).parent / "content"
EMAIL = sys.argv[1] if len(sys.argv) > 1 else "SUPPORT_EMAIL"

ICONS = {
    "apple": '<path fill="currentColor" d="M16.4 12.6c0-2.4 2-3.6 2.1-3.7-1.1-1.7-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.7.9-.8 0-1.9-.9-3.2-.8-1.6 0-3.1 1-4 2.4-1.7 3-.4 7.4 1.2 9.8.8 1.2 1.8 2.5 3 2.4 1.2 0 1.7-.8 3.1-.8 1.5 0 1.9.8 3.2.8 1.3 0 2.2-1.2 3-2.4.9-1.4 1.3-2.7 1.3-2.8-.1 0-2.5-1-2.5-3.9zM14 5.4c.7-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1.1.1 2.1-.6 2.8-1.4z"/>',
    "check": '<path fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round" d="M5 12.5l4.5 4.5L19 7.5"/>',
    "down": '<path fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" d="M12 5v14m-6-6l6 6 6-6"/>',
    "sun": '<circle cx="12" cy="12" r="4.5" fill="currentColor"/><path stroke="currentColor" stroke-width="2.2" stroke-linecap="round" d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M4.9 19.1l1.8-1.8M17.3 6.7l1.8-1.8"/>',
    "moon": '<path fill="currentColor" d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5z"/>',
    "receipt": '<path fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round" d="M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6"/>',
    "arrow-in": '<path fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" d="M12 4v11m-5-5l5 5 5-5M5 20h14"/>',
    "repeat": '<path fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" d="M17 2l3 3-3 3M4 11V9a4 4 0 0 1 4-4h12M7 22l-3-3 3-3M20 13v2a4 4 0 0 1-4 4H4"/>',
    "people": '<path fill="currentColor" d="M8 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zm8 0a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM2 19.5C2 16.5 4.7 14 8 14s6 2.5 6 5.5V20H2zm13.5.5v-.5c0-1.7-.6-3.2-1.6-4.4.6-.4 1.3-.6 2.1-.6 2.8 0 5 2.1 5 4.7v.8z"/>',
    "bell": '<path fill="currentColor" d="M12 2a6 6 0 0 0-6 6v4l-2 4h16l-2-4V8a6 6 0 0 0-6-6zm-2.5 16a2.5 2.5 0 0 0 5 0z"/>',
    "wallet": '<path fill="currentColor" d="M4 6a3 3 0 0 1 3-3h10v3H7v0h12a2 2 0 0 1 2 2v10a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3zm12 7a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3z"/>',
    "lock": '<path fill="currentColor" d="M12 2a5 5 0 0 0-5 5v3H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8a2 2 0 0 0-2-2h-1V7a5 5 0 0 0-5-5zm-3 8V7a3 3 0 0 1 6 0v3z"/>',
    "cloud": '<path fill="currentColor" d="M7 19a5 5 0 0 1-.6-10A6.5 6.5 0 0 1 19 9.5 4.8 4.8 0 0 1 18 19z"/>',
    "share": '<path fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" d="M12 3v12M7 8l5-5 5 5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/>',
    "eye-off": '<path fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" d="M3 3l18 18M10.6 5.1A10 10 0 0 1 12 5c5 0 9 4.5 10 7-.4 1-1.2 2.3-2.4 3.5M6.6 6.6C4.4 8 2.8 10.2 2 12c1 2.5 5 7 10 7 1.8 0 3.4-.6 4.8-1.4"/>',
    "phone": '<rect x="6" y="2" width="12" height="20" rx="3" fill="none" stroke="currentColor" stroke-width="2.2"/><path stroke="currentColor" stroke-width="2.2" stroke-linecap="round" d="M10 18h4"/>',
    "spark": '<path fill="currentColor" d="M12 2l1.8 5.2L19 9l-5.2 1.8L12 16l-1.8-5.2L5 9l5.2-1.8zM19 14l.9 2.1L22 17l-2.1.9L19 20l-.9-2.1L16 17l2.1-.9z"/>',
    "move": '<path fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" d="M4 8h14m-4-4 4 4-4 4M20 16H6m4-4-4 4 4 4"/>',
}


def ic(name, cls=""):
    return f'<svg viewBox="0 0 24 24" aria-hidden="true"{f" class={cls}" if cls else ""}>{ICONS[name]}</svg>'


def shot(lang, name, alt="", lazy=True, cls=""):
    """Light and dark versions of one app screen; CSS shows the one matching the site theme."""
    l = ' loading="lazy"' if lazy else ""
    base = "../" if lang == "fr" else ""
    c = f" {cls}" if cls else ""
    return (f'<img class="lt{c}" src="{base}assets/screens/{lang}-{name}-light.webp" alt="{alt}"{l}>'
            f'<img class="dk{c}" src="{base}assets/screens/{lang}-{name}-dark.webp" alt=""{l} aria-hidden="true">')


def device(lang, name, alt, size="", lazy=True):
    return (f'<div class="device {size}"><div class="island"></div><div class="screen">'
            f'{shot(lang, name, alt, lazy)}</div></div>')


T = {
"en": {
    "title": "Bztam: budget and receipts for iPhone",
    "desc": "See what came in, what you spent and what's left in every category. Snap receipts, share bills, ask questions. Private, on your iPhone.",
    "nav": [("#how", "How it works"), ("#ask", "Ask Bztam"), ("#split", "Split"), ("#dart", "Dart"), ("#features", "Features"), ("#privacy", "Privacy")],
    "other": ("fr/", "FR"), "soon": "Coming soon",
    "chip": ("New", "For iPhone · English and Français"),
    "h1": 'Know what\'s<br><span class="hl">left to spend.</span>',
    "lead": "Bztam (“wallet” in Darija) shows what came in, what you spent and <b>what's left in every category</b>. Snap a receipt, share a bill, and it's added.",
    "store": ("Coming soon on the", "App Store"), "how": "See how it works",
    "notes": ["No account", "No bank connection", "No ads"],
    "tag_a": ("Receipt added", "Marjane · 245.50 DH"), "tag_b": ("+8,000 DH in", "Salary · this period"),
    "facts": ["Money left per category", "Receipt scanning", "Screenshots and PDF bills", "Type it or say it", "Ask Bztam",
              "Split with friends", "Dart tracker", "Recurring entries", "Subscription detection", "PDF and CSV export", "iCloud sync", "Face ID lock",
              "Dark mode", "English and French"],
    "story_eye": "How it works", "story_h": "Three seconds<br>per expense.",
    "story_lead": "Adding money should never feel like bookkeeping. Bztam reads what you give it and puts it in the right place.",
    "steps": [
        ("add", "Add", "Type it. Say it.<br>Done.", "Write <b>“taxi 20”</b> or tap the mic and say it. Bztam fills the amount and the category, and remembers your choices for next time.",
         ["Big keypad, one tap per category", "Speak in English or French", "Warns you about duplicates"]),
        ("scan", "Scan", "Receipts, screenshots<br>and PDF bills.", "Snap a receipt, share a screenshot of a phone bill, or open a PDF. <b>The amount, shop and date are read on your iPhone</b>, not on a server.",
         ["Camera, Photos and Files", "Share from any app", "Suggests your newest screenshot"]),
        ("category", "Budgets", "Money left,<br>per category.", "Your month starts <b>on your payday</b>. Each category shows what's left, and Bztam warns you when you're spending too fast.",
         ["Budgets that follow your payday", "Move money between categories", "Alerts at 80% and over budget"]),
        ("insights", "Insights", "See where it<br>all went.", "A monthly recap in plain words, where your money went, money in vs. out, and <b>this period compared with the last</b>.",
         ["Recap: what's left and what changed", "Spending by category", "Budget suggestions from your history"]),
    ],
    "ask_eye": "Ask Bztam", "ask_h": "Just ask.",
    "ask_lead": "Ask about your money the way you'd say it. Bztam understands English, French and Darija written in Latin letters.",
    "qs": [("EN", "How much did I spend on food last month?"), ("FR", "Combien il me reste ?"), ("DARIJA", "ch7al sreft f taxi had simana"), ("EN", "Biggest expense this year?")],
    "ask_note": "Answered on your iPhone. Every number comes from your own entries, never from a guess.",
    "split_eye": "Split with friends", "split_h": "Who owes what,<br>sorted.",
    "split_lead": "Out with friends and one person pays? Scan the ticket, pick who was there, and Bztam splits it equally and keeps track until everyone has paid back.",
    "split_points": [("receipt", "From a ticket or by hand", "Scan the bill or type the total, then choose friends from your own list."),
                     ("share", "Send it on WhatsApp", "One tap sends everyone their share."),
                     ("wallet", "Counted like your bank", "When you pay, the whole bill leaves your money; paybacks come back into the same category."),
                     ("bell", "Balances and reminders", "See who owes you and whom you owe, and get a reminder after 3 days.")],
    "dart_eye": "Dart (tontine)", "dart_h": "Your dart,<br>finally organized.",
    "dart_lead": "Everyone pays the same each month and one person collects the pot, in turn. Bztam keeps track so nobody has to remember.",
    "dart_points": [("people", "Members in turn order", "Tick who paid this turn, see who collects next."),
                    ("bell", "Reminders on turn day", "A notification at 9:00 on each turn day."),
                    ("wallet", "Linked to your money", "Your payment becomes an expense, the pot becomes money in.")],
    "f_eye": "Everything else", "f_h": "Small details,<br>done properly.",
    "f_lead": "The things that make a budget app something you keep using.",
    "cards": {
        "recurring": ("Recurring", "Rent and salary, added for you.", "Repeat any entry every week, month or year. Bztam also spots shops you pay every month."),
        "sub": ("Netflix every month?", "65 DH each time"),
        "move": ("Move money", "Plans change.", "Give or take from another category, for this month only."),
        "export": ("Export", "A report worth keeping.", "A PDF report or a CSV for Excel and Numbers, for any period."),
        "sync": ("iCloud sync", "On all your iPhones.", "Your data follows your Apple account, in your own iCloud."),
        "lock": ("Face ID", "Locked when you want.", "Open Bztam with Face ID or your passcode."),
        "dark": ("Dark mode", "Easy on the eyes.", "Automatic, light or dark, on every screen."),
        "lang": ("Languages", "English and Français.", "Switch any time. Darija questions work too."),
        "share": ("Share sheet", "From any app.", "Share a screenshot or a PDF bill to Bztam from WhatsApp, Mail or Files."),
    },
    "pv_eye": "Privacy", "pv_h": "Your money<br>stays yours.",
    "pv_lead": "Bztam has no servers and no accounts. Receipts, voice and questions are processed on your iPhone. We never see your data.",
    "pv": [("eye-off", "No tracking, no ads, no analytics"), ("lock", "No bank connection needed"), ("phone", "Receipts read on your iPhone"), ("cloud", "Optional sync to your own iCloud")],
    "final_h": "Take control of<br>your month.", "final_lead": "Bztam is coming soon to the App Store for iPhone.",
    "foot": [("privacy.html", "Privacy"), ("terms.html", "Terms"), ("support.html", "Support"), ("fr/", "Français")],
    "made": "Made in Morocco",
    "theme": "Switch light or dark",
},
"fr": {
    "title": "Bztam : budget et tickets pour iPhone",
    "desc": "Voyez ce qui est rentré, ce que vous avez dépensé et ce qu'il reste dans chaque catégorie. Tickets, factures, questions. Privé, sur votre iPhone.",
    "nav": [("#how", "Fonctionnement"), ("#ask", "Demander"), ("#split", "Partager"), ("#dart", "Dart"), ("#features", "Fonctions"), ("#privacy", "Confidentialité")],
    "other": ("../", "EN"), "soon": "Bientôt",
    "chip": ("Nouveau", "Pour iPhone · Français et English"),
    "h1": 'Sachez ce qu\'il<br><span class="hl">vous reste.</span>',
    "lead": "Bztam (« portefeuille » en darija) montre ce qui est rentré, ce que vous avez dépensé et <b>ce qu'il reste dans chaque catégorie</b>. Un ticket en photo, une facture partagée : c'est ajouté.",
    "store": ("Bientôt sur l'", "App Store"), "how": "Voir le fonctionnement",
    "notes": ["Pas de compte", "Pas de banque", "Pas de pub"],
    "tag_a": ("Ticket ajouté", "Marjane · 245,50 DH"), "tag_b": ("+8 000 DH rentrés", "Salaire · cette période"),
    "facts": ["Le reste par catégorie", "Scan des tickets", "Captures et factures PDF", "Tapez-le ou dites-le", "Demander à Bztam",
              "Partage entre amis", "Suivi de dart", "Entrées récurrentes", "Abonnements repérés", "Export PDF et CSV", "Synchro iCloud", "Verrouillage Face ID",
              "Mode sombre", "Français et anglais"],
    "story_eye": "Fonctionnement", "story_h": "Trois secondes<br>par dépense.",
    "story_lead": "Noter son argent ne devrait jamais ressembler à de la comptabilité. Bztam lit ce que vous lui donnez et le range au bon endroit.",
    "steps": [
        ("add", "Ajouter", "Tapez-le. Dites-le.<br>C'est fait.", "Écrivez <b>« taxi 20 »</b> ou touchez le micro et dites-le. Bztam remplit le montant et la catégorie, et retient vos choix.",
         ["Grand clavier, une catégorie en un geste", "En français ou en anglais", "Vous prévient des doublons"]),
        ("scan", "Scanner", "Tickets, captures<br>et factures PDF.", "Prenez un ticket en photo, partagez une capture de facture téléphone ou ouvrez un PDF. <b>Montant, magasin et date sont lus sur votre iPhone</b>, pas sur un serveur.",
         ["Appareil photo, Photos et Fichiers", "Partage depuis n'importe quelle app", "Propose votre dernière capture"]),
        ("category", "Budgets", "Le reste,<br>par catégorie.", "Votre mois commence <b>le jour de votre paie</b>. Chaque catégorie montre ce qu'il reste, et Bztam vous prévient si vous dépensez trop vite.",
         ["Des budgets qui suivent votre paie", "Déplacez de l'argent entre catégories", "Alertes à 80 % et en cas de dépassement"]),
        ("insights", "Analyses", "Voyez où tout<br>est passé.", "Un récap mensuel en mots simples, la répartition de vos dépenses, rentrées et sorties, et <b>cette période comparée à la précédente</b>.",
         ["Récap : ce qui reste et ce qui change", "Dépenses par catégorie", "Budgets suggérés selon votre historique"]),
    ],
    "ask_eye": "Demander à Bztam", "ask_h": "Demandez.",
    "ask_lead": "Posez vos questions comme vous les diriez. Bztam comprend le français, l'anglais et la darija en lettres latines.",
    "qs": [("FR", "Combien j'ai dépensé en restos le mois dernier ?"), ("FR", "Combien il me reste ?"), ("DARIJA", "ch7al sreft f taxi had simana"), ("EN", "Biggest expense this year?")],
    "ask_note": "Réponses calculées sur votre iPhone. Chaque chiffre vient de vos propres entrées, jamais d'une supposition.",
    "split_eye": "Partage entre amis", "split_h": "Qui doit quoi,<br>c'est réglé.",
    "split_lead": "Sortie entre amis et une seule personne paie ? Scannez le ticket, choisissez qui était là, et Bztam partage à parts égales et suit tout jusqu'à ce que chacun ait remboursé.",
    "split_points": [("receipt", "Depuis un ticket ou à la main", "Scannez l'addition ou tapez le total, puis choisissez vos amis dans votre liste."),
                     ("share", "Envoyez-le sur WhatsApp", "En un geste, chacun reçoit sa part."),
                     ("wallet", "Compté comme votre banque", "Quand vous payez, toute l'addition sort de votre argent ; les remboursements reviennent dans la même catégorie."),
                     ("bell", "Soldes et rappels", "Voyez qui vous doit et à qui vous devez, avec un rappel après 3 jours.")],
    "dart_eye": "Dart (tontine)", "dart_h": "Votre dart,<br>enfin organisée.",
    "dart_lead": "Chacun paie le même montant chaque mois et une personne encaisse le tout, à tour de rôle. Bztam suit tout pour que personne n'ait à s'en souvenir.",
    "dart_points": [("people", "Membres dans l'ordre des tours", "Cochez qui a payé, voyez qui encaisse ensuite."),
                    ("bell", "Rappel le jour du tour", "Une notification à 9 h chaque jour de tour."),
                    ("wallet", "Lié à votre argent", "Votre paiement devient une dépense, la cagnotte une rentrée.")],
    "f_eye": "Et le reste", "f_h": "Les détails,<br>bien faits.",
    "f_lead": "Ce qui fait qu'on continue d'utiliser une app de budget.",
    "cards": {
        "recurring": ("Récurrents", "Loyer et salaire, ajoutés pour vous.", "Répétez une entrée chaque semaine, mois ou année. Bztam repère aussi les magasins payés chaque mois."),
        "sub": ("Netflix chaque mois ?", "65 DH à chaque fois"),
        "move": ("Déplacer", "Les plans changent.", "Donnez ou prenez à une autre catégorie, pour ce mois seulement."),
        "export": ("Export", "Un rapport à garder.", "Un rapport PDF ou un CSV pour Excel et Numbers, pour n'importe quelle période."),
        "sync": ("Synchro iCloud", "Sur tous vos iPhone.", "Vos données suivent votre compte Apple, dans votre propre iCloud."),
        "lock": ("Face ID", "Verrouillé si vous voulez.", "Ouvrez Bztam avec Face ID ou votre code."),
        "dark": ("Mode sombre", "Doux pour les yeux.", "Automatique, clair ou sombre, sur chaque écran."),
        "lang": ("Langues", "Français et English.", "Changez quand vous voulez. Les questions en darija marchent aussi."),
        "share": ("Partage", "Depuis n'importe quelle app.", "Partagez une capture ou une facture PDF vers Bztam depuis WhatsApp, Mail ou Fichiers."),
    },
    "pv_eye": "Confidentialité", "pv_h": "Votre argent<br>reste à vous.",
    "pv_lead": "Bztam n'a ni serveur ni compte. Tickets, voix et questions sont traités sur votre iPhone. Nous ne voyons jamais vos données.",
    "pv": [("eye-off", "Pas de pistage, de pub ni de statistiques"), ("lock", "Aucune connexion bancaire"), ("phone", "Tickets lus sur votre iPhone"), ("cloud", "Synchro facultative vers votre iCloud")],
    "final_h": "Reprenez la main<br>sur votre mois.", "final_lead": "Bztam arrive bientôt sur l'App Store pour iPhone.",
    "foot": [("privacy.html", "Confidentialité"), ("terms.html", "Conditions"), ("support.html", "Aide"), ("../", "English")],
    "made": "Fait au Maroc",
    "theme": "Passer en clair ou sombre",
},
}

THEME_BOOT = """<script>(()=>{try{const s=localStorage.getItem("theme");document.documentElement.dataset.theme=s||(matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light")}catch(e){document.documentElement.dataset.theme="light"}})()</script>"""


def head(t, lang, title, desc):
    base = "../" if lang == "fr" else ""
    return f"""<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{title}</title>
<meta name="description" content="{desc}">
<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0f140d" media="(prefers-color-scheme: dark)">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{desc}">
<meta property="og:image" content="{base}icon.png">
<link rel="icon" href="{base}icon.png">
<link rel="apple-touch-icon" href="{base}icon.png">
<link rel="alternate" hreflang="en" href="/">
<link rel="alternate" hreflang="fr" href="/fr/">
{THEME_BOOT}
<link rel="stylesheet" href="{base}style.css">
</head>
<body>
"""


def nav(t, lang, home=True):
    base = "../" if lang == "fr" else ""
    links = "".join(f'<a href="{"" if home else "./"}{h}">{n}</a>' for h, n in t["nav"])
    other_href, other = t["other"]
    return f"""<header class="nav" id="nav"><div class="wrap">
  <a href="./" class="logo"><img src="{base}icon.png" alt="">Bztam</a>
  <nav class="nav-links">{links}
    <a class="icon-btn keep" href="{other_href}" aria-label="{other}">{other}</a>
    <button class="icon-btn" id="theme" aria-label="{t['theme']}">{ic('moon', 'dk-ic')}{ic('sun', 'lt-ic')}</button>
    <span class="btn btn-lime small">{ic('apple')}{t['soon']}</span>
  </nav>
</div></header>
"""


def footer(t, lang):
    base = "../" if lang == "fr" else ""
    links = "".join(f'<a href="{h}">{n}</a>' for h, n in t["foot"])
    return f"""<footer><div class="wrap">
  <span class="sp"><img src="{base}icon.png" alt="">Bztam</span>
  {links}<span>© 2026 · {t['made']}</span>
</div></footer>
<script src="{base}main.js" defer></script>
</body></html>
"""


def home(lang):
    t = T[lang]
    facts = "".join(f"<span><i></i>{f}</span>" for f in t["facts"] * 2)
    steps = ""
    for i, (scr, eye, h, p, lis) in enumerate(t["steps"]):
        li = "".join(f"<li>{x}</li>" for x in lis)
        steps += f"""<article class="step{' on' if i == 0 else ''}" data-i="{i}">
          <span class="eyebrow">{eye}</span><h3>{h}</h3><p>{p}</p><ul>{li}</ul>
          <div class="shot">{device(lang, scr, eye, 'sm')}</div>
        </article>"""
    sticky_imgs = "".join(shot(lang, s[0], s[1], lazy=i > 0, cls="on" if i == 0 else "").replace('class="lt', f'data-i="{i}" class="lt').replace('class="dk', f'data-i="{i}" class="dk') for i, s in enumerate(t["steps"]))
    qs = "".join(f'<div class="q"><small>{l}</small>{q}</div>' for l, q in t["qs"])
    sp = "".join(f'<li><span class="ic">{ic(i)}</span><div><b>{b}</b><span>{x}</span></div></li>' for i, b, x in t["split_points"])
    dp = "".join(f'<li><span class="ic">{ic(i)}</span><div><b>{b}</b><span>{s}</span></div></li>' for i, b, s in t["dart_points"])
    c = t["cards"]
    pv = "".join(f"<div>{ic(i)}{s}</div>" for i, s in t["pv"])
    base = "../" if lang == "fr" else ""
    money = "245.50" if lang == "en" else "245,50"
    return head(t, lang, t["title"], t["desc"]) + nav(t, lang) + f"""<main id="top">

<section class="hero">
  <div class="wrap">
    <div>
      <div class="chip rv"><b>{t['chip'][0]}</b>{t['chip'][1]}</div>
      <h1 class="rv" style="--d:1">{t['h1']}</h1>
      <p class="lead rv" style="--d:2">{t['lead']}</p>
      <div class="hero-cta rv" style="--d:3">
        <span class="store">{ic('apple')}<span><small>{t['store'][0]}</small>{t['store'][1]}</span></span>
        <a href="#how" class="btn btn-ghost">{t['how']} {ic('down')}</a>
      </div>
      <p class="hero-note rv" style="--d:4">{''.join(f'<span>{ic("check")}{n}</span>' for n in t['notes'])}</p>
    </div>
    <div class="stage rv" style="--d:2">
      <div class="halo"></div>
      {device(lang, 'home', 'Bztam Home', lazy=False)}
      <div class="tag a"><span class="ic">{ic('receipt')}</span><div><b>{t['tag_a'][0]}</b>{t['tag_a'][1]}</div></div>
      <div class="tag b"><span class="ic">{ic('arrow-in')}</span><div><b>{t['tag_b'][0]}</b>{t['tag_b'][1]}</div></div>
    </div>
  </div>
</section>

<div class="facts" aria-hidden="true"><div class="track">{facts}</div></div>

<section class="sec" id="how">
  <div class="wrap">
    <div class="sec-head"><span class="eyebrow rv">{t['story_eye']}</span><h2 class="rv" style="--d:1">{t['story_h']}</h2><p class="lead rv" style="--d:2">{t['story_lead']}</p></div>
    <div class="story-grid">
      <div class="steps">{steps}</div>
      <div class="sticky"><div class="halo"></div>
        <div class="device"><div class="island"></div><div class="screen" id="storyScreen">{sticky_imgs}</div></div>
        <div class="dots" id="dots"><i class="on"></i><i></i><i></i><i></i></div>
      </div>
    </div>
  </div>
</section>

<section class="sec" id="ask" style="background:var(--surface-2)">
  <div class="wrap split">
    <div class="rv">
      <span class="eyebrow">{t['ask_eye']}</span>
      <h2 style="margin:16px 0 18px">{t['ask_h']}</h2>
      <p class="lead">{t['ask_lead']}</p>
      <div class="q-list">{qs}</div>
      <p class="note">{ic('lock')}{t['ask_note']}</p>
    </div>
    <div class="media rv" style="--d:2"><div class="halo"></div>{device(lang, 'ask', t['ask_eye'])}</div>
  </div>
</section>

<section class="sec" id="split">
  <div class="wrap split">
    <div class="rv">
      <span class="eyebrow">{t['split_eye']}</span>
      <h2 style="margin:16px 0 18px">{t['split_h']}</h2>
      <p class="lead">{t['split_lead']}</p>
      <ul class="ticks">{sp}</ul>
    </div>
    <div class="media rv" style="--d:2"><div class="halo"></div>{device(lang, 'friends', t['split_eye'])}</div>
  </div>
</section>

<section class="sec" id="dart" style="background:var(--surface-2)">
  <div class="wrap split rev">
    <div class="rv">
      <span class="eyebrow">{t['dart_eye']}</span>
      <h2 style="margin:16px 0 18px">{t['dart_h']}</h2>
      <p class="lead">{t['dart_lead']}</p>
      <ul class="ticks">{dp}</ul>
    </div>
    <div class="media rv" style="--d:2"><div class="halo"></div>{device(lang, 'dart', t['dart_eye'])}</div>
  </div>
</section>

<section class="sec" id="features" style="padding-top:40px">
  <div class="wrap">
    <div class="sec-head"><span class="eyebrow rv">{t['f_eye']}</span><h2 class="rv" style="--d:1">{t['f_h']}</h2><p class="lead rv" style="--d:2">{t['f_lead']}</p></div>
    <div class="bento">
      <div class="card w4 rv"><span class="eyebrow">{c['recurring'][0]}</span><h3>{c['recurring'][1]}</h3><p>{c['recurring'][2]}</p>
        <div class="art" style="flex-direction:column;align-items:center">
          <div class="mini"><div class="row"><span class="ci">{ic('repeat')}</span><div><b>{c['sub'][0]}</b><small>{c['sub'][1]}</small></div><span class="yes">{'Yes' if lang == 'en' else 'Oui'}</span></div></div>
          <div class="mini"><div class="row"><span class="ci">{ic('wallet')}</span><div><b>{'Rent' if lang == 'en' else 'Loyer'}</b><small>{'Every month · next Dec 1' if lang == 'en' else 'Chaque mois · prochain le 1 déc.'}</small></div><span class="amt">3,000 DH</span></div></div>
        </div></div>
      <div class="card w2 rv" style="--d:1"><span class="eyebrow">{c['move'][0]}</span><h3>{c['move'][1]}</h3><p>{c['move'][2]}</p>
        <div class="art"><div class="mini"><div class="row"><span class="ci">{ic('move')}</span><div><b>{'Groceries → Café' if lang == 'en' else 'Courses → Café'}</b><small>{'This month only' if lang == 'en' else 'Ce mois seulement'}</small></div><span class="amt">200 DH</span></div><div class="bar"><i style="--w:72%"></i></div></div></div></div>
      <div class="card w2 rv"><span class="eyebrow">{c['export'][0]}</span><h3>{c['export'][1]}</h3><p>{c['export'][2]}</p>
        <div class="art"><div class="paper"><b>Bztam</b>Oct 25 – Nov 24<div class="ln"></div><div class="ln g"></div><div class="ln s"></div><div class="ln"></div></div><div class="csv">Date;Amount;Shop<br>2026-11-03;-{money};Marjane<br>2026-11-05;-38,00;Café</div></div></div>
      <div class="card w2 rv" style="--d:1"><span class="eyebrow">{c['sync'][0]}</span><h3>{c['sync'][1]}</h3><p>{c['sync'][2]}</p>
        <div class="art"><div class="sync"><div class="ph"></div><div class="cloud">{ic('cloud')}</div><div class="ph"></div></div></div></div>
      <div class="card w2 rv" style="--d:2"><span class="eyebrow">{c['lock'][0]}</span><h3>{c['lock'][1]}</h3><p>{c['lock'][2]}</p>
        <div class="art"><div class="lockcard">{ic('lock')}</div></div></div>
      <div class="card w3 rv"><span class="eyebrow">{c['dark'][0]}</span><h3>{c['dark'][1]}</h3><p>{c['dark'][2]}</p>
        <div class="art duo">
          <div class="device sm"><div class="island"></div><div class="screen"><img class="force" src="{base}assets/screens/{lang}-insights-light.webp" alt="" loading="lazy"></div></div>
          <div class="device sm"><div class="island"></div><div class="screen"><img class="force" src="{base}assets/screens/{lang}-insights-dark.webp" alt="" loading="lazy"></div></div>
        </div></div>
      <div class="card w3 rv" style="--d:1"><span class="eyebrow">{c['share'][0]}</span><h3>{c['share'][1]}</h3><p>{c['share'][2]}</p>
        <div class="art" style="flex-direction:column;align-items:center">
          <div class="mini"><div class="row"><span class="ci">{ic('share')}</span><div><b>{'Inwi bill.pdf' if lang == 'en' else 'Facture Inwi.pdf'}</b><small>{'Shared to Bztam' if lang == 'en' else 'Partagée vers Bztam'}</small></div><span class="amt">200 DH</span></div></div>
          <div class="langs" style="margin-top:14px"><span class="on">{c['lang'][1]}</span><span>Darija</span></div>
        </div></div>
    </div>
  </div>
</section>

<section class="sec" id="privacy" style="padding-top:20px">
  <div class="wrap">
    <div class="privacy rv">
      <div><span class="eyebrow">{t['pv_eye']}</span><h2>{t['pv_h']}</h2><p>{t['pv_lead']}</p></div>
      <div class="pv">{pv}</div>
    </div>
  </div>
</section>

<section class="final">
  <div class="wrap">
    <img class="rv" src="{base}icon.png" alt="Bztam">
    <h2 class="rv" style="--d:1">{t['final_h']}</h2>
    <p class="lead rv" style="--d:2">{t['final_lead']}</p>
    <span class="store rv" style="--d:3">{ic('apple')}<span><small>{t['store'][0]}</small>{t['store'][1]}</span></span>
  </div>
</section>
</main>
""" + footer(t, lang)


def legal(lang, page):
    t = T[lang]
    body = (CONTENT / f"{lang}-{page}.html").read_text().replace("SUPPORT_EMAIL", EMAIL)
    title = {"privacy": ("Bztam privacy policy", "Bztam : confidentialité"), "terms": ("Bztam terms of use", "Bztam : conditions d'utilisation"),
             "support": ("Bztam support", "Bztam : aide")}[page][0 if lang == "en" else 1]
    return head(t, lang, title, t["desc"]) + nav(t, lang, home=False) + \
        f'<main class="wrap doc">{body}</main>\n' + footer(t, lang)


for lang in ("en", "fr"):
    out = SITE if lang == "en" else SITE / "fr"
    out.mkdir(exist_ok=True)
    (out / "index.html").write_text(home(lang))
    for page in ("privacy", "terms", "support"):
        (out / f"{page}.html").write_text(legal(lang, page))
print("Built website/ with support email:", EMAIL)
