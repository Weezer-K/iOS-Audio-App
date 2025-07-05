//
//  RecordingSession.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/3/25.
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
    var audioFileURL: URL
    @Attribute
    var createdAt: Date
    @Relationship
    var segments: [TranscriptionSegment]

    init(title: String, audioFileURL: URL, createdAt: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.audioFileURL = audioFileURL
        self.createdAt = createdAt
        self.segments = []
    }
}
