//
//  TranscriptionManagerTests.swift
//  TwinMind ProjectTests
//
//  Created by Kyle Peters on 7/7/25.
//

import XCTest
import SwiftData
@testable import TwinMind_Project

@MainActor
final class TranscriptionManagerTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var transcriptionManager: TranscriptionManager!

    override func setUpWithError() throws {
        modelContainer = try ModelContainer(
            for: RecordingSession.self,
                TranscriptionSegment.self,
                QueuedTranscriptionSegment.self
        )
        modelContext = modelContainer.mainContext

        transcriptionManager = TranscriptionManager(modelContext: modelContext)

        deleteAllTestData()
    }

    override func tearDownWithError() throws {
        deleteAllTestData()
        modelContainer = nil
        modelContext = nil
        transcriptionManager = nil
    }

    private func deleteAllTestData() {
        do {
            let recordings = try modelContext.fetch(FetchDescriptor<RecordingSession>())
            for r in recordings { modelContext.delete(r) }

            let segments = try modelContext.fetch(FetchDescriptor<TranscriptionSegment>())
            for s in segments { modelContext.delete(s) }

            let queued = try modelContext.fetch(FetchDescriptor<QueuedTranscriptionSegment>())
            for q in queued { modelContext.delete(q) }

            try modelContext.save()
        } catch {
            print("Failed to clear test data: \(error)")
        }
    }

    func testQueueSegmentAddsSegmentToSession() async throws {
        let session = RecordingSession(
            title: "Test Recording",
            filename: "test.enc",
            createdAt: Date()
        )
        modelContext.insert(session)
        try modelContext.save()

        transcriptionManager.queueSegment(for: session, startTime: 0.0, endTime: 10.0)

        try await Task.sleep(nanoseconds: 200_000_000)

        let fetch = FetchDescriptor<RecordingSession>()
        let updated = try modelContext.fetch(fetch).first

        XCTAssertNotNil(updated)
    }
}
