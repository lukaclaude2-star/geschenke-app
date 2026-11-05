# App Store: Checkliste für Luka

Stand 05.11.2026. Was Claude schon gebaut hat, steht unten unter „Erledigt“. Hintergrund und
Quellen: `recherche.md`. Prüfen, was automatisch prüfbar ist:
`python scripts/pruefe_store_bereit.py --live`

## 1. Vorher klären (nur du)

- [ ] **Gewerbe anmelden**, bevor die erste Provision fließt. Partnerlinks sind gewerblich,
      auch wenn die App gratis ist. Siehe Vault `Projekte/gewerbe` und `Wissen/kleingewerbe-als-schueler`.
- [ ] **Apple Developer Program** (99 $ im Jahr) als Einzelperson. Dein Name steht dann als
      Anbieter im Store.
- [ ] **Welche Adresse wird öffentlich?** Impressum und EU-Händlerstatus (DSA) verlangen eine
      Anschrift, unter der man dir Post zustellen kann, dazu Telefon und E-Mail. Ohne Firmenadresse
      ist das deine Wohnadresse. Eine Geschäftsadresse oder ein Impressum-Service kostet Geld.
- [ ] **Eigene E-Mail für die App** anlegen (z. B. neues Gmail-Konto). Sie steht öffentlich im
      Impressum, im Store und auf der Support-Seite.
- [ ] **App-Name:** „Geschenke“ ist im Store sicher vergeben. Vor der Wahl im Markenregister
      suchen: register.dpma.de und euipo.europa.eu (kostenlos).

## 2. Angaben eintragen (Claude macht das, wenn du sie nennst)

- [ ] Name, Straße, PLZ und Ort, E-Mail, Telefon → `rechtliches/rechtliches.json` (Abschnitt
      `angaben`). Danach stehen sie in App und Webseiten.
- [ ] Hast du eine **Wirtschafts-Identifikationsnummer** oder **USt-IdNr.**: ins Impressum
      (als Kleinunternehmer meist keine USt-IdNr.).

## 3. Groq (2 Minuten, kostenlos)

- [ ] console.groq.com → Settings → **Data Controls → Zero Data Retention** einschalten. Dann
      speichert Groq gar nichts mehr. Sag Claude Bescheid, dann fällt der Satz „bis zu 30 Tage“
      aus Datenschutzerklärung und Zustimmung.

## 4. App Store Connect

- [ ] **Händlerstatus (DSA):** Geschäftlich → Compliance → „Händler“ (Trader) wählen, weil du
      Provision verdienst. Adresse, Telefon, E-Mail bestätigen (Apple schickt Codes an beide).
      Ohne Status ist die App in der EU nicht im Store.
- [ ] **Neue App:** Bundle-ID `de.luka.geschenke`, Sprache Deutsch, Kategorie Lifestyle
      (Zweitkategorie Shopping).
- [ ] **URLs:**
      - Datenschutz: `https://geschenke.onrender.com/datenschutz`
      - Support: `https://geschenke.onrender.com/support`
- [ ] **App-Datenschutz** (das „Etikett“ im Store), passend zum Privacy Manifest in der App:
      - Werden Daten erhoben? **Ja**
      - Typ: **Nutzerinhalte → Andere Nutzerinhalte**
      - Zweck: **App-Funktionalität**
      - Mit der Identität verknüpft? **Nein**
      - Für Tracking verwendet? **Nein**
      - Sonst nichts ankreuzen (keine Kennungen, kein Standort, keine Kontakte, keine Nutzungsdaten).
- [ ] **Altersfreigabe** (neuer Fragebogen): ehrlich beantworten. Wichtig: KI-Chat/Assistent
      **Ja**, Werbung **Ja** (Partnerlinks), nutzergenerierte Inhalte **Nein**, uneingeschränkter
      Webzugriff **Nein** (Shop-Links öffnen Safari, keine Webansicht in der App).
- [ ] **Verschlüsselung:** nichts zu tun, steht in der App (`ITSAppUsesNonExemptEncryption = false`).
- [ ] **Screenshots:** Apple verlangt die größte iPhone-Größe (6,9 Zoll, 1320 × 2868). Mach
      Bildschirmfotos am iPhone 14, Claude bringt sie auf das Format.
- [ ] **Hinweise für die Prüfung** (App Review Information → Notes), auf Englisch einfügen:

```
No account or login is needed.
The app uses a free server that can take up to 60 seconds to wake up on the very first request.
The conversation uses a third-party AI (Groq). Before any data is sent, the app explains what is
shared and asks for explicit consent (Guideline 5.1.2(i)); consent can be withdrawn in Settings.
Product links open the shop in Safari; purchases happen in the shops (Guideline 3.1.3(e)).
Partner links are labeled "Anzeige" (German for "Ad"). Legal notice and privacy policy:
Settings → Datenschutz und Rechtliches.
```

