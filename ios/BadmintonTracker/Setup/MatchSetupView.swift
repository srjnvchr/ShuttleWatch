import SwiftUI
import ScoringKit

/// FR-01: choose the match type, names, length, first server, and starting ends.
struct MatchSetupView: View {
    let onStart: (ScoringViewModel) -> Void
    @State private var form = MatchSetupForm()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Match type", selection: $form.kind) {
                        Text("Singles").tag(MatchKind.singles)
                        Text("Doubles").tag(MatchKind.doubles)
                    }
                    Picker("Length", selection: $form.gamesPerMatch) {
                        ForEach(MatchSetupForm.gameChoices, id: \.self) { games in
                            Text(games == 1 ? "1 game" : "Best of \(games)").tag(games)
                        }
                    }
                }
                .pickerStyle(.segmented)

                ForEach(Side.allCases, id: \.self) { side in
                    Section("Side \(side.rawValue.uppercased())") {
                        ForEach(form.players.filter { $0.side == side }, id: \.self) { player in
                            TextField(placeholder(for: player), text: nameBinding(for: player))
                                .textInputAutocapitalization(.words)
                        }
                    }
                }

                Section("Start") {
                    Picker("Serves first", selection: $form.firstServingSide) {
                        ForEach(Side.allCases, id: \.self) { side in
                            Text(form.names.name(of: side, kind: form.kind)).tag(side)
                        }
                    }
                    Picker("Near end", selection: $form.sideAtNearEnd) {
                        ForEach(Side.allCases, id: \.self) { side in
                            Text(form.names.name(of: side, kind: form.kind)).tag(side)
                        }
                    }
                }

                Section {
                    Toggle("Mark rally starts", isOn: $form.marksRallyStarts)
                } footer: {
                    Text("Tap Serve as each rally starts. Recordings then get exact rally times for training.")
                }

                Section {
                    DisclosureGroup("Advanced") {
                        Stepper("Points per game: \(form.pointsPerGame)", value: $form.pointsPerGame, in: 1...99)
                        Stepper("Point cap: \(form.pointCap)", value: $form.pointCap, in: 1...99)
                    }
                } footer: {
                    if !form.canStart {
                        Text("The point cap must be at least the points per game.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New match")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        if let model = form.makeViewModel() {
                            onStart(model)
                        }
                    }
                    .disabled(!form.canStart)
                }
            }
        }
    }

    private func placeholder(for player: Player) -> String {
        "Name (\(PlayerNames().name(of: player, kind: form.kind)))"
    }

    private func nameBinding(for player: Player) -> Binding<String> {
        Binding(
            get: { form.nameText[player] ?? "" },
            set: { form.nameText[player] = $0 }
        )
    }
}

#Preview {
    MatchSetupView { _ in }
}
