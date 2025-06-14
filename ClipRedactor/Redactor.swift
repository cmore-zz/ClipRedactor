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

    func redact(_ text: String) -> String {
        if let file = overrideFile {
            let path = file.path
            let modTime = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil
            if Redactor.cache[path]?.modTime != modTime {
                map = Redactor.loadEffectiveMap(from: overrideFile)
            }
        }

        var result = text
        for (key, def) in map {
            let isGrouped = def.isGroupedPattern
            let fullPattern: String

            if def.requireCodeContext && !isGrouped {
                let quoted = #"(["'`])("# + def.pattern + #")(\1)"#
                let keyed  = #"(?:\b\w+\s*[:=]\s*)("# + def.pattern + #")"#
                fullPattern = "(?:" + quoted + "|" + keyed + ")"
            } else {
                fullPattern = def.pattern
            }

            print("full pattern is \(fullPattern)")
            print("pre-result is \(result)")

            
            let caseInsensitive = def.pattern.hasPrefix("(?i)")
            let cleanedPattern = def.pattern.replacingOccurrences(of: #"(?i)"#, with: "")

            let adjustedPattern: String
            if def.requireCodeContext && !isGrouped {
                let quoted = #"(["'`])("# + cleanedPattern + #")(\1)"#
                let keyed  = #"(?:\b\w+\s*[:=]\s*)("# + cleanedPattern + #")"#
                adjustedPattern = "(?:" + quoted + "|" + keyed + ")"
            } else {
                adjustedPattern = cleanedPattern
            }

            let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
            guard let regex = try? NSRegularExpression(pattern: adjustedPattern, options: options) else { continue }

            let escapedReplacement = NSRegularExpression.escapedTemplate(for: key)
            let effectiveTemplate: String

            if isGrouped {
                effectiveTemplate = key
            } else {
                effectiveTemplate = "$1" + escapedReplacement + "$3"
            }

            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: effectiveTemplate
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

    private static func loadEffectiveMap(from overrideFile: URL?) -> [String: RuleDef] {
        guard let fileURL = overrideFile else { return builtInMap }
        let path = fileURL.path
        let modTime = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? nil

        if let cached = cache[path], cached.modTime == modTime {
            return cached.map
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
