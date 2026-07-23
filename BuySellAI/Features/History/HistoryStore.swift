import Observation

@Observable
final class HistoryStore {
    var entries: [HistoryEntry] = []
}
