//
//  TranscriptionSegment.swift
//  TwinMind Project
//

import SwiftData
import Foundation

@Model
class TranscriptionSegment: Identifiable {
    @Attribute
    var id: UUID
    @Attribute
    var startTime: Double
    @Attribute
    var endTime: Double
    @Attribute
    var audioFilename: String
    @Attribute
    var status: String
    @Attribute
    var text: String

    init(startTime: Double, endTime: Double, audioFilename: String) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.audioFilename = audioFilename
        self.status = "queued"
        self.text = ""
    }
}
