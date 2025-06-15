import Foundation

struct UserRuleSpec: Codable {
    let replacement: String
    let pattern: String
    let requireCodeContext: Bool?
}

struct RuleDef: Codable {
    let replacement: String
    let pattern: String
    let isGroupedPattern: Bool
    let requireCodeContext: Bool

    init(replacement: String, pattern: String, requireCodeContext: Bool = false) {
        self.replacement = replacement
        self.pattern = pattern
        self.isGroupedPattern = replacement.range(of: #"\$\d+"#, options: .regularExpression) != nil
        self.requireCodeContext = requireCodeContext
    }
}

final class Redactor {
    struct Match {
        let range: NSRange
        let replacement: String
    }

    static let builtInMap: [String: RuleDef] = [
      "[REDACTED_OPENAI_KEY]": RuleDef(replacement: "[REDACTED_OPENAI_KEY]", pattern: #"sk-[a-zA-Z0-9]{48}"#, requireCodeContext: true),
      "[REDACTED_GITHUB_TOKEN]": RuleDef(replacement: "[REDACTED_GITHUB_TOKEN]", pattern: #"gh[pousr]_[a-zA-Z0-9]{36,}"#),
      "[REDACTED_AWS_KEY]": RuleDef(replacement: "[REDACTED_AWS_KEY]", pattern: #"AKIA[0-9A-Z]{16}"#),
      "[REDACTED_BEARER]": RuleDef(replacement: "[REDACTED_BEARER]", pattern: #"(?i)Authorization\s*:\s*Bearer\s+[^"\s]+"#, requireCodeContext: true),
      "[REDACTED_PW]": RuleDef(replacement: "[REDACTED_PW]", pattern: #"(?i)password\s*[:=]\s*['\"]?\S+['\"]?"#),
      "[REDACTED_IP]": RuleDef(replacement: "[REDACTED_IP]", pattern: #"\b\d{1,3}(?:\.\d{1,3}){3}\b"#),
      "[REDACTED_API_KEY]": RuleDef(replacement: "[REDACTED_API_KEY]", pattern: #"[A-Za-z0-9]{32,64}"#)
    ]
    private static var cache: [String: (modTime: Date?, map: [String: RuleDef])] = [:]

    private let overrideFile: URL?
    private var map: [String: RuleDef]

    init(overrideFile: URL? = Redactor.defaultOverrideFile()) {
        self.overrideFile = overrideFile
        self.map = Redactor.loadEffectiveMap(from: overrideFile)
    }
    
    init(customMap: [String: RuleDef]) {
        self.overrideFile = nil
        self.map = customMap
    }

    func redact(_ text: String) -> String {
        if let file = overrideFile {
            let path = file.path
            let modTime = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil
            if Redactor.cache[path]?.modTime != modTime {
                map = Redactor.loadEffectiveMap(from: overrideFile)
            }
        }

        var matches: [Match] = []

        for (key, def) in map {
            let isGrouped = def.isGroupedPattern
            let fullPattern: String

            let caseInsensitive = def.pattern.hasPrefix("(?i)")
            let cleanedPattern = def.pattern.replacingOccurrences(of: #"(?i)"#, with: "")

            if def.requireCodeContext && !isGrouped {
                let quoted = #"(["'`])("# + cleanedPattern + #")(\1)"#
                let keyed  = #"(?:\b\w+\s*[:=]\s*)("# + cleanedPattern + #")"#
                fullPattern = "(?:" + quoted + "|" + keyed + ")"
            } else {
                fullPattern = cleanedPattern
            }

            let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
            guard let regex = try? NSRegularExpression(pattern: fullPattern, options: options) else { continue }

            let escapedReplacement = NSRegularExpression.escapedTemplate(for: key)

            let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
            regex.enumerateMatches(in: text, options: [], range: nsrange) { result, _, _ in
                guard let result = result else { return }
                let replacement: String
                if isGrouped {
                    replacement = regex.replacementString(for: result, in: text, offset: 0, template: key)
                } else {
                    replacement = regex.replacementString(for: result, in: text, offset: 0, template: "$1" + escapedReplacement + "$3")
                }
                matches.append(Match(range: result.range, replacement: replacement))
            }
        }

        // Sort and filter overlapping
        matches.sort { lhs, rhs in
            if lhs.range.location == rhs.range.location {
                return lhs.range.length > rhs.range.length
            }
            return lhs.range.location < rhs.range.location
        }

        var finalMatches: [Match] = []
        var lastEnd = -1
        for m in matches {
            if m.range.location >= lastEnd {
                finalMatches.append(m)
                lastEnd = m.range.location + m.range.length
            }
        }

        // Apply in reverse
        var result = text
        for m in finalMatches.reversed() {
            if let range = Range(m.range, in: result) {
                result.replaceSubrange(range, with: m.replacement)
            }
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

    private static func loadEffectiveMap(from overrideFile: URL?) -> [String: RuleDef] {
        guard let fileURL = overrideFile else { return builtInMap }
        let path = fileURL.path
        let modTime = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil

        if let cached = cache[path], cached.modTime == modTime {
            return cached.map
        } else {
            cache.removeValue(forKey: path)
        }

        var merged = builtInMap
        if let userMap = loadUserMap(from: fileURL) {
            for rule in userMap {
                if rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    merged.removeValue(forKey: rule.replacement)
                } else {
                    merged[rule.replacement] = RuleDef(replacement: rule.replacement, pattern: rule.pattern, requireCodeContext: rule.requireCodeContext ?? false)
                }
            }
        }

        cache[path] = (modTime, merged)
        return merged
    }

    static func mergedMap(from overrideFile: URL? = defaultOverrideFile()) -> [String: RuleDef] {
        guard let fileURL = overrideFile else { return builtInMap }
        let path = fileURL.path
        let modTime = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil

        if let cached = cache[path], cached.modTime == modTime {
            return cached.map
        } else {
            cache.removeValue(forKey: path)
        }
        var merged = builtInMap
        if let userMap = loadUserMap(from: fileURL) {
            for rule in userMap {
                if rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    merged.removeValue(forKey: rule.replacement)
                } else {
                    merged[rule.replacement] = RuleDef(replacement: rule.replacement, pattern: rule.pattern, requireCodeContext: rule.requireCodeContext ?? false)
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
