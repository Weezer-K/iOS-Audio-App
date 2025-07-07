//
//  AudioRecorderViewModel.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/2/25.
//

import SwiftUI
import AVFoundation
import SwiftData
import CryptoKit
import Accelerate
import Speech

enum RecordingQuality: String, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }
    var description: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }
    var sampleRate: Double {
        switch self {
        case .low:    return 22050
        case .medium: return 44100
        case .high:   return 48000
        }
    }
}

@MainActor
class AudioRecorderViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var selectedQuality: RecordingQuality = .medium
    @Published var showLowStorageAlert = false
    @Published var showMicPermissionAlert = false
    @Published var showSpeechRecognitionAlert = false
    @Published var isRecorderViewVisible = false

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var meterTimer: Timer?
    private var wasInterruptedWhileRecording = false
    private let recordingFlagKey = "isRecordingInProgress"
    private let playerViewModel: AudioPlayerViewModel
    private let modelContext: ModelContext
    private let transcriptionManager: TranscriptionManager
    
    init(
        playerViewModel: AudioPlayerViewModel,
        modelContext: ModelContext,
        transcriptionManager: TranscriptionManager
    ) {
        self.playerViewModel     = playerViewModel
        self.modelContext        = modelContext
        self.transcriptionManager = transcriptionManager
        super.init()
        setupAppLifecycleObservers()
        setupAudioSessionObservers()
    }
    
    func viewDidAppear()  { isRecorderViewVisible = true }
    func viewDidDisappear() {
        isRecorderViewVisible = false
        stopMetering()
    }

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .undetermined:
            session.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted { self.startRecording() }
                    else       { self.showMicPermissionAlert = true }
                }
            }
            return
        case .denied:
            showMicPermissionAlert = true
            return
        case .granted:
            break
        @unknown default:
            showMicPermissionAlert = true
            return
        }

        guard hasEnoughStorage() else {
            showLowStorageAlert = true
            return
        }

        UserDefaults.standard.set(true, forKey: recordingFlagKey)

        do {
            try configureAudioSessionForRecording()

            audioEngine = AVAudioEngine()
            guard let engine = audioEngine else { return }

            inputNode = engine.inputNode
            let hwFormat    = inputNode!.inputFormat(forBus: 0)
            audioFile = try AVAudioFile(
                forWriting: getDocumentsDirectory()
                  .appendingPathComponent("Recording_\(Date().timeIntervalSince1970).caf"),
                settings: hwFormat.settings
            )

            inputNode!.installTap(onBus: 0, bufferSize: 1024, format: hwFormat) { [weak self] buffer, _ in
                guard let self = self else { return }
                try? self.audioFile?.write(from: buffer)
                self.updateAudioLevel(from: buffer)
            }

            engine.prepare()
            try engine.start()

            isRecording = true
            startMetering()
        } catch {
            print("[Recorder] Failed to start recording:", error)
        }
    }

    func stopRecording() {
        UserDefaults.standard.set(false, forKey: recordingFlagKey)
        guard isRecording else { return }

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine?.reset()
        isRecording = false
        stopMetering()

        try? AVAudioSession.sharedInstance().setActive(false)

        guard let pcmURL = audioFile?.url else {
            print("[Recorder] No PCM file to transcode")
            return
        }
        let duration = estimateDuration(of: pcmURL)
        audioFile = nil

        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            guard let m4aURL = await self.transcodePCMToM4A(at: pcmURL) else {
                print("[Recorder] Transcode failed—dropping recording")
                return
            }
            try? FileManager.default.removeItem(at: pcmURL)
            await self.encryptAndSaveRecording(at: m4aURL, duration: duration)
        }
    }
    
    private func configureAudioSessionForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .default,
                                options: [.defaultToSpeaker,
                                          .allowBluetooth,
                                          .mixWithOthers,
                                          .duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func transcodePCMToM4A(at source: URL) async -> URL? {
        let asset = AVURLAsset(url: source)
        guard let exporter = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetAppleM4A
        ) else { return nil }
        let dest = source.deletingPathExtension().appendingPathExtension("m4a")
        exporter.outputURL      = dest
        exporter.outputFileType = .m4a
        exporter.timeRange      = CMTimeRange(start: .zero, duration: asset.duration)

        return await withCheckedContinuation { cont in
            exporter.exportAsynchronously {
                cont.resume(returning: exporter.status == .completed ? dest : nil)
            }
        }
    }

    private func estimateDuration(of url: URL) -> Double {
        CMTimeGetSeconds(AVURLAsset(url: url).duration)
    }

    private func encryptAndSaveRecording(at url: URL, duration: Double) async {
        let rawData    = try? Data(contentsOf: url)
        let encrypted  = try? (rawData.flatMap { try? EncryptionConfig.encrypt($0) })
        let encFilename = "\(UUID().uuidString).enc"
        let encURL      = getDocumentsDirectory().appendingPathComponent(encFilename)
        if let encrypted = encrypted {
            try? encrypted.write(to: encURL)
            try? FileManager.default.removeItem(at: url)
        }

        let baseTitle     = "Recording at \(formattedDateString())"
        let existingCount = await countRecordingsWithTitle(baseTitle)
        let title = existingCount > 0 ? "Recording \(existingCount+1) at \(formattedDateString())" : baseTitle
        let session = RecordingSession(title: title, filename: encFilename, createdAt: Date())
        modelContext.insert(session)
        try? modelContext.save()
        playerViewModel.refresh()

        let speechOK = await checkSpeechRecognitionPermission()
        guard speechOK else { return }

        let segmentLength = 30.0
        var startTime     = 0.0
        while startTime < duration {
            let endTime = min(startTime + segmentLength, duration)
            if endTime - startTime > 0.5 {
                transcriptionManager.queueSegment(for: session, startTime: startTime, endTime: endTime)
            }
            startTime += segmentLength
        }
    }

    private func checkSpeechRecognitionPermission() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    DispatchQueue.main.async {
                        cont.resume(returning: newStatus == .authorized)
                    }
                }
            }
        case .denied, .restricted:
            showSpeechRecognitionAlert = true
            return false
        @unknown default:
            showSpeechRecognitionAlert = true
            return false
        }
    }

    func hasEnoughStorage() -> Bool {
        let docURL = getDocumentsDirectory()
        if let vals = try? docURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let avail = vals.volumeAvailableCapacityForImportantUsage {
            return avail > 50_000_000
        }
        return true
    }
    
    private func startMetering() {
        guard isRecorderViewVisible else { return }
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in }
        RunLoop.current.add(meterTimer!, forMode: .common)
    }
    private func stopMetering() {
        meterTimer?.invalidate(); meterTimer = nil; audioLevel = 0
    }
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        var rms: Float = 0
        vDSP_rmsqv(Array(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength))), 1, &rms, vDSP_Length(buffer.frameLength))
        let level = max(0, min(1, (20 * log10(rms) + 120) / 120))
        DispatchQueue.main.async { self.audioLevel = level }
    }

    func formattedDateString() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "h:mm a"; return fmt.string(from: Date())
    }
    func countRecordingsWithTitle(_ title: String) async -> Int {
        let desc = FetchDescriptor<RecordingSession>(predicate: #Predicate { $0.title.contains(title) })
        return (try? modelContext.fetchCount(desc)) ?? 0
    }
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),  name: UIApplication.didBecomeActiveNotification,  object: nil)
    }
    @objc private func appWillResignActive() { try? AVAudioSession.sharedInstance().setActive(true) }
    @objc private func appDidBecomeActive() { try? AVAudioSession.sharedInstance().setActive(true) }

    private func setupAudioSessionObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange),    name: AVAudioSession.routeChangeNotification,      object: AVAudioSession.sharedInstance())
    }
    @objc private func handleInterruption(notification: Notification) {
        guard
            let info = notification.userInfo,
            let raw  = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }
        switch type {
        case .began:
            if isRecording { stopRecording(); wasInterruptedWhileRecording = true }
        case .ended:
            if wasInterruptedWhileRecording { startRecording(); wasInterruptedWhileRecording = false }
        @unknown default: break
        }
    }
    @objc private func handleRouteChange(notification: Notification) {
        guard
            let info   = notification.userInfo,
            let raw    = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: raw)
        else { return }
        print("[Recorder] Audio route changed:", reason)
    }
}
