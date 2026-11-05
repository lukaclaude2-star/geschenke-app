# App Store: Recht und Sicherheit – Recherche und Entscheidungen

Stand 05.11.2026. Grundlage für den Plan `docs/superpowers/plans/2026-11-05-app-store-recht.md`.
Keine Rechtsberatung: Das ist eine sorgfältige Recherche, kein Anwalt. Die Punkte mit
**Restrisiko** am Ende sollte Luka bewusst entscheiden.

## Was gilt für diese App

Die App ist kostenlos, verdient aber Geld über Partnerlinks (Awin, später Amazon). Damit
ist sie **geschäftsmäßig**. Das löst fast alle Pflichten unten aus, auch ohne Preis im Store.

| # | Pflicht | Grundlage | Was die App braucht |
|---|---|---|---|
| 1 | Datenschutzerklärung als Link im Store **und** in der App | Apple 5.1.1(i), DSGVO Art. 13 | Text in der App (Einstellungen) und als Webseite |
| 2 | Ausdrückliche Zustimmung, bevor Daten an eine fremde KI gehen | Apple 5.1.2(i), seit Nov. 2025 | Zustimmungs-Bildschirm vor dem ersten Gespräch, widerrufbar |
| 3 | Hinweis „Du sprichst mit einer KI“ | EU AI Act Art. 50(1), gilt seit 02.08.2026 (vom Digital Omnibus nicht verschoben) | Hinweis im Chat und in der Zustimmung |
| 4 | Impressum, höchstens 2 Klicks entfernt, eigener Menüpunkt | § 5 DDG, KG Berlin 5 U 112/23 | Einstellungen → Impressum; dazu Webseite |
| 5 | Werbung kennzeichnen: „Anzeige“ direkt am Partnerlink | § 5a Abs. 4 UWG, § 6 DDG; LG Berlin II 102 O 27/24 (Symbole reichen nicht), OLG München 29 U 2633/24 (Teaser selbst kennzeichnen) | Abzeichen „Anzeige“ auf jeder Karte mit Partnerlink |
| 6 | Hauptkriterien der Reihenfolge erklären, direkt bei den Ergebnissen | § 5b Abs. 2 UWG (Suche über Angebote verschiedener Händler) | Info-Knopf beim Wischen → „So entstehen die Vorschläge“ |
| 7 | Preise als Endpreise, Hinweis auf Versand und Aktualität | PAngV (Werbung mit Preisen) | Hinweis in „So entstehen die Vorschläge“ |
| 8 | Privacy Manifest (`PrivacyInfo.xcprivacy`) mit Gründen für Pflicht-APIs | Apple seit 01.05.2024 (ITMS-91053) | Datei mit UserDefaults-Grund `CA92.1` |
| 9 | Angaben zur Verschlüsselung | US-Exportrecht, App Store Connect | `ITSAppUsesNonExemptEncryption = false` (nur HTTPS) |
| 10 | Händlerstatus (DSA „Trader“) mit Adresse, Telefon, E-Mail öffentlich im Store | EU Digital Services Act, Apple seit 17.02.2025 | Luka in App Store Connect (siehe Checkliste) |
| 11 | Altersfreigabe neu beantworten (13+/16+/18+, Frage nach KI-Chat) | Apple, Pflicht seit 31.01.2026 | Luka in App Store Connect |
| 12 | Löschen ermöglichen, Widerruf erklären | Apple 5.1.1(i), DSGVO Art. 17 | „Alle Daten löschen“ in den Einstellungen |
| 13 | Gewerbe anmelden, bevor Provision fließt | GewO, Steuerrecht | Luka, siehe [[Projekte/gewerbe]] |

Nicht nötig: Konto löschen (es gibt kein Konto), Sign in with Apple (kein Login), Tracking-Abfrage
ATT (kein Tracking), OS-Plattform-Link (EU-Plattform zum 20.07.2025 abgeschaltet),
Barrierefreiheitsstärkungsgesetz (Kleinstunternehmen bei Dienstleistungen ausgenommen),
Datenschutzbeauftragter (weniger als 20 Personen).

## Dienstleister (für die Datenschutzerklärung)

- **Render** (Hosting, Region Frankfurt): seit 06.01.2025 nach dem EU-US Data Privacy Framework
  zertifiziert, Auftragsverarbeitungsvertrag (DPA) unter render.com/dpa.
- **Groq** (KI, USA): speichert Anfragen laut „Your Data“ standardmäßig nicht; zur Fehlersuche
  und Missbrauchsabwehr können Ein- und Ausgaben bis zu 30 Tage protokolliert werden.
  „Zero Data Retention“ lässt sich in den Data Controls einschalten (kostenlos). Daten liegen
  in den USA, Übermittlung über Standardvertragsklauseln. Eine DPF-Zertifizierung habe ich
  **nicht** gefunden. Zum Training mit API-Daten habe ich keine Primärquelle gefunden, deshalb
  steht dazu nichts in der Datenschutzerklärung.
- **Shops**: Produktfotos lädt die App direkt vom Shop-Server. Der Shop sieht dabei die IP-Adresse.
- **Pixabay-Fotos** liegen auf dem eigenen Server (Lizenz erlaubt Nutzung ohne Namensnennung,
  verboten ist nur der Weiterverkauf der Fotos „as is“ und irreführende Nutzung).

## Entscheidungen (Claude, 05.11.2026, Luka kann sie ändern)

1. **Rechtsgrundlage** für das Gespräch ist Art. 6 Abs. 1 lit. b DSGVO (die Person will
   Vorschläge), nicht die Einwilligung. Grund: Eine Einwilligung von Unter-16-Jährigen bräuchte
   die Eltern (Art. 8 DSGVO). Die Zustimmung in der App erfüllt Apples Regel 5.1.2(i).
