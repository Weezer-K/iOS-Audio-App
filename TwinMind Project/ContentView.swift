//
//  ContentView.swift
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var playerViewModel: AudioPlayerViewModel
    @StateObject private var recorderViewModel: AudioRecorderViewModel

    init(modelContext: ModelContext) {
        let transcriptionManager = TranscriptionManager(modelContext: modelContext)

        let playerVM = AudioPlayerViewModel(
            modelContext: modelContext,
            transcriptionManager: transcriptionManager
        )

        _playerViewModel = StateObject(wrappedValue: playerVM)

        _recorderViewModel = StateObject(
            wrappedValue: AudioRecorderViewModel(
                playerViewModel: playerVM,
                modelContext: modelContext,
                transcriptionManager: transcriptionManager
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            AudioRecorderView(viewModel: recorderViewModel)
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
                .shadow(radius: 1)

            AudioPlayerView(viewModel: playerViewModel)
        }
        .padding()
    }
}
