import XCTest
@testable import ClipGuard

final class RedactorTests: XCTestCase {

    func testOpenAIKeyRedaction() {
        let input = "My key is sk-abcdef0123456789abcdef0123456789abcdef0123456789"
        let output = Redactor.redact(input)
        XCTAssertFalse(output.contains("sk-"))
        XCTAssertTrue(output.contains("[REDACTED_OPENAI_KEY]"))
    }

    func testBearerTokenRedaction() {
        let input = #"let sample = "Authorization: Bearer abc123xyz""#
        let output = Redactor.redact(input)
        XCTAssertTrue(output.contains("[REDACTED_BEARER]"))
    }

    func testPasswordRedaction() {
        let input = "password: hunter2"
        let output = Redactor.redact(input)
        XCTAssertTrue(output.contains("[REDACTED_PW]"))
    }

    func testIpRedaction() {
        let input = "Connecting to 192.168.0.1"
        let output = Redactor.redact(input)
        XCTAssertTrue(output.contains("[REDACTED_IP]"))
    }


    func testBearerPreservesQuotesIfPresent() {
        let input1 = #"Authorization: Bearer abc123xyz"#
        let input2 = #""Authorization: Bearer abc123xyz""#
        let input3 = #"let x = "Authorization: Bearer abc123xyz""#

        let out1 = Redactor.redact(input1)
        let out2 = Redactor.redact(input2)
        let out3 = Redactor.redact(input3)

        XCTAssertEqual(out1, "Authorization: Bearer [REDACTED_BEARER]")
        XCTAssertEqual(out2, "\"Authorization: Bearer [REDACTED_BEARER]\"")
        XCTAssertEqual(out3, #"let x = "Authorization: Bearer [REDACTED_BEARER]""#)
    }
    
}
