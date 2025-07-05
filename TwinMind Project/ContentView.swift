//
//  ContentView.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/2/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var playerViewModel: AudioPlayerViewModel
    @StateObject private var recorderViewModel: AudioRecorderViewModel

    init() {
        let playerVM = AudioPlayerViewModel()
        _playerViewModel = StateObject(wrappedValue: playerVM)
        _recorderViewModel = StateObject(wrappedValue: AudioRecorderViewModel(playerViewModel: playerVM))
    }

    var body: some View {
        VStack(spacing: 30) {
            AudioRecorderView(viewModel: recorderViewModel)
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
                .shadow(radius: 1)

            AudioPlayerView(viewModel: playerViewModel)
        }
        .padding()
    }
}
