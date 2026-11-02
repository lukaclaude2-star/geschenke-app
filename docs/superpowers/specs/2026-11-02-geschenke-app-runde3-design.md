# Geschenke-App – Runde 3 (Design)

Stand: 02.11.2026. Grundlage: Lukas Wünsche nach dem Test von 1.0.13.

## Warum

Luka hat seinem Vater „grillt gerne und zockt gerne“ beschrieben – als Stichwort kam nur
Grillzeug (eigentlich „kochen“), Gaming fehlte bei den Karten ganz. Ursache: Es gibt kein
Stichwort „grillen“, und im Katalog steht kein einziges Gaming-Produkt (140 Produkte, davon
91 Erlebnisse). Außerdem wirkt die Startseite wie eine Standard-iOS-Liste, beim Laden der
Wischseite blitzen schwarze Ränder auf, und eine Schriftgrößen-Einstellung fehlt.

## Ziele

1. **Schwarze Ränder weg:** Die Wischseite füllt beim Laden den ganzen Bildschirm.
2. **Schriftgröße einstellbar:** Klein / Normal / Groß / Sehr groß in den Einstellungen, gilt für
   die ganze App, wird gespeichert.
3. **Neue Startseite (Mischung B+D, von Luka freigegeben):** oben Countdown zum nächsten Anlass
   (Weihnachten 24.12. oder Geburtstag aus einem Profil) mit passendem Knopf; darunter goldene
   Kachel „Neue Suche“, zwei Kacheln „Für mehrere“ und „Merkliste“; unten Profilkarten mit
   Initiale, Stichwort-Chips und ggf. „🎂 in N Tagen“. Kein typischer iOS-Listen-Look.
   - Profile bekommen ein **freiwilliges Geburtstagsfeld (Tag + Monat)**.
   - Weihnachten → „Für alle suchen“ (Sammelsuche, alle Profile vorausgewählt; bei einem Profil
     dessen Wischseite, ohne Profile die neue Suche). Geburtstag → „Für <Name> suchen“.
4. **Stichwörter: 220 neue, zusammen 270 in 22 Oberbereichen** (Liste: Mockup
   `stichwoerter.html`, von Luka freigegeben). Jedes Thema gehört zu einem Oberbereich; gibt es
   zu einem Stichwort zu wenig, zählen Produkte aus demselben Oberbereich als schwächere Treffer.
5. **Wünsche ohne Produkte bekommen Ideenkarten:** Hat ein Wunsch der Person (z. B. Gaming) kaum
   passende Produkte, reserviert der Stapel Plätze für Amazon-Ideenkarten zu genau diesem Wunsch.
6. **Erkannte Stichwörter sichtbar:** Nach dem Chat zeigt die App die erkannten Stichwörter als
   Chips, damit Fehlendes auffällt.
7. **Mehr Produkte: insgesamt 50 Shops, keine Shopify-Shops** (Lukas Bedingung). Ein allgemeiner
   Sammler liest Produktdaten (schema.org/JSON-LD) über die Sitemap, beachtet robots.txt und
   lehnt Shopify-Shops ab. Ziel: grob 20–30 Produkte pro Shop. Die Shops werden passend zu den
   Oberbereichen ausgewählt, damit möglichst jeder Bereich echte Produkte bekommt.
8. **Beispielbilder für Ideenkarten:** Ideenkarten bekommen ein passendes Foto von Pexels
   (kostenlos, Schlüssel nur auf dem Server), klar gekennzeichnet als „Beispielbild · Pexels“.
   Ohne Schlüssel bleibt es bei der bisherigen Emoji-Kachel.

## Nicht-Ziele

- Nächtliche Shop-Suche per Cloud-Auftrag (Luka: „lassen wir das erstmal“).
- Echte Partner-Feeds (Awin) – erst nach der Gewerbeanmeldung.
- Shopify-Shops.

## Grundbausteine

- GB 1: Ideenkarten bleiben als „Idee“ gekennzeichnet; das Foto ist als Beispielbild markiert,
  das Produkt selbst ist echt (Amazon-Suche).
- GB 2: Die neuen Shop-Produkte haben – wie die bisherigen Testprodukte – normale Shop-Links,
  bis Awin steht (Testphasen-Regel aus dem ersten Design-Dokument).
- GB 3/4/5: Ausschlüsse, Ramsch-Filter und Ranking gelten unverändert für alle neuen Produkte.
  Oberbereich-Treffer zählen schwächer als echte Treffer.
- GB 9/11: Pexels-Schlüssel nur in Render, Pexels ist kostenlos.

## Entscheidungen des Bauenden (meine Wahl)

- Oberbereich-Treffer zählen 40 % des Wunschgewichts und nur, wenn das Produkt den Wunsch nicht
  direkt trifft.
- „Unterversorgt“ = Wunsch mit Gewicht ≥ 0,5 und weniger als 3 passenden Produkten; pro
  unterversorgtem Wunsch 2 Plätze für Ideen, höchstens die Hälfte des Stapels.
- Vokabular-Version fließt in den Inhalts-Hash → der ganze Katalog wird einmal neu verschlagwortet.
- Countdown: bei Gleichstand gewinnt der Geburtstag; 29.02. zählt in Nicht-Schaltjahren als 28.02.
- Schriftstufen: Klein = .small, Normal = .large (iOS-Standard), Groß = .xLarge, Sehr groß = .xxLarge.
- Katalog-Workflow bekommt 120 Minuten Zeit (vorher 20), weil der erste Lauf über 1.000 Produkte
  verschlagwortet. Was an einem Tag nicht durchgeht, holt der nächste Lauf nach.
- Standard-Runner für den iOS-Build wird macos-15 (macos-26 hing oft in der Warteschlange).
