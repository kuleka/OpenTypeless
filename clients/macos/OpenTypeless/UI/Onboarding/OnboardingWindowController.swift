//
//  OnboardingWindowController.swift
//  OpenTypeless
//
//  Created on 2026-01-25.
//

import SwiftUI
import AppKit

@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?
    private var hostingController: NSHostingController<AnyView>?

    func showOnboarding(
        settings: SettingsStore,
        permissionManager: PermissionManager,
        engineHealthCheck: @escaping () async -> Bool,
        onComplete: @escaping () -> Void
    ) {
        guard window == nil else {
            Log.boot.info("OnboardingWindowController.showOnboarding: window already present, ordering front")
            window?.makeKeyAndOrderFront(nil)
            return
        }

        Log.boot.info("OnboardingWindowController.showOnboarding: creating window")
        let onboardingView = OnboardingWindow(
            settings: settings,
            permissionManager: permissionManager,
            engineHealthCheck: engineHealthCheck,
            onComplete: { [weak self] in
                self?.closeOnboarding()
                onComplete()
            },
            onPreferredContentSizeChange: { [weak self] size in
                self?.resizeWindowToFitContentSize(size)
            }
        )
        .environment(\.locale, settings.selectedAppLanguage.locale)

        let hosting = NSHostingController(rootView: AnyView(onboardingView))
        hostingController = hosting

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.center()

        window.setContentSize(NSSize(width: 800, height: 600))
        window.minSize = NSSize(width: 800, height: 600)

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Log.boot.info("OnboardingWindowController.showOnboarding: window visible")
    }

    private func resizeWindowToFitContentSize(_ preferredSize: CGSize) {
        guard let window else { return }

        let minimumSize = NSSize(width: 800, height: 600)
        let targetSize = NSSize(
            width: max(minimumSize.width, preferredSize.width),
            height: max(minimumSize.height, preferredSize.height)
        )

        let currentSize = window.contentLayoutRect.size
        guard abs(currentSize.width - targetSize.width) > 1 || abs(currentSize.height - targetSize.height) > 1 else {
            return
        }

        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: targetSize))
        frame.origin.x = window.frame.midX - (frame.size.width / 2)
        frame.origin.y = window.frame.maxY - frame.size.height

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true)
        }
    }

    func closeOnboarding() {
        Log.boot.info("OnboardingWindowController.closeOnboarding")
        window?.close()
        window = nil
        hostingController = nil

        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        if !showInDock {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    var isShowingOnboarding: Bool {
        window != nil && window?.isVisible == true
    }
}
