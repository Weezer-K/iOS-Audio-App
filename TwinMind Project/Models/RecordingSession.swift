//
//  RecordingSession.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/2/25.
//

import SwiftData
import Foundation

@Model
class RecordingSession: Identifiable {
    @Attribute var id: UUID
    var title: String
    var filename: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var segments: [TranscriptionSegment] = []

    init(title: String, filename: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.filename = filename
        self.createdAt = createdAt
    }
}
