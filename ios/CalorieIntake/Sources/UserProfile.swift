import Foundation

struct UserProfile: Codable, Equatable {
    enum Sex: String, Codable, CaseIterable, Identifiable {
        case male
        case female

        var id: String { rawValue }
        var title: String { self == .male ? "男" : "女" }
    }

    enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
        case sedentary
        case light
        case moderate
        case high
        case extreme

        var id: String { rawValue }
        var factor: Double {
            switch self {
            case .sedentary: 1.2
            case .light: 1.375
            case .moderate: 1.55
            case .high: 1.725
            case .extreme: 1.9
            }
        }

        var title: String {
            switch self {
            case .sedentary: "久坐不动"
            case .light: "轻度活动（每周 1–3 次）"
            case .moderate: "中度活动（每周 3–5 次）"
            case .high: "高度活动（每周 6–7 次）"
            case .extreme: "极高强度"
            }
        }
    }

    enum WeightGoal: String, Codable, CaseIterable, Identifiable {
        case loseOneKilogram
        case loseHalfKilogram
        case maintain
        case gainHalfKilogram
        case gainOneKilogram

        var id: String { rawValue }
        var adjustment: Int {
            switch self {
            case .loseOneKilogram: -1100
            case .loseHalfKilogram: -550
            case .maintain: 0
            case .gainHalfKilogram: 550
            case .gainOneKilogram: 1100
            }
        }

        var title: String {
            switch self {
            case .loseOneKilogram: "减重 1 kg/周"
            case .loseHalfKilogram: "减重 0.5 kg/周"
            case .maintain: "维持体重"
            case .gainHalfKilogram: "增重 0.5 kg/周"
            case .gainOneKilogram: "增重 1 kg/周"
            }
        }
    }

    var sex: Sex
    var age: Int
    var heightCentimeters: Double
    var weightKilograms: Double
    var activityLevel: ActivityLevel
    var weightGoal: WeightGoal

    var isValid: Bool {
        (15...80).contains(age) &&
        (100...250).contains(heightCentimeters) &&
        (30...300).contains(weightKilograms)
    }

    static let `default` = UserProfile(
        sex: .male,
        age: 30,
        heightCentimeters: 170,
        weightKilograms: 65,
        activityLevel: .sedentary,
        weightGoal: .maintain
    )
}

@MainActor
final class ProfileStore: ObservableObject {
    @Published var profile: UserProfile? {
        didSet {
            guard let profile else { return }
            let data = try? JSONEncoder().encode(profile)
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private let storageKey = "user-profile.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        profile = try? JSONDecoder().decode(UserProfile.self, from: data)
    }
}
