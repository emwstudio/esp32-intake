import Foundation

enum CalorieCalculator {
    static func basalMetabolicRate(for profile: UserProfile) -> Int {
        let base = 10 * profile.weightKilograms
            + 6.25 * profile.heightCentimeters
            - 5 * Double(profile.age)
        let value = base + (profile.sex == .male ? 5 : -161)
        return Int(value.rounded())
    }

    static func maintenanceCalories(for profile: UserProfile) -> Int {
        Int(Double(basalMetabolicRate(for: profile)) * profile.activityLevel.factor)
    }

    static func dailyTarget(for profile: UserProfile) -> Int {
        max(0, maintenanceCalories(for: profile) + profile.weightGoal.adjustment)
    }
}
