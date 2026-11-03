import Foundation

struct FoodEstimate: Identifiable {
    let id = UUID()
    let name: String
    let calories: Int
}

struct CalorieEstimate: Identifiable {
    let id = UUID()
    let foods: [FoodEstimate]

    var totalCalories: Int {
        foods.reduce(0) { $0 + $1.calories }
    }
}
