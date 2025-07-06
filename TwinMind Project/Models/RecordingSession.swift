//
//  RecordingSession.swift
//  TwinMind Project
//

import SwiftData
import Foundation

@Model
class RecordingSession {
    @Attribute
    var id: UUID
    @Attribute
    var title: String
    @Attribute
    var filename: String
    @Attribute
    var createdAt: Date
    @Relationship
    var segments: [TranscriptionSegment]

    init(title: String, filename: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.filename = filename
        self.createdAt = createdAt
        self.segments = []
    }
}
