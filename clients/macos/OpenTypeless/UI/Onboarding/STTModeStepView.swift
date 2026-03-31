//
//  STTModeStepView.swift
//  OpenTypeless
//
//  Created on 2026-03-30.
//

import SwiftUI

struct STTModeStepView: View {
    @ObservedObject var settings: SettingsStore
    let onContinue: () -> Void

    @Environment(\.locale) private var locale
    @State private var selectedMode: STTMode = .local

    var body: some View {
        VStack(spacing: 24) {
            headerSection

            VStack(spacing: 16) {
                modeCard(
                    mode: .local,
                    icon: .cpu,
                    title: localized("Local (WhisperKit)", locale: locale),
                    description: localized("Transcription runs entirely on your Mac. Fast, private, no API key needed for STT.", locale: locale),
                    badges: [localized("Private", locale: locale), localized("Offline", locale: locale)]
                )

                modeCard(
                    mode: .remote,
                    icon: .router,
                    title: localized("Remote (API)", locale: locale),
                    description: localized("Transcription via a cloud STT provider (Groq, OpenAI, Deepgram). Higher accuracy, requires API key.", locale: locale),
                    badges: [localized("Higher Accuracy", locale: locale), localized("Requires API Key", locale: locale)]
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            infoSection

            Button(action: {
                settings.sttMode = selectedMode
                onContinue()
            }) {
                Text(localized("Continue", locale: locale))
                    .font(.headline)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 24)
        .onAppear {
            selectedMode = settings.sttMode
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            IconView(icon: .waveform, size: 40)
                .foregroundStyle(AppColors.accent)
                .padding(.bottom, 8)

            Text(localized("Speech-to-Text Mode", locale: locale))
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(localized("Choose how your voice is transcribed.", locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    private func modeCard(mode: STTMode, icon: Icon, title: String, description: String, badges: [String]) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 16) {
                IconView(icon: icon, size: 28)
                    .foregroundStyle(selectedMode == mode ? AppColors.accent : .secondary)
                    .frame(width: 48, height: 48)
                    .background(selectedMode == mode ? AppColors.accent.opacity(0.1) : Color.secondary.opacity(0.05))
                    .background(.ultraThinMaterial, in: .circle)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        ForEach(badges, id: \.self) { badge in
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppColors.accent.opacity(0.1))
                                .foregroundStyle(AppColors.accent)
                                .clipShape(.capsule)
                        }
                    }
                }

                Spacer()

                Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selectedMode == mode ? AppColors.accent : .secondary.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedMode == mode ? AppColors.accent : Color.secondary.opacity(0.2), lineWidth: selectedMode == mode ? 2 : 1)
            )
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var infoSection: some View {
        HStack(spacing: 12) {
            IconView(icon: .info, size: 16)
                .foregroundStyle(.secondary)

            Text(localized("You can change this anytime in Settings → Engine.", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 40)
    }
}

#if DEBUG
struct STTModeStepView_Previews: PreviewProvider {
    static var previews: some View {
        STTModeStepView(
            settings: SettingsStore(),
            onContinue: {}
        )
        .frame(width: 800, height: 600)
    }
}
#endif
