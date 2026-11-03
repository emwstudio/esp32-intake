import Foundation

struct DisplayClient {
    enum DisplayError: LocalizedError {
        case missingConfiguration
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingConfiguration: "未配置 ESP32 地址"
            case .invalidResponse: "ESP32 返回了异常响应"
            }
        }
    }

    private let baseURL: URL

    init() throws {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ESP32BaseURL") as? String,
              let url = URL(string: value), url.host != nil else {
            throw DisplayError.missingConfiguration
        }
        baseURL = url
    }

    func synchronize(consumed: Int, target: Int) async throws {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "kcal", value: String(consumed)),
            URLQueryItem(name: "target", value: String(target))
        ]
        let body = components.percentEncodedQuery?.data(using: .utf8)

        var request = URLRequest(
            url: baseURL.appendingPathComponent("update"),
            timeoutInterval: 8
        )
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("close", forHTTPHeaderField: "Connection")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DisplayError.invalidResponse
        }
    }
}
