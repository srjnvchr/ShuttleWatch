//
//  BadmintonTrackerApp.swift
//  BadmintonTracker
//
//  Created by Manjiri Sane on 31/10/2026.
//

import SwiftData
import SwiftUI

@main
struct BadmintonTrackerApp: App {
    @State private var watchSync = WatchSyncService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(watchSync)
                .task { watchSync.activate() }
        }
        .modelContainer(for: MatchRecord.self)
    }
}
