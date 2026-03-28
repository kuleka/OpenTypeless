//
//  MediaPreparationService.swift
//  Pindrop
//
//  Created on 2026-03-07.
//

@preconcurrency import AVFoundation
import Foundation

struct PreparedMediaAudio: Equatable, Sendable {
    let audioData: Data
    let duration: TimeInterval
}

protocol MediaAudioPreparing: Sendable {
    func prepareAudio(from mediaURL: URL) async throws -> PreparedMediaAudio
}

enum MediaPreparationError: Error, LocalizedError {
    case unsupportedMedia(String)
    case exportFailed(String)
    case readFailed(String)
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedMedia(let message):
            return "Unsupported media: \(message)"
        case .exportFailed(let message):
            return "Failed to export audio from media: \(message)"
        case .readFailed(let message):
            return "Failed to read audio: \(message)"
        case .conversionFailed(let message):
            return "Failed to prepare audio for transcription: \(message)"
        }
    }
}

@MainActor
final class MediaPreparationService: MediaAudioPreparing {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func prepareAudio(from mediaURL: URL) async throws -> PreparedMediaAudio {
        let readableAudioURL = try await readableAudioSource(from: mediaURL)

        do {
            let audioFile = try AVAudioFile(forReading: readableAudioURL)
            let outputFormat = Self.targetFormat
            guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: outputFormat) else {
                throw MediaPreparationError.conversionFailed("Unable to initialize audio converter.")
            }

            let inputCapacity = AVAudioFrameCount(max(4096, audioFile.length))
            guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: inputCapacity) else {
                throw MediaPreparationError.readFailed("Unable to allocate input buffer.")
            }

            try audioFile.read(into: inputBuffer)

            let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * (outputFormat.sampleRate / audioFile.processingFormat.sampleRate)) + 1
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
                throw MediaPreparationError.conversionFailed("Unable to allocate output buffer.")
            }

            final class ConversionState: @unchecked Sendable {
                var consumed = false
            }
            let conversionState = ConversionState()
            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
                if conversionState.consumed {
                    outStatus.pointee = .endOfStream
                    return nil
                }
                conversionState.consumed = true
                outStatus.pointee = .haveData
                return inputBuffer
            }

            if let conversionError {
                throw MediaPreparationError.conversionFailed(conversionError.localizedDescription)
            }

            guard status == .haveData || status == .inputRanDry || outputBuffer.frameLength > 0 else {
                throw MediaPreparationError.conversionFailed("Audio converter returned \(status.rawValue).")
            }

            guard let channelData = outputBuffer.floatChannelData else {
                throw MediaPreparationError.conversionFailed("Converted buffer did not contain float audio data.")
            }

            let frameCount = Int(outputBuffer.frameLength)
            let audioData = Data(bytes: channelData[0], count: frameCount * MemoryLayout<Float>.size)
            let duration = Double(audioFile.length) / max(audioFile.processingFormat.sampleRate, 1)
            return PreparedMediaAudio(audioData: audioData, duration: duration)
        } catch let error as MediaPreparationError {
            throw error
        } catch {
            throw MediaPreparationError.readFailed(error.localizedDescription)
        }
    }

    private func readableAudioSource(from mediaURL: URL) async throws -> URL {
        do {
            _ = try AVAudioFile(forReading: mediaURL)
            return mediaURL
        } catch {
            return try await exportAudioTrack(from: mediaURL)
        }
    }

    private func exportAudioTrack(from mediaURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: mediaURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw MediaPreparationError.unsupportedMedia("No audio track was found.")
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw MediaPreparationError.exportFailed("Unable to create export session.")
        }

        let outputURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = false

        await exportSession.export()

        if exportSession.status == .completed {
            return outputURL
        }

        throw MediaPreparationError.exportFailed(exportSession.error?.localizedDescription ?? "Export session did not complete.")
    }

    private static var targetFormat: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
    }
}
