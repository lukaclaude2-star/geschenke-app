"""Feste Schlagwörter, die Verschlagwortung, Profil und Ranking gemeinsam benutzen.

Nur was hier steht, darf in Katalog und Profil landen. So passen Produkt-Schlagwörter
und Gesprächs-Schlagwörter garantiert zusammen.
"""

# Version des Vokabulars: steckt im Inhalts-Hash, damit der Katalog nach einer Änderung
# einmal komplett neu verschlagwortet wird.
VOKABULAR_VERSION = 2

# Oberbereiche: Gibt es zu einem Stichwort zu wenig, zählen Produkte aus demselben Bereich
# als schwächere Treffer (Whisky-Fan → auch Wein, Gin, Feinkost).
BEREICHE: dict[str, str] = {
    "kueche": "🍳 Küche & Kochen",
    "genuss": "🍷 Genuss & Getränke",
    "sport": "🏅 Sport & Ballsport",
    "outdoor": "🏔️ Outdoor & Natur",
    "fahrzeuge": "🚗 Fahrzeuge & Motor",
    "wellness": "🧘 Wellness & Gesundheit",
    "beauty": "💄 Beauty & Pflege",
    "mode": "👗 Mode & Stil",
    "wohnen": "🛋️ Wohnen & Zuhause",
    "garten": "🌱 Garten & Pflanzen",
    "handwerk": "🔨 Handwerk & DIY",
    "kreativ": "🎨 Kreativ",
    "musik": "🎵 Musik",
    "gaming": "🎮 Gaming & Technik",
    "popkultur": "🎬 Film & Popkultur",
    "spiele": "🎲 Spiele & Rätsel",
    "wissen": "📚 Wissen & Lesen",
    "tiere": "🐾 Tiere",
    "kultur": "🌍 Kultur & Reisen",
    "lebensstil": "💚 Lebensstil & Werte",
    "alltag": "💼 Arbeit & Alltag",
}

