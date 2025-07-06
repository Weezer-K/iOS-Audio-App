//
//  AudioRecorderViewModel.swift
//

import SwiftUI
import AVFoundation
import SwiftData
import CryptoKit

enum RecordingQuality: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var settings: [String: Any] {
        switch self {
        case .low:
            return [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 22050,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
            ]
        case .medium:
            return [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
        case .high:
            return [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ]
        }
    }
}


@MainActor
class AudioRecorderViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var selectedQuality: RecordingQuality = .medium

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?

    private let playerViewModel: AudioPlayerViewModel
    private let modelContext: ModelContext
    private let transcriptionManager: TranscriptionManager

    init(playerViewModel: AudioPlayerViewModel, modelContext: ModelContext, transcriptionManager: TranscriptionManager) {
        self.playerViewModel = playerViewModel
        self.modelContext = modelContext
        self.transcriptionManager = transcriptionManager
        super.init()
        setupAudioSessionObservers()
    }

    func startRecording() {
        let filename = "Recording_\(Date().timeIntervalSince1970).m4a"
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)

        let settings = selectedQuality.settings

        do {
            try configureAudioSessionForRecording()

            recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            recorder?.record()

            isRecording = true
            startMetering()

            print("[Recorder] Recording started at: \(fileURL)")
        } catch {
            print("[Recorder] Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        guard let recorder = recorder else { return }
        recorder.stop()
        stopMetering()

        let recordedURL = recorder.url
        let duration = recorder.currentTime

        self.recorder = nil
        isRecording = false

        Task {
            await encryptAndSaveRecording(at: recordedURL, duration: duration)
        }
    }

    private func configureAudioSessionForRecording() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(.playAndRecord,
                                mode: .default,
                                options: [
                                    .defaultToSpeaker,
                                    .allowBluetooth,
                                    .allowAirPlay,
                                    .mixWithOthers,
                                    .duckOthers
                                ])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func setupAudioSessionObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: AVAudioSession.sharedInstance())

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRouteChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: AVAudioSession.sharedInstance())
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            print("[Recorder] Interruption began")
            if isRecording { stopRecording() }
        case .ended:
            print("[Recorder] Interruption ended")
            try? AVAudioSession.sharedInstance().setActive(true)
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        print("[Recorder] Audio route changed: \(reason)")
    }

    private func startMetering() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.recorder?.updateMeters()
            let level = self.recorder?.averagePower(forChannel: 0) ?? -120
            self.audioLevel = max(0, (level + 120) / 120)
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        audioLevel = 0
    }

    private func encryptAndSaveRecording(at url: URL, duration: Double) async {
        do {
            let data = try Data(contentsOf: url)
            let encryptedData = try EncryptionConfig.encrypt(data)

            let baseTitle = "Recording at \(formattedDateString())"
            let count = await countRecordingsWithTitle(baseTitle)
            let finalTitle = count > 0 ? "Recording \(count + 1) at \(formattedDateString())" : baseTitle

            let encryptedFilename = "\(UUID().uuidString).enc"
            let encryptedURL = getDocumentsDirectory().appendingPathComponent(encryptedFilename)
            try encryptedData.write(to: encryptedURL)

            try FileManager.default.removeItem(at: url)

            let session = RecordingSession(
                title: finalTitle,
                filename: encryptedFilename,
                createdAt: Date()
            )
            modelContext.insert(session)
            try modelContext.save()

            playerViewModel.refresh()

            transcriptionManager.queueSegment(for: session, startTime: 0, endTime: duration)

        } catch {
            print("[Recorder] Encryption failed: \(error)")
        }
    }

    private func formattedDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func countRecordingsWithTitle(_ title: String) async -> Int {
        do {
            let fetchDescriptor = FetchDescriptor<RecordingSession>(
                predicate: #Predicate { $0.title.contains(title) }
            )
            return try modelContext.fetchCount(fetchDescriptor)
        } catch {
            print("[Recorder] Error counting recordings: \(error)")
            return 0
        }
    }
}
