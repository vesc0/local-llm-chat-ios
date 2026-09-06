import Foundation

/// Block-level Markdown. Deliberately a small subset: what language models
/// actually emit, parsed in one pass with no dependencies.
enum MarkdownBlock: Equatable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case code(language: String?, text: String)
    case list(ListBlock)
    case table(TableBlock)
    case quote(String)
    case math(String)
    case rule
}

struct ListItem: Equatable {
    let depth: Int
    let marker: String
    let text: String
}

struct ListBlock: Equatable {
    let items: [ListItem]
}

struct TableBlock: Equatable {
    enum Align: Equatable { case leading, center, trailing }
    let headers: [String]
    let rows: [[String]]
    let alignments: [Align]

    func alignment(_ column: Int) -> Align {
        column < alignments.count ? alignments[column] : .leading
    }
}

extension MarkdownBlock {
    static func parse(_ source: String) -> [MarkdownBlock] {
        let lines = source.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
            } else if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                blocks.append(takeCode(lines, &index))
            } else if let heading = heading(trimmed) {
                blocks.append(heading)
                index += 1
            } else if isDisplayMathFence(trimmed) {
                blocks.append(takeMath(lines, &index))
            } else if isRule(trimmed) {
                blocks.append(.rule)
                index += 1
            } else if let table = takeTable(lines, &index) {
                blocks.append(table)
            } else if trimmed.hasPrefix(">") {
                blocks.append(takeQuote(lines, &index))
            } else if listItem(line) != nil {
                blocks.append(takeList(lines, &index))
            } else {
                blocks.append(takeParagraph(lines, &index))
            }
        }
        return blocks
    }

    // MARK: - Fenced code

    private static func takeCode(_ lines: [String], _ index: inout Int) -> MarkdownBlock {
        let fence = String(lines[index].trimmingCharacters(in: .whitespaces).prefix(3))
        let language = lines[index].trimmingCharacters(in: .whitespaces)
            .dropFirst(3).trimmingCharacters(in: .whitespaces)
        index += 1

        var body: [String] = []
        while index < lines.count,
              !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
            body.append(lines[index])
            index += 1
        }
        if index < lines.count { index += 1 }  // closing fence

        return .code(
            language: language.isEmpty ? nil : language,
            text: body.joined(separator: "\n").trimmingCharacters(in: .newlines)
        )
    }

    // MARK: - Headings, rules, math

    private static func heading(_ line: String) -> MarkdownBlock? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return .heading(
            level: hashes,
            text: String(line.dropFirst(hashes)).trimmingCharacters(in: .whitespaces)
        )
    }

    private static func isRule(_ line: String) -> Bool {
        guard line.count >= 3, let first = line.first, "-*_".contains(first) else { return false }
        return line.allSatisfy { $0 == first }
    }

    private static func isDisplayMathFence(_ line: String) -> Bool {
        line == "$$" || line.hasPrefix("\\[")
    }

    private static func takeMath(_ lines: [String], _ index: inout Int) -> MarkdownBlock {
        let opener = lines[index].trimmingCharacters(in: .whitespaces)
        let closer = opener.hasPrefix("\\[") ? "\\]" : "$$"

        // Single-line form: $$ x = 1 $$
        let inner = opener.dropFirst(2)
        if inner.hasSuffix(closer) {
            index += 1
            return .math(String(inner.dropLast(2)).trimmingCharacters(in: .whitespaces))
        }

        index += 1
        var body: [String] = []
        while index < lines.count,
              !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(closer) {
            body.append(lines[index])
            index += 1
        }
        if index < lines.count { index += 1 }
        return .math(body.joined(separator: " ").trimmingCharacters(in: .whitespaces))
    }

    // MARK: - Quote

    private static func takeQuote(_ lines: [String], _ index: inout Int) -> MarkdownBlock {
        var body: [String] = []
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(">") else { break }
            body.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
            index += 1
        }
        return .quote(body.joined(separator: "\n"))
    }

    // MARK: - Lists

    private static func listItem(_ line: String) -> (depth: Int, marker: String, text: String)? {
        let indent = line.prefix { $0 == " " || $0 == "\t" }.count
        let rest = line.dropFirst(indent)
        guard let first = rest.first else { return nil }

        if "-*+".contains(first), rest.dropFirst().first == " " {
            let text = String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            // "- [ ] task" renders as a checkbox rather than a bullet.
            if text.hasPrefix("[ ] ") { return (indent / 2, "☐", String(text.dropFirst(4))) }
            if text.lowercased().hasPrefix("[x] ") { return (indent / 2, "☑", String(text.dropFirst(4))) }
            return (indent / 2, "•", text)
        }

        let digits = rest.prefix(while: \.isNumber)
        guard !digits.isEmpty else { return nil }
        let afterDigits = rest.dropFirst(digits.count)
        guard let separator = afterDigits.first, separator == "." || separator == ")",
              afterDigits.dropFirst().first == " " else { return nil }
        return (
            indent / 2,
            "\(digits).",
            String(afterDigits.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        )
    }

    private static func takeList(_ lines: [String], _ index: inout Int) -> MarkdownBlock {
        var items: [ListItem] = []
        while index < lines.count {
            if let item = listItem(lines[index]) {
                items.append(ListItem(depth: item.depth, marker: item.marker, text: item.text))
                index += 1
            } else if !lines[index].trimmingCharacters(in: .whitespaces).isEmpty,
                      lines[index].hasPrefix(" "), !items.isEmpty {
                // Continuation of the previous item.
                let last = items.removeLast()
                let extra = lines[index].trimmingCharacters(in: .whitespaces)
                items.append(ListItem(depth: last.depth, marker: last.marker, text: last.text + " " + extra))
                index += 1
            } else {
                break
            }
        }
        return .list(ListBlock(items: items))
    }

    // MARK: - Tables

    private static func takeTable(_ lines: [String], _ index: inout Int) -> MarkdownBlock? {
        guard lines[index].contains("|"), index + 1 < lines.count,
              let alignments = delimiterAlignments(lines[index + 1]) else { return nil }

        let headers = cells(lines[index])
        index += 2

        var rows: [[String]] = []
        while index < lines.count, lines[index].contains("|"),
              !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
            var row = cells(lines[index])
            // Pad or trim so every row matches the header width.
            while row.count < headers.count { row.append("") }
            rows.append(Array(row.prefix(headers.count)))
            index += 1
        }

        return .table(TableBlock(headers: headers, rows: rows, alignments: alignments))
    }

    private static func delimiterAlignments(_ line: String) -> [TableBlock.Align]? {
        let parts = cells(line)
        guard !parts.isEmpty else { return nil }

        var alignments: [TableBlock.Align] = []
        for part in parts {
            let body = part.trimmingCharacters(in: .whitespaces)
            let core = body.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            guard !core.isEmpty, core.allSatisfy({ $0 == "-" }) else { return nil }
            switch (body.hasPrefix(":"), body.hasSuffix(":")) {
            case (true, true): alignments.append(.center)
            case (false, true): alignments.append(.trailing)
            default: alignments.append(.leading)
            }
        }
        return alignments
    }

    private static func cells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        // Protect escaped pipes so they survive the split.
        return trimmed
            .replacingOccurrences(of: "\\|", with: "\u{0}")
            .components(separatedBy: "|")
            .map {
                $0.replacingOccurrences(of: "\u{0}", with: "|")
                    .trimmingCharacters(in: .whitespaces)
            }
    }

    // MARK: - Paragraph

    private static func takeParagraph(_ lines: [String], _ index: inout Int) -> MarkdownBlock {
        var body: [String] = []
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("```"), !trimmed.hasPrefix("~~~"),
                  !trimmed.hasPrefix(">"), heading(trimmed) == nil, !isRule(trimmed),
                  !isDisplayMathFence(trimmed), listItem(line) == nil
            else { break }
            // A table header only becomes one when the next line is a delimiter.
            if trimmed.contains("|"), index + 1 < lines.count,
               delimiterAlignments(lines[index + 1]) != nil { break }
            body.append(trimmed)
            index += 1
        }
        return .paragraph(body.joined(separator: "\n"))
    }
}
