import Foundation

enum MarkdownInline {
    /// Inline Markdown (bold, italic, links, code spans) with LaTeX spans
    /// approximated in Unicode first.
    static func render(_ source: String) -> AttributedString {
        let text = TeX.substitute(in: source)
        let parsed = try? AttributedString(markdown: text, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        ))
        return parsed ?? AttributedString(text)
    }
}

/// A best-effort LaTeX renderer. Real typesetting needs a layout engine; this
/// covers the notation models actually emit in chat and leaves the rest legible.
enum TeX {
    /// Rewrites `$…$` and `\(…\)` spans found inside prose.
    static func substitute(in source: String) -> String {
        var result = substituteDelimited(source, open: "\\(", close: "\\)", requireHint: false)
        result = substituteDelimited(result, open: "$", close: "$", requireHint: true)
        return result
    }

    static func unicode(_ latex: String) -> String {
        var text = expandFractions(latex)
        text = expandRoots(text)
        for (command, replacement) in commands {
            text = text.replacingOccurrences(of: command, with: replacement)
        }
        text = applyScripts(text)
        return text
            .replacingOccurrences(of: "\\,", with: " ")
            .replacingOccurrences(of: "\\!", with: "")
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "\\", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Span detection

    private static let hints: Set<Character> = ["\\", "^", "_", "=", "+", "<", ">"]

    private static func substituteDelimited(
        _ source: String, open: String, close: String, requireHint: Bool
    ) -> String {
        var result = ""
        var rest = Substring(source)

        while let start = rest.range(of: open) {
            guard let end = rest[start.upperBound...].range(of: close) else { break }
            let body = rest[start.upperBound..<end.lowerBound]

            // `$5 and $10` is currency, not maths: require adjacency and a hint character.
            let looksLikeMath = !requireHint || (
                body.first?.isWhitespace == false && body.last?.isWhitespace == false
                    && body.contains(where: hints.contains) && body.count < 200
            )

            result += rest[..<start.lowerBound]
            result += looksLikeMath ? unicode(String(body)) : String(rest[start.lowerBound..<end.upperBound])
            rest = rest[end.upperBound...]
        }
        return result + rest
    }

    // MARK: - Structures

    /// `\frac{a}{b}` becomes `a⁄b`, parenthesising compound terms.
    private static func expandFractions(_ source: String) -> String {
        var text = source
        while let range = text.range(of: "\\frac") {
            guard let numerator = braced(in: text, after: range.upperBound),
                  let denominator = braced(in: text, after: numerator.end) else { break }
            let top = wrap(unicode(numerator.body))
            let bottom = wrap(unicode(denominator.body))
            text.replaceSubrange(range.lowerBound..<denominator.end, with: "\(top)⁄\(bottom)")
        }
        return text
    }

    private static func expandRoots(_ source: String) -> String {
        var text = source
        while let range = text.range(of: "\\sqrt") {
            guard let argument = braced(in: text, after: range.upperBound) else { break }
            text.replaceSubrange(range.lowerBound..<argument.end, with: "√\(wrap(unicode(argument.body)))")
        }
        return text
    }

    private static func wrap(_ term: String) -> String {
        term.count > 1 ? "(\(term))" : term
    }

    private static func braced(
        in text: String, after index: String.Index
    ) -> (body: String, end: String.Index)? {
        guard index < text.endIndex, text[index] == "{" else { return nil }
        var depth = 0
        var cursor = index
        while cursor < text.endIndex {
            if text[cursor] == "{" { depth += 1 }
            if text[cursor] == "}" {
                depth -= 1
                if depth == 0 {
                    let end = text.index(after: cursor)
                    return (String(text[text.index(after: index)..<cursor]), end)
                }
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }

    // MARK: - Scripts

    private static let superscripts: [Character: Character] = zip(
        "0123456789+-=()abcdefghijklmnoprstuvwxyz",
        "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐⁿᵒᵖʳˢᵗᵘᵛʷˣʸᶻ"
    ).reduce(into: [:]) { $0[$1.0] = $1.1 }

    private static let subscripts: [Character: Character] = zip(
        "0123456789+-=()aehijklmnoprstuvx",
        "₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓ"
    ).reduce(into: [:]) { $0[$1.0] = $1.1 }

    private static func applyScripts(_ source: String) -> String {
        var result = ""
        var rest = Substring(source)

        while let marker = rest.firstIndex(where: { $0 == "^" || $0 == "_" }) {
            let table = rest[marker] == "^" ? superscripts : subscripts
            result += rest[..<marker]

            let afterMarker = rest.index(after: marker)
            guard afterMarker < rest.endIndex else { rest = rest[afterMarker...]; break }

            let term: String
            var next: Substring.Index
            if rest[afterMarker] == "{",
               let group = braced(in: String(rest[afterMarker...]), after: String(rest[afterMarker...]).startIndex) {
                term = group.body
                next = rest.index(afterMarker, offsetBy: group.body.count + 2)
            } else {
                term = String(rest[afterMarker])
                next = rest.index(after: afterMarker)
            }

            if let converted = try? term.map({ character -> Character in
                guard let mapped = table[character] else { throw ScriptError.unmappable }
                return mapped
            }) {
                result += String(converted)
            } else {
                result += rest[marker] == "^" ? "^(\(term))" : "_(\(term))"
            }
            rest = rest[next...]
        }
        return result + rest
    }

    private enum ScriptError: Error { case unmappable }

    // MARK: - Symbols

    /// Longest first, so `\leq` is not eaten by `\le`.
    private static let commands: [(String, String)] = [
        ("\\alpha", "α"), ("\\beta", "β"), ("\\gamma", "γ"), ("\\delta", "δ"),
        ("\\epsilon", "ε"), ("\\varepsilon", "ε"), ("\\zeta", "ζ"), ("\\eta", "η"),
        ("\\theta", "θ"), ("\\iota", "ι"), ("\\kappa", "κ"), ("\\lambda", "λ"),
        ("\\mu", "μ"), ("\\nu", "ν"), ("\\xi", "ξ"), ("\\pi", "π"), ("\\rho", "ρ"),
        ("\\sigma", "σ"), ("\\tau", "τ"), ("\\upsilon", "υ"), ("\\phi", "φ"),
        ("\\varphi", "φ"), ("\\chi", "χ"), ("\\psi", "ψ"), ("\\omega", "ω"),
        ("\\Gamma", "Γ"), ("\\Delta", "Δ"), ("\\Theta", "Θ"), ("\\Lambda", "Λ"),
        ("\\Sigma", "Σ"), ("\\Phi", "Φ"), ("\\Psi", "Ψ"), ("\\Omega", "Ω"),
        ("\\times", "×"), ("\\div", "÷"), ("\\cdot", "·"), ("\\pm", "±"), ("\\mp", "∓"),
        ("\\leq", "≤"), ("\\geq", "≥"), ("\\neq", "≠"), ("\\approx", "≈"),
        ("\\equiv", "≡"), ("\\propto", "∝"), ("\\sim", "∼"),
        ("\\infty", "∞"), ("\\partial", "∂"), ("\\nabla", "∇"),
        ("\\sum", "∑"), ("\\prod", "∏"), ("\\int", "∫"),
        ("\\forall", "∀"), ("\\exists", "∃"), ("\\emptyset", "∅"),
        ("\\subseteq", "⊆"), ("\\subset", "⊂"), ("\\cup", "∪"), ("\\cap", "∩"),
        ("\\notin", "∉"), ("\\in", "∈"),
        ("\\Rightarrow", "⇒"), ("\\Leftarrow", "⇐"), ("\\leftrightarrow", "↔"),
        ("\\rightarrow", "→"), ("\\leftarrow", "←"), ("\\to", "→"),
        ("\\ldots", "…"), ("\\cdots", "⋯"), ("\\degree", "°"),
        ("\\left", ""), ("\\right", ""), ("\\quad", "  "), ("\\text", ""), ("\\mathrm", ""),
    ]
}
