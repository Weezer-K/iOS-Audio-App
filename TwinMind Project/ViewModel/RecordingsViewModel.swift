//
//  RecordingsViewModel.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/2/25.
//

import SwiftUI
import AVFoundation

class RecordingsViewModel: ObservableObject {
    @Published var recordings: [URL] = []
    @Published var currentlyPlayingURL: URL?
    @Published var isPlaying = false

    private var player: AVAudioPlayer?

    init() {
        loadRecordings()
    }

    func loadRecordings() {
        recordings.removeAll()

        let documentsURL = getDocumentsDirectory()
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            let audioFiles = allFiles.filter { $0.pathExtension == "caf" || $0.pathExtension == "m4a" }
            recordings = audioFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            print("Failed to list recordings: \(error)")
        }
    }

    func playRecording(url: URL) {
        stopPlayback()

        do {
            player = try AVAudioPlayer(contentsOf: url)
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

    func togglePlayback(for url: URL) {
        if currentlyPlayingURL == url && isPlaying {
            stopPlayback()
        } else {
            playRecording(url: url)
        }
    }

    func deleteRecording(at offsets: IndexSet) {
        for index in offsets {
            let url = recordings[index]
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Error deleting recording: \(error)")
            }
        }
        loadRecordings()
    }

    func renameRecording(_ url: URL, newName: String) {
        let safeName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeName.isEmpty else { return }

        let newURL = url.deletingLastPathComponent().appendingPathComponent("\(safeName).\(url.pathExtension)")

        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            loadRecordings()
        } catch {
            print("Error renaming recording: \(error)")
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
