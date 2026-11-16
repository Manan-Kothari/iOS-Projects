//
//  SettingsView.swift
//  MusicShuffle
//

import SwiftUI

/// The light or dark appearance of the app.
enum AppAppearance: String, CaseIterable, Identifiable {
    /// Follows the iOS setting.
    case system
    case light
    case dark

    static let storageKey = "appearance"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// `nil` lets iOS decide.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct SettingsView: View {
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System uses the light or dark setting of your iPhone.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
