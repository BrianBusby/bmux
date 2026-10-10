import Foundation

/// A bounded lexer for literal shell words and sequential commands, never an evaluator.
struct ExpandedTurnShellTokenizer {
    private struct Word { let text: String; let assignment: Bool; let start: Int; let end: Int }

    private func operations(_ source: String) -> [[Word]]? {
        guard source.utf8.count <= 65_536 else { return nil }
        let chars = Array(source)
        var result: [[Word]] = []
        var words: [Word] = []
        var word = ""
        var started = false
        var wordStart = 0
        var assignmentEligible = true
        var hasEqual = false
        var requiresOperation = false
        var quote: Character?
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if !started { wordStart = index }
            if char == "\\", quote != "'" {
                if !hasEqual { assignmentEligible = false }
                index += 1
                guard index < chars.count else { return nil }
                let next = chars[index]
                if quote == "\"", !["$", "`", "\"", "\\", "\n"].contains(next) { word.append("\\") }
                if next != "\n" { word.append(next); hasEqual = hasEqual || next == "="; started = true }
            } else if let currentQuote = quote {
                if char == currentQuote { quote = nil }
                else {
                    if currentQuote == "\"", char == "$" || char == "`" { return nil }
                    word.append(char)
                    hasEqual = hasEqual || char == "="
                }
            } else if char == "'" || char == "\"" {
                if !hasEqual { assignmentEligible = false }
                quote = char
                started = true
            } else if char == "#", !started {
                while index < chars.count, chars[index] != "\n" { index += 1 }
                continue
            } else if char == ";" || char == "\n" || char == "&" {
                let separatorStart = index
                if char == "&" {
                    guard index + 1 < chars.count, chars[index + 1] == "&" else { return nil }
                    index += 1
                }
                if started { words.append(Word(text: word, assignment: assignmentEligible && isAssignment(word), start: wordStart, end: separatorStart)); word = ""; started = false; assignmentEligible = true; hasEqual = false }
                if words.isEmpty, char != "\n" { return nil }
                if !words.isEmpty {
                    result.append(words); words = []
                    requiresOperation = char == "&"
                }
            } else if char == " " || char == "\t" {
                if started { words.append(Word(text: word, assignment: assignmentEligible && isAssignment(word), start: wordStart, end: index)); word = ""; started = false; assignmentEligible = true; hasEqual = false }
            } else if "|<>(){}$`".contains(char) {
                return nil
            } else {
                word.append(char)
                    hasEqual = hasEqual || char == "="
                started = true
            }
            index += 1
        }
        guard quote == nil else { return nil }
        if started { words.append(Word(text: word, assignment: assignmentEligible && isAssignment(word), start: wordStart, end: index)) }
        if !words.isEmpty { result.append(words); requiresOperation = false }
        guard !requiresOperation else { return nil }
        return result
    }

    /// Shell wrappers are literal only; setup operations do not choose the category.
    func firstOperation(_ source: String, depth: Int = 0) -> (words: [String], source: String)? {
        guard depth < 4, let operations = operations(source) else { return nil }
        for operation in operations {
            var words = operation
            while let first = words.first, first.assignment { words.removeFirst() }
            guard let executable = words.first?.text else { continue }
            let name = (executable as NSString).lastPathComponent
            if name == "cd" {
                guard words.count == 2, !words[1].text.hasPrefix("-") else { return nil }
                continue
            }
            if ["sh", "bash", "zsh"].contains(name) {
                guard words.count == 3, ["-c", "-lc"].contains(words[1].text) else { return nil }
                return firstOperation(words[2].text, depth: depth + 1)
            }
            let chars = Array(source)
            let original = String(chars[words[0].start..<words[words.count - 1].end])
            return (words.map(\.text), original)
        }
        return nil
    }

    private func isAssignment(_ word: String) -> Bool {
        guard let separator = word.firstIndex(of: "=") else { return false }
        let name = word[..<separator]
        guard let first = name.first, first.isASCII, first.isLetter || first == "_" else { return false }
        return name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
    }
}
