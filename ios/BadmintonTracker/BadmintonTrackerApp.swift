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
    @State private var capture = CaptureController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(watchSync)
                .environment(capture)
                .task {
                    watchSync.isRecording = { [capture] in capture.isRecording }
                    watchSync.activate()
                }
        }
        .modelContainer(for: MatchRecord.self)
    }
}
