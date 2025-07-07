//
//  AppDelegate.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/6/25.
//

import UIKit
import BackgroundTasks
import SwiftData

class AppDelegate: NSObject, UIApplicationDelegate {
  static var modelContainer: ModelContainer!

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.twinmind.transcription",
      using: nil
    ) { task in
      guard let processingTask = task as? BGProcessingTask else {
        task.setTaskCompleted(success: false)
        return
      }

      let ctx = AppDelegate.modelContainer.mainContext
      let mgr = TranscriptionManager(modelContext: ctx)
      mgr.retryQueuedSegments()

      processingTask.setTaskCompleted(success: true)
    }

    return true
  }
}
