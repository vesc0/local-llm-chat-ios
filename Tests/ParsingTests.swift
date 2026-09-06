import XCTest
@testable import LocalLLMChat

final class ThoughtParserTests: XCTestCase {
    func testSplitsReasoningFromAnswer() {
        let result = ThoughtParser.parse("<think>weighing options</think>The answer is 4.")
        XCTAssertEqual(result.thought, "weighing options")
        XCTAssertEqual(result.answer, "The answer is 4.")
    }

    func testPlainTextIsLeftAlone() {
        let result = ThoughtParser.parse("Just an answer.")
        XCTAssertNil(result.thought)
        XCTAssertEqual(result.answer, "Just an answer.")
    }

    func testUnterminatedThoughtIsStillExtracted() {
        let result = ThoughtParser.parse("<think>still going")
        XCTAssertEqual(result.thought, "still going")
        XCTAssertTrue(result.answer.isEmpty)
    }

    func testAlternateTagSyntax() {
        let result = ThoughtParser.parse("<|begin_of_thought|>hmm<|end_of_thought|>Done")
        XCTAssertEqual(result.thought, "hmm")
        XCTAssertEqual(result.answer, "Done")
    }
}

final class AttachmentCodingTests: XCTestCase {
    func testLegacyAbsoluteURLDecodesToAFilename() throws {
        let legacy = """
        {"id":"1","type":"image","url":"file:///var/mobile/Containers/Data/ABC/Documents/attachments/pic.jpg"}
        """
        let attachment = try JSONDecoder().decode(Attachment.self, from: Data(legacy.utf8))
        XCTAssertEqual(attachment.filename, "pic.jpg")
    }

    func testRoundTrip() throws {
        let attachment = Attachment(type: .pdf, extractedText: "hello")
        let decoded = try JSONDecoder().decode(
            Attachment.self, from: JSONEncoder().encode(attachment)
        )
        XCTAssertEqual(decoded, attachment)
    }
}
