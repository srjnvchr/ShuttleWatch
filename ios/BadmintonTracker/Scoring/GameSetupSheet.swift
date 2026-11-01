import SwiftUI
import ScoringKit

/// Doubles: before each game, the serving side picks its server and the other side its receiver.
struct GameSetupSheet: View {
    let model: ScoringViewModel
    let onEndMatch: () -> Void
    @State private var serverSlot = Player.Slot.first
    @State private var receiverSlot = Player.Slot.first

    private var servingSide: Side { model.state.servingSide }

    var body: some View {
        NavigationStack {
            Form {
                if !model.visibleReminders.isEmpty {
                    Section {
                        ForEach(model.visibleReminders, id: \.self) { reminder in
                            ReminderBanner(reminder: reminder, model: model)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }

                slotPicker("Who serves?", side: servingSide, selection: $serverSlot)
                slotPicker("Who receives?", side: servingSide.opponent, selection: $receiverSlot)
            }
            .navigationTitle("Game \(model.state.gameNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start game") {
                        model.startGame(
                            server: Player(side: servingSide, slot: serverSlot),
                            receiver: Player(side: servingSide.opponent, slot: receiverSlot)
                        )
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    // Undo takes back the rally that ended the last game, closing this sheet.
                    if model.canUndo {
                        Button("Undo", systemImage: "arrow.uturn.backward") { model.undo() }
                    } else {
                        Button("Cancel", action: onEndMatch)
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func slotPicker(_ title: String, side: Side, selection: Binding<Player.Slot>) -> some View {
        Section("\(title) (\(model.name(of: side)))") {
            Picker(title, selection: selection) {
                ForEach(Player.Slot.allCases, id: \.self) { slot in
                    Text(model.name(of: Player(side: side, slot: slot))).tag(slot)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
