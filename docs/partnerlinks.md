# Partnerlinks – vorbereitet, wartet auf Gewerbe

Stand: 16.11.2026. Alles hier ist gebaut und getestet, aber **aus**, solange die Schalter in Render leer
sind. Bis dahin verhält sich die App genau wie vorher (normale Shop-Links, kein „Anzeige“).

## Was schon fertig ist

| Teil | Datei | Was es macht |
|---|---|---|
| Deeplink-Umbau | `app/partnerlinks.py` (`mit_partnerlink`) | Macht beim Ausliefern der Karten aus `bergfreunde.de/…` einen Awin-Link `awin1.com/cread.php?awinmid=…&awinaffid=…&ued=…`, wenn der Shop in `AWIN_PROGRAMME` steht. Sonst bleibt der Link. |
| „Anzeige“-Abzeichen | `app/karten.py` | Prüft den **umgebauten** Link, also bekommt jede Karte mit Provision automatisch „Anzeige“. |
| Feed-Importer | `app/katalog/awin.py`, `scripts/lade_awin_feeds.py` | Liest Awin-Feeds (CSV, gzip, zip; Legacy- und Enhanced-Spalten), Ramsch-Filter Stufe 1, schreibt `katalog/quellen/awin-<shop>.json` (höchstens 300 je Shop). |
| Amazon-Kennung | `app/ideen.py` (gab es schon) | Hängt `&tag=` an die Suchlinks der Ideenkarten. |
| Tests | `tests/test_partnerlinks.py`, `tests/test_awin_feed.py` | |

Grundbausteine: Provision ändert nur den Link, nie die Reihenfolge (4). Schlüssel und Feed-Adressen
stehen nur in Render/`.env`/GitHub-Secrets (9). Kein `clickref`, keine Nutzerkennung im Link (10).

## Schalter (Render → Environment)

| Variable | Beispiel | Wann |
|---|---|---|
| `AMAZON_TAG` | `copperlid-21` | nach Annahme bei Amazon PartnerNet |
| `AWIN_PUBLISHER_ID` | `1234567` | nach Annahme bei Awin (steht oben rechts im Awin-Konto) |
| `AWIN_PROGRAMME` | `{"bergfreunde.de": 14102, "mydays.de": 14087}` | je Programm, sobald **dieser** Partner dich angenommen hat |
| `AWIN_FEEDS` | `{"mydays": "https://…"}` | nur lokal/`.env` bzw. GitHub-Secret für den Feed-Import, **nicht** in der App |

Eine neue Zeile in `AWIN_PROGRAMME` wirkt nach dem Neustart von Render sofort – ohne Katalog-Lauf und
ohne App-Update. Nur angenommene Programme eintragen: Ein Link zu einem Programm ohne Annahme bringt
keine Provision und kann bei Awin als Regelverstoß gelten.

## Ablauf am Tag X

1. Gewerbe angemeldet → bei Awin als Publisher registrieren (Werbefläche: App + copperlid.de,
   Text unten). Awin verlangt eine einmalige Kaution (laut Awin-Hilfe 5 €, wird mit der ersten
   Auszahlung erstattet – vorher nochmal prüfen).
2. Bei den Partnern bewerben (Liste unten, Erlebnisse zuerst).
3. Je Annahme: Programm-ID aus dem Awin-Händlerprofil (`ui.awin.com/merchant-profile/<ID>`) in
   `AWIN_PROGRAMME` eintragen.
4. Für Partner mit gutem Feed (Erlebnisse!): Toolbox → Create-a-Feed → CSV, „Select All“ → Adresse
   in `AWIN_FEEDS` eintragen, und zwar als **GitHub-Secret** (Repo → Settings → Secrets and
   variables → Actions → `AWIN_FEEDS`, Wert wie oben als JSON). Der nächtliche Katalog-Lauf
   (`.github/workflows/katalog.yml`) lädt die Feeds dann von selbst vor dem Katalogbau. Von Hand
   lokal: `python scripts/lade_awin_feeds.py` → `python scripts/build_katalog.py`.
   Danach prüfen, ob die alten `shop-<name>.json` desselben Shops doppelt sind, und sie dann
   entfernen (Luka fragen).
5. App-Store-Text und „So entstehen die Vorschläge“ prüfen (steht schon drin: „Manche Links sind
   Partnerlinks …“).

## Amazon PartnerNet

