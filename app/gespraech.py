"""Das Gespräch über die beschenkte Person (Grundbaustein 7).

Feste erste Frage → je nach gewählter Länge 0–6 KI-Fragen → feste Schlussfrage.
Die KI entscheidet innerhalb des Rahmens, ob sie genug weiß: Wer ausführlich antwortet,
bekommt mehr Nachfragen, wer knapp antwortet, kommt schneller zum Wischen.
"""

from app.ki import KiUeberlastet, frage_json
from app.modelle import ChatAnfrage, ChatAntwort, ChatNachricht

ERSTE_FRAGE = "Für wen suchst du ein Geschenk?"
ERSTER_PLATZHALTER = "z. B. meine Oma, 70, hat gerade mit Gärtnern angefangen"
SCHLUSSFRAGE = "Gibt es sonst noch etwas, das ich wissen sollte?"
SCHLUSS_PLATZHALTER = "z. B. sie mag kein Schwarz, hat schon alle Harry-Potter-Bücher"
ALLGEMEINER_PLATZHALTER = "Schreib einfach drauflos …"

# (mindestens, höchstens) KI-Fragen zwischen erster Frage und Schlussfrage
KI_FRAGEN: dict[str, tuple[int, int]] = {"schnell": (0, 1), "normal": (1, 3), "gruendlich": (2, 6)}

SYSTEM = """Du hilfst in einer Geschenke-App, die beschenkte Person kennenzulernen – wie ein
guter Freund, locker und auf Deutsch (du-Form). Ziel: Hobbys, Interessen, Lebenslage, Budget
und alles, was die Person NICHT mag oder nicht darf.

Antworte nur mit JSON: {"genug": true/false, "frage": "...", "platzhalter": "..."}
- frage: genau EINE kurze Frage. Frag nichts, was schon beantwortet ist.
- Ausführliche Antworten → hake genauer nach. Knappe Antworten → eher genug: true.
- Vage Antwort (z. B. "mag Musik") → einmal konkret nachfragen ("eher selbst spielen oder Konzerte?").
- Wenn das Budget noch fehlt, frag danach.
- platzhalter: ein Beispiel, das grau im Eingabefeld steht. Beginnt mit "z. B.", passt zur
  Frage und zu dem, was du schon über die Person weißt. Höchstens 60 Zeichen.
- genug: true, wenn du genug weißt, um passende Geschenke zu finden."""


def verlauf_text(nachrichten: list[ChatNachricht]) -> str:
    return "\n".join(
        f"{'App' if n.rolle == 'app' else 'Kunde'}: {n.text.strip() or '(keine Antwort)'}"
        for n in nachrichten
    )


async def naechster_schritt(a: ChatAnfrage) -> ChatAntwort:
    if not a.nachrichten:
        return ChatAntwort(fertig=False, frage=ERSTE_FRAGE, platzhalter=ERSTER_PLATZHALTER)

    letzte = a.nachrichten[-1]
    if letzte.rolle == "app":
        # Frage steht noch offen (z. B. App nach Absturz neu geladen): einfach wiederholen.
        if letzte.text == ERSTE_FRAGE:
            return ChatAntwort(fertig=False, frage=ERSTE_FRAGE, platzhalter=ERSTER_PLATZHALTER)
        if letzte.text == SCHLUSSFRAGE:
            return ChatAntwort(fertig=False, frage=SCHLUSSFRAGE, platzhalter=SCHLUSS_PLATZHALTER)
        return ChatAntwort(fertig=False, frage=letzte.text, platzhalter=ALLGEMEINER_PLATZHALTER)

    app_fragen = [n.text for n in a.nachrichten if n.rolle == "app"]
    if app_fragen and app_fragen[-1] == SCHLUSSFRAGE:
        return ChatAntwort(fertig=True)

    schluss = ChatAntwort(fertig=False, frage=SCHLUSSFRAGE, platzhalter=SCHLUSS_PLATZHALTER)
    gestellt = len(app_fragen) - 1
    minimum, maximum = KI_FRAGEN[a.laenge]
    if gestellt >= maximum:
        return schluss

    try:
        antwort = await frage_json(SYSTEM, verlauf_text(a.nachrichten), max_tokens=600)
    except KiUeberlastet:
        return schluss

    frage = antwort.get("frage")
    if not isinstance(frage, str) or not frage.strip():
        return schluss
    if gestellt >= minimum and antwort.get("genug") is True:
        return schluss
    platzhalter = antwort.get("platzhalter")
    if not isinstance(platzhalter, str) or not platzhalter.strip():
        platzhalter = ALLGEMEINER_PLATZHALTER
    return ChatAntwort(fertig=False, frage=frage.strip(), platzhalter=platzhalter.strip())
