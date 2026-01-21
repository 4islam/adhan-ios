//
//  AdhanWidgetLiveActivity.swift
//  AdhanWidget
//
//  Created by Naveed ul Islam on 2026-01-21.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct AdhanWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct AdhanWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AdhanWidgetAttributes.self) { context in
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

extension AdhanWidgetAttributes {
    fileprivate static var preview: AdhanWidgetAttributes {
        AdhanWidgetAttributes(name: "World")
    }
}

extension AdhanWidgetAttributes.ContentState {
    fileprivate static var smiley: AdhanWidgetAttributes.ContentState {
        AdhanWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: AdhanWidgetAttributes.ContentState {
         AdhanWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: AdhanWidgetAttributes.preview) {
   AdhanWidgetLiveActivity()
} contentStates: {
    AdhanWidgetAttributes.ContentState.smiley
    AdhanWidgetAttributes.ContentState.starEyes
}