Bedingungen aus der Mobile Application Policy
([partnernet.amazon.de/help/operating/mobileapps](https://partnernet.amazon.de/help/operating/mobileapps)):

- App muss **im App Store verfügbar** sein → Anmeldung mit der App erst nach dem Launch.
- kostenlos, alle Amazon-Links ohne Bezahlung erreichbar – passt.
- eigene Inhalte – passt (Gespräch, Lernen, Karten aus anderen Shops).
- **keine Amazon-Seiten in WebViews** – passt: Die App öffnet Links mit `openURL` im System-Browser
  bzw. in der Amazon-App (geprüft 16.11.2026, kein `WKWebView`/`SFSafariViewController` im Code).
  Das muss so bleiben.
- keine Nachahmung der Amazon-Shopping-App, **keine Preisverfolgung/Preisalarme** – nie einbauen.
- Verstoß beendet den Vertrag automatisch.
- Mindestens **3 qualifizierte Verkäufe in 180 Tagen**, sonst wird der Antrag abgelehnt
  ([Application Review Process](https://affiliate-program.amazon.com/help/topic/t21/)). Eigene Käufe zählen nicht.
- Nicht auf der Mobile-Seite, aber im Teilnahmevertrag: der Pflichthinweis (unten). Vor der Anmeldung
  [Teilnahmevereinbarung](https://partnernet.amazon.de/help/operating/agreement/) und
  [Programmrichtlinien](https://partnernet.amazon.de/help/operating/policies/) lesen.

### Pflichtsatz – erst nach der Annahme einbauen

In `rechtliches/rechtliches.json`, Dokument `nutzung`, Abschnitt „Wie die App Geld verdient“, als
zweiten Absatz ergänzen:

```json
"Als Amazon-Partner verdiene ich an qualifizierten Verkäufen."
```

Nicht vorher: Der Satz würde sonst etwas behaupten, das nicht stimmt. Die App bündelt die Datei,
also braucht die Änderung eine neue App-Version (Server allein reicht nicht).

## Welche Shops sich lohnen (Websuche, unbestätigt)

Erst nach dem Login im Awin-Händlerverzeichnis bestätigen – Konditionen ändern sich.

| Shop | Netzwerk | Provision / Cookie | Quelle | Hinweis |
|---|---|---|---|---|
| Jochen Schweizer | Awin (ID 11717) | Content-Partner 11 %, 30 Tage | [Awin-Profil](https://ui.awin.com/merchant-profile/11717) | **zuerst bewerben**; Brand-Bidding verboten |
| mydays | Awin (ID 14087) | Content-Partner 11 %, 30 Tage | [Awin-Profil](https://ui.awin.com/merchant-profile/14087) | **zuerst bewerben** |
| erlebnisgeschenke.de | unklar | – | – | Partnerseite im Shop-Fußbereich prüfen |
| Bergfreunde | Awin (DE vermutlich ID 14102) + eigenes Programm | 30 Tage | [Partnerprogramm-FAQ](https://www.bergfreunde.de/partnerprogramm-faq/), [affi.io](https://affi.io/m/bergfreunde) | welches Profil DE ist, im Verzeichnis klären |
| EMP | Awin (ID 14172) | bis 12 %, 30 Tage | [Awin-Profil](https://ui.awin.com/merchant-profile-terms/14172) | ab 18; **keine Frames** (passt: Browser) |
| Tchibo | Awin (ID 11792) | %, 30 Tage | [Awin-Bedingungen](https://ui.awin.com/merchant-profile-terms/11792) | Ausnahmen für einige Kategorien |
| Notino | unklar (FlexOffers nennt 15 Tage Cookie) | – | [FlexOffers](https://www.flexoffers.com/affiliate-programs/notino-de-at-affiliate-program) | auf Awin nicht gefunden |
| Hugendubel | unklar (früher Affilinet) | früher 4–10 % | [affi.io](https://affi.io/m/hugendubel) | Bücher: Preisbindung, niedrige Provision |
| Etsy (noch nicht im Katalog) | Awin | laut Drittquellen bis 4 %, 30 Tage | [Etsy-Hilfe](https://help.etsy.com/hc/de/articles/360000335987-Das-Affiliate-Programm) | Bewerbung über Awin; Apps nicht ausdrücklich geregelt |

Die übrigen ~195 Shops aus `katalog/shops.json` sind noch nicht geprüft. Am schnellsten geht das nach
dem Awin-Login: Händlerverzeichnis nach Domain durchsuchen. Shops ohne Programm behalten den normalen
Link (erlaubt nach Grundbaustein 2).

## Bewerbungstext für Awin (Werbefläche)

**Name der Werbefläche:** Copperlid – Geschenke finden per Chat (iPhone-App) und copperlid.de

**Art:** Mobile App (iOS) + Website · **Kategorie:** Geschenke, Erlebnisse, Lifestyle · **Land:** DE

**Beschreibung:**

> Copperlid ist eine kostenlose iPhone-App, die Geschenke für eine bestimmte Person findet. Im Chat
> beschreibt man die Person – Hobbys, Lebenslage, Budget, was nicht in Frage kommt. Danach zeigt die
> App passende Produkte und Erlebnisse aus Online-Shops als Karten zum Wischen und lernt aus jedem
> Wisch dazu.
>
> Wir zeigen nur echte, lieferbare Produkte mit Foto, Preis und Beschreibung. Jedes Produkt durchläuft
> vorher einen Qualitätsfilter. Die Provision beeinflusst die Reihenfolge nicht – sortiert wird nur
> danach, wie gut ein Geschenk passt. Dadurch klicken die Nutzer gezielt auf Produkte, die sie wirklich
> verschenken wollen.
>
> Links öffnen sich im normalen Browser (kein In-App-Frame), Partnerlinks sind direkt an der Karte als
> „Anzeige“ gekennzeichnet. Kein Gutschein-, Cashback- oder Incentive-Traffic, kein Suchmaschinen-
> marketing auf Markenbegriffe, keine Pop-ups.
>
> Besonders passen Erlebnisgeschenke, Hobby- und Outdoor-Ausrüstung, Wohnaccessoires und personalisierte
> Geschenke.

**Werbemittel:** Deeplinks und Produktfeeds. **Zielgruppe:** Erwachsene in Deutschland, die ein Geschenk
suchen (Geburtstag, Weihnachten, Jahrestag).

Vor dem Abschicken: App-Store-Link und Screenshots ergänzen, Nutzerzahlen nur nennen, wenn es echte gibt.
