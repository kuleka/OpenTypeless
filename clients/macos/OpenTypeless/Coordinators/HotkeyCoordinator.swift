//
//  HotkeyCoordinator.swift
//  OpenTypeless
//
//  Extracted from AppCoordinator — manages hotkey registration and conflict detection.
//

import Foundation
import os.log

@MainActor
final class HotkeyCoordinator {

    // MARK: - Dependencies

    private let hotkeyManager: HotkeyManager
    private let settingsStore: SettingsStore
    private let toastService: ToastService

    // MARK: - State

    private var reportedHotkeyConflicts = Set<String>()

    // MARK: - Action Closures (wired by AppCoordinator)

    var onToggleRecording: ((_ source: RecordingTriggerSource) async -> Void)?
    var onPushToTalkStart: (() async -> Void)?
    var onPushToTalkEnd: (() async -> Void)?
    var onTranslateToggle: (() async -> Void)?

    // MARK: - Initialization

    init(
        hotkeyManager: HotkeyManager,
        settingsStore: SettingsStore,
        toastService: ToastService
    ) {
        self.hotkeyManager = hotkeyManager
        self.settingsStore = settingsStore
        self.toastService = toastService
    }

    // MARK: - Hotkey Setup

    func setupHotkeys() {
        registerHotkeysFromSettings()
    }

    func registerHotkeysFromSettings() {
        hotkeyManager.unregisterAll()
        reportedHotkeyConflicts.removeAll()
        guard HotkeyRegistrationState.shouldRegisterHotkeys(hasCompletedOnboarding: settingsStore.hasCompletedOnboarding) else {
            Log.hotkey.info("Skipping hotkey registration until onboarding is complete")
            return
        }

        var registrationState = HotkeyRegistrationState()

        if !settingsStore.pushToTalkHotkey.isEmpty,
           let binding = validatedHotkeyBinding(
               displayName: "Push-to-Talk",
               hotkeyString: settingsStore.pushToTalkHotkey,
               keyCodeValue: settingsStore.pushToTalkHotkeyCode,
               modifiersValue: settingsStore.pushToTalkHotkeyModifiers
           ) {
            if canRegisterHotkey(
                identifier: "push-to-talk",
                displayName: "Push-to-Talk",
                hotkeyString: settingsStore.pushToTalkHotkey,
                keyCode: binding.keyCode,
                modifiers: binding.modifiers,
                registrationState: &registrationState
            ) {
                let didRegister = hotkeyManager.registerHotkey(
                    keyCode: binding.keyCode,
                    modifiers: binding.modifiers,
                    identifier: "push-to-talk",
                    mode: .pushToTalk,
                    onKeyDown: { [weak self] in
                        Task { @MainActor in
                            await self?.onPushToTalkStart?()
                        }
                    },
                    onKeyUp: { [weak self] in
                        Task { @MainActor in
                            await self?.onPushToTalkEnd?()
                        }
                    }
                )

                if !didRegister {
                    handleHotkeyRegistrationFailure(displayName: "Push-to-Talk", hotkeyString: settingsStore.pushToTalkHotkey)
                }
            }
        }

        if !settingsStore.toggleHotkey.isEmpty,
           let binding = validatedHotkeyBinding(
               displayName: "Toggle Recording",
               hotkeyString: settingsStore.toggleHotkey,
               keyCodeValue: settingsStore.toggleHotkeyCode,
               modifiersValue: settingsStore.toggleHotkeyModifiers
           ) {
            if canRegisterHotkey(
                identifier: "toggle-recording",
                displayName: "Toggle Recording",
                hotkeyString: settingsStore.toggleHotkey,
                keyCode: binding.keyCode,
                modifiers: binding.modifiers,
                registrationState: &registrationState
            ) {
                let didRegister = hotkeyManager.registerHotkey(
                    keyCode: binding.keyCode,
                    modifiers: binding.modifiers,
                    identifier: "toggle-recording",
                    mode: .toggle,
                    onKeyDown: { [weak self] in
                        Task { @MainActor in
                            await self?.onToggleRecording?(.hotkeyToggle)
                        }
                    },
                    onKeyUp: nil
                )

                if !didRegister {
                    handleHotkeyRegistrationFailure(displayName: "Toggle Recording", hotkeyString: settingsStore.toggleHotkey)
                }
            }
        }

        if !settingsStore.translateHotkey.isEmpty,
           let binding = validatedHotkeyBinding(
               displayName: "Translate",
               hotkeyString: settingsStore.translateHotkey,
               keyCodeValue: settingsStore.translateHotkeyCode,
               modifiersValue: settingsStore.translateHotkeyModifiers
           ) {
            Log.hotkey.info("Registering translate: keyCode=\(binding.keyCode), modifiers=0x\(String(binding.modifiers.rawValue, radix: 16)), string=\(self.settingsStore.translateHotkey)")

            if canRegisterHotkey(
                identifier: "translate",
                displayName: "Translate",
                hotkeyString: settingsStore.translateHotkey,
                keyCode: binding.keyCode,
                modifiers: binding.modifiers,
                registrationState: &registrationState
            ) {
                let didRegister = hotkeyManager.registerHotkey(
                    keyCode: binding.keyCode,
                    modifiers: binding.modifiers,
                    identifier: "translate",
                    mode: .toggle,
                    onKeyDown: { [weak self] in
                        Task { @MainActor in
                            await self?.onTranslateToggle?()
                        }
                    },
                    onKeyUp: nil
                )

                if !didRegister {
                    handleHotkeyRegistrationFailure(displayName: "Translate", hotkeyString: settingsStore.translateHotkey)
                }
            }
        }

    }