2. **Ein Text, zwei Orte:** Alle Rechtstexte stehen einmal in `rechtliches/rechtliches.json`.
   Die App zeigt sie offline (für die 2-Klick-Regel unabhängig vom schlafenden Server), der
   Server zeigt sie als Webseiten `/impressum`, `/datenschutz`, `/nutzung`, `/support`,
   `/lizenzen` für App Store Connect.
3. **Lukas Daten** (Name, Adresse, Telefon, E-Mail) sind Platzhalter in eckigen Klammern.
   `scripts/pruefe_store_bereit.py` meldet sie, bis sie ausgefüllt sind.
4. **„Anzeige“ nur bei echten Partnerlinks:** Der Server erkennt Partnerlinks (Awin und
   andere Netzwerke, Amazon mit `tag=`) und setzt `anzeige: true`. Heute sind alle Shop-Links
   normale Links ohne Provision, deshalb zeigt die App heute noch kein Abzeichen.
5. **Produktfotos bleiben direkt vom Shop** (kein eigener Bild-Proxy): Kopieren oder
   Durchreichen der Fotos wäre urheberrechtlich heikler als das direkte Laden. Die IP-Übertragung
   steht in Zustimmung und Datenschutzerklärung (Art. 6 Abs. 1 lit. f).
6. **Server-Schutz:** Drosselung je Verbindung (IP nur gehasht im Arbeitsspeicher), Längengrenzen
   (zu lange Texte werden gekürzt statt abgelehnt, damit die App nicht kaputtgeht),
   Größengrenze für Anfragen, Sicherheits-Header, API-Dokumentation `/docs` aus, keine
   Nutzertexte mehr im Log.

## Sicherheit: Befund vor dieser Runde

- Keine Drosselung: Wer den Token aus der App zieht (der steckt in jeder öffentlichen App),
  kann das Groq-Kontingent leer laufen lassen. Der Token ist nur eine Hürde, kein Schutz.
  Echter Schutz wäre App Attest (braucht das bezahlte Entwicklerkonto, später).
- Keine Längengrenzen: beliebig lange Texte gehen an die KI.
- `/docs` und `/openapi.json` zeigen die ganze Schnittstelle öffentlich.
- Fehler-Logs enthalten bis zu 300 Zeichen KI-Antwort, also Angaben über die beschenkte Person.
- Links aus dem Katalog öffnet die App ungeprüft (auch andere Schemata als https).
- Im Repo und im Verlauf: keine Schlüssel gefunden (geprüft in Task 1).

## Restrisiken (Luka entscheidet)

1. **Produktfotos und Produktdaten der Shops ohne Vertrag.** Auch einfache Produktfotos sind
   urheberrechtlich geschützt. Das direkte Einbinden (ohne Kopie) ist nach EuGH C-392/19
   deutlich weniger riskant als Kopieren, aber nicht null. Sicher wird es erst mit Feeds aus
   Partnerprogrammen (Awin), deren Bedingungen die Bildnutzung erlauben. Empfehlung: zum Start
   nur Shops zeigen, mit denen ein Partnervertrag besteht (passt auch zu Grundbaustein 2).
2. **Versandkosten nicht an der Karte.** Für Preisvergleiche verlangt der BGH (Froogle II)
   Versandkosten direkt am Preis. Die App ist kein Preisvergleich, der Hinweis steht in
   „So entstehen die Vorschläge“. Vorsichtiger wäre „zzgl. Versand“ an jeder Karte.
3. **Öffentliche Adresse.** DSA und Impressum verlangen eine ladungsfähige Anschrift. Ohne
   Firmenadresse ist das die Wohnadresse. Alternativen (Impressum-Service, Geschäftsadresse)
   kosten Geld.
4. **Render Free schläft.** Prüfer bei Apple können 30–60 s Wartezeit als Fehler werten.
   Dafür gibt es den Workflow „Server wachhalten“ (von Hand starten, hält 6 Stunden wach).

## Quellen

- Apple App Review Guidelines (5.1.1, 5.1.2, 3.1.3(e), 4.2): https://developer.apple.com/app-store/review/guidelines/
- Apple 5.1.2(i) und fremde KI: https://techcrunch.com/2025/11/13/apples-new-app-review-guidelines-clamp-down-on-apps-sharing-personal-data-with-third-party-ai
- DSA Trader-Status: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements und https://developer.apple.com/news/?id=a0nevv65
- Altersfreigaben: https://developer.apple.com/news/?id=ks775ehf
- Privacy Manifest / ITMS-91053: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- Verschlüsselung: https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
- EU AI Act Art. 50 nicht verschoben: https://www.goodwinlaw.com/en/insights/publications/2026/08/alerts-technology-dpc-eu-ai-act-transparency-obligations-now-in-force
- Impressum in Apps: https://www.e-recht24.de/impressum/10176-app-impressum.html und https://www.it-recht-kanzlei.de/shopping-apps-recht.html
- Affiliate-Kennzeichnung: https://www.it-recht-kanzlei.de/affiliate-links-korrekte-kennzeichnung.html und https://www.it-recht-kanzlei.de/lgberlin-affiliate-einkaufswagen.html
- Groq „Your Data“: https://console.groq.com/docs/your-data
- Render DPF: https://render.com/changelog/render-achieves-certification-under-the-eu-us-data-privacy-framework und https://render.com/dpa
- Produktbilder: https://ohn.haendlerbund.de/recht/abmahnungen/die-drei-haeufigsten-abmahngruende-produktbildern
- Pixabay-Lizenz: https://pixabay.com/service/license-summary/
- Render und Client-IP: https://feedback.render.com/features/p/send-the-correct-xforwardedfor