THEMEN_NACH_BEREICH: dict[str, dict[str, str]] = {
    "kueche": {
        "kochen": "🍳 Kochen", "backen": "🧁 Backen", "grillen": "🔥 Grillen", "pizza": "🍕 Pizza",
        "sushi": "🍣 Sushi", "asiatische_kueche": "🥢 Asiatische Küche",
        "italienische_kueche": "🍝 Italienische Küche", "vegetarisch": "🥗 Vegetarisch",
        "vegan": "🌱 Vegan", "gewuerze": "🧂 Gewürze", "chili": "🌶️ Chili & Scharf",
        "kochmesser": "🔪 Kochmesser", "kuechengeraete": "🥘 Küchengeräte",
        "fermentieren": "🫙 Fermentieren", "brot_backen": "🍞 Brot backen",
    },
    "genuss": {
        "tee": "🍵 Tee", "kaffee": "☕ Kaffee", "wein": "🍷 Wein", "bier": "🍺 Bier",
        "whisky": "🥃 Whisky", "gin": "🍸 Gin", "cocktails": "🍹 Cocktails", "sekt": "🥂 Sekt",
        "likoer": "🍶 Likör", "schokolade": "🍫 Schokolade", "suesses": "🍬 Süßes",
        "feinkost": "🧺 Feinkost", "olivenoel": "🫒 Olivenöl", "kaese": "🧀 Käse",
        "honig": "🍯 Honig", "alkoholfrei": "🧃 Alkoholfrei",
    },
    "sport": {
        "sport": "🏅 Sport", "fitness": "💪 Fitness", "laufen": "🏃 Laufen",
        "fussball": "⚽ Fußball", "basketball": "🏀 Basketball", "tennis": "🎾 Tennis",
        "tischtennis": "🏓 Tischtennis", "golf": "⛳ Golf", "american_football": "🏈 American Football",
        "boxen": "🥊 Boxen", "kampfsport": "🥋 Kampfsport", "darts": "🎯 Darts",
        "billard": "🎱 Billard", "bowling": "🎳 Bowling", "schwimmen": "🏊 Schwimmen",
    },
    "outdoor": {
        "wandern": "🥾 Wandern", "outdoor": "🏕️ Outdoor", "camping": "⛺ Camping",
        "angeln": "🎣 Angeln", "klettern": "🧗 Klettern", "bouldern": "🪨 Bouldern",
        "ski": "⛷️ Ski", "snowboard": "🏂 Snowboard", "jagd": "🦌 Jagd",
        "vogelbeobachtung": "🐦 Vogelbeobachtung", "bushcraft": "🪓 Bushcraft", "kanu": "🛶 Kanu",
        "segeln": "⛵ Segeln", "surfen": "🏄 Surfen", "tauchen": "🤿 Tauchen",
    },
    "fahrzeuge": {
        "fahrrad": "🚲 Fahrrad", "auto": "🚗 Auto", "motorrad": "🏍️ Motorrad",
        "oldtimer": "🚙 Oldtimer", "mountainbike": "🚵 Mountainbike", "rennrad": "🚴 Rennrad",
        "motorsport": "🏁 Motorsport", "wohnmobil": "🚐 Wohnmobil", "luftfahrt": "✈️ Luftfahrt",
        "skateboard": "🛹 Skateboard",
    },
    "wellness": {
        "yoga": "🧘 Yoga", "wellness": "🛁 Wellness", "meditation": "🕉️ Meditation",
        "sauna": "🧖 Sauna", "massage": "💆 Massage", "schlaf": "😴 Schlaf", "pilates": "🤸 Pilates",
        "aromatherapie": "🌿 Aromatherapie", "gesunde_ernaehrung": "🥦 Gesunde Ernährung",
    },
    "beauty": {
        "beauty": "💄 Beauty", "make_up": "💋 Make-up", "hautpflege": "🧴 Hautpflege",
        "haarpflege": "💇 Haarpflege", "parfum": "🌸 Parfum", "bartpflege": "🧔 Bartpflege",
        "rasur": "🪒 Rasur",
    },
    "mode": {
        "mode": "👗 Mode", "schmuck": "💍 Schmuck", "uhren": "⌚ Uhren", "taschen": "👜 Taschen",
        "rucksaecke": "🎒 Rucksäcke", "sneaker": "👟 Sneaker", "sonnenbrillen": "🕶️ Sonnenbrillen",
        "streetwear": "🧢 Streetwear", "vintage": "🧥 Vintage", "huete": "🎩 Hüte",
    },
    "wohnen": {
        "deko": "🕯️ Deko", "wohnen": "🛋️ Wohnen", "smart_home": "🏠 Smart Home",
        "kerzen": "🕯️ Kerzen", "lampen": "💡 Lampen", "poster": "🖼️ Poster & Bilder",
        "ordnung": "🗂️ Ordnung", "boho": "🌾 Boho", "kuscheldecken": "🧣 Kuscheldecken",
    },
    "garten": {
        "garten": "🌱 Garten", "pflanzen": "🪴 Pflanzen", "kraeuter": "🌿 Kräuter",
        "gemuesegarten": "🥕 Gemüsegarten", "kakteen": "🌵 Kakteen", "bonsai": "🌳 Bonsai",
        "balkon": "🌼 Balkon", "hochbeet": "🪵 Hochbeet", "insekten": "🐝 Insekten",
    },
    "handwerk": {
        "technik": "🔧 Technik", "heimwerken": "🔨 Heimwerken", "werkzeug": "🧰 Werkzeug",
        "holzarbeiten": "🪚 Holzarbeiten", "druck_3d": "🖨️ 3D-Druck",
        "elektronik_basteln": "🔌 Elektronik basteln", "upcycling": "♻️ Upcycling",
    },
    "kreativ": {
        "kunst": "🎨 Kunst", "basteln": "✂️ Basteln", "handarbeit": "🧶 Handarbeit",
        "fotografie": "📷 Fotografie", "zeichnen": "✏️ Zeichnen", "malen": "🖌️ Malen",
        "aquarell": "💧 Aquarell", "kalligrafie": "🖋️ Kalligrafie",
        "handlettering": "✍️ Handlettering", "toepfern": "🏺 Töpfern", "naehen": "🧵 Nähen",
        "stricken": "🧶 Stricken", "haekeln": "🪡 Häkeln", "sticken": "🪢 Sticken",
        "journaling": "📓 Journaling", "schreiben": "📝 Schreiben",
        "analogfotografie": "🎞️ Analogfotografie",
    },
    "musik": {
        "musik": "🎵 Musik", "gitarre": "🎸 Gitarre", "klavier": "🎹 Klavier",
        "schlagzeug": "🥁 Schlagzeug", "singen": "🎤 Singen", "vinyl": "💿 Vinyl",
        "konzerte": "🎫 Konzerte", "klassik": "🎻 Klassik", "rock": "🤘 Rock",
        "hip_hop": "🎧 Hip-Hop", "metal": "⚡ Metal", "jazz": "🎷 Jazz", "schlager": "🪗 Schlager",
        "musik_produzieren": "🎛️ Musik produzieren", "kopfhoerer": "🎧 Kopfhörer",
    },
    "gaming": {
        "gaming": "🎮 Gaming", "playstation": "🎮 PlayStation", "xbox": "🟩 Xbox",
        "nintendo": "🍄 Nintendo", "pc_gaming": "🖥️ PC-Gaming", "retro_gaming": "👾 Retro-Gaming",
        "virtual_reality": "🥽 Virtual Reality", "e_sport": "🏆 E-Sport", "gadgets": "🔋 Gadgets",
        "drohnen": "🚁 Drohnen", "programmieren": "💻 Programmieren", "smartphone": "📱 Smartphone",
        "smartwatch": "⌚ Smartwatch", "lautsprecher": "🔊 Lautsprecher",
    },
    "popkultur": {
        "film": "🎬 Film & Serien", "anime": "🎌 Anime", "manga": "📖 Manga", "comics": "💥 Comics",
        "superhelden": "🦸 Superhelden", "fantasy": "🐉 Fantasy", "science_fiction": "🚀 Science-Fiction",
        "horror": "👻 Horror", "true_crime": "🕵️ True Crime", "podcasts": "🎙️ Podcasts",
        "k_pop": "💜 K-Pop", "cosplay": "🎭 Cosplay", "achtziger_neunziger": "📼 80er & 90er",
    },
    "spiele": {
        "spiele": "🎲 Spiele", "puzzle": "🧩 Puzzle", "kinder": "🧸 Kinder",
        "brettspiele": "♟️ Brettspiele", "kartenspiele": "🃏 Kartenspiele",
        "pen_and_paper": "🐲 Pen & Paper", "escape_raetsel": "🔐 Escape-Rätsel", "quiz": "❓ Quiz",
        "schach": "♞ Schach", "raetsel": "🧠 Rätsel", "zaubertricks": "🎩 Zaubertricks",
        "lego": "🧱 Lego", "modellbau": "✈️ Modellbau", "modelleisenbahn": "🚂 Modelleisenbahn",
        "tabletop": "⚔️ Tabletop",
    },
    "wissen": {
        "lesen": "📚 Lesen", "krimis": "🔍 Krimis", "sprachen": "🗣️ Sprachen",
        "geschichte": "🏛️ Geschichte", "astronomie": "🔭 Astronomie", "philosophie": "🤔 Philosophie",
        "psychologie": "🧠 Psychologie", "wissenschaft": "🔬 Wissenschaft", "politik": "🗳️ Politik",
        "finanzen": "📈 Finanzen & Börse", "mittelalter": "🏰 Mittelalter",
        "landkarten": "🗺️ Landkarten", "gedichte": "📜 Gedichte", "biografien": "👤 Biografien",
        "persoenlichkeitsentwicklung": "🌟 Persönlichkeitsentwicklung", "dinosaurier": "🦕 Dinosaurier",
    },
    "tiere": {
        "tiere": "🐾 Tiere", "hund": "🐶 Hund", "katze": "🐱 Katze", "pferde": "🐴 Pferde",
        "reiten": "🏇 Reiten", "aquaristik": "🐠 Aquaristik", "voegel": "🦜 Vögel",
        "kleintiere": "🐹 Kleintiere", "reptilien": "🦎 Reptilien", "imkern": "🐝 Imkern",
        "huehner": "🐔 Hühner",
    },
    "kultur": {
        "reisen": "✈️ Reisen", "erlebnis": "🎟️ Erlebnisse", "staedtereisen": "🏙️ Städtereisen",
        "roadtrip": "🛣️ Roadtrip", "backpacking": "🎒 Backpacking", "theater": "🎭 Theater",
        "museen": "🖼️ Museen", "musicals": "🎶 Musicals", "oper_ballett": "🩰 Oper & Ballett",
        "tanzen": "💃 Tanzen", "festivals": "🎪 Festivals", "japan": "🗾 Japan",
        "italien": "🇮🇹 Italien", "frankreich": "🇫🇷 Frankreich", "skandinavien": "❄️ Skandinavien",
    },
    "lebensstil": {
        "nachhaltigkeit": "♻️ Nachhaltigkeit", "fair_trade": "🤝 Fair Trade", "regional": "🏡 Regional",
        "handgemacht": "🤲 Handgemacht", "personalisiert": "✍️ Personalisiert", "luxus": "💎 Luxus",
        "humor": "😂 Humor", "romantik": "❤️ Romantik", "achtsamkeit": "🌙 Achtsamkeit",
        "astrologie": "🔮 Astrologie",
    },
    "alltag": {
        "homeoffice": "💻 Homeoffice", "schreibwaren": "🖊️ Schreibwaren", "fueller": "🖋️ Füller",
        "planer": "📅 Planer",
    },
}

