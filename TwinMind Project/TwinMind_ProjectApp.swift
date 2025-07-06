//
//  TwinMind_ProjectApp.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/2/25.
//

import SwiftUI
import SwiftData

@main
struct TwinMindApp: App {
    let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: RecordingSession.self, TranscriptionSegment.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(modelContext: modelContainer.mainContext)
                .modelContainer(modelContainer)
        }
    }
}
