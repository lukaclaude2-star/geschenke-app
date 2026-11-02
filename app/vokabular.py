"""Feste Schlagwörter, die Verschlagwortung, Profil und Ranking gemeinsam benutzen.

Nur was hier steht, darf in Katalog und Profil landen. So passen Produkt-Schlagwörter
und Gesprächs-Schlagwörter garantiert zusammen.
"""

THEMEN: dict[str, str] = {
    "garten": "🌱 Garten",
    "pflanzen": "🪴 Pflanzen",
    "lesen": "📚 Lesen",
    "krimis": "🔍 Krimis",
    "kochen": "🍳 Kochen",
    "backen": "🧁 Backen",
    "gaming": "🎮 Gaming",
    "musik": "🎵 Musik",
    "sport": "⚽ Sport",
    "fitness": "💪 Fitness",
    "wandern": "🥾 Wandern",
    "outdoor": "🏕️ Outdoor",
    "camping": "⛺ Camping",
    "angeln": "🎣 Angeln",
    "fahrrad": "🚲 Fahrrad",
    "laufen": "🏃 Laufen",
    "yoga": "🧘 Yoga",
    "wellness": "🛁 Wellness",
    "reisen": "✈️ Reisen",
    "fotografie": "📷 Fotografie",
    "kunst": "🎨 Kunst",
    "basteln": "✂️ Basteln",
    "handarbeit": "🧶 Handarbeit",
    "technik": "🔧 Technik",
    "film": "🎬 Film & Serien",
    "tiere": "🐾 Tiere",
    "hund": "🐶 Hund",
    "katze": "🐱 Katze",
    "tee": "🍵 Tee",
    "kaffee": "☕ Kaffee",
    "wein": "🍷 Wein",
    "mode": "👗 Mode",
    "schmuck": "💍 Schmuck",
    "deko": "🕯️ Deko",
    "wohnen": "🛋️ Wohnen",
    "kinder": "🧸 Kinder",
    "spiele": "🎲 Spiele",
    "puzzle": "🧩 Puzzle",
    "sprachen": "🗣️ Sprachen",
    "geschichte": "🏛️ Geschichte",
    "astronomie": "🔭 Astronomie",
    "erlebnis": "🎟️ Erlebnisse",
}

LEBENSLAGEN: dict[str, str] = {
    "umzug": "📦 Umzug",
    "rente": "🌅 Rente",
    "abi": "🎓 Abi",
    "studium": "📖 Studium",
    "baby": "👶 Baby",
    "hochzeit": "💒 Hochzeit",
    "neuer_job": "💼 Neuer Job",
    "geburtstag_rund": "🎂 Runder Geburtstag",
}

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
