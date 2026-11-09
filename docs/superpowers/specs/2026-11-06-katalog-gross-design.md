# Runde „Katalog groß“: Kleidung in drei Stufen, Franchises, ≈ 20.000 neue sichtbare Produkte

Stand: 06.11.2026, im Gespräch mit Luka erarbeitet. Branch `katalog-gross` (von `main`).

## Warum

Luka will mehr Auswahl. Heute haben 2267 Produkte Stichwörter, aber Kleidung und Fanartikel
fehlen fast ganz: „schuhe“ 67 Produkte, „jacken“ 2, „sneaker“, „streetwear“, „disney“,
„harry_potter“, „star_wars“ jeweils 0. Wer „trägt gern Stiefel“ oder „liebt Hello Kitty“
sagt, bekommt nichts Passendes.

## Was Luka gesagt und entschieden hat

- Neue Stichwörter, „auf jeden Fall in der Kategorie Bekleidung mit Unterkategorien wie
  Schuhe, Schmuck, Jacken, Shirts usw.“
- Darunter eine weitere Stufe: „Unterkategorie für Schuhe wie Sneaker, Stiefel etc. und dass
  dann halt auch für die anderen Arten.“
- Franchises „wie Hello Kitty“, „mehr Franchises als Hello Kitty, also überlege welche selber“.
- Rund **20.000 neue Produkte**, gemeint als in der App sichtbar. Weil die KI-Note grob
  20–40 % aussortiert, hat Luka entschieden: „dann mach 30000“ (≈ 30.000 sammeln).
- **Spätestens in einer Woche fertig** (bis 13.11.2026), also alle Produkte verschlagwortet
  und in der App zeigbar.
- Dafür ein zweiter KI-Anbieter: **Mistral** (Experiment-Plan). Luka legt das Konto an und gibt
  den Schlüssel, wenn er gebraucht wird.

## Ziele

1. **Drei Stufen im Vokabular** für Kleidung: Bereich → Gruppe → Stichwort,
   z. B. Kleidung → Schuhe → Stiefel. Gruppen auch für Jacken, Oberteile/Shirts, Hosen,
   Schmuck, Taschen, Kopfbedeckungen, Accessoires (genaue Liste: Builder, siehe unten).
2. **Neuer Bereich „Franchises“** mit großen Marken und Welten.
3. **≈ 30.000 neue Produkte**, die den Regel-Filter bestehen (Ziel: ≈ 20.000 davon sichtbar), Schwerpunkt Kleidung, Schuhe,
   Schmuck und Fanartikel, die übrigen Bereiche ebenfalls breiter.
4. Bis 13.11. ist der ganze Katalog (alt + neu) mit dem neuen Vokabular verschlagwortet.
5. Die Karten kommen trotz neunfacher Katalog-Größe so schnell wie heute.

## Nicht-Ziele

- Keine neue Ansicht in der App, in der man sich durch die Stufen klickt. Die Stufen wirken im
  Hintergrund beim Treffen (Claudes Entscheidung, Luka hat ihr nicht widersprochen).
- Keine Awin- oder Amazon-Anbindung. Die neuen Shop-Links bleiben normale Links wie bisher in
  der Testphase.
- Keine Änderung an Chat oder Gesprächsführung außer dem längeren Vokabular im Prompt.

## Anti-Ziele: daran wäre die Runde gescheitert, auch wenn sie technisch läuft

- Ramsch rutscht durch: Billig-T-Shirts, No-Name-Massenware, Ersatzteile, Größen-Einzel-
  varianten als eigene Karten. Grundbaustein 4 gilt für jedes neue Produkt.
- Unechte Fanartikel: Fälschungen oder Fan-Made-Ware mit Markennamen. Nur Shops, die
  Lizenzware verkaufen.
- Ausschlüsse greifen schlechter als heute, z. B. weil ein schneller Filter Fälle übersieht,
  die der alte gefangen hat (Grundbaustein 3).
- Die App wird spürbar langsamer, oder der Render-Free-Dienst stürzt wegen Speicher ab.
- Gesprächs-KI läuft öfter ins Groq-Limit, weil der Prompt mit dem Vokabular zu lang wird.

## Grundbausteine, die diese Runde berührt

- **1 und 2:** Jedes neue Produkt stammt aus einem echten Shop und hat einen funktionierenden
  Link. Wie bisher über `scripts/sammle_shops.py` (robots.txt beachten, JSON-LD).
- **3:** Der umgebaute Ausschluss-Filter muss mindestens dieselben Fälle fangen wie heute.
  Bestehende Tests zu Ausschlüssen bleiben unverändert grün.
- **4:** Ramsch-Filter (Regeln + KI-Note ≥ 6) läuft über jedes neue Produkt.
- **5:** Die neue Gruppen-Stufe ändert nur, *wie nah* ein Treffer zählt, nicht dass die
  Reihenfolge an den Schlagwörtern hängt.
