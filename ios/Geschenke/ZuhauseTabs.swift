import GeschenkeCore
import SwiftUI

enum ZuhauseReiter: Hashable {
    case start, wischen, merkliste, einstellungen
}

/// Leiste im Zuhause-Stil: Start, Wischen, Merkliste, Einstellungen. Die Profile erreicht man
/// über die Startseite (Luka, 04.11.).
struct ZuhauseTabs: View {
    @State private var reiter: ZuhauseReiter = .start

    var body: some View {
        TabView(selection: $reiter) {
            Tab("Start", systemImage: "house", value: ZuhauseReiter.start) {
                NavigationStack { ZuhauseStartView(reiter: $reiter) }
            }
            Tab("Wischen", systemImage: "rectangle.stack", value: ZuhauseReiter.wischen) {
                NavigationStack { ZuhauseWischenListe() }
            }
            Tab("Merkliste", systemImage: "heart", value: ZuhauseReiter.merkliste) {
                NavigationStack { MerklisteView(zumWischen: { reiter = .wischen }) }
            }
            Tab("Einstellungen", systemImage: "gearshape", value: ZuhauseReiter.einstellungen) {
                EinstellungenView()
            }
        }
    }
}

/// Reiter „Wischen“: für wen weitersuchen? Offen auf dem Hintergrund, ohne Kachelflächen.
struct ZuhauseWischenListe: View {
    @EnvironmentObject private var zustand: AppZustand

    var body: some View {
        let profile = zustand.daten.profile
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("wischen").font(.titel(.largeTitle))
                    Text(profile.isEmpty ? "noch niemand gespeichert" : "für wen soll ich weitersuchen?")
                        .font(.zuhause(.subheadline)).foregroundStyle(Look.leise)
                }
                .padding(.top, 8)
                if profile.isEmpty {
                    VStack(spacing: 12) {
                        Image("coco-katze").resizable().scaledToFit().frame(width: 130)
                            .accessibilityHidden(true)
                        Text("Starte eine Suche. Danach kannst du die Person speichern und hier weiterwischen.")
                            .font(.zuhause(.subheadline)).foregroundStyle(Look.leise)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 12).frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(profile.enumerated()), id: \.element.id) { nummer, eintrag in
                            if nummer > 0 { Look.trenner }
                            NavigationLink {
                                WischZielView(ziel: WischZiel(personen: [WischPerson(eintrag)]))
                            } label: {
                                ZuhausePersonZeile(eintrag: eintrag)
                            }
                            .buttonStyle(.plain)
                        }
                        if profile.count >= 2 {
                            Look.trenner
                            NavigationLink {
                                SammelAuswahlView(vorauswahl: Set(profile.map(\.id)))
                            } label: {
                                HStack(spacing: 12) {
                                    Image("coco-familie").resizable().scaledToFit().frame(width: 40, height: 40)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Für mehrere zugleich").font(.zuhause(.headline, .fett)).foregroundStyle(Look.text)
                                        Text("z. B. alle zu Weihnachten").font(.zuhause(.footnote)).foregroundStyle(Look.leise)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(Look.leise)
                                }
                                .frame(minHeight: 62)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                NavigationLink { LaengeView() } label: {
                    Text(profile.isEmpty ? "Gespräch starten" : "Neue Person").font(.zuhause(.headline, .fett))
                        .foregroundStyle(Look.aufAkzent)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Look.akzent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .zuhauseHintergrund()
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Alle Profile (über die Startseite erreichbar).
struct ZuhauseProfileView: View {
    @EnvironmentObject private var zustand: AppZustand
    @State private var zuLoeschen: GespeichertesProfil?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(zustand.daten.profile.enumerated()), id: \.element.id) { nummer, eintrag in
                    if nummer > 0 { Look.trenner }
                    NavigationLink { ProfilView(profilID: eintrag.id) } label: {
                        ZuhausePersonZeile(eintrag: eintrag)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Löschen", systemImage: "trash", role: .destructive) { zuLoeschen = eintrag }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .zuhauseHintergrund()
        .navigationTitle("Deine Leute")
        .confirmationDialog("Profil löschen?", isPresented: Binding(
            get: { zuLoeschen != nil }, set: { if !$0 { zuLoeschen = nil } }
        ), presenting: zuLoeschen) { eintrag in
            Button("„\(eintrag.name)“ löschen", role: .destructive) { zustand.loescheProfile([eintrag.id]) }
        }
    }
}

/// Eine Person: Name, wichtigste Wünsche, Pfeil. Keine Kachel, kein Farbstreifen.
struct ZuhausePersonZeile: View {
    let eintrag: GespeichertesProfil

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eintrag.name).font(.zuhause(.headline, .fett)).foregroundStyle(Look.text)
                Text(beschreibung).font(.zuhause(.footnote)).foregroundStyle(Look.leise).lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(Look.leise)
        }
        .frame(minHeight: 62)
        .contentShape(Rectangle())
    }

    private var beschreibung: String {
        let wuensche = eintrag.profil.wuensche.sorted { $0.gewicht > $1.gewicht }.prefix(3).map { ohneEmoji($0.label) }
        return wuensche.isEmpty ? eintrag.profil.zusammenfassung : wuensche.joined(separator: ", ")
    }
}

extension View {
    /// Karte im Zuhause-Stil: Kartenfarbe, im Hellen mit feinem Rand (nie Rand und Schatten zugleich).
    func zuhauseKarte(ecken: CGFloat) -> some View {
        self.background(Look.karte, in: RoundedRectangle(cornerRadius: ecken))
            .overlay {
                if Look.palette.hell { RoundedRectangle(cornerRadius: ecken).stroke(Look.rand, lineWidth: 1) }
            }
    }
}
