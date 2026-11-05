# Farbpalette „Zuhause“ (Stand 04.11.2026, von Luka im Coco-Test abgenommen)

Zwei Farbwelten: **Abendlicht** (dunkel) und **Hell**. Abgeleitet aus dem Moodboard
(`moodboard.md`). Muster zum Ansehen: `.superpowers/zeigen/ansichten/2026-11-04-coco-test/`
(nicht im Git, Erzeuger `bauen.py`).

Wechsel (Lukas Entscheidung): automatisch nach dem Dunkelmodus des iPhones, dazu ein
Schalter in den Einstellungen (Automatisch / Hell / Abendlicht).

## Oberfläche

| Rolle | Abendlicht | Hell | Wofür |
|---|---|---|---|
| grund | `#23160C` | `#EFE6D6` | Seitenhintergrund |
| karte | `#452C1B` | `#F8F1E5` | Karten, Kacheln |
| karte2 | `#3A2516` | `#E6D9C3` | zweite Kartenstufe |
| text | `#F1E3C6` | `#23160C` | Fließtext, Titel |
| leise | `#C0AE88` | `#7B5930` | Nebentext |
| linie | `#7B5930` | `#23160C` | Linien der Illustrationen* |
| akzent | `#C2721E` | `#C2721E` | Knöpfe, Hervorhebung |
| akzenttext | `#23160C` | `#23160C` | Schrift auf Akzent\*\* |
| licht | `rgba(239,178,73,.22)` | `rgba(239,178,73,.30)` | Lichtinsel oben links (radialer Verlauf) |

\* Linie Abendlicht: Luka hat am 04.11. Cognac `#7B5930` statt `#140C06` gewählt (Coco-Test 2). Fast-Schwarz
hatte auf der Karte nur Kontrast 1,5, die Zeichnungen wurden zu Farbflecken. Schaum `#D7BA81` war
abgelehnt, weil die Linie innen auf Licht und Haut verschwindet (Kontrast 1,0).

\*\* Im Muster stand bei Hell `#FFF6E6`. Auf `#C2721E` ergibt das nur Kontrast ≈ 3,4
(Pflicht: mindestens 4,5), daher auch hier Espresso `#23160C` (≈ 4,8).

Für die App zusätzlich festgelegt (noch nicht im Muster sichtbar):

| Rolle | Abendlicht | Hell |
|---|---|---|
| rand | `#5E3F27` | `#E0D0B5` |
| preis | `#EFB249` | `#9A3A24` |

## Illustrationsfarben (Coco Material)

| Name | Abendlicht | Hell |
|---|---|---|
| rot | `#C9573A` | `#BE4A2E` |
| rotdunkel | `#A2432C` | `#9A3A24` |
| kupfer | `#D7843A` | `#D07A2C` |
| licht | `#EFB249` | `#EFB249` |
| haut | `#E2B98C` | `#EBC499` |
| braun | `#7B5930` | `#7B5930` |
| moos | `#86A04B` | `#7C9A42` |
| moosdunkel | `#5F7A33` | `#566F2D` |
| schaum | `#D7BA81` | `#D7BA81` |
| creme | `#EBD9B4` | `#F6E7C8` |

## Regeln fürs Einfärben (aus Lukas Rückmeldungen)

- Ein Gegenstand = eine Farbe. Nicht krampfhaft viele Farben, keine ungefärbten Reste.
- Lücken in der Zeichnung (z. B. zwischen Arm und Körper) zeigen die Kartenfarbe, nicht
  eine Füllfarbe.
- Mehrere Farben pro Motiv sind erlaubt, Grün darf kräftig sein (Kranz).

Zuordnung je Motiv (genaue Bereichsnummern in `FARBEN` in `bauen.py`):

| Motiv | Grundfarbe | weitere Farben |
|---|---|---|
| Katze (`animals_cat_sleeping2`) | kupfer | – |
| Geschenk auspacken (`unwrap_gift_3`) | licht | haut, braun, rot; 1 Lücke offen |
| Kranz (`christmas_holly_3`) | moosdunkel (Abendlicht: moos) | moos, kleine Bereiche rot; 4 Lücken offen |
| Geschenkstapel (`present_5`) | rot (große + kleine Schachtel) | runde Schachtel licht, flache moos; 3 Lücken offen |
| Familie (`family_love-7`) | kupfer | haut, rot, Rest braun |
| Tee (`food_tea`) | licht | braun, rot; 1 Lücke offen |
