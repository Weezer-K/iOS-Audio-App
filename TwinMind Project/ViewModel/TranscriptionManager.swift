//
//  TranscriptionManager.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/3/25.
//

import Foundation
import SwiftData
import Speech
import AVFoundation
import CryptoKit

@MainActor
class TranscriptionManager {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        requestSpeechAuthorization()
    }

    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                print("[TranscriptionManager] Speech permission authorized")
            case .denied:
                print("[TranscriptionManager] Speech permission denied")
            case .restricted:
                print("[TranscriptionManager] Speech permission restricted")
            case .notDetermined:
                print("[TranscriptionManager] Speech permission not determined")
            @unknown default:
                break
            }
        }
    }

    func queueSegment(for session: RecordingSession, startTime: Double, endTime: Double) {
        Task {
            await processAndAddSegment(to: session, startTime: startTime, endTime: endTime)
        }
    }

    private func processAndAddSegment(to session: RecordingSession, startTime: Double, endTime: Double) async {
        print("[TranscriptionManager] Queuing new segment for session \(session.id)")

        let newSegment = TranscriptionSegment(
            startTime: startTime,
            endTime: endTime,
            audioFilename: session.filename,
            session: session
        )

        await MainActor.run {
            session.segments.append(newSegment)
            newSegment.status = "transcribing"
            try? modelContext.save()
        }

        await processSegment(newSegment, session: session)
    }

    private func processSegment(_ segment: TranscriptionSegment, session: RecordingSession) async {
        do {
            print("[TranscriptionManager] Start processing segment \(segment.id)")

            segment.status = "transcribing"
            try modelContext.save()

            let encryptedURL = getDocumentsDirectory().appendingPathComponent(segment.audioFilename)
            let encryptedData = try Data(contentsOf: encryptedURL)
            let decryptedData = try EncryptionConfig.decrypt(encryptedData)

            let decryptedTempURL = getTempDirectory()
                .appendingPathComponent("temp_decrypted_\(UUID().uuidString).m4a")
            try decryptedData.write(to: decryptedTempURL)
            print("[TranscriptionManager] Decrypted audio to \(decryptedTempURL)")

            let trimmedURL = try await exportSegmentAudio(
                from: decryptedTempURL,
                startTime: segment.startTime,
                endTime: segment.endTime
            )

            let transcriptText = try await transcribeAudioFile(trimmedURL)

            segment.text = transcriptText
            segment.status = "complete"
            try modelContext.save()
            print("[TranscriptionManager] Transcription complete for segment \(segment.id)")

        } catch {
            print("[TranscriptionManager] Transcription failed: \(error)")
            segment.status = "error"
            try? modelContext.save()
            queueForOffline(segment, session: session)
        }
    }

    private func exportSegmentAudio(from audioURL: URL, startTime: Double, endTime: Double) async throws -> URL {
        let duration = endTime - startTime

        if duration < 2.0 {
            print("[Trimming] Segment <2s, skipping trim")
            return audioURL
        }

        let trimmedURL = getTempDirectory()
            .appendingPathComponent("trimmed_\(UUID().uuidString).m4a")
        let asset = AVURLAsset(url: audioURL)

        if #available(iOS 16.0, *) {
            let playable = try await asset.load(.isPlayable)
            guard playable else {
                throw NSError(domain: "AudioTrimming", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Asset not playable"])
            }
        }

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw NSError(domain: "AudioTrimming", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }

        exportSession.outputURL = trimmedURL
        exportSession.outputFileType = .m4a
        let startCM = CMTime(seconds: startTime, preferredTimescale: 600)
        let durationCM = CMTime(seconds: duration, preferredTimescale: 600)
        exportSession.timeRange = CMTimeRange(start: startCM, duration: durationCM)

        await withCheckedContinuation { cont in
            exportSession.exportAsynchronously { cont.resume() }
        }

        guard exportSession.status == .completed else {
            throw NSError(domain: "AudioTrimming", code: -5,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Trim failed: \(exportSession.error?.localizedDescription ?? "unknown")"])
        }

        print("[Trimming] Trimmed audio to \(trimmedURL)")
        return trimmedURL
    }

    private func transcribeAudioFile(_ audioFile: URL) async throws -> String {
        guard let apiKey = KeychainHelper.loadAPIKey(), !apiKey.isEmpty else {
            print("[TranscriptionManager] No Deepgram key—using Apple Speech")
            return try await transcribeWithAppleSpeech(at: audioFile)
        }

        var attempts = 0
        var delay: Double = 2
        while attempts < 5 {
            do {
                print("[TranscriptionManager] Trying Deepgram (attempt \(attempts + 1))")
                let result = try await transcribeWithDeepgram(audioFile, apiKey: apiKey)
                if !result.isEmpty { return result }
                throw NSError(domain: "Transcription", code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Empty transcript"])
            } catch {
                print("[TranscriptionManager] Deepgram failed (\(error))")
                attempts += 1
                if attempts < 5 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2
                }
            }
        }

        print("[TranscriptionManager] Falling back to Apple Speech")
        return try await transcribeWithAppleSpeech(at: audioFile)
    }

    private func transcribeWithDeepgram(_ audioFile: URL, apiKey: String) async throws -> String {
        let audioData = try Data(contentsOf: audioFile)
        var request = URLRequest(
            url: URL(string: "https://api.deepgram.com/v1/listen")!
        )
        request.httpMethod = "POST"
        request.addValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("audio/m4a", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await URLSession.shared.upload(for: request, from: audioData)
        if let raw = String(data: data, encoding: .utf8) {
            print("[DEBUG] Deepgram Raw Response: \(raw)")
        }

        let decoded = try JSONDecoder().decode(DeepgramResponse.self, from: data)
        guard let transcript = decoded
                .results
                .channels
                .first?
                .alternatives
                .first?
                .transcript,
              !transcript.isEmpty
        else {
            throw NSError(domain: "Transcription", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "No transcript found"])
        }
        return transcript
    }

    private func transcribeWithAppleSpeech(at url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
                cont.resume(throwing: NSError(
                    domain: "AppleSpeech",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable"]
                ))
                return
            }
            let request = SFSpeechURLRecognitionRequest(url: url)
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    cont.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    private func queueForOffline(_ segment: TranscriptionSegment, session: RecordingSession) {
        let queued = QueuedTranscriptionSegment(
            sessionID: session.id,
            startTime: segment.startTime,
            endTime: segment.endTime
        )
        modelContext.insert(queued)
        try? modelContext.save()
        print("[TranscriptionManager] Queued segment \(segment.id) for offline retry")
    }

    func retryQueuedSegments() {
        let fetch = FetchDescriptor<QueuedTranscriptionSegment>()
        if let queuedList = try? modelContext.fetch(fetch) {
            for queued in queuedList {
                if let session = findSession(by: queued.sessionID) {
                    queueSegment(for: session, startTime: queued.startTime, endTime: queued.endTime)
                    modelContext.delete(queued)
                }
            }
            try? modelContext.save()
        }
    }

    private func findSession(by id: UUID) -> RecordingSession? {
        let fetch = FetchDescriptor<RecordingSession>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(fetch).first
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func getTempDirectory() -> URL {
        FileManager.default.temporaryDirectory
    }
}


struct DeepgramResponse: Codable {
    let results: DeepgramResults
}

struct DeepgramResults: Codable {
    let channels: [DeepgramChannel]
}

struct DeepgramChannel: Codable {
    let alternatives: [DeepgramAlternative]
}

struct DeepgramAlternative: Codable {
    let transcript: String
}
