import Foundation
import StageCore

/// The manifest of this round, embedded so the executable runs on its own (`--demo`).
/// `manifest.sample.json` beside this file is the same text; a test in StageCoreTests checks they stay identical.
/// When Hatch launches the Stage it passes the real manifest instead.
enum ToastManifest {
    static let json: String = #"""
{
  "title": "#151 Toast spacing",
  "revision": 2,
  "specs": ["NOTIF-1.3"],
  "summary": "The notification toast gets more room: padding and icon size are the decision. Echo today is the reference.",
  "asked": "The toast feels cramped next to the sidebar; try more breathing room.",
  "controls": [
    {
      "id": "padding",
      "title": "Padding, Option B",
      "default": "p12",
      "choices": [
        {"id": "p12", "name": "12 pt"},
        {"id": "p16", "name": "16 pt"},
        {"id": "p20", "name": "20 pt", "addedIn": 2}
      ],
      "question": "Look at the error toast at Large text, then say whether the padding feels calm without wasting width.",
      "recommend": "p16",
      "why": "16 pt matches the 12 pt rhythm of the other cards plus one step, and keeps the error toast readable at Large text. 12 pt is what Echo has today; 20 pt costs a third more height."
    },
    {
      "id": "icon",
      "title": "Icon size, Option B",
      "default": "medium",
      "choices": [
        {"id": "small", "name": "Small 22 pt"},
        {"id": "medium", "name": "Medium 28 pt"},
        {"id": "large", "name": "Large 34 pt"}
      ],
      "question": "Does the icon help you find the toast, or does it outweigh the title?",
      "recommend": "medium",
      "why": "Medium is large enough to find at a glance and still lets the title lead. Large pulls the eye away from the message."
    },
    {
      "id": "timeout",
      "title": "Dismiss after",
      "default": "4",
      "choices": [
        {"id": "4", "name": "4 s"},
        {"id": "8", "name": "8 s"}
      ]
    }
  ],
  "specimens": [
    {"id": "today", "title": "Echo today", "summary": "As it is built now.", "isEchoToday": true, "designWidth": 300, "designHeight": 190, "matchNote": "checked 2 days ago"},
    {"id": "a", "title": "Option A · Quiet", "summary": "A little more room, same layout.", "designWidth": 300, "designHeight": 190},
    {"id": "b", "title": "Option B · Roomy", "summary": "Built from the controls above.", "designWidth": 300, "designHeight": 190}
  ],
  "questions": [
    {
      "id": "actions",
      "title": "Actions",
      "question": "Hover the toast. Should View and Dismiss appear only on hover?",
      "choices": [
        {"id": "hover", "name": "Only on hover"},
        {"id": "always", "name": "Always visible"}
      ],
      "recommended": "hover",
      "why": "A resting toast should be quiet. The close button already shows on hover, so the actions follow it."
    }
  ],
  "exhibitTopic": {
    "id": "option",
    "title": "Which toast?",
    "question": "Which option do you prefer, judged against Echo today?",
    "recommended": "b",
    "why": "B fixes the cramped feel the ticket asked about, and the controls let you tune it. A is safe but barely different from today."
  },
  "presets": [
    {"id": "recommended", "name": "Recommended", "values": {"padding": "p16", "icon": "medium"}, "isRecommended": true},
    {"id": "airy", "name": "Airy", "values": {"padding": "p20", "icon": "large"}}
  ],
  "scenarios": [
    {"id": "rest", "title": "Rest"},
    {"id": "hover", "title": "Hover"},
    {"id": "pressed", "title": "Pressed", "applicable": false, "notApplicableReason": "A toast has no pressed state; its buttons look the same as in Echo today."},
    {"id": "focus", "title": "Focus", "applicable": false, "notApplicableReason": "A toast never takes keyboard focus."},
    {"id": "disabled", "title": "Disabled", "applicable": false, "notApplicableReason": "A toast cannot be disabled."},
    {"id": "empty", "title": "Empty", "applicable": false, "notApplicableReason": "A toast always has a message."},
    {"id": "error", "title": "Error"},
    {"id": "long-text", "title": "Long text"},
    {"id": "many-items", "title": "Many items"},
    {"id": "loading", "title": "Loading", "applicable": false, "notApplicableReason": "A toast reports a result; it does not load."}
  ],
  "conformance": {
    "states": [{"id": "rest", "title": "Rest", "observe": 4.5}, {"id": "hover", "title": "Hovered"}],
    "subject": "toast.card",
    "knownDifferences": {}
  },
  "mixSpecimen": "b",
  "plan": {
    "repos": [{"name": "tashda/Echo", "branch": "ticket/151-toast-spacing"}],
    "tests": ["NotificationToast tests", "Match check: toast.card"],
    "tokenEstimate": 60000
  }
}
"""#

    static func load() -> StageManifest {
        do {
            return try StageManifest.parse(json: json)
        } catch {
            return StageManifest(title: "Toast round (manifest failed to load)", summary: "\(error)")
        }
    }
}
