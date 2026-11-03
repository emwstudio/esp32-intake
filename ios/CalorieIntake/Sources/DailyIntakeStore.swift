import Foundation

@MainActor
final class DailyIntakeStore: ObservableObject {
    @Published private(set) var consumedCalories = 0

    private let caloriesKey = "daily-calories.v1"
    private let dateKey = "daily-date.v1"
    private var storedDay: Date

    init() {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        let savedDay = Date(timeIntervalSince1970: defaults.double(forKey: dateKey))
        if defaults.object(forKey: dateKey) != nil && savedDay == today {
            consumedCalories = max(0, defaults.integer(forKey: caloriesKey))
            storedDay = savedDay
        } else {
            storedDay = today
            persist()
        }
    }

    func refreshForToday() {
        let today = Calendar.current.startOfDay(for: Date())
        guard storedDay != today else { return }
        storedDay = today
        consumedCalories = 0
        persist()
    }

    func addCalories(_ amount: Int) {
        precondition(amount >= 0)
        refreshForToday()
        consumedCalories += amount
        persist()
    }

    func resetToday() {
        storedDay = Calendar.current.startOfDay(for: Date())
        consumedCalories = 0
        persist()
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(consumedCalories, forKey: caloriesKey)
        defaults.set(storedDay.timeIntervalSince1970, forKey: dateKey)
    }
}
