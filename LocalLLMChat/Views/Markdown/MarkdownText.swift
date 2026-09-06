import SwiftUI

/// Renders model output as formatted blocks: tables, headings, lists, quotes, code and display math.
struct MarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(MarkdownBlock.parse(text).enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(MarkdownInline.render(text)).textSelection(.enabled)

        case .heading(let level, let text):
            Text(MarkdownInline.render(text))
                .font(Self.headingFont(level))
                .padding(.top, level <= 2 ? 4 : 0)
                .textSelection(.enabled)

        case .code(let language, let text):
            CodeBlock(language: language, code: text)

        case .list(let list):
            ListView(list: list)

        case .table(let table):
            TableView(table: table)

        case .quote(let text):
            HStack(alignment: .top, spacing: 8) {
                Capsule().fill(.secondary.opacity(0.4)).frame(width: 3)
                Text(MarkdownInline.render(text))
                    .italic()
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .math(let latex):
            Text(TeX.unicode(latex))
                .font(.system(.body, design: .serif))
                .frame(maxWidth: .infinity, alignment: .center)
                .textSelection(.enabled)

        case .rule:
            Divider()
        }
    }

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2.bold()
        case 2: .title3.bold()
        case 3: .headline
        default: .subheadline.bold()
        }
    }
}

// MARK: - Lists

private struct ListView: View {
    let list: ListBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(list.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.marker)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text(MarkdownInline.render(item.text))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, CGFloat(item.depth) * 16)
            }
        }
    }
}

// MARK: - Tables

private struct TableView: View {
    let table: TableBlock

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                ForEach(Array(table.headers.enumerated()), id: \.offset) { column, header in
                    cell(header, column: column).fontWeight(.semibold)
                }
            }
            Divider().gridCellUnsizedAxes(.horizontal)

            ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { column, value in
                        cell(value, column: column)
                    }
                }
                if index < table.rows.count - 1 {
                    Divider().gridCellUnsizedAxes(.horizontal).opacity(0.4)
                }
            }
        }
        .font(.callout)
        .padding(10)
        .overlay {
            RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3), lineWidth: 1)
        }
    }

    private func cell(_ value: String, column: Int) -> some View {
        Text(MarkdownInline.render(value))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: alignment(column))
            .multilineTextAlignment(textAlignment(column))
    }

    private func alignment(_ column: Int) -> Alignment {
        switch table.alignment(column) {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private func textAlignment(_ column: Int) -> TextAlignment {
        switch table.alignment(column) {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

// MARK: - Code

private struct CodeBlock: View {
    let language: String?
    let code: String

    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language?.uppercased() ?? "CODE")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    withAnimation { isCopied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { isCopied = false }
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(isCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy code")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
        }
        .background(Theme.surface, in: .rect(cornerRadius: 8))
    }
}
