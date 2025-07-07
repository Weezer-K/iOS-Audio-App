//
//  AudioPlayerView.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/2/25.
//


import SwiftUI
import SwiftData

@main
struct TwinMindApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  let modelContainer: ModelContainer = {
    do {
      return try ModelContainer(
        for: RecordingSession.self,
             TranscriptionSegment.self,
             QueuedTranscriptionSegment.self
      )
    } catch {
      fatalError("Failed to create ModelContainer: \(error)")
    }
  }()

  @StateObject private var connectivity = ConnectivityMonitor()

  init() {
    AppDelegate.modelContainer = modelContainer

    #if DEBUG
    if KeychainHelper.loadAPIKey() == nil,
       let envKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"],
       !envKey.isEmpty
    {
      try? KeychainHelper.saveAPIKey(envKey)
    }
    if KeychainHelper.loadKey(forKey: EncryptionConfig.keyTag) == nil {
      try? KeychainHelper.save(
        key: EncryptionConfig.sharedKey,
        forKey: EncryptionConfig.keyTag
      )
    }
    #endif
  }

  var body: some Scene {
    WindowGroup {
      ContentView(modelContext: modelContainer.mainContext)
        .environmentObject(connectivity)
        .modelContainer(modelContainer)
    }
  }
}
