//
//  TranscriptionManager.swift
//

import Foundation
import SwiftData
import Speech
import AVFoundation

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
            await self.processAndAddSegment(to: session, startTime: startTime, endTime: endTime)
        }
    }

    private func processAndAddSegment(to session: RecordingSession, startTime: Double, endTime: Double) async {
        print("[TranscriptionManager] Queuing new segment for session \(session.id)")

        let newSegment = TranscriptionSegment(
            startTime: startTime,
            endTime: endTime,
            audioFilename: session.filename
        )

        await MainActor.run {
            session.segments.append(newSegment)
            newSegment.status = "transcribing"
            try? modelContext.save()
        }

        await processSegment(newSegment)
    }

    func processSegment(_ segment: TranscriptionSegment) async {
        do {
            print("[TranscriptionManager] Start processing segment \(segment.id)")

            segment.status = "transcribing"
            try modelContext.save()
            let encryptedURL = getDocumentsDirectory().appendingPathComponent(segment.audioFilename)
            let encryptedData = try Data(contentsOf: encryptedURL)
            let decryptedData = try EncryptionConfig.decrypt(encryptedData)

            let decryptedTempURL = getTempDirectory().appendingPathComponent("temp_decrypted_\(UUID().uuidString).m4a")
            try decryptedData.write(to: decryptedTempURL)

            print("[TranscriptionManager] Decrypted audio to \(decryptedTempURL)")

            let trimmedFile = try await exportSegmentAudio(
                from: decryptedTempURL,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
            let transcriptText = try await transcribeAudioFile(trimmedFile)
            segment.text = transcriptText
            segment.status = "complete"
            try modelContext.save()

            print("[TranscriptionManager] Transcription complete.")

        } catch {
            print("[TranscriptionManager] Transcription failed: \(error)")
            segment.status = "error"
            try? modelContext.save()
        }
    }

    private func exportSegmentAudio(from audioURL: URL, startTime: Double, endTime: Double) async throws -> URL {
        guard startTime > 0 || endTime > 0 else {
            return audioURL
        }

        let asset = AVAsset(url: audioURL)
        let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)!
        let outputURL = getTempDirectory().appendingPathComponent("trimmed_\(UUID().uuidString).m4a")

        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a

        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let duration = CMTime(seconds: endTime - startTime, preferredTimescale: 600)
        exporter.timeRange = CMTimeRange(start: start, duration: duration)

        return try await withCheckedThrowingContinuation { continuation in
            exporter.exportAsynchronously {
                if let error = exporter.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: outputURL)
                }
            }
        }
    }

    private func transcribeAudioFile(_ audioFile: URL) async throws -> String {
        var attempts = 0
        while attempts < 5 {
            do {
                print("[TranscriptionManager] Trying Deepgram (attempt \(attempts + 1))")
                let transcript = try await transcribeWithDeepgram(audioFile)
                if !transcript.isEmpty {
                    return transcript
                }
            } catch {
                print("[TranscriptionManager] Deepgram failed on attempt \(attempts + 1): \(error.localizedDescription)")
            }
            attempts += 1
        }

        print("[TranscriptionManager] Falling back to Apple Speech framework")
        return try await transcribeWithAppleSpeech(at: audioFile)
    }

    private func transcribeWithDeepgram(_ audioFile: URL) async throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["API_KEY"], !apiKey.isEmpty else {
            throw NSError(domain: "Transcription", code: 0, userInfo: [NSLocalizedDescriptionKey: "API_KEY not set"])
        }

        let audioData = try Data(contentsOf: audioFile)

        var request = URLRequest(url: URL(string: "https://api.deepgram.com/v1/listen")!)
        request.httpMethod = "POST"
        request.addValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("audio/m4a", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await URLSession.shared.upload(for: request, from: audioData)

        if let rawJSON = String(data: data, encoding: .utf8) {
            print("[DEBUG] Deepgram Raw Response: \(rawJSON)")
        }

        let decoded = try JSONDecoder().decode(DeepgramResponse.self, from: data)
        guard let transcript = decoded.results.channels.first?.alternatives.first?.transcript,
              !transcript.isEmpty else {
            throw NSError(domain: "Transcription", code: 0, userInfo: [NSLocalizedDescriptionKey: "No transcript found"])
        }

        return transcript
    }

    private func transcribeWithAppleSpeech(at url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let recognizer = SFSpeechRecognizer()
            guard let recognizer = recognizer, recognizer.isAvailable else {
                continuation.resume(throwing: NSError(domain: "AppleSpeech", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"]))
                return
            }

            let request = SFSpeechURLRecognitionRequest(url: url)
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
