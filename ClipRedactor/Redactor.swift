import Foundation

final class Redactor {
    enum RedactionRule: Codable {
        case simple(String)
        case grouped(pattern: String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let pattern = try? container.decode(String.self) {
                self = .simple(pattern)
            } else if let dict = try? container.decode([String: String].self),
                      let pattern = dict["pattern"] {
                self = .grouped(pattern: pattern)
            } else {
                throw DecodingError.typeMismatch(
                    RedactionRule.self,
                    .init(codingPath: decoder.codingPath,
                          debugDescription: "Invalid redaction rule format")
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .simple(let pattern):
                try container.encode(pattern)
            case .grouped(let pattern):
                try container.encode(["pattern": pattern])
            }
        }
    }

    static let builtInMap: [String: (String, Bool)] = [
        "[REDACTED_OPENAI_KEY]": (#"sk-[a-zA-Z0-9]{48}"#, false),
        "[REDACTED_GITHUB_TOKEN]": (#"gh[pousr]_[a-zA-Z0-9]{36,}"#, false),
        "[REDACTED_AWS_KEY]": (#"AKIA[0-9A-Z]{16}"#, false),
        "$1[REDACTED_BEARER]$2": (#"(?i)(Authorization\s*:\s*Bearer\s+)[^"\s]+("?)(?=\s|$)"#, true),
        "[REDACTED_PW]": (#"(?i)password\s*[:=]\s*['\"]?\S+['\"]?"#, false),
        "[REDACTED_IP]": (#"\b\d{1,3}(?:\.\d{1,3}){3}\b"#, false),
        "$1[REDACTED_API_KEY]$3": (
            #"((?:["']|=\s*?))([A-Za-z0-9]{32}|[A-Za-z0-9]{64})(["']?)"#,
            true
        )
    ]

    private static var cache: [String: (modTime: Date?, map: [String: (String, Bool)])] = [:]

    private let overrideFile: URL?
    private var map: [String: (String, Bool)]

    init(overrideFile: URL? = Redactor.defaultOverrideFile()) {
        self.overrideFile = overrideFile
        self.map = Redactor.loadEffectiveMap(from: overrideFile)
    }

    func redact(_ text: String) -> String {
        // Re-check file mod time on every redact()
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

    func saveUserMap(_ userMap: [String: RedactionRule?]) {
        guard let file = overrideFile else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(userMap)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: file)
            Redactor.cache.removeValue(forKey: file.path)
        } catch {
            print("⚠️ Failed to save ClipRedactor user map: \\(error)")
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
            for (replacement, (pattern, isGrouped)) in userMap {
                if pattern == "__DELETE__" {
                    merged.removeValue(forKey: replacement)
                } else {
                    merged[replacement] = (pattern, isGrouped)
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
            for (replacement, (pattern, isGrouped)) in userMap {
                if pattern == "__DELETE__" {
                    merged.removeValue(forKey: replacement)
                } else {
                    merged[replacement] = (pattern, isGrouped)
                }
            }
        }

        cache[path] = (modTime, merged)
        return merged
    }    

    static func loadUserMap(from url: URL) -> [String: (pattern: String, isGrouped: Bool)]? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        do {
            let raw = try JSONDecoder().decode([String: RedactionRule?].self, from: data)
            var result = [String: (String, Bool)]()

            for (replacement, rule) in raw {
                guard let rule = rule else {
                    result[replacement] = ("__DELETE__", false)
                    continue
                }

                switch rule {
                    case .simple(let pattern):
                        result[replacement] = (pattern, false)
                    case .grouped(let pattern):
                        result[replacement] = (pattern, true)
                }
            }

            return result
        } catch {
            print("⚠️ Could not parse ClipRedactor overrides.json: \\(error)")
            return nil
        }
    }

    static func defaultOverrideFile() -> URL? {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClipRedactor/overrides.json")
    }
}
