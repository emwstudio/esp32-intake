import Foundation
import UIKit

struct ModelBestClient {
    enum ModelError: LocalizedError {
        case missingAPIKey
        case invalidImage
        case invalidResponse
        case httpStatus(Int)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: "未配置 ModelBest API Key"
            case .invalidImage: "无法处理这张照片"
            case .invalidResponse: "没有识别出有效的食物和热量，请重新拍摄"
            case .httpStatus(let code): "模型服务请求失败（\(code)）"
            }
        }
    }

    func estimate(in image: UIImage) async throws -> CalorieEstimate {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "ModelBestAPIKey") as? String,
              !apiKey.isEmpty else {
            throw ModelError.missingAPIKey
        }
        guard let jpegData = resizedJPEGData(for: image) else {
            throw ModelError.invalidImage
        }

        let prompt = "请识别这张照片里的食物和饮品，并估算每一项的热量，单位为千卡。只输出 JSON：{\"foods\":[{\"name\":\"食物名称\",\"calories\":整数}]}。foods 必须包含所有可见食物和饮品，不要输出解释或 Markdown。根据可见份量给出合理估计。"
        let payload: [String: Any] = [
            "model": "MiniCPM-V-4.7-35B-A3B",
            "stream": false,
            "temperature": 0,
            "max_tokens": 300,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
                        ]
                    ]
                ]
            ]]
        ]

        var request = URLRequest(
            url: URL(string: "https://api.modelbest.cn/v1/chat/completions")!,
            timeoutInterval: 120
        )
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw ModelError.httpStatus(httpResponse.statusCode)
        }
        return try parseEstimate(from: data)
    }

    private func resizedJPEGData(for image: UIImage) -> Data? {
        let maximumDimension: CGFloat = 1280
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > 0 else { return nil }
        let scale = min(1, maximumDimension / largestSide)
        let size = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }

    private func parseEstimate(from data: Data) throws -> CalorieEstimate {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}") else {
            throw ModelError.invalidResponse
        }

        let json = String(content[start...end])
        guard let jsonData = json.data(using: .utf8),
              let result = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let foods = result["foods"] as? [[String: Any]] else {
            throw ModelError.invalidResponse
        }

        var items: [FoodEstimate] = []
        for food in foods {
            guard let rawName = food["name"] as? String,
                  let number = food["calories"] as? NSNumber,
                  number.doubleValue.rounded() == number.doubleValue,
                  number.doubleValue >= 0,
                  number.doubleValue <= 100000 else {
                throw ModelError.invalidResponse
            }
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw ModelError.invalidResponse }
            items.append(FoodEstimate(name: name, calories: number.intValue))
        }
        guard !items.isEmpty else { throw ModelError.invalidResponse }
        return CalorieEstimate(foods: items)
    }
}
