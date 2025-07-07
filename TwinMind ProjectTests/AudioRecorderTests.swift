//
//  AudioRecorderTests.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/7/25.
//
import XCTest
import SwiftData
@testable import TwinMind_Project

final class AudioRecorderViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var playerViewModel: AudioPlayerViewModel!
    var transcriptionManager: TranscriptionManager!
    var recorderViewModel: AudioRecorderViewModel!

    @MainActor
    override func setUpWithError() throws {
        modelContainer = try ModelContainer(for: RecordingSession.self)
        modelContext = modelContainer.mainContext

        playerViewModel = AudioPlayerViewModel(modelContext: modelContext)
        transcriptionManager = TranscriptionManager(modelContext: modelContext)
        recorderViewModel = AudioRecorderViewModel(
            playerViewModel: playerViewModel,
            modelContext: modelContext,
            transcriptionManager: transcriptionManager
        )
        
        deleteAllRecordingsForTestIsolation()
    }

    override func tearDownWithError() throws {
        deleteAllRecordingsForTestIsolation()
        modelContainer = nil
        modelContext = nil
        playerViewModel = nil
        transcriptionManager = nil
        recorderViewModel = nil
    }

    private func deleteAllRecordingsForTestIsolation() {
        do {
            let fetch = FetchDescriptor<RecordingSession>()
            let all = try modelContext.fetch(fetch)
            for session in all {
                modelContext.delete(session)
            }
            try modelContext.save()
        } catch {
            print("Failed to clear store in test: \(error)")
        }
    }

    @MainActor func testHasEnoughStorageReturnsTrue() {
        XCTAssertTrue(recorderViewModel.hasEnoughStorage())
    }

    @MainActor func testFormattedDateStringIsCorrectFormat() {
        let dateString = recorderViewModel.formattedDateString()

        let regex = try! NSRegularExpression(pattern: "^\\d{1,2}:\\d{2} [AP]M$")
        let range = NSRange(location: 0, length: dateString.utf16.count)
        XCTAssertNotNil(regex.firstMatch(in: dateString, options: [], range: range))
    }

    func testCountRecordingsWithTitleReturnsZeroInitially() async throws {
        let count = await recorderViewModel.countRecordingsWithTitle("Test")
        XCTAssertEqual(count, 0)
    }

    func testCountRecordingsWithTitleCountsCorrectly() async throws {
        for _ in 0..<3 {
            let session = RecordingSession(title: "Meeting Notes", filename: "file.enc", createdAt: Date())
            modelContext.insert(session)
        }
        try modelContext.save()

        let count = await recorderViewModel.countRecordingsWithTitle("Meeting")
        XCTAssertEqual(count, 3)
    }
}
