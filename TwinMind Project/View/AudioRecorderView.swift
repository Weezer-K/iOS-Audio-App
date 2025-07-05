//
//  AudioRecorderView.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/2/25.
//

import SwiftUI

struct AudioRecorderView: View {
    @ObservedObject var viewModel: AudioRecorderViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text(viewModel.isRecording ? "Recording..." : "Ready to Record")
                .font(.title2)
                .bold()
                .foregroundStyle(viewModel.isRecording ? .red : .primary)
                .padding(.top, 8)

            Circle()
                .fill(viewModel.isRecording ? Color.red : Color.gray.opacity(0.3))
                .frame(width: 100, height: 100)
                .overlay(
                    Circle()
                        .strokeBorder(Color.red.opacity(0.8), lineWidth: 4)
                        .scaleEffect(1 + CGFloat(viewModel.audioLevel * 2))
                        .opacity(viewModel.isRecording ? 1 : 0)
                        .animation(.easeOut(duration: 0.2), value: viewModel.audioLevel)
                )
                .shadow(radius: 6)

            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.isRecording ? "stop.fill" : "record.circle.fill")
                        .font(.system(size: 32))
                    Text(viewModel.isRecording ? "Stop" : "Record")
                        .font(.title2)
                        .bold()
                }
                .padding()
                .foregroundColor(.white)
                .background(viewModel.isRecording ? Color.red : Color.blue)
                .cornerRadius(12)
                .shadow(radius: 4)
            }

            Spacer()
        }
        .padding()
    }
}
