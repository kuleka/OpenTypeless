//
//  OnboardingWindow.swift
//  Pindrop
//
//  Created on 2026-01-25.
//

import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case permissions
    case sttMode
    case llmConfig
    case sttConfig
    case hotkeySetup
    case complete

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .permissions: return "Permissions"
        case .sttMode: return "STT Mode"
        case .llmConfig: return "LLM Provider"
        case .sttConfig: return "STT Provider"
        case .hotkeySetup: return "Hotkeys"
        case .complete: return "Ready"
        }
    }

    var canSkip: Bool {
        switch self {
        case .hotkeySetup: return true
        default: return false
        }
    }

    /// Steps visible in the dot indicator (sttConfig is conditional, shown inline)
    static var indicatorSteps: [OnboardingStep] {
        [.welcome, .permissions, .sttMode, .llmConfig, .hotkeySetup, .complete]
    }
}

struct OnboardingWindow: View {
    @ObservedObject var settings: SettingsStore
    let permissionManager: PermissionManager
    let engineHealthCheck: () async -> Bool
    let onComplete: () -> Void
    let onPreferredContentSizeChange: (CGSize) -> Void

    @State private var currentStep: OnboardingStep = .welcome
    @State private var direction: Int = 1
    @Namespace private var namespace

    private var canGoBack: Bool {
        switch currentStep {
        case .welcome:
            return false
        default:
            return true
        }
    }

    private var previousStep: OnboardingStep? {
        switch currentStep {
        case .welcome: return nil
        case .permissions: return .welcome
        case .sttMode: return .permissions
        case .llmConfig: return .sttMode
        case .sttConfig: return .llmConfig
        case .hotkeySetup:
            return settings.sttMode == .remote ? .sttConfig : .llmConfig
        case .complete: return .hotkeySetup
        }
    }

    private static func preferredContentSize(for step: OnboardingStep) -> CGSize {
        switch step {
        case .llmConfig, .sttConfig:
            return CGSize(width: 800, height: 700)
        default:
            return CGSize(width: 800, height: 600)
        }
    }

    private var preferredContentSize: CGSize {
        Self.preferredContentSize(for: currentStep)
    }

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                ZStack {
                    HStack {
                        if canGoBack {
                            Button(action: goBack) {
                                HStack(spacing: 4) {
                                    IconView(icon: .chevronLeft, size: 14)
                                    Text("Back")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    stepIndicator
                }
                .frame(height: 44)
                .padding(.top, 8)

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, idealWidth: preferredContentSize.width, minHeight: 600, idealHeight: preferredContentSize.height)
        .environment(\.locale, settings.selectedAppLanguage.locale)
        .onAppear {
            let initialStep = OnboardingStep(rawValue: settings.currentOnboardingStep) ?? .welcome
            currentStep = initialStep
            onPreferredContentSizeChange(Self.preferredContentSize(for: initialStep))
            Log.boot.info("OnboardingWindow appeared step=\(initialStep.title) storedStepIndex=\(settings.currentOnboardingStep)")
        }
        .onChange(of: currentStep) { _, newStep in
            onPreferredContentSizeChange(Self.preferredContentSize(for: newStep))
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .controlBackgroundColor),
                Color(nsColor: .controlBackgroundColor).opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.indicatorSteps, id: \.rawValue) { step in
                stepDot(for: step)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .capsule)
    }

    @ViewBuilder
    private func stepDot(for step: OnboardingStep) -> some View {
        let isActive = step == currentStep || (step == .llmConfig && currentStep == .sttConfig)
        let isPast = step.rawValue < currentStep.rawValue

        Circle()
            .fill(isActive ? AppColors.accent : (isPast ? AppColors.accent.opacity(0.5) : Color.secondary.opacity(0.3)))
            .frame(width: isActive ? 10 : 8, height: isActive ? 10 : 8)
            .background(isActive ? AppColors.accent.opacity(0.2) : .clear)
            .clipShape(.circle)
            .animation(.spring(duration: 0.3), value: currentStep)
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch currentStep {
            case .welcome:
                WelcomeStepView(onContinue: { goToStep(.permissions) })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

            case .permissions:
                PermissionsStepView(
                    permissionManager: permissionManager,
                    onContinue: { goToStep(.sttMode) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                ))

            case .sttMode:
                STTModeStepView(
                    settings: settings,
                    onContinue: { goToStep(.llmConfig) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                ))

            case .llmConfig:
                LLMConfigStepView(
                    settings: settings,
                    onContinue: {
                        if settings.sttMode == .remote {
                            goToStep(.sttConfig)
                        } else {
                            goToStep(.hotkeySetup)
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                ))

            case .sttConfig:
                STTConfigStepView(
                    settings: settings,
                    onContinue: { goToStep(.hotkeySetup) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                ))

            case .hotkeySetup:
                HotkeySetupStepView(
                    settings: settings,
                    onContinue: { goToStep(.complete) },
                    onSkip: { goToStep(.complete) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                ))

            case .complete:
                CompleteStepView(
                    settings: settings,
                    engineHealthCheck: engineHealthCheck,
                    onComplete: completeOnboarding
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: currentStep)
    }

    private func goToStep(_ step: OnboardingStep, direction: Int = 1) {
        Log.boot.info("Onboarding goToStep -> \(step.title) direction=\(direction)")
        self.direction = direction
        withAnimation {
            currentStep = step
            settings.currentOnboardingStep = step.rawValue
        }
    }

    private func goBack() {
        guard let previous = previousStep else { return }
        goToStep(previous, direction: -1)
    }

    private func completeOnboarding() {
        Log.boot.info("Onboarding completeOnboarding")
        settings.hasCompletedOnboarding = true
        settings.currentOnboardingStep = 0
        onComplete()
    }
}

#if DEBUG
struct OnboardingWindow_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingWindow(
            settings: SettingsStore(),
            permissionManager: PermissionManager(),
            engineHealthCheck: { true },
            onComplete: {},
            onPreferredContentSizeChange: { _ in }
        )
    }
}
#endif
