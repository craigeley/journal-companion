//
//  StateOfMindConstants.swift
//  JournalCompanion
//
//  Constants for State of Mind labels and associations
//

import Foundation
import HealthKit

struct StateOfMindConstants {

    // MARK: - All Available Labels (actual HealthKit emotions)

    static let allLabels: [(label: HKStateOfMind.Label, display: String, category: String)] = [
        // Positive emotions
        (.amazed, "Amazed", "positive"),
        (.amused, "Amused", "positive"),
        (.calm, "Calm", "positive"),
        (.confident, "Confident", "positive"),
        (.content, "Content", "positive"),
        (.excited, "Excited", "positive"),
        (.grateful, "Grateful", "positive"),
        (.happy, "Happy", "positive"),
        (.hopeful, "Hopeful", "positive"),
        (.joyful, "Joyful", "positive"),
        (.passionate, "Passionate", "positive"),
        (.peaceful, "Peaceful", "positive"),
        (.proud, "Proud", "positive"),
        (.relieved, "Relieved", "positive"),

        // Negative emotions
        (.angry, "Angry", "negative"),
        (.annoyed, "Annoyed", "negative"),
        (.anxious, "Anxious", "negative"),
        (.ashamed, "Ashamed", "negative"),
        (.disappointed, "Disappointed", "negative"),
        (.discouraged, "Discouraged", "negative"),
        (.disgusted, "Disgusted", "negative"),
        (.embarrassed, "Embarrassed", "negative"),
        (.frustrated, "Frustrated", "negative"),
        (.guilty, "Guilty", "negative"),
        (.lonely, "Lonely", "negative"),
        (.overwhelmed, "Overwhelmed", "negative"),
        (.sad, "Sad", "negative"),
        (.scared, "Scared", "negative"),
        (.stressed, "Stressed", "negative"),
        (.worried, "Worried", "negative"),

        // Neutral emotions
        (.indifferent, "Indifferent", "neutral"),
        (.surprised, "Surprised", "neutral"),
    ]

    // MARK: - All Available Associations (Life contexts)

    static let allAssociations: [(association: HKStateOfMind.Association, display: String, icon: String)] = [
        (.community, "Community", "person.3"),
        (.currentEvents, "Current Events", "newspaper"),
        (.dating, "Dating", "heart"),
        (.education, "Education", "graduationcap"),
        (.family, "Family", "house"),
        (.fitness, "Fitness", "figure.run"),
        (.friends, "Friends", "person.2"),
        (.health, "Health", "heart.text.square"),
        (.hobbies, "Hobbies", "paintbrush"),
        (.identity, "Identity", "person.crop.circle"),
        (.money, "Money", "dollarsign.circle"),
        (.partner, "Partner", "heart.circle"),
        (.selfCare, "Self-Care", "sparkles"),
        (.spirituality, "Spirituality", "leaf"),
        (.tasks, "Tasks", "checklist"),
        (.travel, "Travel", "airplane"),
        (.weather, "Weather", "cloud.sun"),
        (.work, "Work", "briefcase"),
    ]

    // MARK: - Helper Methods

    /// Get display name for a label
    static func displayName(for label: HKStateOfMind.Label) -> String {
        allLabels.first { $0.label == label }?.display ?? "Unknown"
    }

    /// Get category for a label (positive, negative, or neutral)
    static func category(for label: HKStateOfMind.Label) -> String {
        allLabels.first { $0.label == label }?.category ?? "neutral"
    }

    /// Get display name for an association
    static func displayName(for association: HKStateOfMind.Association) -> String {
        allAssociations.first { $0.association == association }?.display ?? "Unknown"
    }

    /// Get SF Symbol icon for an association
    static func icon(for association: HKStateOfMind.Association) -> String {
        allAssociations.first { $0.association == association }?.icon ?? "tag"
    }
}
