import SwiftUI

/// Shows match setup until a match starts, then the scoring screen.
struct ContentView: View {
    @State private var scoring: ScoringViewModel?

    var body: some View {
        if let scoring {
            ScoringView(model: scoring) { self.scoring = nil }
        } else {
            MatchSetupView { scoring = $0 }
        }
    }
}

#Preview {
    ContentView()
}
