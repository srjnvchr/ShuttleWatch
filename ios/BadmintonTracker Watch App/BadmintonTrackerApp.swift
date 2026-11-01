//
//  BadmintonTrackerApp.swift
//  BadmintonTracker Watch App
//
//  Created by Manjiri Sane on 31/10/2026.
//

import SwiftUI

@main
struct BadmintonTracker_Watch_AppApp: App {
    @State private var link = WatchSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(link)
                .task { link.activate() }
        }
    }
}
