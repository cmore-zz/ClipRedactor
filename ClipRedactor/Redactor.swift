import Foundation

struct UserRuleSpec: Codable {
    let replacement: String
    let pattern: String
    let requireCodeContext: Bool
}

final class Redactor {
    static let builtInMap: [String: (String, Bool)] = [
      "[REDACTED_OPENAI_KEY]": (#"sk-[a-zA-Z0-9]{48}"#, false),
      "[REDACTED_GITHUB_TOKEN]": (#"gh[pousr]_[a-zA-Z0-9]{36,}"#, false),
      "[REDACTED_AWS_KEY]": (#"AKIA[0-9A-Z]{16}"#, false),
      "[REDACTED_BEARER]": (#"(?i)Authorization\s*:\s*Bearer\s+[^"\s]+"#, true),
      "[REDACTED_PW]": (#"(?i)password\s*[:=]\s*['\"]?\S+['\"]?"#, false),
      "[REDACTED_IP]": (#"\b\d{1,3}(?:\.\d{1,3}){3}\b"#, false),
      "[REDACTED_API_KEY]": (#"[A-Za-z0-9]{32,64}"#, true)
    ]
    private static var cache: [String: (modTime: Date?, map: [String: (String, Bool)])] = [:]

    private let overrideFile: URL?
    private var map: [String: (String, Bool)]

    init(overrideFile: URL? = Redactor.defaultOverrideFile()) {
        self.overrideFile = overrideFile
        self.map = Redactor.loadEffectiveMap(from: overrideFile)
    }

    func redact(_ text: String) -> String {
        if let file = overrideFile {
            let path = file.path
            let modTime = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil
            if Redactor.cache[path]?.modTime != modTime {
                map = Redactor.loadEffectiveMap(from: overrideFile)
            }
        }

        var result = text
        for (replacement, (pattern, _)) in map {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: replacement
            )
        }
        return result
    }

    func saveUserMap(_ userRules: [UserRuleSpec]) {
        guard let file = overrideFile else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(userRules)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: file)
            Redactor.cache.removeValue(forKey: file.path)
        } catch {
            print("⚠️ Failed to save ClipRedactor user rules: \(error)")
        }
    }

    private static func loadEffectiveMap(from overrideFile: URL?) -> [String: (String, Bool)] {
        guard let fileURL = overrideFile else { return builtInMap }
        let path = fileURL.path
        let modTime = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil

        if let cached = cache[path], cached.modTime == modTime {
            return cached.map
        }

        var merged = builtInMap
        if let userMap = loadUserMap(from: fileURL) {
            for rule in userMap {
                if rule.pattern == "__DELETE__" {
                    merged.removeValue(forKey: rule.replacement)
                } else {
                    merged[rule.replacement] = (rule.pattern, rule.requireCodeContext)
                }
            }
        }

        cache[path] = (modTime, merged)
        return merged
    }

    static func mergedMap(from overrideFile: URL? = defaultOverrideFile()) -> [String: (String, Bool)] {
        guard let fileURL = overrideFile else { return builtInMap }
        let path = fileURL.path
        let modTime = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil

        if let cached = cache[path], cached.modTime == modTime {
            return cached.map
        }

        var merged = builtInMap
        if let userMap = loadUserMap(from: fileURL) {
            for rule in userMap {
                if rule.pattern == "__DELETE__" {
                    merged.removeValue(forKey: rule.replacement)
                } else {
                    merged[rule.replacement] = (rule.pattern, rule.requireCodeContext)
                }
            }
        }

        cache[path] = (modTime, merged)
        return merged
    }

    static func loadUserMap(from url: URL) -> [UserRuleSpec]? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        do {
            return try JSONDecoder().decode([UserRuleSpec].self, from: data)
        } catch {
            print("⚠️ Could not parse ClipRedactor overrides.json: \(error)")
            return nil
        }
    }

    static func defaultOverrideFile() -> URL? {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClipRedactor/overrides.json")
    }
}

