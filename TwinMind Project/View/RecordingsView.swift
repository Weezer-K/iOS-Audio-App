//
//  RecordingsView.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/2/25.
//

import SwiftUI

struct RecordingsView: View {
    @StateObject private var viewModel = RecordingsViewModel()
    @State private var editMode: EditMode = .inactive

    @State private var renamingRecording: URL?
    @State private var newName: String = ""
    @State private var showRenameSheet = false

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.recordings.isEmpty {
                    Text("No recordings found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(viewModel.recordings, id: \.self) { recording in
                            HStack {
                                Text(recording.lastPathComponent)
                                    .lineLimit(1)
                                    .onTapGesture {
                                        if editMode.isEditing {
                                            startRenaming(recording)
                                        }
                                    }

                                Spacer()

                                if !editMode.isEditing {
                                    Button(action: {
                                        viewModel.togglePlayback(for: recording)
                                    }) {
                                        Image(systemName: viewModel.currentlyPlayingURL == recording && viewModel.isPlaying ? "stop.circle" : "play.circle")
                                            .resizable()
                                            .frame(width: 30, height: 30)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: viewModel.deleteRecording)
                    }
                }
            }
            .navigationTitle("Recordings")
            .toolbar {
                EditButton()
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $showRenameSheet) {
                NavigationView {
                    VStack {
                        Text("Rename Recording")
                            .font(.headline)
                            .padding()

                        TextField("New Name", text: $newName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()

                        Spacer()

                        Button("Save") {
                            if let url = renamingRecording {
                                viewModel.renameRecording(url, newName: newName)
                            }
                            showRenameSheet = false
                        }
                        .padding()
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .navigationBarItems(trailing: Button("Cancel") {
                        showRenameSheet = false
                    })
                }
            }
            .onAppear {
                viewModel.loadRecordings()
            }
        }
    }

    private func startRenaming(_ recording: URL) {
        newName = recording.deletingPathExtension().lastPathComponent
        renamingRecording = recording
        showRenameSheet = true
    }
}
