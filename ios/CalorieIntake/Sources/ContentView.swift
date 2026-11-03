import PhotosUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var intakeStore: DailyIntakeStore
    @State private var isShowingCamera = false
    @State private var isShowingSourcePicker = false
    @State private var isShowingProfile = false
    @State private var isAnalyzing = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingEstimate: CalorieEstimate?
    @State private var statusMessage = "拍照或从相册选择，测量后再决定是否计入"
    @State private var statusIsError = false

    private var target: Int {
        profileStore.profile.map(CalorieCalculator.dailyTarget) ?? 0
    }

    private var remaining: Int {
        target - intakeStore.consumedCalories
    }

    private var intakeColor: Color {
        guard target > 0 else { return .green }
        if intakeStore.consumedCalories >= target { return .red }
        if intakeStore.consumedCalories * 100 >= target * 70 { return .yellow }
        return .green
    }

    private var intakeProgress: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(intakeStore.consumedCalories) / Double(target))
    }

    private var intakeButtonTextColor: Color {
        intakeColor == .yellow ? .black : .white
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.055, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    HStack {
                        Button("硬件配对") {}
                            .font(.headline)
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.08), in: Capsule())
                        Spacer()
                        Button("基本信息") {
                            isShowingProfile = true
                        }
                        .font(.headline)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.08), in: Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: intakeProgress)
                            .stroke(
                                intakeColor,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 8) {
                            Text(remaining >= 0 ? "今日还可摄入" : "今日已超出")
                                .font(.title2)
                                .foregroundStyle(intakeColor)
                            Text("\(abs(remaining))")
                                .font(.system(size: 84, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.55)
                                .lineLimit(1)
                                .foregroundStyle(.white)
                            Text("千卡")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 280, height: 280)

                    Spacer()

                    HStack(spacing: 28) {
                        LabeledContent("目标") {
                            Text("\(target)")
                        }
                        LabeledContent("已摄入") {
                            Text("\(intakeStore.consumedCalories)")
                        }
                    }
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 28)

                    Button {
                        isShowingSourcePicker = true
                    } label: {
                        HStack(spacing: 10) {
                            if isAnalyzing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(intakeButtonTextColor)
                            } else {
                                Image(systemName: "camera.fill")
                            }
                            Text(isAnalyzing ? "正在识别…" : "拍照测热量")
                        }
                        .font(.title2.bold())
                        .foregroundStyle(intakeButtonTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(intakeColor)
                    .disabled(isAnalyzing || profileStore.profile == nil)
                    .padding(.horizontal, 28)

                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(statusIsError ? .red : .secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()
                }
            }
            .sheet(isPresented: $isShowingSourcePicker) {
                VStack(spacing: 18) {
                    Text("选择照片来源")
                        .font(.title3.bold())
                        .padding(.top, 12)

                    Button {
                        isShowingSourcePicker = false
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            isShowingCamera = true
                        }
                    } label: {
                        Label("拍照", systemImage: "camera.fill")
                            .foregroundStyle(intakeButtonTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(intakeColor)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("相册选择", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(intakeColor)

                    Button("取消", role: .cancel) {
                        isShowingSourcePicker = false
                    }
                    .font(.subheadline)
                    .foregroundStyle(intakeColor)
                }
                .padding(24)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(red: 0.055, green: 0.07, blue: 0.09))
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    isShowingCamera = false
                    if let image {
                        Task { await analyze(image) }
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isShowingProfile) {
                ProfileView(
                    profile: profileStore.profile,
                    isFirstSetup: profileStore.profile == nil,
                    onSave: { profile in
                        profileStore.profile = profile
                        isShowingProfile = false
                        Task { await synchronize() }
                    },
                    onReset: {
                        intakeStore.resetToday()
                        isShowingProfile = false
                        Task { await synchronize() }
                    }
                )
            }
            .sheet(item: $pendingEstimate) { estimate in
                EstimateConfirmationView(
                    estimate: estimate,
                    themeColor: intakeColor,
                    currentCalories: intakeStore.consumedCalories,
                    targetCalories: target,
                    onAdd: {
                        intakeStore.addCalories(estimate.totalCalories)
                        pendingEstimate = nil
                        statusMessage = "已加入 \(estimate.totalCalories) 千卡，正在同步…"
                        Task { await synchronize() }
                    },
                    onRetake: {
                        pendingEstimate = nil
                        statusMessage = "请重新选择照片来源"
                        Task {
                            try? await Task.sleep(nanoseconds: 350_000_000)
                            isShowingSourcePicker = true
                        }
                    },
                    onMeasureOnly: {
                        pendingEstimate = nil
                        statusIsError = false
                        statusMessage = "测量完成，本次未计入今日摄入"
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(Color(red: 0.055, green: 0.07, blue: 0.09))
            }
            .task(id: selectedPhotoItem) {
                await loadSelectedPhoto()
            }
            .onAppear {
                intakeStore.refreshForToday()
                if profileStore.profile == nil {
                    isShowingProfile = true
                } else {
                    Task { await synchronize() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)) { _ in
                intakeStore.refreshForToday()
                Task { await synchronize() }
            }
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }
        isShowingSourcePicker = false
        isAnalyzing = true
        statusIsError = false
        statusMessage = "正在读取照片…"
        defer {
            isAnalyzing = false
            self.selectedPhotoItem = nil
        }

        do {
            let data = try await selectedPhotoItem.loadTransferable(type: Data.self)
            guard let data, let image = UIImage(data: data) else {
                statusIsError = true
                statusMessage = "无法读取这张图片"
                return
            }
            await analyze(image)
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
    }

    private func analyze(_ image: UIImage) async {
        isAnalyzing = true
        statusIsError = false
        statusMessage = "正在识别食物并估算热量…"
        defer { isAnalyzing = false }

        do {
            let estimate = try await ModelBestClient().estimate(in: image)
            statusMessage = "请确认识别结果"
            pendingEstimate = estimate
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
    }

    private func synchronize() async {
        guard profileStore.profile != nil else { return }
        do {
            try await DisplayClient().synchronize(
                consumed: intakeStore.consumedCalories,
                target: target
            )
            statusIsError = false
            statusMessage = "ESP32 屏幕已同步"
        } catch {
            statusIsError = true
            statusMessage = "屏幕同步失败：\(error.localizedDescription)"
        }
    }
}
