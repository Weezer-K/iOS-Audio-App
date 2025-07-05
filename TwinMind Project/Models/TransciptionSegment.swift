//
//  TranscriptionSegment.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/3/25.
//

import Foundation
import SwiftData

@Model
class TranscriptionSegment {
    var id: UUID
    var startTime: Double
    var endTime: Double
    var audioFileURL: URL
    var text: String?
    var status: String

    init(startTime: Double, endTime: Double, audioFileURL: URL) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.audioFileURL = audioFileURL
        self.status = "queued"
    }
}
