# Geschenke-App – Design

Stand: 02.11.2026 · Arbeitstitel „Geschenke-App“ (Name noch offen)

## Worum es geht und warum

Luka will eine App, mit der er Geld verdient. Die Idee: eine Suchmaschine für
**persönliche** Geschenke, bedient wie Tinder. Das Nervige an Geschenkesuche ist,
dass ein gutes Geschenk zur Person passen und Bedeutung haben soll – normale Shops
kennen die Person aber nicht. Die App fragt deshalb erst wie ein Freund nach der
Person (Hobbys, Interessen, Lebenslage, Budget) und zeigt dann passende, kaufbare
Geschenke als Karten zum Wischen.

**Geld** kommt über Affiliate-Provision: Jedes Geschenk führt per Partnerlink in
den Shop, Luka bekommt bei einem Kauf ein paar Prozent.

## Ziele

- Vorschläge, die spürbar zur beschriebenen Person passen.
- Nur echte, kaufbare Dinge – Produkte **und** kaufbare Erlebnisse
  (z. B. Kochkurs, Krimi-Dinner) und personalisierte Sachen (z. B. Gravur).
- Jede gezeigte Karte hat einen funktionierenden Partnerlink.

## Nicht-Ziele (erste Version)

- Geburtstags-Erinnerungen (passen später gut zu Profilen).
- Konto/Login, Sync zwischen Geräten.
- Android, Webseite.
- App-Store-Veröffentlichung selbst (Entwicklerkonto kommt später; Luka ist 18).

## Was auf keinen Fall passieren darf

- **Die App wirkt wie eine Werbeschleuder** – Ramsch nur wegen Provision. Dann
  vertraut niemand den Vorschlägen.
- **Vorschläge sind trotz Gespräch beliebig** (Oma gärtnert → Powerbanks).

Möglichst vermeiden, aber kein Totalschaden: ein Ausschluss rutscht vereinzelt
durch (z. B. ein schwarzes Produkt, bei dem die Farbe nirgends steht).

## Ablauf in der App

### 1. Gesprächslänge wählen
Vor dem Gespräch wählt man die Länge: **Schnell (~3 Fragen), Normal (~5),
Gründlich (~8)**. *Zahlen sind meine Wahl, leicht änderbar.*

### 2. Gespräch (Chat)
- Die App stellt Fragen wie ein Freund: für wen, was die Person gern macht,
  Lebenslage, Budget.
- **Passt sich dem Kunden an:** Wer ausführlich schreibt, bekommt mehr und
  genauere Nachfragen; wer knapp antwortet, kommt schneller zum Wischen. Die
  gewählte Stufe ist der Rahmen.
- Bei vagen Antworten darf die KI nachhaken („Musik – eher selbst spielen oder
  Konzerte?“).
- **Letzte Frage immer:** „Gibt es sonst noch etwas, das ich wissen sollte?“
- **Graue Beispiele im Eingabefeld** (Platzhalter), passend zur Frage und zu den
  bisherigen Antworten von der KI formuliert, z. B. „z. B. Gärtnern, Krimis
  lesen …“. Verschwinden beim ersten getippten Zeichen. Keine Antwort-Knöpfe
  zum Antippen.
- Die KI macht daraus im Hintergrund **zwei Listen**:
  - **Wunsch-Schlagwörter** (Garten, Krimis, Rente, bis 50 €) – mit Gewicht.
  - **Ausschlüsse** (nichts in Schwarz, kein Alkohol, keine Süßigkeiten) –
    harte Filter, solche Produkte werden **nie** gezeigt.

### 3. Als Profil speichern (freiwillig)
- Nach dem Gespräch: „Als Profil speichern?“ mit frei wählbarem Namen
  („Oma Gerda“). Muss man nicht.
- **Profil per Chat ändern:** Profil öffnen, schreiben „sie hat jetzt einen Hund“
  oder „Krimis hat sie genug“ → KI passt Wunsch- und Ausschlussliste an.
