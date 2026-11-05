import GeschenkeCore
import SwiftUI

/// Startseite: Begrüßung, eine große Hauptkarte mit der schlafenden Katze, Anlasszeile, zuletzt
/// Gemerktes und die Profile. Nur die Hauptkarte hat eine Fläche (die Katze schläft auf ihr),
/// alles andere steht offen auf dem Hintergrund (Luka, 05.11.2026: „die Kacheln weglassen“).
struct ZuhauseStartView: View {
    @EnvironmentObject private var zustand: AppZustand
    @Binding var reiter: ZuhauseReiter
    @State private var ziel: WischZiel?
    @State private var zeigeSammel = false
    @State private var zeigeNeueSuche = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                kopf
                hauptkarte
                anlassZeile(naechsterAnlass(heute: Date(), profile: zustand.daten.profile))
                zuletztGemerkt
                if !zustand.daten.profile.isEmpty { profile }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .zuhauseHintergrund()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $ziel) { WischZielView(ziel: $0) }
        .navigationDestination(isPresented: $zeigeSammel) {
            SammelAuswahlView(vorauswahl: Set(zustand.daten.profile.map(\.id)))
        }
        .navigationDestination(isPresented: $zeigeNeueSuche) { LaengeView() }
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(begruessung(stunde: Calendar.current.component(.hour, from: Date())))
                .font(.titel(.largeTitle))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text("für wen suchst du heute?").font(.zuhause(.subheadline)).foregroundStyle(Look.leise)
        }
        .padding(.top, 8)
    }

    private var hauptkarte: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Geschenk finden").font(.titel(.title2))
            Text("Erzähl mir kurz von der Person, ich suche passende Ideen.")
                .font(.zuhause(.subheadline)).foregroundStyle(Look.leise)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink { LaengeView() } label: {
                Text("Gespräch starten").font(.zuhause(.headline, .fett))
                    .foregroundStyle(Look.aufAkzent)
                    .padding(.horizontal, 22).frame(minHeight: 46)
                    .background(Look.akzent, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zuhauseKarte(ecken: 26)
        // Erkennungsmerkmal: die Katze schläft auf der Kante der Hauptkarte
        .overlay(alignment: .topTrailing) {
            Image("coco-katze").resizable().scaledToFit()
                .frame(width: 132)
                .offset(x: -12, y: -60)
                .accessibilityHidden(true)
        }
        .padding(.top, 44)
    }

    private func anlassZeile(_ anlass: Anlass) -> some View {
        HStack(spacing: 10) {
            Image(anlass.art == .weihnachten ? "coco-kranz" : "coco-stapel")
                .resizable().scaledToFit().frame(width: 48, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(tageText(anlass)).font(.zuhause(.headline, .fett))
                Text(untertitel(anlass)).font(.zuhause(.subheadline)).foregroundStyle(Look.leise)
            }
            Spacer(minLength: 8)
            Button { anlassGewaehlt(anlass) } label: {
                Text(knopfText(anlass)).font(.zuhause(.footnote, .halbfett)).foregroundStyle(Look.leise)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
    }

    private var zuletztGemerkt: some View {
        let liste = zustand.daten.merkliste
        // Noch offene Ideen zuerst; schon Gekauftes braucht hier keinen Platz
        let zuerst = liste.filter { !$0.gekauft } + liste.filter(\.gekauft)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Abschnittstitel(text: "Zuletzt gemerkt")
                Spacer()
                if !liste.isEmpty {
                    Button { reiter = .merkliste } label: {
                        Text("alle \(liste.count) ›").font(.zuhause(.footnote)).foregroundStyle(Look.leise)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            if liste.isEmpty {
                Text("Noch nichts gemerkt. Was du beim Wischen nach rechts schiebst, landet hier.")
                    .font(.zuhause(.subheadline)).foregroundStyle(Look.leise)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(zuerst.prefix(3)) { eintrag in
                        VStack(alignment: .leading, spacing: 3) {
                            ZuhauseFoto(karte: eintrag.karte, ecken: 10).aspectRatio(1, contentMode: .fit)
                            Text(eintrag.karte.preisText).font(.zuhause(.caption, .fett)).foregroundStyle(Look.preis)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    ForEach(0..<max(0, 3 - liste.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var profile: some View {
        let alle = zustand.daten.profile
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Abschnittstitel(text: "Deine Leute")
                Spacer()
                NavigationLink { ZuhauseProfileView() } label: {
                    Text("alle ansehen ›").font(.zuhause(.footnote)).foregroundStyle(Look.leise)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Alle Personen ansehen")
            }
            ForEach(Array(alle.prefix(2).enumerated()), id: \.element.id) { nummer, eintrag in
                if nummer > 0 { Look.trenner }
                NavigationLink { ProfilView(profilID: eintrag.id) } label: {
                    ZuhausePersonZeile(eintrag: eintrag)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    private func tageText(_ anlass: Anlass) -> String {
        switch anlass.tage {
        case 0: return "heute"
        case 1: return "morgen"
        default: return "noch \(anlass.tage) Tage"
        }
    }

    private func untertitel(_ anlass: Anlass) -> String {
        switch anlass.art {
        case .weihnachten:
            return anlass.tage == 0 ? "ist Weihnachten" : "bis Weihnachten"
        case .geburtstag(_, let name):
            return anlass.tage == 0 ? "hat \(name) Geburtstag" : "bis \(besitzform(name)) Geburtstag"
        }
    }

    private func knopfText(_ anlass: Anlass) -> String {
        switch anlass.art {
        case .weihnachten:
            return zustand.daten.profile.count >= 2 ? "Für alle suchen ›" : "Suchen ›"
        case .geburtstag(_, let name):
            return "Für \(name) ›"
        }
    }

    /// „Mamas Geburtstag“, aber „Klaus’ Geburtstag“.
    private func besitzform(_ name: String) -> String {
        let letztes = name.lowercased().last
        return ["s", "x", "z", "ß"].contains(letztes) ? name + "’" : name + "s"
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

/// Katalogfoto auf einer Creme-Tafel, multipliziert: Der weiße Fotogrund verschwindet,
/// es entsteht kein reines Weiß (DESIGN.md 5).
struct ZuhauseFoto: View {
    let karte: Karte
    var ecken: CGFloat = 16

    var body: some View {
        ZStack {
            Color(hex: Look.palette.hell ? 0xF6E7C8 : 0xEBD9B4)
            if let adresse = karte.bildURL, let url = URL(string: adresse) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let bild):
                        // etwas aufgehellt: fast weiße Fotogründe bilden sonst einen sichtbaren Kasten
                        bild.resizable().scaledToFit().brightness(0.04).blendMode(.multiply).padding(6)
                    case .failure: platzhalter
                    default: ProgressView().tint(Color(hex: 0x7B5930))
                    }
                }
            } else {
                platzhalter
            }
        }
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: ecken))
    }

    private var platzhalter: some View {
        Image(systemName: karte.istIdee ? "lightbulb" : "gift")
            .font(.title2).foregroundStyle(Color(hex: 0x7B5930))
    }
}
