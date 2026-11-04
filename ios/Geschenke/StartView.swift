import GeschenkeCore
import SwiftUI

/// Startseite (Runde 3, Mischung aus „Kacheln“ und „Anlass“): oben der Countdown zum nächsten
/// Anlass, darunter große Kacheln, unten die Profile mit ihren Stichwörtern – kein Listen-Look.
struct StartView: View {
    @EnvironmentObject private var zustand: AppZustand
    @State private var ziel: WischZiel?
    @State private var zeigeSammel = false
    @State private var zeigeNeueSuche = false
    @State private var zuLoeschen: GespeichertesProfil?

    private var ecken: CGFloat { Look.stil == .deco ? 2 : 18 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                kopf
                AnlassBanner(anlass: naechsterAnlass(heute: Date(), profile: zustand.daten.profile),
                             profilAnzahl: zustand.daten.profile.count,
                             ecken: ecken) { anlassGewaehlt($0) }
                kacheln
                profile
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .nachtblau()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $ziel) { WischZielView(ziel: $0) }
        .navigationDestination(isPresented: $zeigeSammel) {
            SammelAuswahlView(vorauswahl: Set(zustand.daten.profile.map(\.id)))
        }
        .navigationDestination(isPresented: $zeigeNeueSuche) { LaengeView() }
        .confirmationDialog("Profil löschen?", isPresented: Binding(
            get: { zuLoeschen != nil }, set: { if !$0 { zuLoeschen = nil } }
        ), presenting: zuLoeschen) { eintrag in
            Button("„\(eintrag.name)“ löschen", role: .destructive) { zustand.loescheProfile([eintrag.id]) }
        }
    }

    private var kopf: some View {
        HStack {
            Text("Geschenke")
                .font(Look.stil == .pinnwand ? .custom("Noteworthy-Bold", size: 32, relativeTo: .largeTitle)
                                              : .largeTitle.bold())
            Spacer()
            Button {
                zustand.zeigeEinstellungen = true
            } label: {
                Image(systemName: "gearshape").font(.title2).foregroundStyle(Look.leise)
            }
            .accessibilityLabel("Einstellungen")
        }
        .padding(.top, 8)
    }

    private var kacheln: some View {
        VStack(spacing: 10) {
            NavigationLink { LaengeView() } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("✨ Neue Suche").font(.title3.bold())
                        Text("Erzähl mir von der Person").font(.footnote).opacity(0.8)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.title3.bold())
                }
                .foregroundStyle(Look.aufAkzent)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [Look.akzent, Look.akzent.opacity(0.72)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: ecken))
                .shadow(color: Look.akzent.opacity(0.25), radius: 12, y: 6)
            }
            HStack(spacing: 10) {
                let anzahl = zustand.daten.profile.count
                NavigationLink { SammelAuswahlView() } label: {
                    Kachel(symbol: "👨‍👩‍👧", titel: "Für mehrere",
                           unten: anzahl >= 2 ? "\(anzahl) Profile" : "ab 2 Profilen", ecken: ecken)
                }
                .disabled(anzahl < 2)
                .opacity(anzahl < 2 ? 0.55 : 1)
                NavigationLink { MerklisteView() } label: {
                    Kachel(symbol: "♥", titel: "Merkliste",
                           unten: "\(zustand.daten.merkliste.count) gemerkt", ecken: ecken)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var profile: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROFILE")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Look.leise)
                .padding(.top, 6)
            if zustand.daten.profile.isEmpty {
                Text("Noch keine Profile. Nach einer Suche kannst du die Person speichern.")
                    .font(.subheadline)
                    .foregroundStyle(Look.leise)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Look.karte)
                    .clipShape(RoundedRectangle(cornerRadius: ecken))
            }
            ForEach(zustand.daten.profile) { eintrag in
                NavigationLink { ProfilView(profilID: eintrag.id) } label: {
                    ProfilKarte(eintrag: eintrag, ecken: ecken)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Löschen", systemImage: "trash", role: .destructive) { zuLoeschen = eintrag }
                }
            }
        }
    }

    private func anlassGewaehlt(_ anlass: Anlass) {
        let profile = zustand.daten.profile
        switch anlass.art {
        case .geburtstag(let id, _):
            if let eintrag = zustand.profil(id) { ziel = WischZiel(personen: [WischPerson(eintrag)]) }
        case .weihnachten:
            if profile.count >= 2 {
                zeigeSammel = true
            } else if let eintrag = profile.first {
                ziel = WischZiel(personen: [WischPerson(eintrag)])
            } else {
                zeigeNeueSuche = true
            }
        }
    }
}