- Mit einem Profil kann man jederzeit direkt wieder wischen, ohne neues Gespräch.

### 4. Wischen
- Karte zeigt: Bild, Name, Preis, Shop, ein paar Schlagwörter.
- Rechts = gefällt → Merkliste. Links = nein.
- **Endlos**, solange der Kunde will.
- **Lernen:** Schlagwörter von Ja-Karten werden stärker gewichtet. Wird sehr
  einseitig Nein gesagt, gewinnen die wenigen Ja-Karten deutlich an Einfluss.
  *Meine Wahl:* Ein Nein senkt Gewichte leicht, schwächer als ein Ja sie hebt.
- **Gewichtung ansehen und ändern** über ein Symbol oben auf dem
  Wisch-Bildschirm: Bildschirm „Was ich gelernt habe“ mit **Schiebereglern** je
  Schlagwort, darunter die Ausschlüsse, unten „Alles zurücksetzen“
  (Mockup: `.superpowers/brainstorm/…/content/gewichtung.html`, Variante A).

### 5. Merkliste
Liste der Rechts-Karten; jede führt per Partnerlink in den Shop.

## Wo die Produkte herkommen

Die KI erfindet **keine** Produkte. Alles Gezeigte stammt aus echten Quellen:

1. **Partner-Feeds** (z. B. über Awin: Erlebnis-Anbieter wie Jochen Schweizer /
   mydays, Etsy, Geschenke-Shops). Feeds liefern Bild, Preis, Partnerlink und
   dürfen offiziell angezeigt werden.
2. **Einmal täglich verschlagwortet die KI neue Feed-Produkte:** Hobbys/Themen,
   passende Lebenslagen, Preisstufe, „persönlich ja/nein“ **und Eigenschaften für
   Ausschlüsse** (Farbe, Material, Inhaltsstoffe, Alkohol …). Farbe zuerst aus dem
   Feed-Feld, sonst aus der Beschreibung.
3. **Amazon am Anfang nur als Suchlink:** Die KI kann zusätzlich Ideen nennen
   („Kniekissen für die Gartenarbeit“) → Amazon-Suchlink mit Partner-Tag. Diese
   Karten haben kein echtes Produktfoto. Die Amazon-Produktschnittstelle gibt es
   erst nach den ersten Verkäufen – dann nachrüsten.

### Ramsch-Filter (Lukas Entscheidung: Kriterien statt Shop-Handauswahl)
Ganze Feeds dürfen rein, aber jedes Produkt muss zwei Stufen bestehen:

**Stufe 1 – feste Regeln (ohne KI).** Raus fliegt, was
- kein Bild oder nur ein sehr kleines Bild hat,
- keine oder nur eine sehr kurze Beschreibung hat,
- unter ca. 8 € kostet,
- nicht lieferbar ist,
- aus einer gesperrten Kategorie stammt (Ersatzteile, Druckerpatronen, Kabel,
  Medikamente, Hygieneartikel, Erotik – Liste erweiterbar).
Varianten desselben Produkts (Farben/Größen) werden zu einer Karte zusammengefasst.

**Stufe 2 – KI-Geschenk-Note.** Beim täglichen Verschlagworten bewertet die KI
„Würde man das verschenken?“ von 1–10. Unter 6 fliegt raus. Achtet besonders auf
No-Name-Ramsch mit vollgestopften Titeln.

Alle Grenzwerte (8 €, Note 6, Kategorien) sind einstellbar. *Später, mit echten
Nutzern:* Was fast alle nach links wischen, wird seltener gezeigt.

### Kartenauswahl
Auswahl der Karten: Kandidaten nach Ausschlüssen hart filtern, dann nach
gewichteten Schlagwörtern und Budget sortieren, mit etwas Abwechslung, damit nicht
zehnmal dasselbe kommt.

**Wenn passende Produkte ausgehen** *(meine Wahl):* schwächere Treffer zeigen und
ehrlich sagen „Für Oma wird's langsam dünn“. Ausschlüsse gelten immer.

