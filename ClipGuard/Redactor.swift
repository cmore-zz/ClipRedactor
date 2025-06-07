import Foundation

struct Redactor {
    enum RedactionRule: Decodable {
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
    }

    // Hardcoded base redaction map: [replacementText: (pattern, isGrouped)]
    static let builtInMap: [String: (String, Bool)] = [
        "[REDACTED_OPENAI_KEY]": (#"sk-[a-zA-Z0-9]{48}"#, false),
        "[REDACTED_GITHUB_TOKEN]": (#"gh[pousr]_[a-zA-Z0-9]{36,}"#, false),
        "[REDACTED_AWS_KEY]": (#"AKIA[0-9A-Z]{16}"#, false),
        "$1[REDACTED_BEARER]$2": (#"(?i)(Authorization\s*:\s*Bearer\s+)[^"\s]+("?)(?=\s|$)"#, true),
        "[REDACTED_PW]": (#"(?i)password\s*[:=]\s*['\"]?\S+['\"]?"#, false),
        "[REDACTED_IP]": (#"\b\d{1,3}(?:\.\d{1,3}){3}\b"#, false)
    ]

    private static var cache: [String: (modTime: Date?, map: [String: (String, Bool)])] = [:]

    static func redact(_ text: String, overrideFile: URL? = defaultOverrideFile()) -> String {
        var result = text
        for (replacement, (pattern, _)) in mergedMap(from: overrideFile) {
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
            print("⚠️ Could not parse ClipGuard overrides.json: \(error)")
            return nil
        }
    }

    private static func defaultOverrideFile() -> URL? {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClipGuard/overrides.json")
    }
}