- **10:** An Mistral gehen **nur Produktdaten aus Shops** (Titel, Beschreibung, Kategorie),
  nie Gesprächstext und nichts über Nutzer. Chat, Profil und Ideen bleiben bei Groq. Dass
  Mistral im Gratis-Tarif mit Eingaben trainieren darf, ist deshalb vertretbar.
- **11:** Mistral nur im Gratis-Tarif.

## Wie es gebaut wird: was feststeht

### Vokabular (`app/vokabular.py`)

- Neuer Bereich **„Kleidung“** (Schlüssel z. B. `kleidung`). Die Kleidungs- und Accessoire-
  Stichwörter aus „Mode & Stil“ (schmuck, uhren, taschen, rucksaecke, sneaker, sonnenbrillen,
  huete, socken, krawatten, schals_muetzen, geldboersen, manschettenknoepfe, tracht, jacken,
  schuhe, pyjamas) wandern in die passende Gruppe. Bestehende Schlüssel bleiben erhalten,
  damit Profile und Merklisten auf dem Handy weiter passen. Ein Stichwort, das zur Gruppe wird
  (z. B. `schuhe`, `jacken`, `schmuck`), ist danach der Name der Gruppe.
- Stilrichtungen wie streetwear, vintage, gothic bleiben Stichwörter, keine Gruppe.
- Jede Gruppe ist selbst ein Stichwort. Die KI vergibt das genaueste Stichwort (z. B.
  `stiefel`), der Code ergänzt die Gruppe (`schuhe`) automatisch. So passt ein Wunsch
  „schuhe“ voll auf jeden Stiefel, ein Wunsch „stiefel“ aber nicht voll auf jeden Sneaker.
- Neuer Bereich **„Franchises“**. Die vorhandenen Franchise-Stichwörter (harry_potter,
  star_wars, herr_der_ringe, disney, star_trek) ziehen dorthin um, Schlüssel bleiben gleich.
  Genres (anime, manga, superhelden, fantasy …) bleiben in „Film & Popkultur“.
- Franchise-Auswahl trifft der Builder. Richtschnur: in Deutschland bekannt und mit viel
  Lizenzware in normalen Shops. Mindestens: Hello Kitty, Pokémon, Marvel, Minions, Barbie,
  Lego, Super Mario, Zelda, Peanuts, Simpsons, One Piece, Stranger Things, Friends.
  Weitere nach Ermessen, z. B. Paw Patrol, Peppa Wutz, Die Maus, Sailor Moon, Studio Ghibli,
  Naruto, Dragon Ball, Minecraft, Fortnite, Sonic, Game of Thrones, Batman, Winnie Puuh,
  Snoopy, Sanrio-Figuren, Mickey Mouse, Frozen, Toy Story.
- `VOKABULAR_VERSION` steigt auf 4. Der ganze Katalog wird neu verschlagwortet.
- Jedes neue Stichwort braucht ein Foto (bestehender Test, `scripts/hole_beispielbilder.py`).
  **Franchise-Stichwörter bekommen neutrale Fotos** ohne Markenmotiv (z. B. Kuscheltier,
  Sammelfigur, Fan-Shirt ohne Logo). Gratis-Fotodienste haben dafür kaum etwas, und fremde
  Markenbilder in der App sind rechtlich heikel (Claudes Entscheidung).
- Die Prompt-Liste (`vokabular_text`) darf wie gelernt **keine Überschriften** oder
  Bereichsschlüssel enthalten, sonst vergeben die gpt-oss-Modelle sie als Stichwort.

### Treffen (`app/ranking.py`)

Heute: direkter Treffer voll, sonst stärkster Wunsch im selben Bereich × 0,4. Neu kommt eine
Stufe dazwischen: Wunsch und Produkt in derselben Gruppe, aber verschiedene Stichwörter, zählen
mehr als nur der gleiche Bereich und weniger als ein direkter Treffer. Den genauen Faktor wählt
der Builder (Vorschlag 0,7).

### App

- `scripts/bereiche_fuer_app.py` neu laufen lassen, damit `Bereiche.swift` die neuen Bereiche
  kennt. Die Merkliste nach Kategorien zeigt dann „Kleidung“ und „Franchises“. Danach braucht es
  einen neuen App-Build.
- Sonst keine Änderung an der App.

### Produkte sammeln

- Neue Shops in `katalog/shops.json`, Sammeln über `scripts/sammle_shops.py`. Wenn nötig,
  mehr Produkte je Shop (`--ziel`) statt nur mehr Shops.
- Ziel: **≈ 30.000 neue Produkte, die den Regel-Filter bestehen** (Stufe 1), damit nach der
  KI-Note ≈ 20.000 sichtbar werden. Wie viele danach die
  KI-Note ≥ 6 schaffen, wird gemessen und Luka genannt, nicht durch lockerere Regeln geschönt.
- Schwerpunkt: Kleidung und Schuhe (Marken- und Fachhändler, keine Billig-Marktplätze),
  Schmuck, Taschen, Fanartikel und Lizenzware (offizielle Shops oder große Spielwaren- und
  Merch-Händler). Die übrigen Bereiche ebenfalls breiter machen.