**Amazon-Ideenkarten** *(meine Wahl):* nur wenn Feed-Produkte knapp werden. Gold-
Abzeichen „Idee“, Symbol statt Foto, geschätzter Preisbereich. Die KI beachtet
Ausschlüsse und Budget schon beim Erzeugen der Idee.

## Aussehen

**Entschieden (05.11.2026):** Einziges Design ist „Zuhause“ (Abendlicht und Hell, siehe
`DESIGN.md`); alle anderen Designs sind entfernt.

*Vorher (03.11.2026):* Luka hat den Grundbaustein „Standard ist Nachtblau mit Gold“
gestrichen. Das Design wird neu erarbeitet, weil es nach KI-Standard aussieht.
Gewünschtes Gefühl: wie die Umarmung beim Schenken, also Geborgenheit, Sicherheit
und Vertrauen. Bis dahin bleibt der bisherige Stil in der App.

*Bisher:* **Stil C – dunkel & edel:** Nachtblau-Hintergrund, dunkle Karten, **Gold-Akzente**
(Schlagwörter, Knöpfe, Chat-Blasen der App). Mockup:
`.superpowers/brainstorm/…/content/design-stile.html`, Variante C.

## Technik (meine Entscheidungen, Luka hat ihnen nicht widersprochen)

- **iPhone-App in Swift/SwiftUI**, gebaut ohne Mac über GitHub Actions + XcodeGen,
  zum Testen per SideStore – wie beim Wecker (siehe Vault-Notiz
  `Wissen/iphone-apps-ohne-mac`). Logik möglichst in ein Swift-Paket, das auf
  Linux testbar ist.
- **Kleiner Server** zwischen App und Außenwelt, weil KI- und Partner-Schlüssel
  nicht in die App dürfen. Aufgaben: Gesprächs-Anfragen an die KI weiterreichen,
  Feeds täglich laden und verschlagworten, Karten passend zu Schlagwörtern
  ausliefern. Kostenloser Hosting-Dienst.
- **KI:** kostenlose Kontingente (Vault-Notiz `Wissen/gratis-llm-apis`, z. B.
  Groq). Bei Wachstum umstellen.
- **Kein Login:** Profile, Merkliste und Gewichtungen liegen nur auf dem Handy.
  Nachteil: Handywechsel = Profile weg.

## Umfang der ersten Version (Lukas Entscheidung)

- **Nur Luka testet**, per SideStore. Keine Freunde/Tester → kein Missbrauchs-
  schutz für den Server nötig.
- **Testprodukte statt echter Feeds:** Die KI stellt eine Testliste aus echten
  Shops zusammen (im selben Format wie später die Feeds). Der Ramsch-Filter und
  das Verschlagworten laufen trotzdem schon darüber.
- Echte Awin-/Amazon-Anbindung erst, wenn Luka dort angenommen ist.

## Datenschutz *(meine Wahl)*
Der Server reicht nur den Gesprächstext an die KI weiter, keine Gerätekennung.
Vor einem App-Store-Start neu prüfen (Daten über Dritte wie „Oma Gerda“, DSGVO,
Nutzungsbedingungen des KI-Anbieters).

## Rahmenbedingungen

- Kein Geld für Infrastruktur am Anfang – alles kostenlos.
- Partnerprogramme (Awin, Amazon) müssen Luka erst annehmen; Auszahlungen setzen
  vermutlich das Kleingewerbe voraus (siehe Projekt `gewerbe`). Bis zur Annahme
  braucht die Entwicklung Testdaten.
- Apple prüft Apps, die hauptsächlich Links weiterreichen, streng – Gespräch und
  Lernen sind der eigene Nutzen der App und müssen das tragen.

## Dem Bauenden überlassen

- Wahl des Hosting-Dienstes und der Datenbank für den Server.
- Genaue Gewichtungs-Formel und Abwechslungs-Regel.
- KI-Modell und Prompts.
- Navigation zwischen Start, Profilen, Wischen, Merkliste.
- Format der Testdaten, solange echte Feeds fehlen.
