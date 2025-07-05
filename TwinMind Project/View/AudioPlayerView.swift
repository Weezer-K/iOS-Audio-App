//
//  AudioRecorderView.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/2/25.
//

import SwiftUI
import SwiftData

struct AudioPlayerView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel

    @Query(filter: nil, sort: \RecordingSession.createdAt, order: .reverse)
    var sessions: [RecordingSession]

    @State private var expandedSessionID: UUID?

    var body: some View {
        VStack(alignment: .leading) {
            Text("Recordings")
                .font(.largeTitle)
                .padding(.horizontal)

            if sessions.isEmpty {
                Text("No recordings found")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(sessions, id: \.id) { session in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(session.title)
                                        .font(.headline)

                                    Spacer()

                                    Button {
                                        viewModel.deleteRecording(at: session.audioFileURL)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                                HStack {
                                    Button {
                                        viewModel.togglePlayback(for: session.audioFileURL)
                                    } label: {
                                        Label(
                                            viewModel.isPlaying && viewModel.currentlyPlayingURL == session.audioFileURL ? "Stop" : "Play",
                                            systemImage: viewModel.isPlaying && viewModel.currentlyPlayingURL == session.audioFileURL ? "stop.fill" : "play.fill"
                                        )
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)

                                    Spacer()

                                    Button {
                                        withAnimation {
                                            expandedSessionID = expandedSessionID == session.id ? nil : session.id
                                        }
                                    } label: {
                                        Label("Transcript", systemImage: "text.bubble")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                }
                                if expandedSessionID == session.id {
                                    segmentList(for: session)
                                        .padding(.top, 6)
                                }
                            }
                            .padding()
                            .background(Color(.systemGroupedBackground))
                            .cornerRadius(12)
                            .shadow(radius: 1)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }
    
    private func segmentList(for session: RecordingSession) -> some View {
        if session.segments.isEmpty {
            return AnyView(
                Text("No transcription yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            )
        } else {
            return AnyView(
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(session.segments, id: \.id) { segment in
                        VStack(alignment: .leading, spacing: 2) {
                            if segment.status == "completed" {
                                Text(segment.text ?? "No text")
                                    .font(.subheadline)
                            } else if segment.status == "transcribing" {
                                Text("Transcribing...")
                                    .italic()
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Not transcribed")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            )
        }
    }
}
