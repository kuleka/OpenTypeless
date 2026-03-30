//
//  PindropUITests.swift
//  PindropUITests
//
//  Created on 2026-03-21.
//

import AppKit
import XCTest

final class PindropUITests: XCTestCase {
    private let targetBundleIdentifier = "tech.watzon.pindrop"
    private let testModeKey = "PINDROP_TEST_MODE"
    private let uiTestModeKey = "PINDROP_UI_TEST_MODE"
    private let uiTestSurfaceKey = "PINDROP_UI_TEST_SURFACE"
    private let settingsTabKey = "PINDROP_UI_TEST_SETTINGS_TAB"
    private let settingsSearchTextKey = "PINDROP_UI_TEST_SETTINGS_SEARCH_TEXT"
    private let defaultsSuiteKey = "PINDROP_TEST_USER_DEFAULTS_SUITE"
    private var launchedApplication: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if let launchedApplication, launchedApplication.state != .notRunning {
            launchedApplication.terminate()
        }
        launchedApplication = nil
    }

    func testSettingsFixtureLaunches() {
        guard assertTargetAppIsNotAlreadyRunning() else { return }

        let app = configuredApplication()
        launchedApplication = app
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.textFields["settings.search.field"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.tab.general"].waitForExistence(timeout: 2))
    }

    func testSettingsSearchShowsEmptyStateForUnknownQuery() throws {
        try skipIfTargetAppIsAlreadyRunning()

        let app = configuredApplication(searchText: "no-match-query")
        launchedApplication = app
        app.launch()

        XCTAssertTrue(app.textFields["settings.search.field"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.search.clear"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["settings.search.emptyState.title"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["settings.tab.general"].exists)
    }

    func testThemeTabFixtureLaunches() throws {
        try skipIfTargetAppIsAlreadyRunning()

        let app = configuredApplication()
        launchedApplication = app
        app.launch()

        let themeTabButton = app.buttons["settings.tab.theme"]
        XCTAssertTrue(themeTabButton.waitForExistence(timeout: 5))
        themeTabButton.tap()

        XCTAssertTrue(app.staticTexts["settings.theme.card.mode.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["settings.theme.card.light.title"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["settings.theme.card.dark.title"].waitForExistence(timeout: 2))
    }

    func testEngineSettingsFixtureLoadsEngineAndAIConfiguration() throws {
        try skipIfTargetAppIsAlreadyRunning()

        let app = configuredApplication()
        launchedApplication = app
        app.launch()

        let aiTabButton = app.buttons["settings.tab.ai-enhancement"]
        XCTAssertTrue(aiTabButton.waitForExistence(timeout: 5))
        aiTabButton.tap()

        let engineConnectionTitle = app.staticTexts["settings.ai.engineConnection.title"]
        let transcriptionModeTitle = app.staticTexts["settings.ai.sttModeCard.title"]
        let localSTTTitle = app.staticTexts["settings.ai.localSTT.title"]
        let llmProviderTitle = app.staticTexts["settings.ai.llmProvider.title"]

        XCTAssertTrue(engineConnectionTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(transcriptionModeTitle.waitForExistence(timeout: 2))
        XCTAssertTrue(localSTTTitle.waitForExistence(timeout: 2))
        XCTAssertTrue(llmProviderTitle.waitForExistence(timeout: 2))
    }

    private func configuredApplication(
        surface: String = "settings",
        settingsTab: String = "General",
        searchText: String? = nil,
        defaultsSuite: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        let resolvedDefaultsSuite = defaultsSuite ?? "tech.watzon.pindrop.ui-tests.\(UUID().uuidString)"
        app.launchEnvironment[testModeKey] = "1"
        app.launchEnvironment[uiTestModeKey] = "1"
        app.launchEnvironment[uiTestSurfaceKey] = surface
        app.launchEnvironment[settingsTabKey] = settingsTab
        if let searchText {
            app.launchEnvironment[settingsSearchTextKey] = searchText
        }
        app.launchEnvironment[defaultsSuiteKey] = resolvedDefaultsSuite
        return app
    }

    private func skipIfTargetAppIsAlreadyRunning() throws {
        let runningApplications = NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleIdentifier)
        if !runningApplications.isEmpty {
            throw XCTSkip("Quit Pindrop before running UI tests so XCTest does not force-terminate your active app session.")
        }
    }

    private func assertTargetAppIsNotAlreadyRunning() -> Bool {
        let runningApplications = NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleIdentifier)
        guard runningApplications.isEmpty else {
            XCTFail("Quit Pindrop before running UI tests so XCTest does not force-terminate your active app session.")
            return false
        }
        return true
    }

}
