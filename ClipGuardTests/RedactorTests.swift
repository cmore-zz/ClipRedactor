import XCTest
@testable import ClipGuard

final class RedactorTests: XCTestCase {

    func testOpenAIKeyRedaction() {
        let input = "My key is sk-abcdef0123456789abcdef0123456789abcdef0123456789"
        let output = Redactor.redact(input, overrideFile: nil)
        XCTAssertFalse(output.contains("sk-"))
        XCTAssertTrue(output.contains("[REDACTED_OPENAI_KEY]"))
    }

    func testBearerTokenRedaction() {
        let input = #"let sample = "Authorization: Bearer abc123xyz""#
        let output = Redactor.redact(input, overrideFile: nil)
        XCTAssertTrue(output.contains("[REDACTED_BEARER]"))
    }

    func testPasswordRedaction() {
        let input = "password: hunter2"
        let output = Redactor.redact(input, overrideFile: nil)
        XCTAssertTrue(output.contains("[REDACTED_PW]"))
    }

    func testIpRedaction() {
        let input = "Connecting to 192.168.0.1"
        let output = Redactor.redact(input, overrideFile: nil)
        XCTAssertTrue(output.contains("[REDACTED_IP]"))
    }


    func testBearerPreservesQuotesIfPresent() {
        let input1 = #"Authorization: Bearer abc123xyz"#
        let input2 = #""Authorization: Bearer abc123xyz""#
        let input3 = #"let x = "Authorization: Bearer abc123xyz""#

        let out1 = Redactor.redact(input1, overrideFile: nil)
        let out2 = Redactor.redact(input2, overrideFile: nil)
        let out3 = Redactor.redact(input3, overrideFile: nil)

        XCTAssertEqual(out1, "Authorization: Bearer [REDACTED_BEARER]")
        XCTAssertEqual(out2, "\"Authorization: Bearer [REDACTED_BEARER]\"")
        XCTAssertEqual(out3, #"let x = "Authorization: Bearer [REDACTED_BEARER]""#)
    }

    func testJSONOverrideAddsAndDeletes() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let overrideFile = tempDir.appendingPathComponent("testOverrides.json")

        let json = """
        {
            "[REDACTED_EMAIL]": "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\\\.[a-zA-Z]{2,}",
            "$1[REDACTED_COOKIE]$2": {
                "pattern": "(Cookie:\\\\s*)[^;\\\\n]+(;?)"
            },
            "[REDACTED_PW]": null
        }
        """

        try json.write(to: overrideFile, atomically: true, encoding: .utf8)

        let input = """
        user@example.com
        Cookie: sessionid=1234;
        password: hunter2
        """

        let output = Redactor.redact(input, overrideFile: overrideFile)

        XCTAssertTrue(output.contains("[REDACTED_EMAIL]"))
        XCTAssertTrue(output.contains("[REDACTED_COOKIE]"))
        XCTAssertFalse(output.contains("[REDACTED_PW]"), "Default password rule should be disabled")

        try? FileManager.default.removeItem(at: overrideFile) // Clean up
    }

    func testCacheByModTime() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let overrideFile = tempDir.appendingPathComponent("cacheCheck.json")

        let json1 = """
        {
            "[REDACTED_X]": "x+"
        }
        """
        try json1.write(to: overrideFile, atomically: true, encoding: .utf8)

        let input1 = "abc xxx def"
        let result1 = Redactor.redact(input1, overrideFile: overrideFile)
        XCTAssertTrue(result1.contains("[REDACTED_X]"))

        sleep(1) // Ensure file mod time actually differs
        let json2 = """
        {
            "[REDACTED_Y]": "y+"
        }
        """
        try json2.write(to: overrideFile, atomically: true, encoding: .utf8)

        let input2 = "abc yyy def"
        let result2 = Redactor.redact(input2, overrideFile: overrideFile)
        XCTAssertTrue(result2.contains("[REDACTED_Y]"))

        try? FileManager.default.removeItem(at: overrideFile)
    }
    
}
