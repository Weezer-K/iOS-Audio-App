//
//  ContentView.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/2/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectivity: ConnectivityMonitor

    @StateObject private var playerViewModel: AudioPlayerViewModel
    @StateObject private var recorderViewModel: AudioRecorderViewModel

    @State private var showInterruptedRecordingAlert = false
    @State private var showSettings = false

    enum ActiveAlert: Identifiable {
        case micPermission, lowStorage, speechRecognition, interrupted
        var id: ActiveAlert { self }
    }

    @State private var activeAlert: ActiveAlert?

    init(modelContext: ModelContext) {
        if UserDefaults.standard.bool(forKey: "isRecordingInProgress") {
            _showInterruptedRecordingAlert = State(initialValue: true)
        }
        
        let transcriptionManager = TranscriptionManager(modelContext: modelContext)
        transcriptionManager.retryQueuedSegments()

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
            if !connectivity.isOnline {
                Text("You’re offline — recordings will queue")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.red.opacity(0.85))
                    .foregroundColor(.white)
            }

            AudioRecorderView(viewModel: recorderViewModel)
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
                .shadow(radius: 1)

            AudioPlayerView(viewModel: playerViewModel)
        }
        .toolbar {
            Button { showSettings = true } label: {
                Image(systemName: "gear")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .micPermission:
                return Alert(
                    title: Text("Microphone Access Denied"),
                    message: Text("To record audio, please enable Microphone access in Settings."),
                    primaryButton: .default(Text("Settings")) {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    },
                    secondaryButton: .cancel {
                        recorderViewModel.showMicPermissionAlert = false
                        activeAlert = nil
                    }
                )

            case .lowStorage:
                return Alert(
                    title: Text("Insufficient Storage"),
                    message: Text("Please free up some space before recording."),
                    dismissButton: .default(Text("OK")) {
                        recorderViewModel.showLowStorageAlert = false
                        activeAlert = nil
                    }
                )

            case .speechRecognition:
                return Alert(
                    title: Text("Speech Recognition Denied"),
                    message: Text("To transcribe audio, please enable Speech Recognition in Settings."),
                    primaryButton: .default(Text("Settings")) {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    },
                    secondaryButton: .cancel {
                        recorderViewModel.showSpeechRecognitionAlert = false
                        activeAlert = nil
                    }
                )

            case .interrupted:
                return Alert(
                    title: Text("Recording Interrupted"),
                    message: Text("Your previous recording was interrupted because the app closed. Please start again."),
                    dismissButton: .default(Text("OK")) {
                        showInterruptedRecordingAlert = false
                        UserDefaults.standard.set(false, forKey: "isRecordingInProgress")
                        activeAlert = nil
                    }
                )
            }
        }

        .onChange(of: recorderViewModel.showMicPermissionAlert) { newValue in
            if newValue, activeAlert == nil {
                activeAlert = .micPermission
            }
        }
        .onChange(of: recorderViewModel.showLowStorageAlert) { newValue in
            if newValue, activeAlert == nil {
                activeAlert = .lowStorage
            }
        }
        .onChange(of: recorderViewModel.showSpeechRecognitionAlert) { newValue in
            if newValue, activeAlert == nil {
                activeAlert = .speechRecognition
            }
        }
        .onChange(of: showInterruptedRecordingAlert) { newValue in
            if newValue, activeAlert == nil {
                activeAlert = .interrupted
            }
        }
        .padding()
    }
}
