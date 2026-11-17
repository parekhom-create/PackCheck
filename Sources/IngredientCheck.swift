import Foundation

struct IngredientCheck {
    enum Result: Equatable {
        case contains([String])
        case trace([String])
        case unsure(String)
        case noMatch

        var title: String {
            switch self {
            case .contains: return "Ingredient flagged"
            case .trace: return "May contain"
            case .unsure: return "Unsure — check the label"
            case .noMatch: return "No selected ingredients found"
            }
        }

        var detail: String {
            switch self {
            case .contains(let terms): return terms.joined(separator: ", ")
            case .trace(let terms): return terms.joined(separator: ", ")
            case .unsure(let reason): return reason
            case .noMatch: return "This check covers only your selected terms and the text reviewed."
            }
        }
    }

    static func terms(avoidEgg: Bool, custom: String) -> [String] {
        var terms = avoidEgg ? ["egg", "eggs", "albumen", "ovalbumin", "ovomucoid"] : []
        for term in custom.components(separatedBy: CharacterSet(charactersIn: ",\n")) {
            let cleaned = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !cleaned.isEmpty && !terms.contains(cleaned) { terms.append(cleaned) }
        }
        return terms
    }

    static func evaluate(
        label: String, confirmed: Bool, terms: [String], online: Product?
    ) -> Result {
        guard !terms.isEmpty else { return .unsure("Add an ingredient to avoid.") }

        let parts = label.range(
            of: #"(?i)\b(?:may\s+(?:also\s+)?contain|traces\s+of|(?:made|prepared|packed)\s+in\s+a\s+(?:factory|facility))\b"#,
            options: .regularExpression
        )
        let ingredients = parts.map { String(label[..<$0.lowerBound]) } ?? label
        let warnings = parts.map { String(label[$0.lowerBound...]) } ?? ""
        let onPack = matches(terms, in: ingredients)
        let packTraces = matches(terms, in: warnings)

        if !onPack.isEmpty { return .contains(onPack) }
        if !packTraces.isEmpty { return .trace(packTraces) }
        guard confirmed, !normalize(ingredients).isEmpty else {
            return .unsure("Scan or enter the full ingredients and warning text, then confirm it against the pack.")
        }

        if let online {
            let onlineFlags = matches(terms, in: [online.ingredients, online.allergens, online.traces]
                .compactMap { $0 }.joined(separator: " "))
            if !onlineFlags.isEmpty {
                return .unsure("The online listing flags \(onlineFlags.joined(separator: ", ")). Check the package and manufacturer details.")
            }
            if let onlineIngredients = online.ingredients,
               !normalize(onlineIngredients).isEmpty,
               normalize(ingredients) != normalize(onlineIngredients) {
                return .unsure("The pack and online ingredient lists differ. Review both lists.")
            }
        }
        return .noMatch
    }

    private static func matches(_ terms: [String], in text: String) -> [String] {
        let normalized = normalize(text)
        return terms.filter { term in
            let words = normalize(term)
            return !words.isEmpty && " \(normalized) ".contains(" \(words) ")
        }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_GB"))
            .replacingOccurrences(of: #"^\s*ingredients?\s*:"#,
                                  with: "", options: .regularExpression)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
