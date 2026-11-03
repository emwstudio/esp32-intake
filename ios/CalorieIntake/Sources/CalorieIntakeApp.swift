import SwiftUI

@main
struct CalorieIntakeApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var intakeStore = DailyIntakeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profileStore)
                .environmentObject(intakeStore)
        }
    }
}
