//
//  MediaSourceKind.swift
//  Pindrop
//
//  Created on 2026-03-07.
//

import Foundation

enum MediaSourceKind: String, Codable, CaseIterable, Sendable {
    case voiceRecording
    case importedFile
    case webLink

    var isMediaBacked: Bool {
        switch self {
        case .voiceRecording:
            return false
        case .importedFile, .webLink:
            return true
        }
    }
}