THEMEN: dict[str, str] = {tag: label for themen in THEMEN_NACH_BEREICH.values()
                          for tag, label in themen.items()}
THEMA_BEREICH: dict[str, str] = {tag: bereich for bereich, themen in THEMEN_NACH_BEREICH.items()
                                 for tag in themen}

LEBENSLAGEN: dict[str, str] = {
    "umzug": "📦 Umzug",
    "rente": "🌅 Rente",
    "abi": "🎓 Abi",
    "studium": "📖 Studium",
    "baby": "👶 Baby",
    "hochzeit": "💒 Hochzeit",
    "neuer_job": "💼 Neuer Job",
    "geburtstag_rund": "🎂 Runder Geburtstag",
    "erste_wohnung": "🏠 Erste Wohnung",
    "fuehrerschein": "🚘 Führerschein",
    "ausbildung": "🛠️ Ausbildung",
    "schwangerschaft": "🤰 Schwangerschaft",
    "jahrestag": "💑 Jahrestag",
    "gute_besserung": "🩹 Gute Besserung",
    "einschulung": "🎒 Einschulung",
    "konfirmation_kommunion": "⛪ Konfirmation & Kommunion",
    "abschied": "👋 Abschied",
    "dankeschoen": "🙏 Dankeschön",
}


def vokabular_text() -> str:
    """Themen nach Oberbereich gruppiert – für die Prompts, damit die KI das genaueste
    Stichwort leichter findet."""
    return "\n".join(f"  {bereich}: {', '.join(themen)}" for bereich, themen in THEMEN_NACH_BEREICH.items())


