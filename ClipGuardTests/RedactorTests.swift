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
    
}
