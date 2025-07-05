//
//  AudioRecorderViewModel.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/2/25.
//

import SwiftUI
import AVFoundation
import Combine
import SwiftData

class AudioRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private let session = AVAudioSession.sharedInstance()
    private var outputURL: URL?
    private var recordingQueue = DispatchQueue(label: "RecordingQueue")

    private weak var playerViewModel: AudioPlayerViewModel?
    private var notificationObservers: [NSObjectProtocol] = []

    init(playerViewModel: AudioPlayerViewModel? = nil) {
        self.playerViewModel = playerViewModel
        setupNotifications()
        requestPermission()
    }

    private func requestPermission() {
        session.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    print("Microphone permission denied.")
                }
            }
        }
    }

    private func setupNotifications() {
        let center = NotificationCenter.default
        notificationObservers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        })

        notificationObservers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        })
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .began {
            pauseRecording()
        } else if type == .ended {
            try? session.setActive(true)
            startRecording()
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        print("Audio route changed: \(notification)")
    }

    func startRecording() {
        recordingQueue.async {
            do {
                try self.session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
                try self.session.setActive(true)

                let inputNode = self.engine.inputNode
                let format = inputNode.inputFormat(forBus: 0)

                let fileName = "engineRecording_\(Date().timeIntervalSince1970).caf"
                let fileURL = self.getDocumentsDirectory().appendingPathComponent(fileName)
                self.outputURL = fileURL
                self.audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)

                inputNode.removeTap(onBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                    try? self?.audioFile?.write(from: buffer)
                    self?.updateLevel(buffer: buffer)
                }

                try self.engine.start()
                DispatchQueue.main.async {
                    self.isRecording = true
                }
            } catch {
                print("Error starting recording: \(error)")
            }
        }
    }

    func pauseRecording() {
        engine.pause()
        isRecording = false
    }

    func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        try? session.setActive(false)

        if let url = outputURL {
            print("Recording saved at: \(url)")

            Task {
                await createRecordingSession(with: url)
            }
        }

        playerViewModel?.refresh()
    }

    private func updateLevel(buffer: AVAudioPCMBuffer) {
        let channelData = buffer.floatChannelData?[0]
        let channelDataValue = channelData?.advanced(by: Int(buffer.frameLength / 2)).pointee ?? 0
        let level = abs(channelDataValue)
        DispatchQueue.main.async {
            self.audioLevel = level
        }
    }

    @MainActor
    private func createRecordingSession(with url: URL) async {
        do {
            guard let container = try? ModelContainer(for: RecordingSession.self, TranscriptionSegment.self) else {
                print("Failed to get SwiftData container")
                return
            }
            let context = ModelContext(container)

            let audioFile = try AVAudioFile(forReading: url)
            let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            print("Audio duration: \(duration) seconds")

            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let timestamp = formatter.string(from: Date())

            let session = RecordingSession(
                title: "Recording at \(timestamp)",
                audioFileURL: url,
                createdAt: Date()
            )

            var start: Double = 0.0
            while start < duration {
                let end = min(start + 30.0, duration)
                let segment = TranscriptionSegment(
                    startTime: start,
                    endTime: end,
                    audioFileURL: url
                )
                session.segments.append(segment)
                start += 30.0
            }

            context.insert(session)
            try context.save()

            print("Saved RecordingSession with \(session.segments.count) segments")

            let manager = TranscriptionManager(modelContext: context)
            for segment in session.segments {
                manager.queueSegment(segment)
            }

        } catch {
            print("Error creating session: \(error)")
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
