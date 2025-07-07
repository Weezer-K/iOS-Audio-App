//
//  AudioPlayerView.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/2/25.
//


import SwiftUI
import SwiftData

struct AudioPlayerView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel

    @State private var expandedSessionID: UUID?
    @State private var confirmDeleteSession: RecordingSession?
    @State private var searchText: String = ""
    
    private var groupedRecordings: [(date: String, items: [RecordingSession])] {
        let fmt = DateFormatter()
        fmt.dateStyle = .long

        let tokens = searchText
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        let grouped = Dictionary(grouping: viewModel.recordings) { session in
            fmt.string(from: session.createdAt)
        }

        let filtered = grouped.mapValues { sessions in
            sessions.filter { session in
                guard !tokens.isEmpty else { return true }
                let titleLower = session.title.lowercased()
                let dateLower  = fmt.string(from: session.createdAt).lowercased()
                return tokens.allSatisfy { token in
                    titleLower.contains(token) || dateLower.contains(token)
                }
            }
        }

        return filtered
            .filter { !$0.value.isEmpty }
            .map { (date: $0.key, items: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Search recordings…", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .padding(.top)

            if groupedRecordings.isEmpty {
                emptyStateRow().padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 24, pinnedViews: .sectionHeaders) {
                        ForEach(groupedRecordings, id: \.date) { group in
                            Section(header:
                                Text(group.date)
                                    .font(.title3).bold()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .background(Color(.systemBackground))
                            ) {
                                ForEach(group.items) { session in
                                    recordingRow(for: session)
                                }
                            }
                        }
                        if viewModel.hasMore {
                            loadMoreButton()
                        }
                    }
                    .padding(.bottom)
                }
                .refreshable { viewModel.refresh() }
            }
        }
        .confirmationDialog(
            "Delete “\(confirmDeleteSession?.title ?? "")”?",
            isPresented: Binding<Bool>(
                get: { confirmDeleteSession != nil },
                set: { if !$0 { confirmDeleteSession = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let s = confirmDeleteSession {
                    viewModel.deleteSession(s)
                }
                confirmDeleteSession = nil
            }
            Button("Cancel", role: .cancel) {
                confirmDeleteSession = nil
            }
        }
        .onAppear {
            if viewModel.recordings.isEmpty {
                viewModel.loadRecordings()
            }
        }
    }

    private func emptyStateRow() -> some View {
        VStack {
            Spacer(minLength: 40)
            Text("No recordings found")
                .italic()
                .foregroundStyle(.secondary)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 1)
    }

    private func loadMoreButton() -> some View {
        Button("Load More") { viewModel.loadNextPage() }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(8)
            .padding(.horizontal)
    }

    private func recordingRow(for session: RecordingSession) -> some View {
        let pendingCount = viewModel.queuedCount(for: session.id)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.title).font(.headline)

                if pendingCount > 0 {
                    Text("Pending \(pendingCount)")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }

                Spacer()

                Button {
                    confirmDeleteSession = session
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if viewModel.currentlyPlayingSessionID == session.id {
                        Button(viewModel.isPlaying ? "Pause" : "Resume") {
                            viewModel.togglePause(for: session)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Play") {
                            viewModel.togglePlayback(for: session)
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button(expandedSessionID == session.id ? "Hide Transcript" : "Show Transcript") {
                        expandedSessionID = (expandedSessionID == session.id) ? nil : session.id
                        if session.segments.isEmpty {
                            viewModel.transcriptionManager?
                                .queueSegment(for: session, startTime: 0, endTime: 0)
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if let state = viewModel.playbackStates[session.id],
                   viewModel.currentlyPlayingSessionID == session.id
                {
                    Slider(
                        value: Binding(
                            get: { state.currentTime },
                            set: { viewModel.seek(to: $0, for: session) }
                        ),
                        in: 0...state.duration,
                        step: 0.1
                    )
                    Text(String(format: "%.1f / %.1f sec", state.currentTime, state.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            if expandedSessionID == session.id {
                VStack(alignment: .leading, spacing: 6) {
                    if session.segments.isEmpty {
                        Text("No transcript yet.")
                            .italic()
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(session.segments) { seg in
                            Text(seg.text.isEmpty ? "Transcribing…" : seg.text)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}
