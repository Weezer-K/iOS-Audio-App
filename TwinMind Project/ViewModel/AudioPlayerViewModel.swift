//
//  AudioPlayerViewModel.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/2/25.
//

import SwiftUI
import AVFoundation

class AudioPlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var recordings: [URL] = []
    @Published var currentlyPlayingURL: URL?
    @Published var isPlaying = false

    private var player: AVAudioPlayer?

    override init() {
        super.init()
        loadRecordings()
    }
    
    func loadRecordings() {
        recordings.removeAll()

        let documentsURL = getDocumentsDirectory()
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )

            let audioFiles = allFiles.filter {
                $0.pathExtension.lowercased() == "caf" || $0.pathExtension.lowercased() == "m4a"
            }

            let sortedAudioFiles = audioFiles.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return date1 > date2
            }

            recordings = sortedAudioFiles

        } catch {
            print("Failed to list recordings: \(error)")
        }
    }

    func refresh() {
        loadRecordings()
    }

    func togglePlayback(for url: URL) {
        if currentlyPlayingURL == url && isPlaying {
            stopPlayback()
        } else {
            playRecording(url: url)
        }
    }

    func playRecording(url: URL) {
        stopPlayback()

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()

            currentlyPlayingURL = url
            isPlaying = true
        } catch {
            print("Failed to play recording: \(error)")
        }
    }

    func stopPlayback() {
        player?.stop()
        isPlaying = false
        currentlyPlayingURL = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentlyPlayingURL = nil
        }
    }

    func deleteRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            refresh()
        } catch {
            print("Failed to delete recording: \(error)")
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
