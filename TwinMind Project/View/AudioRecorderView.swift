import SwiftUI

struct AudioRecorderView: View {
    @ObservedObject var viewModel: AudioRecorderViewModel
    
    let ringGradient = AngularGradient(
        gradient: Gradient(colors: [.red, .red.opacity(0.7), .red]),
        center: .center
    )

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Text(viewModel.isRecording ? "Listening..." : "Tap to Record")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 30)

                ZStack {
                    Circle()
                        .stroke(
                            viewModel.isRecording
                                ? AnyShapeStyle(ringGradient)
                                : AnyShapeStyle(Color.blue),
                            lineWidth: 12
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(
                            viewModel.isRecording
                            ? (0.5 + 0.5 * CGFloat(viewModel.audioLevel))
                            : 0.75
                        )
                        .opacity(viewModel.isRecording ? 0.8 : 0.3)
                        .blur(radius: 1.5)

                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "mic.fill")
                                .font(.system(size: 40))
                                .foregroundColor(viewModel.isRecording ? .red : .blue)
                        )
                        .shadow(radius: 10)
                        .onTapGesture {
                            if viewModel.isRecording {
                                viewModel.stopRecording()
                            } else {
                                viewModel.startRecording()
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recording Quality")
                        .font(.headline)
                        .foregroundColor(.white)

                    Picker("Quality", selection: $viewModel.selectedQuality) {
                        ForEach(RecordingQuality.allCases, id: \.self) { quality in
                            Text(quality.description).tag(quality)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}
