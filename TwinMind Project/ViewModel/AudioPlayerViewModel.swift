//
//  AudioPlayerViewModel.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/2/25.
//

import SwiftUI
import AVFoundation
import SwiftData

class AudioPlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var recordings: [RecordingSession] = []
    @Published var currentlyPlayingSessionID: UUID?
    @Published var isPlaying = false
    @Published var playbackStates: [UUID: PlaybackState] = [:]

    private var player: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var currentTempURL: URL?

    private let modelContext: ModelContext
    let transcriptionManager: TranscriptionManager?

    private let pageSize = 20
    @Published var currentPage = 0
    @Published var hasMore = true

    struct PlaybackState {
        var currentTime: TimeInterval
        var duration: TimeInterval
        var isPlaying: Bool
    }

    init(modelContext: ModelContext, transcriptionManager: TranscriptionManager? = nil) {
        self.modelContext = modelContext
        self.transcriptionManager = transcriptionManager
        super.init()
        loadRecordings()
    }

    func loadRecordings() {
        do {
            var fetch = FetchDescriptor<RecordingSession>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            fetch.fetchLimit = pageSize
            fetch.fetchOffset = currentPage * pageSize

            let results = try modelContext.fetch(fetch)
            hasMore = (results.count == pageSize)

            if currentPage == 0 {
                recordings = results
            } else {
                recordings.append(contentsOf: results)
            }
        } catch {
            print("Failed to fetch recordings: \(error)")
        }
    }

    func loadNextPage() {
        guard hasMore else { return }
        currentPage += 1
        loadRecordings()
    }

    func refresh() {
        currentPage = 0
        hasMore = true
        loadRecordings()
    }
    
    func deleteSession(_ session: RecordingSession) {
        let encryptedURL = getDocumentsDirectory().appendingPathComponent(session.filename)
        try? FileManager.default.removeItem(at: encryptedURL)

        do {
            modelContext.delete(session)
            try modelContext.save()
            refresh()
        } catch {
            print("Failed to delete session: \(error)")
        }
    }

    func togglePlayback(for session: RecordingSession) {
        if currentlyPlayingSessionID == session.id && isPlaying {
            stopPlayback()
        } else {
            playRecording(for: session)
        }
    }

    func togglePause(for session: RecordingSession) {
        guard currentlyPlayingSessionID == session.id, let player = player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            playbackStates[session.id]?.isPlaying = false
            stopPlaybackTimer()
        } else {
            player.play()
            isPlaying = true
            playbackStates[session.id]?.isPlaying = true
            startPlaybackTimer()
        }
    }

    private func playRecording(for session: RecordingSession) {
        stopPlayback()
        do {
            let encURL = getDocumentsDirectory().appendingPathComponent(session.filename)
            let encData = try Data(contentsOf: encURL)
            let decData = try EncryptionConfig.decrypt(encData)
            let tmpURL = getTempDirectory().appendingPathComponent("tmp_\(UUID().uuidString).m4a")
            
            try decData.write(to: tmpURL)
            currentTempURL = tmpURL

            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let p = try AVAudioPlayer(contentsOf: tmpURL)
            p.delegate = self
            p.prepareToPlay()
            p.play()
            player = p

            currentlyPlayingSessionID = session.id
            isPlaying = true
            playbackStates[session.id] = PlaybackState(
                currentTime: 0,
                duration: p.duration,
                isPlaying: true
            )
            startPlaybackTimer()

        } catch {
            print("Playback error: \(error)")
        }
    }

    func stopPlayback() {
        player?.stop()

        if let tmp = currentTempURL {
            try? FileManager.default.removeItem(at: tmp)
            currentTempURL = nil
        }

        isPlaying = false
        if let id = currentlyPlayingSessionID {
            playbackStates[id]?.isPlaying = false
        }
        currentlyPlayingSessionID = nil
        stopPlaybackTimer()
    }

    func seek(to time: TimeInterval, for session: RecordingSession) {
        guard currentlyPlayingSessionID == session.id, let p = player else { return }
        p.currentTime = time
        playbackStates[session.id]?.currentTime = time
    }

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self,
                  let id = self.currentlyPlayingSessionID,
                  let p = self.player
            else { return }
            self.playbackStates[id]?.currentTime = p.currentTime
        }
        RunLoop.current.add(playbackTimer!, forMode: .common)
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            if let tmp = self.currentTempURL {
                try? FileManager.default.removeItem(at: tmp)
                self.currentTempURL = nil
            }

            self.isPlaying = false
            if let id = self.currentlyPlayingSessionID {
                self.playbackStates[id]?.isPlaying = false
            }
            self.currentlyPlayingSessionID = nil
            self.stopPlaybackTimer()
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }

    private func getTempDirectory() -> URL {
        FileManager.default.temporaryDirectory
    }

    func queuedCount(for sessionID: UUID) -> Int {
        do {
            let desc = FetchDescriptor<QueuedTranscriptionSegment>(
                predicate: #Predicate { $0.sessionID == sessionID }
            )
            return try modelContext.fetchCount(desc)
        } catch {
            return 0
        }
    }
    
    func deleteAllRecordings() {
        do {
            let fetch = FetchDescriptor<RecordingSession>()
            let allSessions = try modelContext.fetch(fetch)

            for session in allSessions {
                let encryptedURL = getDocumentsDirectory().appendingPathComponent(session.filename)
                try? FileManager.default.removeItem(at: encryptedURL)
            }

            for session in allSessions {
                modelContext.delete(session)
            }

            try modelContext.save()
            refresh()
        } catch {
            print("Failed to delete all recordings: \(error)")
        }
    }
}
