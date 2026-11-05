# Neues Design – Fahrplan

> **Für Agenten:** Dies ist ein Design-Fahrplan, kein Code-Plan. Jede Phase endet mit
> einer **Abnahme durch Luka**. Die nächste Phase beginnt erst nach seinem Okay. Bis
> Phase 8 wird kein App-Code geändert. Den Code-Plan schreibt Phase 8 mit
> superpowers:writing-plans (TDD, Branch).

**Ziel:** Die Geschenke-App bekommt ein eigenes Design, das sich anfühlt wie die
Umarmung beim Schenken (Geborgenheit, Sicherheit, Vertrauen) und nicht nach
KI-Standard aussieht.

**Vorgehen:** Wir erfinden keinen Stil am Reißbrett, sondern leiten ihn aus echten
Vorbildern ab: Moodboard → Marke → Grundsystem → Herzstück Wischkarte → übrige Screens →
Bewegung. Entwürfe sieht Luka in Handygröße im Browser, ab Phase 3 auch direkt auf dem
iPhone.

**Technik:** SwiftUI, iOS 26 (`project.yml`: `deploymentTarget iOS "26.0"`), damit ist
Liquid Glass ohne Einschränkung nutzbar. Entwürfe als HTML über den Visual-Companion-Server
(`--project-dir C:/Claude/Apps/geschenke-app`).

**Spec:** `docs/superpowers/specs/2026-11-02-geschenke-app-design.md`, Abschnitt
„Aussehen“ (seit 03.11. offen).

## Feste Vorgaben

- Gefühl, Lukas Wortlaut: „wie die Umarmung welche man beim Geschenk geben bekommt.
  ein Gefühl von Geborgenheit, Sicherheit und Vertrauen“
- Kein KI-Look. Prüfliste: `docs/design/ki-look-checkliste.md` (Phase 0)
- Alle Grundbausteine aus `CLAUDE.md` gelten weiter. Nr. 12 (Nachtblau & Gold) hat
  Luka am 03.11. gestrichen.
- Texte lesbar: Kontrast mindestens 4,5 (bestehende Funktion `kontrast()` in
  `Designs.swift`), Dynamic Type muss weiter funktionieren
- Nur kostenlose Schriften und Bilder (Grundbaustein 11), z. B. Google Fonts (OFL) in die
  App einbetten
- Umlaute in allen Texten korrekt

## Worauf beim Prüfen achten

1. **Echte Produktfotos sind unordentlich** (weißer Hintergrund, Freisteller, Querformat,
   niedrige Auflösung). Jeder Karten-Entwurf wird mit echten Fotos aus dem Katalog
   gezeigt, nicht mit schönen Beispielbildern.
2. **Lange deutsche Wörter und Namen** („Kuscheltiere“, „Weihnachtsgeschenk“, Profil
   „Oma Gertrud“) dürfen weder umbrechen noch abgeschnitten werden, auch nicht bei
   großer Schrift.
3. **Leere Zustände** (keine Profile, Merkliste leer, Server wacht auf) gehören zum
   Design und werden in Phase 5 mit entworfen.
4. **Hell und dunkel:** Festlegen, ob das Design beides kann oder bewusst nur eins.
   iPhones stehen nachts oft im Dunkelmodus.
5. **Bewegung reduzieren:** Wer in iOS „Bewegung reduzieren“ eingeschaltet hat, bekommt
   ruhige Übergänge ohne Wackeln.

---

### Phase 0: Ausgangslage festhalten

- [x] **Luka:** Screenshots der aktuellen App vom iPhone: Start, Chat, Wischkarte,
      Merkliste, Profil, „Was ich gelernt habe“. Ablage: `docs/design/vorher/`
- [x] **Claude:** `docs/design/ki-look-checkliste.md` aus der Recherche vom 03.11.
      (Farbstreifen an Karten, ✨, Leuchten und Verläufe ohne Grund, Großbuchstaben über
      Überschriften, gleiche Kachel-Raster, Karte in Karte, nur Systemschrift, Emojis als
      Symbole, Rand plus Schatten zugleich)
- [x] **Claude:** jeden Vorher-Screenshot gegen die Liste prüfen und die Treffer notieren
- [x] **Abnahme:** Luka bestätigt Liste und Treffer

### Phase 1: Moodboard aus echten Dingen

- [x] **Luka:** 5–10 Dinge außerhalb von Apps, die sich nach „Umarmung“ anfühlen: Orte,
      Läden, Verpackungen, Filme, Fotos, Gegenstände. Als Foto, Link oder Beschreibung.
- [x] **Claude:** echte Screens veröffentlichter Apps sammeln (App-Store-Screenshots,
      keine Konzeptbilder), die Wärme oder Vertrauen ausstrahlen. Nicht nur Geschenk-Apps,
      auch Banking, Tagebuch, Familie oder Kochen.
