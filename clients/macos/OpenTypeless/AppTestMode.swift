//
//  AppTestMode.swift
//  OpenTypeless
//
//  Created on 2026-03-21.
//

import AppKit
import SwiftUI

enum AppTestMode {
    static let unitTestModeKey = "OPENTYPELESS_TEST_MODE"
    static let uiTestModeKey = "OPENTYPELESS_UI_TEST_MODE"
    static let uiTestSurfaceKey = "OPENTYPELESS_UI_TEST_SURFACE"
    static let uiTestSettingsTabKey = "OPENTYPELESS_UI_TEST_SETTINGS_TAB"
    static let uiTestSettingsSearchTextKey = "OPENTYPELESS_UI_TEST_SETTINGS_SEARCH_TEXT"
    static let testUserDefaultsSuiteKey = "OPENTYPELESS_TEST_USER_DEFAULTS_SUITE"

    static var environment: [String: String] {
        ProcessInfo.processInfo.environment
    }

    static var isRunningUITests: Bool {
        environment[uiTestModeKey] == "1"
    }

    static var isRunningUnitTests: Bool {
        !isRunningUITests && (
            environment[unitTestModeKey] == "1"
                || environment["XCTestConfigurationFilePath"] != nil
        )
    }

    static var isRunningAnyTests: Bool {
        isRunningUITests || isRunningUnitTests
    }
}

enum AppUITestSurface: String {
    case settings
}

enum AppUITestFixture {
    static var isEnabled: Bool {
        surface != nil
    }

    static var surface: AppUITestSurface? {
        guard AppTestMode.isRunningUITests else { return nil }
        let rawValue = AppTestMode.environment[AppTestMode.uiTestSurfaceKey] ?? AppUITestSurface.settings.rawValue
        return AppUITestSurface(rawValue: rawValue)
    }

    static var settingsInitialTab: SettingsTab {
        let rawValue = AppTestMode.environment[AppTestMode.uiTestSettingsTabKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let rawValue, !rawValue.isEmpty else {
            return .general
        }

        return SettingsTab.allCases.first {
            $0.rawValue.caseInsensitiveCompare(rawValue) == .orderedSame
        } ?? .general
    }

    @ViewBuilder
    static func rootView() -> some View {
        switch surface {
        case .settings:
            SettingsFixtureRootView(initialTab: settingsInitialTab)
        case nil:
            EmptyView()
        }
    }

    @MainActor
    static func configureApplication() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct SettingsFixtureRootView: View {
    @StateObject private var settings = SettingsStore()

    let initialTab: SettingsTab

    var body: some View {
        SettingsWindow(settings: settings, initialTab: initialTab)
            .environment(\.locale, settings.selectedAppLanguage.locale)
    }
}
