import Foundation

// ============================================================
//  Gemini API - フォールバック付き順次リクエスト
// ============================================================

enum GeminiAPI {

    /// モデルを順次試行し、最初に成功した結果を返す
    /// 429 → 5秒待って次モデル、404 → 即次モデル
    static func request(
        system: String,
        user: String,
        apiKey: String,
        temperature: Double = Config.temperature,
        completion: @escaping (String?) -> Void
    ) {
        func tryModel(_ index: Int) {
            guard index < Config.geminiModels.count else {
                Log.api.error("All models failed")
                completion(nil)
                return
            }
            let model = Config.geminiModels[index]
            Log.api.info("Trying model: \(model)")

            let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
            guard let url = URL(string: urlStr) else {
                tryModel(index + 1)
                return
            }

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = Config.apiTimeout

            let body: [String: Any] = [
                "system_instruction": ["parts": [["text": system]]],
                "contents": [["parts": [["text": user]]]],
                "generationConfig": [
                    "maxOutputTokens": Config.maxOutputTokens,
                    "temperature": temperature,
                ],
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: req) { data, resp, error in
                if let error = error {
                    Log.api.error("Network error: \(error.localizedDescription)")
                    tryModel(index + 1)
                    return
                }

                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                Log.api.info("Response \(code) from \(model)")

                if code == 429 {
                    Log.api.warning("Rate limited, waiting \(Config.rateLimitRetryDelay)s")
                    DispatchQueue.global().asyncAfter(deadline: .now() + Config.rateLimitRetryDelay) {
                        tryModel(index + 1)
                    }
                    return
                }
                if code == 404 {
                    tryModel(index + 1)
                    return
                }

                guard code == 200, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let first = candidates.first,
                      let content = first["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let text = parts.first?["text"] as? String, !text.isEmpty
                else {
                    Log.api.error("Invalid response from \(model)")
                    tryModel(index + 1)
                    return
                }

                completion(text)
            }.resume()
        }

        tryModel(0)
    }
}
