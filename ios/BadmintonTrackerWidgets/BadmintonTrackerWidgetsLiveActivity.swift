//
//  BadmintonTrackerWidgetsLiveActivity.swift
//  BadmintonTrackerWidgets
//
//  Created by Manjiri Sane on 1/11/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BadmintonTrackerWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct BadmintonTrackerWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BadmintonTrackerWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension BadmintonTrackerWidgetsAttributes {
    fileprivate static var preview: BadmintonTrackerWidgetsAttributes {
        BadmintonTrackerWidgetsAttributes(name: "World")
    }
}

extension BadmintonTrackerWidgetsAttributes.ContentState {
    fileprivate static var smiley: BadmintonTrackerWidgetsAttributes.ContentState {
        BadmintonTrackerWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: BadmintonTrackerWidgetsAttributes.ContentState {
         BadmintonTrackerWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: BadmintonTrackerWidgetsAttributes.preview) {
   BadmintonTrackerWidgetsLiveActivity()
} contentStates: {
    BadmintonTrackerWidgetsAttributes.ContentState.smiley
    BadmintonTrackerWidgetsAttributes.ContentState.starEyes
}
