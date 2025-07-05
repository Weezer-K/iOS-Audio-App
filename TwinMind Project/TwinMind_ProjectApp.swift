//
//  TwinMind_ProjectApp.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/2/25.
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
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