- [ ] **Während der Prüfung:** GitHub → Actions → „Server wachhalten“ → Run workflow (hält 6 Stunden
      wach, danach bei Bedarf neu starten).

## 5. Signieren und Hochladen ohne Mac (Claude baut es, sobald das Konto da ist)

Heute baut die CI unsigniert für SideStore. Für den Store braucht es zusätzlich, alles im
Entwicklerportal und als GitHub-Secrets:
- [ ] Distribution-Zertifikat (Claude erzeugt die Anfrage per `openssl`, du lädst sie hoch)
- [ ] App-Store-Provisioning-Profil für `de.luka.geschenke`
- [ ] App-Store-Connect-API-Schlüssel (Rolle „App Manager“)
Dann lädt ein Workflow den Build zu TestFlight hoch. Erst TestFlight testen, dann einreichen.

## 6. Geld verdienen

- [ ] **Awin** (nach dem Gewerbe): als Werbefläche die App angeben. Feeds aus Partnerprogrammen
      erlauben die Produktfotos. Partnerlinks bekommen in der App automatisch „Anzeige“.
- [ ] **Amazon PartnerNet** (später): Dann muss der Satz „Als Amazon-Partner verdiene ich an
      qualifizierten Verkäufen.“ in „So entstehen die Vorschläge“ (Claude ergänzt). Vorher prüfen:
      Amazon erlaubt Preisangaben nur aus der eigenen Schnittstelle; die geschätzten Preisspannen
      der Ideenkarten müssten dann eventuell weg.

## 7. Restrisiken (bewusst entscheiden)

1. **Produktfotos ohne Vertrag:** Die App bindet Fotos der Shops direkt ein (keine Kopie). Das ist
   deutlich weniger riskant als Kopieren, aber nicht null. Am sichersten: zum Start nur Shops,
   mit denen ein Partnervertrag besteht.
2. **Versandkosten nicht an der Karte**, nur in „So entstehen die Vorschläge“. Vorsichtiger wäre
   „zzgl. Versand“ direkt am Preis.
3. **Öffentliche Adresse** (siehe oben).
4. **Kein echter Schutz des App-Tokens:** Er steckt in jeder öffentlichen App. Die Drosselung
   begrenzt den Schaden. Echter Schutz (App Attest) geht erst mit dem bezahlten Konto.

## 8. Am iPhone testen (nächste SideStore-Version)

- [ ] Neue Suche → erst „bevor wir loslegen.“, „Nicht jetzt“ geht zurück, „Einverstanden“ startet.
- [ ] Gespeichertes Profil wischen nach Widerruf → wieder die Zustimmung.
- [ ] Profil per Chat ändern ohne Zustimmung → Zustimmung als Blatt, danach wird gesendet.
- [ ] Chat zeigt oben „Du schreibst mit einer KI. Sie kann sich irren.“
- [ ] Einstellungen → Datenschutz und Rechtliches: Impressum, Datenschutzerklärung, So entstehen
      die Vorschläge, Hilfe und Kontakt, Lizenzen lesbar, Links tippbar.
- [ ] Beim Wischen oben das Info-Symbol → „So entstehen die Vorschläge“.
- [ ] „Alle Daten löschen“ → Rückfrage, danach leer, Einführung kommt nicht wieder.
- [ ] Das Token-Feld in den Einstellungen ist weg.

## Erledigt (Claude, 05.11.2026, Zweig `app-store-recht`)

- Zustimmung vor dem ersten KI-Kontakt, widerrufbar (Apple 5.1.2(i)); KI-Hinweis im Chat (AI Act)
- Impressum, Datenschutzerklärung, „So entstehen die Vorschläge“, Hilfe, Lizenzen: in der App
  (offline, 2 Tipper) und als Webseiten
- „Anzeige“ an Partnerlinks (Karte und Merkliste), Erklärung der Reihenfolge beim Wischen
- „Alle Daten löschen“ (auch alte Sicherungsdateien)
- Privacy Manifest, Verschlüsselungs-Angabe, CI prüft beides in jedem Build
- Server: Drosselung je Verbindung, Längen- und Größengrenzen, Sicherheits-Header, `/docs` aus,
  keine Nutzertexte mehr im Log, nur Web-Links werden geöffnet
- Abhängigkeits-Prüfung (`pip-audit`) in der CI, Geheimnis-Scan über den Git-Verlauf (sauber)
- Workflow „Server wachhalten“ für die Prüfphase
