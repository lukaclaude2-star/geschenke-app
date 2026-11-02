import GeschenkeCore
import SwiftUI

struct StartView: View {
    @EnvironmentObject private var zustand: AppZustand
    @State private var zeigeEinstellungen = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Finde ein Geschenk, das passt.")
                        .font(.title2.bold())
                    Text("Erzähl mir von der Person – dann wischst du durch passende Ideen.")
                        .foregroundStyle(Look.leise)
                }
                .padding(.vertical, 8)
                NavigationLink {
                    LaengeView()
                } label: {
                    Label("Neue Suche", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(Look.gold)
                }
            }
            .listRowBackground(Look.karte)

            Section("Profile") {
                if zustand.daten.profile.isEmpty {
                    Text("Noch keine Profile. Nach einer Suche kannst du die Person speichern.")
                        .foregroundStyle(Look.leise)
                }
                ForEach(zustand.daten.profile) { eintrag in
                    NavigationLink {
                        ProfilView(profilID: eintrag.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(eintrag.name).font(.headline)
                            Text(eintrag.profil.zusammenfassung)
                                .font(.caption)
                                .foregroundStyle(Look.leise)
                                .lineLimit(1)
                        }
                    }
                }
                .onDelete { indizes in
                    zustand.loescheProfile(indizes.map { zustand.daten.profile[$0].id })
                }
            }
            .listRowBackground(Look.karte)
        }
        .nachtblau()
        .navigationTitle("Geschenke")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MerklisteView()
                } label: {
                    Image(systemName: "heart.fill")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    zeigeEinstellungen = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $zeigeEinstellungen) {
            EinstellungenView()
        }
    }
}

struct EinstellungenView: View {
    @Environment(\.dismiss) private var schliessen
    @AppStorage(Konfiguration.tokenSchluessel) private var token = ""

    var body: some View {
        NavigationStack {
            Form {
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
                Button("Fertig") { schliessen() }
            }
        }
    }
}
