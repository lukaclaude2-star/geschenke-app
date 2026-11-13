# Neues App-Icon „Geschenk mit Katzenohren“ (H2 mit Augen von H3) – Kurzdesign

Stand 13.11.2026, von Luka freigegeben und eingebaut (Branch `icon-geschenk-ohren`).

## Warum
Luka findet Icon Version 8 hässlich: „zu viele Farben, zu viel Detail, die ganze Idee.
Ich brauche etwas, wo das Auge dran hängen bleibt, wenn man es auf dem Screen sieht.“

## Ziel / Nicht-Ziele
- Ziel: sehr simpel, eine klare Silhouette, kräftiger Kontrast, Fokus auf dem Geschenk.
- Nicht: Licht aus der Box (Luka: „das Licht muss weg“), Schleife (🎁-Look), Schrift,
  liegende Katze, Verläufe.

## Ansätze (betrachtet)
1. Geschenk pur (Deckel auf, Anhänger, Stapel, leuchtendes Band, Wischen) – verworfen,
   Licht unerwünscht, Rest zu beliebig.
2. Katze im Lampenlicht – verworfen („sieht aus wie GitHub“, Katze nicht Kern der App).
3. **Geschenk mit Katzenohren und schlafenden Augen – gewählt.** Bringt Geschenk und
   Wiedererkennung zusammen; Prüfer: H3 (Zweiton) Note 9, H2 (einfarbig) Note 8.

## Das Icon (Vorlage: `.superpowers/zeigen/ansichten/2026-11-13-icon-gruen-2/`, Variante H2)
Luka (13.11.): „die Box muss eine einheitliche Farbe haben, also lass uns H2 nehmen“.
- viewBox 100, Grund Moosgrün `#5F7A33`, Figur mit `translate(-3 -3) scale(1.06)`.
- Ohren `22,35 28,14 42,35` und `58,35 72,14 78,35`, Spitzen gerundet (Kontur 4), Kupfer `#D7843A`.
- Deckel x15 y33 b70 h16 r6 und Box x20 y53 b60 h33,5 r8, beide Kupfer `#D7843A` (einfarbig).
- Band x43 b14 auf Deckel und Box, Creme `#EBD9B4`.
- Schlafende Augen: Bögen `M26.5 67 q6 6 12 0` und `M61.5 67 q6 6 12 0`, Espresso `#23160C`, Strich 5,6 wie H3 (Luka 13.11.: „setz deine Idee um“).
- Alle Farben aus `docs/design/palette-zuhause.md`.

## Was gebaut wird
1. `AppIcon.png` 1024 × 1024 aus dem SVG (ohne eigene Ecken, iOS maskiert).
2. Getönte Fassung `AppIcon-getoent.png` in Graustufen (Band und Augen als Kontrast).
3. DESIGN.md 6a: Version 8 durch H3 ersetzen, Verworfenes kurz nennen.
4. Prüfen: getönte Fassung und Kleinstgröße (Einstellungen/Spotlight) auf der Zeigeseite zeigen.

## Offen / Hinweis
- Startanimation zeigt weiter das 3D-Geschenk mit liegender Katze. Passt nicht mehr 1:1
  zum Icon – eigene Entscheidung später.
- Ausliefern aufs iPhone (Build über GitHub Actions, macOS) erst nach Rückfrage wegen Minuten.