/// Countdown zum nächsten Anlass mit passendem Knopf.
struct AnlassBanner: View {
    let anlass: Anlass
    let profilAnzahl: Int
    let ecken: CGFloat
    let los: (Anlass) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(anlass.tage == 0 ? "HEUTE" : "NÄCHSTER ANLASS")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Look.leise)
            Text(tageText)
                .font(.system(size: 40, weight: .black, design: Look.stil == .deco ? .serif : .rounded))
                .foregroundStyle(Look.akzent)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(untertitel).font(.headline)
            Button(knopfText) { los(anlass) }
                .buttonStyle(GoldKnopf())
                .padding(.top, 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Look.karte
                RadialGradient(colors: [Look.akzent.opacity(0.32), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 220)
            }
        )
        .overlay(RoundedRectangle(cornerRadius: ecken).stroke(Look.rand))
        .clipShape(RoundedRectangle(cornerRadius: ecken))
    }

    private var tageText: String {
        switch anlass.tage {
        case 0: return anlass.art == .weihnachten ? "Heute 🎄" : "Heute 🎂"
        case 1: return "Morgen"
        default: return "\(anlass.tage) Tage"
        }
    }

    private var untertitel: String {
        switch anlass.art {
        case .weihnachten:
            return anlass.tage == 0 ? "ist Weihnachten" : "bis Weihnachten 🎄"
        case .geburtstag(_, let name):
            return anlass.tage == 0 ? "hat \(name) Geburtstag" : "bis \(genitiv(name)) Geburtstag 🎂"
        }
    }

    private var knopfText: String {
        switch anlass.art {
        case .weihnachten:
            return profilAnzahl >= 2 ? "Für alle suchen" : profilAnzahl == 1 ? "Geschenk suchen" : "Jetzt Geschenk suchen"
        case .geburtstag(_, let name):
            return "Für \(name) suchen"
        }
    }

    /// „Mamas Geburtstag“, aber „Klaus’ Geburtstag“.
    private func genitiv(_ name: String) -> String {
        let letztes = name.lowercased().last
        return ["s", "x", "z", "ß"].contains(letztes) ? name + "’" : name + "s"
    }
}

private struct Kachel: View {
    let symbol: String
    let titel: String
    let unten: String
    let ecken: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(symbol).font(.title2).foregroundStyle(Look.akzent)
            Text(titel).font(.headline).foregroundStyle(Look.text)
            Text(unten).font(.caption).foregroundStyle(Look.leise)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Look.karte)
        .overlay(RoundedRectangle(cornerRadius: ecken).stroke(Look.rand))
        .clipShape(RoundedRectangle(cornerRadius: ecken))
    }
}

private struct ProfilKarte: View {
    let eintrag: GespeichertesProfil
    let ecken: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            Text(String(eintrag.name.prefix(1)).uppercased())
                .font(.headline.weight(.heavy))
                .foregroundStyle(Look.akzent)
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(Look.akzent, lineWidth: 2))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(eintrag.name).font(.headline).foregroundStyle(Look.text)
                    if let geburtstag = geburtstagText {
                        Text("· \(geburtstag)").font(.caption).foregroundStyle(Look.leise)
                    }
                }
                let wuensche = eintrag.profil.wuensche.sorted { $0.gewicht > $1.gewicht }.prefix(3)
                if wuensche.isEmpty {
                    Text(eintrag.profil.zusammenfassung).font(.caption).foregroundStyle(Look.leise).lineLimit(1)
                } else {
                    FlussLayout(abstand: 4) {
                        ForEach(Array(wuensche), id: \.tag) { Abzeichen(text: $0.label) }
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(Look.leise)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Look.karte)
        .overlay(alignment: .leading) { Look.akzent.frame(width: 4) }
        .clipShape(RoundedRectangle(cornerRadius: ecken))
    }

    private var geburtstagText: String? {
        guard let g = eintrag.geburtstag else { return nil }
        let tage = tageBis(tag: g.tag, monat: g.monat, heute: Date())
        switch tage {
        case 0: return "🎂 heute"
        case 1: return "🎂 morgen"
        case ...60: return "🎂 in \(tage) Tagen"
        default: return "🎂 \(g.tag).\(g.monat)."
        }
    }
}

