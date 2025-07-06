//
//  AudioPlayerView.swift
//

import SwiftUI
import SwiftData

struct AudioPlayerView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @State private var expandedSessionID: UUID?

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.recordings.isEmpty {
                        emptyStateRow()
                    } else {
                        ForEach(viewModel.recordings, id: \.id) { session in
                            recordingRow(for: session)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

extension AudioPlayerView {
    private func emptyStateRow() -> some View {
        VStack(spacing: 12) {
            Text("No recordings found")
                .foregroundStyle(.secondary)
                .italic()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 1)
    }

    private func recordingRow(for session: RecordingSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.title)
                    .font(.headline)
                Spacer()
                deleteButton(session)
            }
            .padding(.horizontal)
            
            HStack {
                playbackButton(session)
                Spacer()
                transcriptButton(session)
            }
            .padding(.horizontal)

            if expandedSessionID == session.id {
                segmentList(session)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 1)
    }

    private func playbackButton(_ session: RecordingSession) -> some View {
        Button {
            viewModel.togglePlayback(for: session)
        } label: {
            HStack {
                Image(systemName: viewModel.isPlaying && viewModel.currentlyPlayingSessionID == session.id ? "stop.fill" : "play.fill")
                Text(viewModel.isPlaying && viewModel.currentlyPlayingSessionID == session.id ? "Stop" : "Play")
            }
        }
        .buttonStyle(.bordered)
    }
    
    private func transcriptButton(_ session: RecordingSession) -> some View {
        Button {
            if expandedSessionID == session.id {
                expandedSessionID = nil
            } else {
                expandedSessionID = session.id
                if session.segments.isEmpty {
                    viewModel.transcriptionManager?.queueSegment(for: session, startTime: 0, endTime: 0)
                }
            }
        } label: {
            HStack {
                Image(systemName: "text.bubble")
                Text("Transcript")
            }
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.transcriptionManager == nil)
    }

    private func deleteButton(_ session: RecordingSession) -> some View {
        Button {
            viewModel.deleteSession(session)
        } label: {
            Image(systemName: "trash")
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private func segmentList(_ session: RecordingSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if session.segments.isEmpty {
                Text("No transcript yet.")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(session.segments) { segment in
                    VStack(alignment: .leading, spacing: 4) {
                        if segment.status == "complete" {
                            Text(segment.text)
                                .font(.subheadline)
                        } else if segment.status == "transcribing" {
                            Text("Transcribing…")
                                .italic()
                                .foregroundStyle(.secondary)
                        } else if segment.status == "error" {
                            Text("Error: Failed to transcribe")
                                .foregroundStyle(.red)
                                .italic()
                        } else {
                            Text("Not transcribed")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.top, 4)
    }
}