    // MARK: - Private Helpers

    private func validatedHotkeyBinding(
        displayName: String,
        hotkeyString: String,
        keyCodeValue: Int,
        modifiersValue: Int
    ) -> (keyCode: UInt32, modifiers: HotkeyManager.ModifierFlags)? {
        guard let keyCode = UInt32(exactly: keyCodeValue),
              let modifiersRawValue = UInt32(exactly: modifiersValue) else {
            Log.hotkey.error("Invalid hotkey values for \(displayName): string=\(hotkeyString), keyCode=\(keyCodeValue), modifiers=\(modifiersValue)")
            AlertManager.shared.showGenericErrorAlert(
                title: "Invalid Hotkey Configuration",
                message: "The saved hotkey for \(displayName) is invalid. Re-record this hotkey in Settings."
            )
            return nil
        }
        return (keyCode: keyCode, modifiers: HotkeyManager.ModifierFlags(rawValue: modifiersRawValue))
    }

    private func handleHotkeyRegistrationFailure(displayName: String, hotkeyString: String) {
        Log.hotkey.error("Failed to register hotkey for \(displayName): \(hotkeyString)")
        AlertManager.shared.showGenericErrorAlert(
            title: "Hotkey Registration Failed",
            message: "Could not register '\(hotkeyString)' for \(displayName). Choose a different shortcut in Settings."
        )
    }

    private func canRegisterHotkey(
        identifier: String,
        displayName: String,
        hotkeyString: String,
        keyCode: UInt32,
        modifiers: HotkeyManager.ModifierFlags,
        registrationState: inout HotkeyRegistrationState
    ) -> Bool {
        if let conflict = registrationState.register(
            identifier: identifier,
            keyCode: keyCode,
            modifiers: modifiers.rawValue
        ) {
            let existingDisplayName = hotkeyDisplayName(for: conflict.existingIdentifier)
            let conflictKey = conflict.conflictKey

            Log.hotkey.error(
                "Hotkey conflict detected for \(hotkeyString): \(existingDisplayName) conflicts with \(displayName). Ignoring \(displayName)"
            )

            if !reportedHotkeyConflicts.contains(conflictKey) {
                reportedHotkeyConflicts.insert(conflictKey)
                AlertManager.shared.showHotkeyConflictAlert(
                    hotkey: hotkeyString,
                    firstAction: existingDisplayName,
                    secondAction: displayName
                )
            }

            return false
        }

        return true
    }

    private func hotkeyDisplayName(for identifier: String) -> String {
        switch identifier {
        case "toggle-recording":
            return "Toggle Recording"
        case "push-to-talk":
            return "Push-to-Talk"
        case "translate":
            return "Translate"
        default:
            return identifier
        }
    }
}
