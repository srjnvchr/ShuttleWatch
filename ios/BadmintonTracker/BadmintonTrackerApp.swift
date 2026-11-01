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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: MatchRecord.self)
    }
}
