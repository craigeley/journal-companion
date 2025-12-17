//
//  StateOfMindData.swift
//  JournalCompanion
//
//  Represents captured State of Mind information
//

import Foundation

struct StateOfMindData: Sendable, Codable {
    let valence: Double  // -1.0 (unpleasant) to 1.0 (pleasant)
    let labels: [String]  // Emotion descriptors
    let associations: [String]  // Life context tags

    /// Emoji representation based on valence
    var emoji: String {
        switch valence {
        case 0.6...1.0: return "😊"
        case 0.2..<0.6: return "🙂"
        case -0.2..<0.2: return "😐"
        case -0.6..<(-0.2): return "🙁"
        default: return "😢"
        }
    }

    /// Human-readable description of mood
    var description: String {
        let valenceDesc = valence > 0.3 ? "Positive" :
                         valence < -0.3 ? "Negative" : "Neutral"
        let labelList = labels.prefix(2).joined(separator: ", ")
        return "\(valenceDesc) • \(labelList)"
    }
}
