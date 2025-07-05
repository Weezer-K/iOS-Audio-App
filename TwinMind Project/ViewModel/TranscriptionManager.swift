//
//  TranscriptionManager.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/3/25.
//

import Foundation
import AVFoundation
import SwiftData

class TranscriptionManager {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func queueSegment(_ segment: TranscriptionSegment) {
        Task {
            await processSegment(segment)
        }
    }

    private func processSegment(_ segment: TranscriptionSegment) async {
        print("[TranscriptionManager] Queuing segment \(segment.id)")

        segment.status = "transcribing"
        try? modelContext.save()

        do {
            let trimmedFile = try await exportSegmentAudio(
                from: segment.audioFileURL,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
            print("[TranscriptionManager] Exported segment to \(trimmedFile)")
            let text = try await transcribeAudioFile(trimmedFile)
            print("[TranscriptionManager] Transcription result: \(text)")

            segment.text = text
            segment.status = "completed"
            try? modelContext.save()

        } catch {
            print("[TranscriptionManager] Error: \(error.localizedDescription)")
            segment.status = "error"
            try? modelContext.save()
        }
    }
    
    private func exportSegmentAudio(from audioURL: URL, startTime: Double, endTime: Double) async throws -> URL {
        let asset = AVAsset(url: audioURL)
        guard asset.isPlayable else {
            throw NSError(domain: "Export", code: 0, userInfo: [NSLocalizedDescriptionKey: "Audio asset is not playable"])
        }

        let exportName = "segment_\(UUID().uuidString).m4a"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(exportName)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "Export", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let end = CMTime(seconds: endTime, preferredTimescale: 600)
        exportSession.timeRange = CMTimeRangeFromTimeToTime(start: start, end: end)

        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                if exportSession.status == .completed {
                    continuation.resume(returning: outputURL)
                } else {
                    let error = exportSession.error ?? NSError(domain: "Export", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown export error"])
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func transcribeAudioFile(_ audioFile: URL) async throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["API_KEY"], !apiKey.isEmpty else {
            throw NSError(domain: "Transcription", code: 0, userInfo: [NSLocalizedDescriptionKey: "API_KEY not set in environment"])
        }

        let audioData = try Data(contentsOf: audioFile)
        guard audioData.count > 100 else {
            throw NSError(domain: "Transcription", code: 0, userInfo: [NSLocalizedDescriptionKey: "Audio file is empty or too small to upload"])
        }

        print("[DEBUG] Audio file size: \(audioData.count) bytes")
        print("[DEBUG] Transcribing with Deepgram")

        var request = URLRequest(url: URL(string: "https://api.deepgram.com/v1/listen")!)
        request.httpMethod = "POST"
        request.addValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("audio/m4a", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await URLSession.shared.upload(for: request, from: audioData)

        if let rawJSON = String(data: data, encoding: .utf8) {
            print("[DEBUG] Raw Deepgram Response: \(rawJSON)")
        }

        let decoded = try JSONDecoder().decode(DeepgramResponse.self, from: data)
        guard let transcript = decoded.results.channels.first?.alternatives.first?.transcript else {
            throw NSError(domain: "Transcription", code: 0, userInfo: [NSLocalizedDescriptionKey: "No transcript found"])
        }

        return transcript
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
