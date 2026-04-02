import Foundation

// ============================================================
//  自動アップデートチェック
//  GitHub Releases APIで最新バージョンを確認
//  Sparkleなし・外部依存なしで動作
// ============================================================

enum UpdateChecker {

    struct Release {
        let version: String
        let url: String
        let notes: String
    }

    /// GitHub Releasesから最新バージョンを確認
    /// repo: "owner/repo" 形式
    static func check(
        repo: String = "kobayashitakuro/voice-to-prompt",
        completion: @escaping (Release?) -> Void
    ) {
        let urlStr = "https://api.github.com/repos/\(repo)/releases/latest"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }

        var req = URLRequest(url: url)
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { data, resp, error in
            guard let data = data,
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String
            else {
                Log.update.info("No update info available")
                completion(nil)
                return
            }

            let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let htmlUrl = json["html_url"] as? String ?? ""
            let body = json["body"] as? String ?? ""

            if isNewer(version, than: Config.version) {
                Log.update.info("Update available: \(version)")
                completion(Release(version: version, url: htmlUrl, notes: body))
            } else {
                Log.update.info("Up to date (current: \(Config.version), latest: \(version))")
                completion(nil)
            }
        }.resume()
    }

    /// セマンティックバージョン比較
    private static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}