- Gleiche Regeln wie bisher: robots.txt beachten, keine Shops ohne deutschen Sprachpfad
  (englische Seiten fliegen raus), Shopify geht nicht über diesen Weg.
- Größenvarianten (S/M/L, Schuhgröße 38–45) sind eine Karte (`varianten_gruppe`). Bei Kleidung
  besonders darauf achten, sonst flutet ein Shirt in 8 Größen den Stapel.

### Verschlagworten in einer Woche

- Neuer Arbeiter **Mistral** in der Verschlagwortung (`app/katalog/verschlagworten.py`,
  `_parallel`), neben gpt-oss-20b und Qwen. Schlüssel als GitHub-Secret `MISTRAL_API_KEY`
  (und lokal in `.env`), nie im Repo. Mistral spricht eine OpenAI-ähnliche Schnittstelle.
- Mistral nur für den Katalog, nicht in der Chat-Kette.
- Die Gratis-Zahlen von Mistral (≈ 1 Anfrage/s, ≈ 1 Mrd. Token/Monat, Recherche 03.11.,
  unbestätigt) beim ersten echten Aufruf prüfen und in der Wissensnotiz festhalten.
- Grobe Rechnung: rund 33.000 Produkte × ≈ 330 Token in 20er-Stapeln ≈ 11 Mio. Token.
  Das passt in den Mistral-Tarif. Die Grenze ist eher 1 Anfrage/s (≈ 1650 Stapel ≈ 30 min
  reine Wartezeit) und die Qualität.
- **Qualität vor Tempo:** Vor dem großen Lauf eine Stichprobe (z. B. 100 Produkte) mit Mistral
  verschlagworten und mit Qwen/gpt-oss vergleichen: Vergibt es die neuen Stichwörter? Vergibt es
  Überschriften oder erfundene Schlüssel? Hält es das JSON-Format? Welches Mistral-Modell,
  entscheidet der Builder nach dieser Stichprobe.
- Der Nachtlauf (`.github/workflows/katalog.yml`, 120 min Zeitlimit) reicht für 33.000 eventuell
  nicht. Erlaubt: Handläufe, mehrere Läufe hintereinander, längeres Zeitlimit.

### Tempo und Speicher

- Der Ausschluss-Filter mit 21 Regex-Mustern braucht heute ≈ 0,35 s je Anfrage (≈ 2600
  Produkte). Bei ≈ 33.000 wären das ≈ 4–5 s. Umbauen, z. B. die Muster einmal beim Laden je Produkt
  vorberechnen oder zu einem Regex zusammenfassen. Messen: vorher und nachher, Ziel ≤ heute.
- Render Free hat 512 MB Speicher. Katalog mit ≈ 33.000 Produkten laden (inkl. aussortierter, falls die mitgeladen werden) und den Speicher messen,
  bevor gemergt wird.
- `katalog.json` hat heute 3,4 MB, mit ≈ 33.000 Produkten grob 40 MB. Dateien unter 50 MB halten
  (GitHub warnt darüber, Grenze 100 MB). Der Nachtlauf committet die Datei täglich, also wächst
  das Repo. Wenn nötig, Datei aufteilen oder verkleinern (Builder).

## Was der Builder entscheidet

- Genaue Gruppen und Stichwörter unter „Kleidung“. Vorschlag: Schuhe (sneaker, stiefel,
  sandalen, pumps, hausschuhe, laufschuhe …), Jacken, Oberteile (t_shirts, hemden, blusen,
  pullover, hoodies …), Hosen & Röcke, Kleider, Schmuck (ketten, ringe, ohrringe, armbänder …),
  Taschen, Kopfbedeckungen, Accessoires. Nur Stichwörter, für die es echte Produkte gibt.
- Endgültige Franchise-Liste über das Minimum hinaus.
- Gruppen-Faktor im Ranking.
- Welche Shops, wie viele Produkte je Shop.
- Mistral-Modell.
- Wie der Filter schneller wird.

## Erfolg, gemessen

- ≥ 30.000 neue Produkte bestehen den Regel-Filter. Die Zahl mit KI-Note ≥ 6 (Ziel ≈ 20.000)
  wird genannt und nicht durch lockerere Regeln geschönt.
- Bis 13.11. sind alle Produkte mit Vokabular 4 verschlagwortet (`noch_offen` = 0).
- Jede neue Gruppe und jedes Franchise-Stichwort mit mindestens 1 zeigbaren Produkt. Wer weniger
  als 5 hat, steht in einer Liste für Luka.
- Karten-Anfrage nicht langsamer als heute, Speicher unter 512 MB.
- Alle Tests grün (pytest, Swift-Kern, App-Build).

## Ablauf mit Luka

1. Luka gibt den Mistral-Schlüssel, sobald die Stichprobe dran ist.
2. Commits und Merge nach `main` nur mit Lukas Okay (wie immer).
