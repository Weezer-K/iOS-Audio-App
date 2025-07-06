import SwiftUI
import AVFoundation
import SwiftData

class AudioPlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var recordings: [RecordingSession] = []
    @Published var currentlyPlayingSessionID: UUID?
    @Published var isPlaying = false

    private var player: AVAudioPlayer?
    private let modelContext: ModelContext
    let transcriptionManager: TranscriptionManager?

    init(modelContext: ModelContext, transcriptionManager: TranscriptionManager? = nil) {
        self.modelContext = modelContext
        self.transcriptionManager = transcriptionManager
        super.init()
        loadRecordings()
    }

    func loadRecordings() {
        do {
            let fetch = FetchDescriptor<RecordingSession>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            self.recordings = try modelContext.fetch(fetch)
        } catch {
            print("Failed to fetch recordings: \(error)")
        }
    }

    func refresh() {
        loadRecordings()
    }

    func togglePlayback(for session: RecordingSession) {
        if currentlyPlayingSessionID == session.id && isPlaying {
            stopPlayback()
        } else {
            playRecording(for: session)
        }
    }

    private func playRecording(for session: RecordingSession) {
        stopPlayback()

        do {
            let encryptedURL = getDocumentsDirectory().appendingPathComponent(session.filename)
            let encryptedData = try Data(contentsOf: encryptedURL)
            let decryptedData = try EncryptionConfig.decrypt(encryptedData)

            let tempURL = getTempDirectory().appendingPathComponent("temp_decrypted_\(UUID().uuidString).m4a")
            try decryptedData.write(to: tempURL)

            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: tempURL)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()

            currentlyPlayingSessionID = session.id
            isPlaying = true

        } catch {
            print("Failed to play recording: \(error)")
        }
    }

    func stopPlayback() {
        player?.stop()
        isPlaying = false
        currentlyPlayingSessionID = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentlyPlayingSessionID = nil
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func getTempDirectory() -> URL {
        FileManager.default.temporaryDirectory
    }

    func deleteSession(_ session: RecordingSession) {
        do {
            modelContext.delete(session)
            try modelContext.save()
            refresh()
        } catch {
            print("Failed to delete session: \(error)")
        }
    }
}