struct EinstellungenView: View {
    @EnvironmentObject private var zustand: AppZustand
    @Environment(\.dismiss) private var schliessen
    @AppStorage(Konfiguration.tokenSchluessel) private var token = ""
    /// Im Zuhause-Stil sind die Einstellungen ein Reiter der Leiste statt eines Blatts.
    var alsReiter = false

    var body: some View {
        NavigationStack {
            Form {
                if zustand.daten.design == Designs.zuhauseID {
                    zuhauseAbschnitte
                }
                Section("Schriftgröße") {
                    Picker("Schriftgröße", selection: Binding(
                        get: { Schriftstufe.aus(zustand.daten.schriftgroesse) },
                        set: { zustand.setzeSchrift($0) }
                    )) {
                        ForEach(Schriftstufe.allCases) { Text($0.titel).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("So sieht Text in der App aus.").foregroundStyle(Look.leise)
                }
                .listRowBackground(Look.karte)

                Section("Design") {
                    ForEach(Designs.alle) { palette in
                        Button {
                            zustand.setzeDesign(palette.id)
                        } label: {
                            HStack(spacing: 12) {
                                HStack(spacing: -6) {
                                    ForEach([palette.hintergrund, palette.karte, palette.akzent], id: \.self) { farbe in
                                        Circle().fill(Color(hex: farbe))
                                            .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                                            .frame(width: 22, height: 22)
                                    }
                                }
                                Text(palette.name).foregroundStyle(Look.text)
                                Spacer()
                                if zustand.daten.design == palette.id {
                                    Image(systemName: "checkmark").foregroundStyle(Look.akzent)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Look.karte)

                Section {
                    SecureField("Server-Token", text: $token)
                } footer: {
                    Text("Nur nötig, wenn der Token nicht schon beim Bauen mitgegeben wurde.")
                }
                .listRowBackground(Look.karte)
            }
            .nachtblau()
            .navigationTitle("Einstellungen")
            .toolbar {
                if !alsReiter { Button("Fertig") { schliessen() } }
            }
        }
    }

    /// Erscheinung, Startbildschirm und Auspacken gibt es nur im Design „Zuhause“.
    @ViewBuilder private var zuhauseAbschnitte: some View {
        Section {
            Picker("Erscheinung", selection: Binding(
                get: { Erscheinung.aus(zustand.daten.erscheinung) },
                set: { zustand.setzeErscheinung($0) }
            )) {
                ForEach(Erscheinung.allCases) { Text($0.titel).tag($0) }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Erscheinung")
        } footer: {
            Text("Automatisch folgt dem Dunkelmodus des iPhones.")
        }
        .listRowBackground(Look.karte)

        Section {
            Toggle("Zum Öffnen tippen", isOn: Binding(
                get: { zustand.daten.startTippen },
                set: { zustand.setzeStartTippen($0) }
            ))
            VStack(alignment: .leading, spacing: 8) {
                Text("Auspacken guter Treffer")
                Picker("Auspacken guter Treffer", selection: Binding(
                    get: { AuspackTempo.aus(zustand.daten.auspacken) },
                    set: { zustand.setzeAuspacken($0) }
                )) {
                    ForEach(AuspackTempo.allCases) { Text($0.titel).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.vertical, 4)
        } header: {
            Text("Geschenk")
        } footer: {
            Text("Ohne Tippen öffnet sich das Geschenk beim Start von selbst. Bei „aus“ verlieren auch gute Treffer ihre Verpackung nur mit dem Wischen.")
        }
        .listRowBackground(Look.karte)
    }
}
