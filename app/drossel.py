"""Drosselung je Verbindung für die Routen, die die KI fragen.

Der App-Token steckt in jeder öffentlichen App und lässt sich herausziehen. Ohne Drosselung
könnte jemand damit das Gratis-Kontingent bei Groq leer laufen lassen, und alle anderen
bekämen nur noch „KI ausgelastet“.

Datensparsam (Grundbaustein 10): Gezählt wird unter einem Hash der IP-Adresse mit einem Salz,
das bei jedem Serverstart neu entsteht. Die Adresse selbst wird nie gespeichert, die Zähler
liegen nur im Arbeitsspeicher und gelten höchstens einen Tag.
"""

from __future__ import annotations

import hashlib
import secrets
import time
from collections.abc import Callable

from starlette.requests import Request

_SALZ = secrets.token_bytes(16)


def schluessel_fuer(request: Request) -> str:
    """Render steht hinter Cloudflare: Alle Anfragen kommen von derselben Proxy-Adresse.
    Die echte Adresse setzt Cloudflare in cf-connecting-ip (vom Client nicht fälschbar)."""
    adresse = (request.headers.get("cf-connecting-ip")
               or request.headers.get("true-client-ip")
               or (request.client.host if request.client else "unbekannt"))
    return hashlib.sha256(_SALZ + adresse.strip().encode()).hexdigest()[:24]


class Drossel:
    """Feste Fenster je Schlüssel: höchstens `pro_minute` je Minute und `pro_tag` je Tag."""

    def __init__(self, pro_minute: int, pro_tag: int, max_schluessel: int = 50_000,
                 uhr: Callable[[], float] = time.time):
        self.pro_minute = pro_minute
        self.pro_tag = pro_tag
        self.max_schluessel = max_schluessel
        self._uhr = uhr
        # Schlüssel → [Minute, Anzahl in der Minute, Tag, Anzahl am Tag]
        self._eintraege: dict[str, list[int]] = {}
        self._tag: int | None = None

    def erlaubt(self, schluessel: str, kosten: int = 1) -> bool:
        jetzt = self._uhr()
        minute, tag = int(jetzt // 60), int(jetzt // 86400)
        if tag != self._tag:
            # Was vom Vortag stammt, fliegt raus (Datenschutzerklärung: höchstens einen Tag).
            self._eintraege = {s: e for s, e in self._eintraege.items() if e[2] == tag}
            self._tag = tag
        eintrag = self._eintraege.get(schluessel)
        if eintrag is None:
            self._platz_schaffen(tag)
            eintrag = self._eintraege[schluessel] = [minute, 0, tag, 0]
        if eintrag[0] != minute:
            eintrag[0], eintrag[1] = minute, 0
        if eintrag[2] != tag:
            eintrag[2], eintrag[3] = tag, 0
        if eintrag[1] + kosten > self.pro_minute or eintrag[3] + kosten > self.pro_tag:
            return False
        eintrag[1] += kosten
        eintrag[3] += kosten
        return True

    def zuruecksetzen(self) -> None:
        self._eintraege.clear()

    def _platz_schaffen(self, tag: int) -> None:
        if len(self._eintraege) < self.max_schluessel:
            return
        for schluessel in [s for s, e in self._eintraege.items() if e[2] != tag]:
            del self._eintraege[schluessel]
        if len(self._eintraege) >= self.max_schluessel:
            # Lieber kurz alle durchlassen als den Speicher volllaufen lassen oder falsch sperren.
            self._eintraege.clear()
