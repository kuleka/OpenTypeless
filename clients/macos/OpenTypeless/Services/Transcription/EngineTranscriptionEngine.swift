//
//  EngineTranscriptionEngine.swift
//  OpenTypeless
//
//  Created on 2026-03-29.
//

import Foundation

@MainActor
final class EngineTranscriptionEngine: TranscriptionEngine {
    enum EngineError: Error, LocalizedError, Equatable {
        case modelNotLoaded
        case invalidAudioData

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "Engine transcription is not ready"
            case .invalidAudioData:
                return "Invalid audio data"
            }
        }
    }

    private let client: EngineClient

    private(set) var state: TranscriptionEngineState = .unloaded
    private(set) var error: Error?

    init(client: EngineClient = EngineClient()) {
        self.client = client
    }

    func loadModel(path: String) async throws {
        state = .loading
        error = nil
        state = .ready
    }

    func loadModel(name: String, downloadBase: URL?) async throws {
        state = .loading
        error = nil
        state = .ready
    }

    func transcribe(audioData: Data, options: TranscriptionOptions) async throws -> String {
        guard state == .ready else {
            throw EngineError.modelNotLoaded
        }

        guard !audioData.isEmpty else {
            throw EngineError.invalidAudioData
        }

        state = .transcribing

        let wavData = wrapFloat32PCMAsWAV(audioData, sampleRate: 16000, channels: 1)

        do {
            let response = try await client.transcribe(
                audioData: wavData,
                language: options.language.whisperLanguageCode
            )
            state = .ready
            return response.text
        } catch {
            self.error = error
            state = .ready
            throw error
        }
    }

    /// Convert raw float32 PCM samples to a 16-bit WAV file.
    private func wrapFloat32PCMAsWAV(_ rawData: Data, sampleRate: Int, channels: Int) -> Data {
        let float32Count = rawData.count / MemoryLayout<Float>.size
        let float32Samples = rawData.withUnsafeBytes { ptr in
            Array(ptr.bindMemory(to: Float.self).prefix(float32Count))
        }

        // Convert float32 [-1.0, 1.0] to int16
        var int16Samples = [Int16](repeating: 0, count: float32Samples.count)
        for i in 0..<float32Samples.count {
            let clamped = max(-1.0, min(1.0, float32Samples[i]))
            int16Samples[i] = Int16(clamped * Float(Int16.max))
        }

        let dataSize = int16Samples.count * MemoryLayout<Int16>.size
        let bitsPerSample = 16
        let byteRate = sampleRate * channels * (bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)

        var wav = Data()
        wav.append(contentsOf: "RIFF".utf8)
        wav.appendLittleEndian(UInt32(36 + dataSize))
        wav.append(contentsOf: "WAVE".utf8)
        wav.append(contentsOf: "fmt ".utf8)
        wav.appendLittleEndian(UInt32(16))           // chunk size
        wav.appendLittleEndian(UInt16(1))            // PCM format
        wav.appendLittleEndian(UInt16(channels))
        wav.appendLittleEndian(UInt32(sampleRate))
        wav.appendLittleEndian(UInt32(byteRate))
        wav.appendLittleEndian(UInt16(blockAlign))
        wav.appendLittleEndian(UInt16(bitsPerSample))
        wav.append(contentsOf: "data".utf8)
        wav.appendLittleEndian(UInt32(dataSize))
        int16Samples.withUnsafeBytes { rawBuffer in
            wav.append(contentsOf: rawBuffer)
        }

        return wav
    }

    func unloadModel() async {
        error = nil
        state = .unloaded
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var le = value.littleEndian
        append(UnsafeBufferPointer(start: &le, count: 1))
    }
}
