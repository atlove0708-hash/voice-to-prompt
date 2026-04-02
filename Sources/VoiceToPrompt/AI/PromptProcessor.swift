import Foundation

// ============================================================
//  プロンプト変換 + 忠実度チェック
//  意味が大きく変わる変換を防ぐ2段階システム
// ============================================================

enum PromptProcessor {

    struct Result {
        let original: String       // 元の音声テキスト
        let prompt: String         // 変換後プロンプト
        let wasConservative: Bool  // 保守的モードで生成されたか
        let success: Bool
    }

    /// 音声テキスト → プロンプト変換（忠実度チェック付き）
    static func process(
        rawText: String,
        apiKey: String,
        overlay: Overlay,
        completion: @escaping (Result) -> Void
    ) {
        let system = Config.loadSystemPrompt()
        let user = "以下の音声テキストを最適なプロンプトに変換してください:\n\n\(rawText)"

        overlay.show("✨ 変換中…", color: .systemCyan)

        GeminiAPI.request(system: system, user: user, apiKey: apiKey) { result in
            guard let text = result, !text.isEmpty else {
                // API失敗 → 元テキストをそのまま返す
                Log.api.warning("API failed, using raw text")
                completion(Result(original: rawText, prompt: rawText, wasConservative: false, success: false))
                return
            }

            // --- 忠実度チェック ---
            if isFaithful(original: rawText, converted: text) {
                Log.api.info("Faithful check passed")
                completion(Result(original: rawText, prompt: text, wasConservative: false, success: true))
            } else {
                // 忠実度が低い → 保守的プロンプトで再生成
                Log.api.warning("Faithful check FAILED, retrying with conservative prompt")
                overlay.show("🔄 再変換中…", color: .systemYellow)

                let conservativeUser = "以下の音声テキストを修正・整形してください:\n\n\(rawText)"
                GeminiAPI.request(
                    system: DefaultPrompts.conservative,
                    user: conservativeUser,
                    apiKey: apiKey,
                    temperature: Config.conservativeTemperature
                ) { retryResult in
                    if let retryText = retryResult, !retryText.isEmpty {
                        Log.api.info("Conservative generation succeeded")
                        completion(Result(original: rawText, prompt: retryText, wasConservative: true, success: true))
                    } else {
                        // 保守的生成も失敗 → 最初の結果を使う
                        completion(Result(original: rawText, prompt: text, wasConservative: false, success: true))
                    }
                }
            }
        }
    }

    // --- 忠実度チェック ---
    // 出力が入力の意味を大幅に変えていないかを検証
    private static func isFaithful(original: String, converted: String) -> Bool {
        let origLen = original.count
        let convLen = converted.count

        // 空の場合はパス
        guard origLen > 0 else { return true }

        // 1. 長さ比率チェック: 出力が入力の2.5倍以上なら意味が追加されすぎ
        let ratio = Double(convLen) / Double(origLen)
        if ratio > Config.maxLengthRatio {
            Log.api.warning("Length ratio too high: \(String(format: "%.1f", ratio))x (limit: \(Config.maxLengthRatio)x)")
            return false
        }

        // 2. キーワード保持チェック: 元テキストの重要な単語が残っているか
        let origWords = extractKeywords(original)
        let convLower = converted.lowercased()
        var preserved = 0
        for word in origWords {
            if convLower.contains(word.lowercased()) {
                preserved += 1
            }
        }
        if origWords.count > 0 {
            let preserveRatio = Double(preserved) / Double(origWords.count)
            if preserveRatio < 0.3 {
                Log.api.warning("Keyword preservation too low: \(String(format: "%.0f", preserveRatio * 100))%")
                return false
            }
        }

        return true
    }

    // 重要なキーワードを抽出（3文字以上のカタカナ・漢字・英単語）
    private static func extractKeywords(_ text: String) -> [String] {
        var keywords: [String] = []
        // 英単語（3文字以上）
        let engPattern = try? NSRegularExpression(pattern: "[a-zA-Z]{3,}")
        let nsText = text as NSString
        engPattern?.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
            if let range = match?.range { keywords.append(nsText.substring(with: range)) }
        }
        // カタカナ語（3文字以上）
        let kataPattern = try? NSRegularExpression(pattern: "[\\u30A0-\\u30FF]{3,}")
        kataPattern?.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
            if let range = match?.range { keywords.append(nsText.substring(with: range)) }
        }
        // 漢字連続（2文字以上）
        let kanjiPattern = try? NSRegularExpression(pattern: "[\\u4E00-\\u9FFF]{2,}")
        kanjiPattern?.enumerateMatches(in: text, range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
            if let range = match?.range { keywords.append(nsText.substring(with: range)) }
        }
        return keywords
    }
}
