import Foundation

struct Redactor {
    static let patterns: [String: String] = [
        #"sk-[a-zA-Z0-9]{48}"#: "[REDACTED_OPENAI_KEY]",
        #"gh[pousr]_[a-zA-Z0-9]{36,}"#: "[REDACTED_GITHUB_TOKEN]",
        #"AKIA[0-9A-Z]{16}"#: "[REDACTED_AWS_KEY]",
        #"("?Authorization\s*:\s*Bearer\s+)[^"\s]+("?)(?=\s|$)"#: "$1[REDACTED_BEARER]$2",
        #"(?i)password\s*[:=]\s*['\"]?\S+['\"]?"#: "password: [REDACTED_PW]",
        #"\b\d{1,3}(?:\.\d{1,3}){3}\b"#: "[REDACTED_IP]"
    ]

    static func redact(_ text: String) -> String {
        var result = text
        for (pattern, replacement) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

            // Use NSRegularExpression’s replacement engine, which supports $1, $2, etc.
            result = regex.stringByReplacingMatches(
              in: result,
              options: [],
              range: NSRange(result.startIndex..., in: result),
              withTemplate: replacement
            )
        }
        return result
    }
}
