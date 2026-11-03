import SwiftUI

struct ProfileView: View {
    @State private var draft: UserProfile
    let isFirstSetup: Bool
    let onSave: (UserProfile) -> Void
    let onReset: () -> Void

    init(profile: UserProfile?, isFirstSetup: Bool, onSave: @escaping (UserProfile) -> Void, onReset: @escaping () -> Void) {
        _draft = State(initialValue: profile ?? .default)
        self.isFirstSetup = isFirstSetup
        self.onSave = onSave
        self.onReset = onReset
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    Picker("性别", selection: $draft.sex) {
                        ForEach(UserProfile.Sex.allCases) { sex in
                            Text(sex.title).tag(sex)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("年龄") {
                        TextField("15–80 岁", value: $draft.age, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("身高") {
                        TextField("cm", value: $draft.heightCentimeters, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("体重") {
                        TextField("kg", value: $draft.weightKilograms, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("活动水平") {
                    Picker("活动水平", selection: $draft.activityLevel) {
                        ForEach(UserProfile.ActivityLevel.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("体重目标") {
                    Picker("目标", selection: $draft.weightGoal) {
                        ForEach(UserProfile.WeightGoal.allCases) { goal in
                            Text(goal.title).tag(goal)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    LabeledContent("每日目标") {
                        Text("\(CalorieCalculator.dailyTarget(for: draft)) 千卡")
                            .fontWeight(.semibold)
                    }
                    Text("采用 Mifflin–St Jeor 公式，仅供一般健康参考。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !isFirstSetup {
                    Section {
                        Button("清空今日摄入", role: .destructive, action: onReset)
                    }
                }
            }
            .navigationTitle(isFirstSetup ? "设置每日目标" : "个人资料")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                    }
                    .disabled(!draft.isValid)
                }
            }
            .interactiveDismissDisabled(isFirstSetup)
        }
    }
}