FARBEN: tuple[str, ...] = (
    "schwarz", "weiss", "grau", "rot", "rosa", "orange", "gelb",
    "gruen", "blau", "lila", "braun", "gold", "silber", "bunt",
)

FARB_LABELS: dict[str, str] = {
    "schwarz": "Schwarz", "weiss": "Weiß", "grau": "Grau", "rot": "Rot", "rosa": "Rosa",
    "orange": "Orange", "gelb": "Gelb", "gruen": "Grün", "blau": "Blau", "lila": "Lila",
    "braun": "Braun", "gold": "Gold", "silber": "Silber", "bunt": "Bunt",
}

EIGENSCHAFTEN: dict[str, str] = {
    "alkohol": "Alkohol",
    "suessigkeiten": "Süßigkeiten",
    "lebensmittel": "Lebensmittel",
    "leder": "Leder",
    "plastik": "Plastik",
    "duft": "Duft/Parfüm",
    "tierprodukt": "Tierprodukte",
    "elektronik": "Elektronik",
}


def ist_gueltiger_ausschluss(schluessel: str) -> bool:
    art, _, wert = schluessel.partition(":")
    if art == "thema":
        return wert in THEMEN or wert in LEBENSLAGEN
    if art == "farbe":
        return wert in FARBEN
    if art == "eigenschaft":
        return wert in EIGENSCHAFTEN
    if art == "wort":
        return bool(wert.strip())
    return False


def label_fuer(schluessel: str) -> str:
    art, _, wert = schluessel.partition(":")
    if art == "thema":
        return THEMEN.get(wert) or LEBENSLAGEN.get(wert, wert)
    if art == "farbe":
        return FARB_LABELS.get(wert, wert)
    if art == "eigenschaft":
        return EIGENSCHAFTEN.get(wert, wert)
    if art == "wort":
        return f"„{wert.strip()}“"
    return schluessel


def tag_label(tag: str) -> str:
    """Label eines Wunsch-Tags (Thema oder Lebenslage)."""
    return THEMEN.get(tag) or LEBENSLAGEN.get(tag, tag)


# Wörter, an denen eine Eigenschaft im Text erkannt wird – zusätzlich zum KI-Tag, damit ein
# Ausschluss nicht allein an der Verschlagwortung hängt (Grundbaustein 3).
# Regex, geprüft am Wortanfang (\b davor); \b am Ende nur, wo kurze Wörter sonst zu viel treffen.
EIGENSCHAFT_MUSTER: dict[str, tuple[str, ...]] = {
    "alkohol": (r"alkohol", r"wein(?!acht)", r"sekt\b", r"bier", r"gin\b", r"whisk", r"cocktail",
                r"aperitif", r"aperol", r"lik[öo]r", r"schnaps", r"prosecco", r"champagner", r"rum\b",
                r"wodka", r"vodka", r"spirituose", r"cider", r"tasting", r"brauerei", r"weingut"),
    "suessigkeiten": (r"s[üu](ß|ss)igkeit", r"schoko", r"praline", r"bonbon", r"fruchtgummi",
                      r"lakritz", r"nasch", r"marzipan", r"tr[üu]ffel"),
    "leder": (r"leder",),
    "duft": (r"duft", r"parf[üu]m", r"eau de"),
}
