//
//  RecentVisitsViewModel.swift
//  JournalCompanion
//
//  Manages recent visit display and selection
//

import Foundation
import SwiftUI
import Combine

@MainActor
class RecentVisitsViewModel: ObservableObject {
    @Published var visits: [PersistedVisit] = []

    private let visitTracker: SignificantLocationTracker
    private var cancellables = Set<AnyCancellable>()

    init(visitTracker: SignificantLocationTracker) {
        self.visitTracker = visitTracker

        // Observe visits from tracker
        visitTracker.$recentVisits
            .receive(on: RunLoop.main)
            .sink { [weak self] visits in
                // Sort by arrival date descending (most recent first)
                self?.visits = visits.sorted { $0.arrivalDate > $1.arrivalDate }
            }
            .store(in: &cancellables)
    }

    /// Group visits by calendar day for sectioned display
    func visitsByDate() -> [(date: Date, visits: [PersistedVisit])] {
        let calendar = Calendar.current

        // Group by start of day
        let grouped = Dictionary(grouping: visits) { visit in
            calendar.startOfDay(for: visit.arrivalDate)
        }

        // Sort by date descending and return as array of tuples
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, visits: $0.value) }
    }

    /// Format date for section header
    func sectionHeader(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    /// Format time range for visit row
    func timeRange(for visit: PersistedVisit) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let start = formatter.string(from: visit.arrivalDate)
        let end = formatter.string(from: visit.departureDate)

        return "\(start) - \(end)"
    }
}
