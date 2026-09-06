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

final class MarkdownBlockTests: XCTestCase {
    func testTableWithAlignments() {
        let blocks = MarkdownBlock.parse("""
        | Name | Qty | Price |
        |:-----|:---:|------:|
        | Tea  |  2  |  3.50 |
        | Cake |  1  | 12.00 |
        """)

        guard case .table(let table)? = blocks.first else { return XCTFail("expected a table") }
        XCTAssertEqual(table.headers, ["Name", "Qty", "Price"])
        XCTAssertEqual(table.rows, [["Tea", "2", "3.50"], ["Cake", "1", "12.00"]])
        XCTAssertEqual(table.alignments, [.leading, .center, .trailing])
    }

    func testShortRowsArePaddedToHeaderWidth() {
        let blocks = MarkdownBlock.parse("""
        | A | B |
        |---|---|
        | 1 |
        """)
        guard case .table(let table)? = blocks.first else { return XCTFail("expected a table") }
        XCTAssertEqual(table.rows, [["1", ""]])
    }

    func testPipesWithoutADelimiterStayProse() {
        let blocks = MarkdownBlock.parse("use a | b to pipe")
        XCTAssertEqual(blocks, [.paragraph("use a | b to pipe")])
    }

    func testHeadingsListsQuotesAndRules() {
        let blocks = MarkdownBlock.parse("""
        ## Steps

        1. First
        2. Second
           - Nested

        > Note this

        ---
        """)

        XCTAssertEqual(blocks.first, .heading(level: 2, text: "Steps"))
        guard case .list(let list) = blocks[1] else { return XCTFail("expected a list") }
        XCTAssertEqual(list.items.map(\.marker), ["1.", "2.", "•"])
        XCTAssertEqual(list.items.last?.depth, 1)
        XCTAssertEqual(blocks[2], .quote("Note this"))
        XCTAssertEqual(blocks[3], .rule)
    }

    func testFencedCodeKeepsLanguageAndBody() {
        let blocks = MarkdownBlock.parse("""
        ```swift
        let x = 1
        ```
        """)
        XCTAssertEqual(blocks, [.code(language: "swift", text: "let x = 1")])
    }

    func testTaskListMarkers() {
        let blocks = MarkdownBlock.parse("- [x] done\n- [ ] todo")
        guard case .list(let list)? = blocks.first else { return XCTFail("expected a list") }
        XCTAssertEqual(list.items.map(\.marker), ["☑", "☐"])
        XCTAssertEqual(list.items.map(\.text), ["done", "todo"])
    }

    func testDisplayMath() {
        XCTAssertEqual(MarkdownBlock.parse("$$\nx = 1\n$$"), [.math("x = 1")])
    }
}

final class TeXTests: XCTestCase {
    func testFractionsRootsAndSymbols() {
        XCTAssertEqual(TeX.unicode("\\frac{1}{2}"), "1⁄2")
        XCTAssertEqual(TeX.unicode("\\frac{a+b}{2}"), "(a+b)⁄2")
        XCTAssertEqual(TeX.unicode("\\sqrt{2}"), "√2")
        XCTAssertEqual(TeX.unicode("\\alpha \\leq \\beta"), "α ≤ β")
    }

    func testScripts() {
        XCTAssertEqual(TeX.unicode("x^2"), "x²")
        XCTAssertEqual(TeX.unicode("a_{ij}"), "aᵢⱼ")
        XCTAssertEqual(TeX.unicode("x^{10}"), "x¹⁰")
    }

    func testInlineSpansAreConvertedButCurrencyIsNot() {
        XCTAssertEqual(TeX.substitute(in: "area is $r^2$ wide"), "area is r² wide")
        XCTAssertEqual(TeX.substitute(in: "costs $5 and $10 total"), "costs $5 and $10 total")
    }
}
