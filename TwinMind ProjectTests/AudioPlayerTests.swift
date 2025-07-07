import XCTest
import SwiftData
@testable import TwinMind_Project

final class AudioPlayerViewModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: AudioPlayerViewModel!

    @MainActor
    override func setUpWithError() throws {
        modelContainer = try ModelContainer(for: RecordingSession.self)
        modelContext = modelContainer.mainContext

        viewModel = AudioPlayerViewModel(modelContext: modelContext)
        deleteAllRecordingsForTestIsolation()
    }

    override func tearDownWithError() throws {
        deleteAllRecordingsForTestIsolation()
        modelContainer = nil
        modelContext = nil
        viewModel = nil
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

    func testLoadRecordingsLoadsFirstPage() throws {
        for i in 0..<25 {
            let rec = RecordingSession(title: "Rec \(i)", filename: "file\(i).enc", createdAt: Date())
            modelContext.insert(rec)
        }
        try modelContext.save()

        viewModel.loadRecordings()

        XCTAssertEqual(viewModel.recordings.count, 20)
        XCTAssertTrue(viewModel.hasMore)
        XCTAssertEqual(viewModel.currentPage, 0)

        viewModel.deleteAllRecordings()
    }

    func testLoadNextPageAppendsMore() throws {
        for i in 0..<40 {
            let rec = RecordingSession(title: "Rec \(i)", filename: "file\(i).enc", createdAt: Date())
            modelContext.insert(rec)
        }
        try modelContext.save()

        viewModel.loadRecordings()
        XCTAssertEqual(viewModel.recordings.count, 20)
        XCTAssertTrue(viewModel.hasMore)

        viewModel.loadNextPage()
        XCTAssertEqual(viewModel.recordings.count, 40)
        XCTAssertTrue(viewModel.hasMore)

        viewModel.deleteAllRecordings()
    }

    func testRefreshResetsPagination() throws {
        viewModel.currentPage = 3
        viewModel.hasMore = false

        viewModel.refresh()

        XCTAssertEqual(viewModel.currentPage, 0)
        XCTAssertFalse(viewModel.hasMore)
    }

    func testDeleteSessionRemovesFromModel() throws {
        let session = RecordingSession(title: "Delete Me", filename: "deleteme.enc", createdAt: Date())
        modelContext.insert(session)
        try modelContext.save()

        viewModel.loadRecordings()
        XCTAssertEqual(viewModel.recordings.count, 1)

        viewModel.deleteSession(session)

        viewModel.refresh()
        XCTAssertEqual(viewModel.recordings.count, 0)
    }

    func testQueuedCountDefaultsToZero() throws {
        let sessionID = UUID()
        let count = viewModel.queuedCount(for: sessionID)
        XCTAssertEqual(count, 0)
    }
}
