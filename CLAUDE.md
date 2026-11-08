# Geschenke-App – Grundbausteine

Diese Datei wird bei jeder Session in diesem Projekt geladen.
Vollständiges Design: `docs/superpowers/specs/2026-11-02-geschenke-app-design.md`

## Pflicht vor jeder Änderung

Prüfe jede Änderung (Code, Prompts, Daten, Design-Dokument) gegen die Grundbausteine
unten. Würde eine Änderung einen davon verletzen, aufweichen oder umgehen:
**nicht umsetzen, sondern Luka den Konflikt nennen und nachfragen.** Das gilt auch,
wenn die Änderung nur „vorübergehend“ oder „zum Testen“ wäre.

Grundbausteine ändert nur Luka selbst, ausdrücklich. Dann auch das Design-Dokument
anpassen.

## Die Grundbausteine

1. **Nur echte, kaufbare Dinge.** Die KI erfindet keine Produkte. Jede Karte stammt
   aus einer echten Quelle (Feed, später Amazon-API). Einzige Ausnahme: als „Idee“
   gekennzeichnete Amazon-Ideenkarten mit Suchlink.
2. **Jede Karte hat einen funktionierenden Link zum Shop.** Ohne Link keine Karte.
   Gibt es für den Shop ein Partnerprogramm, ist es ein Partnerlink. (Von Luka am
   08.11.2026 gelockert: Start ohne Gewerbe/Awin mit normalen Shop-Links.)
3. **Ausschlüsse sind hart.** Was der Kunde ausschließt („nichts in Schwarz“,
   „kein Alkohol“), wird nie gezeigt – auch nicht bei schwachen Treffern, nicht bei
   Ideenkarten, nicht durch Gewichtung.
4. **Keine Werbeschleuder.** Der Ramsch-Filter (feste Regeln + KI-Geschenk-Note)
   läuft über jedes Produkt, bevor es gezeigt werden kann. Provisionshöhe darf die
   Reihenfolge der Karten nicht beeinflussen.
5. **Vorschläge müssen zur Person passen.** Reihenfolge richtet sich nach den
   Schlagwörtern aus dem Gespräch und dem Wischen – nie zufällig oder beliebig.
6. **Der Kunde behält die Kontrolle über das Lernen.** Gelernte Gewichtung ist auf
   „Was ich gelernt habe“ sichtbar, per Schieberegler änderbar und zurücksetzbar.
7. **Gespräch statt Formular.** Die Person wird im Chat beschrieben; Länge wählbar
   und an den Kunden angepasst; letzte Frage immer „Gibt es sonst noch etwas?“.
   Ausnahme: Das Budget wird per Regler mit Spanne (von–bis) abgefragt.
8. **Profile sind freiwillig.** Niemand muss ein Profil anlegen, um Vorschläge zu
   bekommen. Profile lassen sich per Chat ändern.
9. **Geheimnisse bleiben auf dem Server.** KI- und Partner-Schlüssel stehen nie im
   App-Code oder im Repo.
10. **Datensparsam.** Kein Login. Profile, Merkliste und Gewichtung liegen nur auf
    dem Handy. An die KI geht nur der Gesprächstext, keine Gerätekennung.
11. **Kostenlos im Betrieb**, solange Luka nichts anderes entscheidet.

## Luka etwas zeigen

Alles Visuelle (Entwürfe, Vergleiche, Bildschirmfotos, Vorschauen) zeigst du auf der
Zeigeseite `.superpowers/zeigen/` (nicht im Git), nicht über neue Server oder Dateien.

1. Server läuft? Sonst im Hintergrund starten:
   `python -m http.server 8770 --bind 127.0.0.1 --directory .superpowers/zeigen`
2. Neue Ansicht als Ordner `ansichten/<JJJJ-MM-TT>-<thema>/index.html` anlegen
   (eigenständige Seite, Bilder in denselben Ordner).
   Ist es ein Design-Entwurf: erst den Agenten `design-pruefer` prüfen lassen und
   überarbeiten, bis er FREIGEBEN sagt (höchstens 3 Runden). Seine Noten Luka mitnennen.
3. Anmelden: `python -X utf8 .superpowers/zeigen/anmelden.py <ordner> "<Titel>"`.
   Die Seite springt dann von selbst zur neuen Ansicht.
4. Luka den Link `http://127.0.0.1:8770/` nennen. Er öffnet ihn im integrierten
   Browser von VS Code.

## Design

Vor jeder Arbeit an der Oberfläche (Entwürfe, SwiftUI-Views, Farben, Illustrationen)
`DESIGN.md` lesen. Sie hat Vorrang vor Design-Skills (`swiftui-design-skill`,
`frontend-design`). Was dort als offen markiert ist, entscheidet Luka.
