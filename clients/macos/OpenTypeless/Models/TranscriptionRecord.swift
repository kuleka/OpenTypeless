import Foundation
import SwiftData

typealias TranscriptionRecord = TranscriptionRecordSchemaV6.TranscriptionRecord
typealias MediaFolder = TranscriptionRecordSchemaV6.MediaFolder

extension TranscriptionRecord {
    var diarizedSegments: [DiarizedTranscriptSegment] {
        guard let diarizationSegmentsJSON,
              let data = diarizationSegmentsJSON.data(using: .utf8),
              let segments = try? JSONDecoder().decode([DiarizedTranscriptSegment].self, from: data) else {
            return []
        }
        return segments
    }
}
