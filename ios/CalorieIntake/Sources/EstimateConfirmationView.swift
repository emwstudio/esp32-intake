import SwiftUI

struct EstimateConfirmationView: View {
    let estimate: CalorieEstimate
    let themeColor: Color
    let currentCalories: Int
    let targetCalories: Int
    let onAdd: () -> Void
    let onRetake: () -> Void
    let onMeasureOnly: () -> Void

    private var projectedCalories: Int {
        currentCalories + estimate.totalCalories
    }

    private var decisionColor: Color {
        if projectedCalories >= targetCalories { return .red }
        if projectedCalories * 100 >= targetCalories * 70 { return .yellow }
        return .green
    }

    private var decisionText: String {
        if projectedCalories > targetCalories {
            return "如果吃了这个，将超出今天总目标 \(projectedCalories - targetCalories) 千卡"
        }
        return "如果吃了这个，今天下一顿最多还能吃 \(targetCalories - projectedCalories) 千卡"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("确认测量结果")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)

                VStack(spacing: 14) {
                    ForEach(estimate.foods) { food in
                        HStack {
                            Text(food.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(food.calories) 千卡")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                HStack {
                    Text("合计")
                        .font(.headline)
                    Spacer()
                    Text("\(estimate.totalCalories) 千卡")
                        .font(.title2.bold())
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: projectedCalories > targetCalories
                          ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    Text(decisionText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(decisionColor)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(decisionColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                Button(action: onAdd) {
                    Text("加入今日摄入")
                        .font(.headline)
                        .foregroundStyle(themeColor == .yellow ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColor)

                HStack(spacing: 12) {
                    Button("重新测量", action: onRetake)
                        .buttonStyle(.borderedProminent)
                        .tint(themeColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    Button("不吃了", action: onMeasureOnly)
                        .buttonStyle(.borderedProminent)
                        .tint(themeColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .font(.headline)
                .foregroundStyle(themeColor == .yellow ? .black : .white)

                Text("热量为模型估算，仅供饮食决策参考。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
    }
}
