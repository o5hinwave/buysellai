import Foundation
import SwiftData

@ModelActor
actor HistoryReader {
    func entries() throws -> [HistoryEntry] {
        let descriptor = FetchDescriptor<HistoryEntryModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.entry)
    }
}
