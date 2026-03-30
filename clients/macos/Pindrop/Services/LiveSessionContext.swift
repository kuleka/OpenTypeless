//
//  LiveSessionContext.swift
//  Pindrop
//
//  Extracted from AIEnhancementService.swift during legacy cleanup.
//

import Foundation

struct LiveSessionContext: Sendable, Equatable {
    static let maxFileTagCandidates = 8
    static let maxSignals = 8
    static let maxTransitions = 6

    let runtimeState: VibeRuntimeState
    let latestAppName: String?
    let latestWindowTitle: String?
    let activeFilePath: String?
    let activeFileConfidence: Double
    let workspacePath: String?
    let workspaceConfidence: Double
    let fileTagCandidates: [String]
    let styleSignals: [String]
    let codingSignals: [String]
    let transitions: [ContextSessionTransition]

    static let none = LiveSessionContext(
        runtimeState: .degraded,
        latestAppName: nil,
        latestWindowTitle: nil,
        activeFilePath: nil,
        activeFileConfidence: 0,
        workspacePath: nil,
        workspaceConfidence: 0,
        fileTagCandidates: [],
        styleSignals: [],
        codingSignals: [],
        transitions: []
    )

    var hasAnySignals: Bool {
        latestAppName != nil ||
            latestWindowTitle != nil ||
            activeFilePath != nil ||
            workspacePath != nil ||
            !fileTagCandidates.isEmpty ||
            !styleSignals.isEmpty ||
            !codingSignals.isEmpty ||
            !transitions.isEmpty
    }

    func bounded() -> LiveSessionContext {
        LiveSessionContext(
            runtimeState: runtimeState,
            latestAppName: latestAppName?.trimmingCharacters(in: .whitespacesAndNewlines),
            latestWindowTitle: latestWindowTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
            activeFilePath: activeFilePath?.trimmingCharacters(in: .whitespacesAndNewlines),
            activeFileConfidence: min(max(activeFileConfidence, 0), 1),
            workspacePath: workspacePath?.trimmingCharacters(in: .whitespacesAndNewlines),
            workspaceConfidence: min(max(workspaceConfidence, 0), 1),
            fileTagCandidates: Self.boundedUnique(fileTagCandidates, limit: Self.maxFileTagCandidates),
            styleSignals: Self.boundedUnique(styleSignals, limit: Self.maxSignals),
            codingSignals: Self.boundedUnique(codingSignals, limit: Self.maxSignals),
            transitions: Array(transitions.prefix(Self.maxTransitions))
        )
    }

    private static func boundedUnique(_ values: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            guard seen.insert(normalized).inserted else { continue }
            result.append(normalized)
            if result.count >= limit {
                break
            }
        }
        return result
    }
}
