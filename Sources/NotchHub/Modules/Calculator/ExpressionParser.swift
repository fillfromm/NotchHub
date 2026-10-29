import Foundation

/// Small recursive-descent evaluator (no `NSExpression`, which crashes on bad input).
///
///     expr    = term (('+' | '-') term)*
///     term    = unary (('*' | '/' | '%') unary)*
///     unary   = '-' unary | power
///     power   = atom ('^' unary)?          (right associative)
///     atom    = number | constant | function '(' expr ')' | '(' expr ')'
struct ExpressionParser {
    enum ParseError: Error, LocalizedError {
        case unexpected(String)
        case divisionByZero
        case unknownName(String)

        var errorDescription: String? {
            switch self {
            case .unexpected(let s): return s
            case .divisionByZero: return "Division by zero"
            case .unknownName(let n): return "Unknown name “\(n)”"
            }
        }
    }

    private let chars: [Character]
    private var pos = 0

    private init(_ text: String) {
        // Accept common typographic operators and a decimal comma.
        let normalized = text
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: ",", with: ".")
        chars = Array(normalized)
    }

    static func evaluate(_ text: String) throws -> Double {
        var parser = ExpressionParser(text)
        let value = try parser.parseExpression()
        parser.skipSpaces()
        if parser.pos < parser.chars.count {
            throw ParseError.unexpected("Unexpected “\(parser.chars[parser.pos])”")
        }
        return value
    }

    // MARK: Grammar

    private mutating func parseExpression() throws -> Double {
        var value = try parseTerm()
        while true {
            skipSpaces()
            if match("+") { value += try parseTerm() }
            else if match("-") { value -= try parseTerm() }
            else { return value }
        }
    }

    private mutating func parseTerm() throws -> Double {
        var value = try parseUnary()
        while true {
            skipSpaces()
            if match("*") { value *= try parseUnary() }
            else if match("/") {
                let divisor = try parseUnary()
                if divisor == 0 { throw ParseError.divisionByZero }
                value /= divisor
            } else if match("%") {
                let divisor = try parseUnary()
                if divisor == 0 { throw ParseError.divisionByZero }
                value = value.truncatingRemainder(dividingBy: divisor)
            } else { return value }
        }
    }

    private mutating func parseUnary() throws -> Double {
        skipSpaces()
        if match("-") { return -(try parseUnary()) }
        if match("+") { return try parseUnary() }
        return try parsePower()
    }

    private mutating func parsePower() throws -> Double {
        let base = try parseAtom()
        skipSpaces()
        if match("^") { return pow(base, try parseUnary()) }
        return base
    }

    private mutating func parseAtom() throws -> Double {
        skipSpaces()
        if match("(") {
            let value = try parseExpression()
            skipSpaces()
            guard match(")") else { throw ParseError.unexpected("Missing )") }
            return value
        }
        if let c = peek, c.isNumber || c == "." { return try parseNumber() }
        if let c = peek, c.isLetter { return try parseName() }
        if let c = peek { throw ParseError.unexpected("Unexpected “\(c)”") }
        throw ParseError.unexpected("Incomplete expression")
    }

    private mutating func parseNumber() throws -> Double {
        let start = pos
        while let c = peek, c.isNumber || c == "." { pos += 1 }
        guard let value = Double(String(chars[start..<pos])) else {
            throw ParseError.unexpected("Bad number")
        }
        return value
    }

    private mutating func parseName() throws -> Double {
        let start = pos
        while let c = peek, c.isLetter || c.isNumber { pos += 1 }
        let name = String(chars[start..<pos]).lowercased()

        switch name {
        case "pi", "π": return .pi
        case "e": return M_E
        default: break
        }

        let functions: [String: (Double) -> Double] = [
            "sqrt": { $0.squareRoot() }, "abs": { abs($0) },
            "sin": sin, "cos": cos, "tan": tan,
            "ln": log, "log": log10, "exp": exp,
            "floor": { $0.rounded(.down) }, "ceil": { $0.rounded(.up) }, "round": { $0.rounded() },
        ]
        guard let function = functions[name] else { throw ParseError.unknownName(name) }
        skipSpaces()
        guard match("(") else { throw ParseError.unexpected("Expected ( after \(name)") }
        let argument = try parseExpression()
        skipSpaces()
        guard match(")") else { throw ParseError.unexpected("Missing )") }
        return function(argument)
    }

    // MARK: Scanning helpers

    private var peek: Character? { pos < chars.count ? chars[pos] : nil }

    private mutating func match(_ c: Character) -> Bool {
        if peek == c { pos += 1; return true }
        return false
    }

    private mutating func skipSpaces() {
        while let c = peek, c == " " { pos += 1 }
    }
}
