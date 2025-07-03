//
//  RecordingViewModel.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/2/25.
//

import SwiftUI
import AVFoundation

class RecordingViewModel: ObservableObject {
    @Published var isRecording = false

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private let session = AVAudioSession.sharedInstance()

    private var outputURL: URL?

    init() {
        requestPermission()
    }

    private func requestPermission() {
        session.requestRecordPermission { granted in
            if !granted {
                print("Microphone permission denied.")
            }
        }
    }

    func startRecording() {
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let inputNode = engine.inputNode
            let format = inputNode.inputFormat(forBus: 0)

            let fileName = "engineRecording_\(Date().timeIntervalSince1970).caf"
            let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
            outputURL = fileURL

            audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, time) in
                do {
                    try self?.audioFile?.write(from: buffer)
                } catch {
                    print("Error writing buffer: \(error)")
                }
            }

            try engine.start()
            DispatchQueue.main.async {
                self.isRecording = true
            }

            print("Recording started at: \(fileURL)")

        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        do {
            try session.setActive(false)
        } catch {
            print("Failed to deactivate session: \(error)")
        }

        DispatchQueue.main.async {
            self.isRecording = false
        }

        if let url = outputURL {
            print("Recording saved at: \(url)")
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
