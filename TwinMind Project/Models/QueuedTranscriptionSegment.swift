//
//  QueuedTranscriptionSegment.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/6/25.
//

import SwiftData
import Foundation

@Model
class QueuedTranscriptionSegment {
    @Attribute
    var id: UUID
    @Attribute
    var sessionID: UUID
    @Attribute
    var startTime: Double
    @Attribute
    var endTime: Double

    init(sessionID: UUID, startTime: Double, endTime: Double) {
        self.id = UUID()
        self.sessionID = sessionID
        self.startTime = startTime
        self.endTime = endTime
    }
}
