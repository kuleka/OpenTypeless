//
//  CompleteStepView.swift
//  OpenTypeless
//
//  Created on 2026-03-30.
//

import SwiftUI

struct CompleteStepView: View {
    @ObservedObject var settings: SettingsStore
    let engineHealthCheck: () async -> Bool
    let onComplete: () -> Void

    @Environment(\.locale) private var locale
    @State private var showConfetti = false
    @State private var engineStatus: EngineCheckStatus = .checking

    private enum EngineCheckStatus {
        case checking
        case ready
        case failed
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            statusIcon

            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(statusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            summarySection

            Spacer()

            actionSection

            Spacer()
        }
        .padding(40)
        .task {
            await checkEngine()
        }
    }

    private var statusTitle: String {
        switch engineStatus {
        case .checking:
            return localized("Verifying Setup...", locale: locale)
        case .ready:
            return localized("You're All Set!", locale: locale)
        case .failed:
            return localized("Engine Not Responding", locale: locale)
        }
    }

    private var statusSubtitle: String {
        switch engineStatus {
        case .checking:
            return localized("Checking Engine connection...", locale: locale)
        case .ready:
            return localized("OpenTypeless is ready to use.\nClick the menu bar icon to get started.", locale: locale)
        case .failed:
            return localized("The Engine could not be reached.\nYou can still complete setup and retry later.", locale: locale)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch engineStatus {
        case .checking:
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.2))
                    .frame(width: 100, height: 100)

                ProgressView()
                    .controlSize(.large)
            }
        case .ready:
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                IconView(icon: .check, size: 48)
                    .foregroundStyle(.white)
            }
            .background(.green.opacity(0.1))
            .background(.ultraThinMaterial, in: .circle)
            .scaleEffect(showConfetti ? 1.0 : 0.5)
            .opacity(showConfetti ? 1.0 : 0)
        case .failed:
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                IconView(icon: .warning, size: 48)
                    .foregroundStyle(.white)
            }
            .background(.orange.opacity(0.1))
            .background(.ultraThinMaterial, in: .circle)
        }
    }

    private var summarySection: some View {
        VStack(spacing: 12) {
            summaryRow(
                icon: .waveform,
                label: localized("STT Mode", locale: locale),
                value: settings.sttMode == .local
                    ? localized("Local (WhisperKit)", locale: locale)
                    : localized("Remote", locale: locale)
            )
            summaryRow(
                icon: .sparkles,
                label: localized("LLM Provider", locale: locale),
                value: settings.selectedEngineLLMProvider.displayName
            )
            summaryRow(
                icon: .keyboard,
                label: localized("Toggle Hotkey", locale: locale),
                value: settings.toggleHotkey.isEmpty
                    ? localized("Not set", locale: locale)
                    : settings.toggleHotkey
            )
            summaryRow(
                icon: .server,
                label: localized("Engine", locale: locale),
                value: engineStatusLabel
            )
        }
        .padding(20)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var engineStatusLabel: String {
        switch engineStatus {
        case .checking: return localized("Checking...", locale: locale)
        case .ready: return localized("Connected", locale: locale)
        case .failed: return localized("Not responding", locale: locale)
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        switch engineStatus {
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .ready:
            Button(action: onComplete) {
                HStack {
                    Text(localized("Start Using OpenTypeless", locale: locale))
                    IconView(icon: .arrowRight, size: 16)
                }
                .font(.headline)
                .frame(maxWidth: 240)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        case .failed:
            VStack(spacing: 12) {
                Button(action: {
                    engineStatus = .checking
                    Task { await checkEngine() }
                }) {
                    Text(localized("Retry", locale: locale))
                        .font(.headline)
                        .frame(maxWidth: 200)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                Button(action: onComplete) {
                    Text(localized("Continue Anyway", locale: locale))
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryRow(icon: Icon, label: String, value: String) -> some View {
        HStack {
            IconView(icon: icon, size: 16)
                .foregroundStyle(AppColors.accent)
                .frame(width: 24)

            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }

    private func checkEngine() async {
        // Give Engine a moment to start up if it was just spawned
        try? await Task.sleep(for: .seconds(1))

        // Try up to 3 times with increasing delays
        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(Double(attempt) * 2))
            }
            if await engineHealthCheck() {
                withAnimation(.spring(duration: 0.6, bounce: 0.5)) {
                    engineStatus = .ready
                    showConfetti = true
                }
                return
            }
        }

        engineStatus = .failed
    }
}

#if DEBUG
struct CompleteStepView_Previews: PreviewProvider {
    static var previews: some View {
        CompleteStepView(
            settings: SettingsStore(),
            engineHealthCheck: { true },
            onComplete: {}
        )
        .frame(width: 800, height: 600)
    }
}
#endif
