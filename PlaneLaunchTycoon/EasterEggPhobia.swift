import Foundation

/// Fear of long words — often cited as the longest phobia name; spelling varies by one “p”.
enum EasterEggPhobia {
    /// 36 letters — common “extra p” spelling (e.g. some dictionaries / trivia lists).
    static let primary = "hippopotomonstrosesquippedaliophobia"
    /// 35 letters — Wiktionary-style spelling.
    static let alternate = "hippopotomonstrosesquipedaliophobia"

    static func matches(_ typed: String) -> Bool {
        let s = typed.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return s == primary || s == alternate
    }
}
