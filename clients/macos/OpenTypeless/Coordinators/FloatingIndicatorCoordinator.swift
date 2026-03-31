//
//  FloatingIndicatorCoordinator.swift
//  OpenTypeless
//
//  Manages floating indicator visibility, recording/processing indicator sessions,
//  and temporary hide state. Extracted from AppCoordinator.
//

import Foundation
import os.log

@MainActor
final class FloatingIndicatorCoordinator {

    // MARK: - Dependencies

    private let settingsStore: SettingsStore
    private let floatingIndicatorPresenters: [FloatingIndicatorType: any FloatingIndicatorPresenting]

    // MARK: - State

    private var floatingIndicatorHiddenUntil: Date?
    private var floatingIndicatorHiddenTask: Task<Void, Never>?
    private(set) var activeFloatingIndicatorType: FloatingIndicatorType?

    // MARK: - Init

    init(
        settingsStore: SettingsStore,
        floatingIndicatorPresenters: [FloatingIndicatorType: any FloatingIndicatorPresenting]
    ) {
        self.settingsStore = settingsStore
        self.floatingIndicatorPresenters = floatingIndicatorPresenters
    }

    // MARK: - Visibility

    func updateFloatingIndicatorVisibility(
        isRecording: Bool = false,
        isProcessing: Bool = false,
        previousType: FloatingIndicatorType? = nil
    ) {
        guard !isFloatingIndicatorTemporarilyHidden() else {
            hideAllFloatingIndicators()
            return
        }

        guard settingsStore.floatingIndicatorEnabled else {
            hideAllFloatingIndicators()
            return
        }

        let selectedType = configuredFloatingIndicatorType()

        if isRecording || isProcessing {
            if previousType != selectedType {
                let oldType = activeFloatingIndicatorType ?? previousType ?? selectedType
                if oldType != selectedType {
                    floatingIndicatorPresenters[oldType]?.hide()
                    activeFloatingIndicatorType = selectedType
                    floatingIndicatorPresenters[selectedType]?.showForCurrentState()
                }
            }
            return
        }

        hideAllFloatingIndicators(except: selectedType)
        floatingIndicatorPresenters[selectedType]?.showIdleIndicator()
    }

    func configuredFloatingIndicatorType() -> FloatingIndicatorType {
        settingsStore.selectedFloatingIndicatorType
    }

    // MARK: - Trigger Source Mapping

    func recordingTriggerSourceForIndicatorStart(_ type: FloatingIndicatorType) -> RecordingTriggerSource {
        switch type {
        case .pill:
            .pillIndicatorStart
        case .notch:
            .floatingIndicatorStart
        case .bubble:
            .bubbleIndicatorStart
        }
    }

    func recordingTriggerSourceForIndicatorStop(_ type: FloatingIndicatorType) -> RecordingTriggerSource {
        switch type {
        case .pill:
            .pillIndicatorStop
        case .notch:
            .floatingIndicatorStop
        case .bubble:
            .bubbleIndicatorStop
        }
    }

    // MARK: - Indicator Session Lifecycle

    func hideAllFloatingIndicators(except selectedType: FloatingIndicatorType? = nil) {
        for (type, presenter) in floatingIndicatorPresenters where type != selectedType {
            presenter.hide()
        }
    }

    func startRecordingIndicatorSession() {
        guard settingsStore.floatingIndicatorEnabled else { return }

        let selectedType = configuredFloatingIndicatorType()
        activeFloatingIndicatorType = selectedType
        hideAllFloatingIndicators(except: selectedType)
        floatingIndicatorPresenters[selectedType]?.startRecording()
    }

    func transitionRecordingIndicatorToProcessing() {
        guard settingsStore.floatingIndicatorEnabled else {
            finishIndicatorSession()
            return
        }

        let activeType = activeFloatingIndicatorType ?? configuredFloatingIndicatorType()
        floatingIndicatorPresenters[activeType]?.transitionToProcessing()
    }

    func startProcessingIndicatorSession() {
        guard settingsStore.floatingIndicatorEnabled else { return }
        startRecordingIndicatorSession()
        transitionRecordingIndicatorToProcessing()
    }

    func finishIndicatorSession() {
        for presenter in floatingIndicatorPresenters.values {
            presenter.finishProcessing()
        }
        activeFloatingIndicatorType = nil

        guard settingsStore.floatingIndicatorEnabled else {
            hideAllFloatingIndicators()
            return
        }
        updateFloatingIndicatorVisibility()
    }

    // MARK: - Temporary Hide

    func isFloatingIndicatorTemporarilyHidden() -> Bool {
        guard let hiddenUntil = floatingIndicatorHiddenUntil else { return false }
        if Date() >= hiddenUntil {
            floatingIndicatorHiddenUntil = nil
            return false
        }
        return true
    }

    func clearFloatingIndicatorTemporaryHiddenState() {
        floatingIndicatorHiddenUntil = nil
        floatingIndicatorHiddenTask?.cancel()
        floatingIndicatorHiddenTask = nil
    }

    func handleHideFloatingIndicatorForOneHour() {
        let hideDuration: TimeInterval = 60 * 60
        floatingIndicatorHiddenUntil = Date().addingTimeInterval(hideDuration)

        hideAllFloatingIndicators()

        floatingIndicatorHiddenTask?.cancel()
        floatingIndicatorHiddenTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(hideDuration * 1_000_000_000))
            } catch {
                return
            }

            await MainActor.run {
                guard let self = self else { return }
                self.floatingIndicatorHiddenUntil = nil
                self.updateFloatingIndicatorVisibility()
            }
        }

        Log.ui.info("Floating indicator hidden for one hour")
    }
}