- [x] **Claude:** alles auf einer Browser-Seite zeigen; Luka markiert „liebe“ und
      „hasse“
- [ ] **Neu (03.11.):** Gratis-Illustrationspaket wählen (Kandidaten in `docs/design/moodboard.md`)
- [ ] **Claude:** aus den Markierungen 3–5 Stichwörter ableiten (z. B. „Papier statt
      Glas“) und je Stichwort sagen, woran man es im Bild erkennt
- [ ] **Abnahme:** Luka bestätigt Stichwörter und Moodboard. Ablage:
      `docs/design/moodboard.md`

### Phase 2: Marke

- [ ] **Name der App** (bisher Arbeitstitel): Claude schlägt 8–10 Namen passend zu den
      Stichwörtern vor und prüft jeden kurz auf Kollisionen im App Store; Luka wählt
      oder bringt eigene.
- [ ] **Tonfall:** Wie spricht die App? Drei Beispielsätze in zwei Varianten (Begrüßung,
      leere Merkliste, Fehler „Server wacht auf“); Luka wählt.
- [ ] **App-Icon:** 2–3 Skizzen im Browser
- [ ] **Abnahme:** Name, Tonfall, Icon-Richtung

### Phase 3: Grundsystem

Alles wird am iPhone angesehen: Companion-Server mit `--host 0.0.0.0`, Luka öffnet die
Adresse im WLAN auf dem Handy.

- [ ] **Schrift:** 2–3 Paare (Überschrift + Fließtext) mit echten App-Texten; Luka wählt
- [ ] **Farben:** 2 Paletten, abgeleitet aus dem Moodboard, jede mit Kontrast-Werten;
      Luka wählt
- [ ] **Formen:** Ecken, Abstände, Rand oder kein Rand, Symbole (SF Symbols oder eigene)
- [ ] **Liquid Glass:** wo ja (Navigation, schwebende Knöpfe), wo nein
- [ ] **Hell/dunkel:** entscheiden (siehe Prüfpunkt 4)
- [ ] **Die 8 bisherigen Designs in den Einstellungen:** behalten, reduzieren oder
      streichen? Luka entscheidet.
- [ ] **Abnahme:** Grundsystem als eine Übersichtsseite

### Phase 4: Herzstück Wischkarte

- [ ] **Claude:** 2–3 Varianten der Wischkarte mit dem Grundsystem, jeweils mit 5 echten
      Katalog-Produkten (auch ein hässliches Foto, ein langer Titel, eine Ideenkarte ohne
      Foto)
- [ ] **Luka:** wählt eine, sagt, was fehlt
- [ ] **Claude:** eine überarbeitete Fassung, bis es passt
- [ ] **Abnahme:** Wischkarte

### Phase 5: Übrige Screens

- [ ] Start (Kacheln behalten oder ersetzen?), Chat, Merkliste, Profil, „Was ich gelernt
      habe“, Budget-Regler, Einstellungen, alle leeren Zustände
- [ ] Luka geht jeden Screen am iPhone durch
- [ ] Jeder Screen wird gegen `ki-look-checkliste.md` geprüft; Treffer werden behoben,
      bevor Luka ihn sieht
- [ ] **Abnahme:** alle Screens

### Phase 6: Bewegung und Haptik

- [ ] Kurze Clips oder klickbare Prototypen: Wischen, Merken (mit Vibration), Karte
      zurück, Übergänge zwischen Screens, Laden
- [ ] Regeln: Routine-Animationen unter 300 ms, Vibration nur bei Entscheidungen
      (Merken, Profil gespeichert), „Bewegung reduzieren“ beachten
- [ ] **Abnahme:** Bewegung

### Phase 7: Design-Dokument

- [ ] Abschnitt „Aussehen“ im Spec neu schreiben: Stichwörter, Name, Tonfall, Schrift,
      Farben, Formen, alle Screens, Bewegung, Links zu den Mockups
- [ ] Prüfung durch einen frischen Subagenten (Builder-Check); offene Fragen in einer
      Runde an Luka
- [ ] Wenn Luka will: neuen Grundbaustein „Aussehen“ formulieren (nur Luka ändert
      Grundbausteine)
- [ ] **Abnahme:** Luka segnet das Dokument ab

### Phase 8: Umsetzung

- [ ] Code-Plan mit superpowers:writing-plans (Branch `design-neu`, TDD für den Kern,
      z. B. Paletten- und Kontrast-Tests in `GeschenkeCore`)
- [ ] Umsetzung nach Lukas Wahl (Subagenten oder selbst)
- [ ] Build über GitHub Actions, Test über SideStore auf Lukas iPhone
- [ ] Feinschliff-Runde nach Lukas iPhone-Eindruck
- [ ] Merge nach `main` nur mit Lukas Okay
