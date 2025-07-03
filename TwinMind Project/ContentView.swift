//
//  ContentView.swift
//  TwinMind Project
//
//  Created by Boba Fett on 7/2/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            RecordingView()
            RecordingsView()
        }
        .padding()
    }
}
