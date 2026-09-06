import SwiftUI

/// Renders model output: fenced code blocks verbatim, prose as inline Markdown.
/// `Text` cannot style block elements, so lists and headings keep their source
/// characters rather than being silently swallowed.
struct MarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(Self.segments(of: text).enumerated()), id: \.offset) { _, segment in
                if segment.isCode {
                    CodeBlock(code: segment.text)
                } else {
                    Text(Self.inline(segment.text))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private struct Segment {
        let text: String
        let isCode: Bool
    }

    private static func segments(of text: String) -> [Segment] {
        var segments: [Segment] = []
        var buffer: [Substring] = []
        var isCode = false

        func flush() {
            let joined = buffer.joined(separator: "\n").trimmingCharacters(in: .newlines)
            if !joined.isEmpty { segments.append(Segment(text: joined, isCode: isCode)) }
            buffer = []
        }

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                flush()
                isCode.toggle()
            } else {
                buffer.append(line)
            }
        }
        flush()
        return segments
    }

    private static func inline(_ string: String) -> AttributedString {
        (try? AttributedString(markdown: string, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        ))) ?? AttributedString(string)
    }
}

private struct CodeBlock: View {
    let code: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
        }
        .background(Theme.surface, in: .rect(cornerRadius: 8))
    }
}
