//
//  SettingsView.swift
//  TwinMind Project
//
//  Created by Kyle Peters on 7/6/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKeyText: String = KeychainHelper.loadAPIKey() ?? ""
    @State private var saveStatus: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Deepgram API Key")) {
                    SecureField("Paste API Key here", text: $apiKeyText)
                }
                if let status = saveStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try KeychainHelper.saveAPIKey(apiKeyText)
                            saveStatus = "Key saved ✓"
                        } catch {
                            saveStatus = "Failed to save key"
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
