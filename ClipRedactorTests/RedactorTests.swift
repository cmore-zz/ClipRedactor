import XCTest
@testable import ClipRedactor

final class RedactorTests: XCTestCase {

    func testOpenAIKeyRedaction() {
        let input = "let key =\"sk-abcdef0123456789abcdef0123456789abcdef0123456789\""
        let redactor = Redactor(overrideFile: nil)
        let output = redactor.redact(input)
        print("Redacted Output: \(output)")
        XCTAssertFalse(output.contains("sk-"))
        XCTAssertTrue(output.contains("[REDACTED_OPENAI_KEY]"))
    }

    func testBearerTokenRedaction() {
        let input = #"let sample = "Authorization: Bearer abc123xyz""#
        let redactor = Redactor(overrideFile: nil)
        let output = redactor.redact(input)
        XCTAssertTrue(output.contains("[REDACTED_BEARER]"))
    }

    func testPasswordRedaction() {
        let input = "password: hunter2"
        let redactor = Redactor(overrideFile: nil)
        let output = redactor.redact(input)
        XCTAssertTrue(output.contains("[REDACTED_PW]"))
    }

    func testIpRedaction() {
        let input = "Connecting to 192.168.0.1"
        let redactor = Redactor(overrideFile: nil)
        let output = redactor.redact(input)
        XCTAssertTrue(output.contains("[REDACTED_IP]"))
    }


    func testBearerPreservesQuotesIfPresent() {
        let input1 = #"Authorization: Bearer abc123xyz"#
        let input2 = #""Authorization: Bearer abc123xyz""#
        let input3 = #"let x = "Authorization: Bearer abc123xyz""#
        let redactor = Redactor(overrideFile: nil)

        let out1 = redactor.redact(input1)
        let out2 = redactor.redact(input2)
        let out3 = redactor.redact(input3)
        
        print("Redacted Output 1: \(out1)")
        print("Redacted Output 2: \(out2)")
        print("Redacted Output 3: \(out3)")

        // first one isn't modified, because is bare
        XCTAssertEqual(out1, "Authorization: Bearer abc123xyz")
        XCTAssertEqual(out2, "\"[REDACTED_BEARER]\"")
        XCTAssertEqual(out3, #"let x = "[REDACTED_BEARER]""#)
    }

    func testJSONOverrideAddsAndDeletes() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let overrideFile = tempDir.appendingPathComponent("testOverrides.json")

        let json = """
        [
          {
            "replacement": "[REDACTED_EMAIL]",
            "pattern": "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\\\.[a-zA-Z]{2,}"
          },
          {
            "replacement": "$1[REDACTED_COOKIE]$2",
            "pattern": "(Cookie:\\\\s*)[^;\\\\n]+(;?)"
          },
          {
            "replacement": "[REDACTED_PW]",
            "pattern": ""
          }
        ]
        """

        try json.write(to: overrideFile, atomically: true, encoding: .utf8)

        let input = """
        user@example.com
        Cookie: sessionid=1234;
        password: hunter2
        """

        let redactor = Redactor(overrideFile: overrideFile)
        let output = redactor.redact(input)

        print("Combined Redacted Output: \(output)")
        
        XCTAssertTrue(output.contains("[REDACTED_EMAIL]"))
        XCTAssertTrue(output.contains("[REDACTED_COOKIE]"))
        XCTAssertFalse(output.contains("[REDACTED_PW]"))

        try? FileManager.default.removeItem(at: overrideFile) // Clean up
    }

    func testCacheByModTime() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let overrideFile = tempDir.appendingPathComponent("cacheCheck.json")

        let json1 = """
        [
          {
            "replacement": "[REDACTED_X]",
            "pattern": "x+"
          }
        ]
        """
        try json1.write(to: overrideFile, atomically: true, encoding: .utf8)

        let input1 = "abc xxx def"
        
        let redactor = Redactor(overrideFile: overrideFile)
        let result1 = redactor.redact(input1)
        print("result1: \(result1)")
        XCTAssertTrue(result1.contains("[REDACTED_X]"))

        sleep(1) // Ensure file mod time actually differs
        let json2 = """
        [
          {
            "replacement": "[REDACTED_Y]",
            "pattern": "y+"
          }
        ]
        """
        try json2.write(to: overrideFile, atomically: true, encoding: .utf8)

        let input2 = "abc yyy def"
        let result2 = redactor.redact(input2)
        XCTAssertTrue(result2.contains("[REDACTED_Y]"))

        try? FileManager.default.removeItem(at: overrideFile)
    }
    
}
