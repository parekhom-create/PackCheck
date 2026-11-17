import Foundation

struct Product: Decodable {
    let name: String?
    let brand: String?
    let englishIngredients: String?
    let listedIngredients: String?
    let language: String?
    let allergenTags: [String]?
    let traceTags: [String]?

    var ingredients: String? {
        if let englishIngredients, !englishIngredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return englishIngredients
        }
        return language == "en" ? listedIngredients : nil
    }

    var allergens: String? { allergenTags?.joined(separator: ", ") }
    var traces: String? { traceTags?.joined(separator: ", ") }

    enum CodingKeys: String, CodingKey {
        case name = "product_name"
        case brand = "brands"
        case englishIngredients = "ingredients_text_en"
        case listedIngredients = "ingredients_text"
        case language = "lang"
        case allergenTags = "allergens_tags"
        case traceTags = "traces_tags"
    }
}

enum ProductLookup {
    private struct Response: Decodable {
        let status: Int
        let product: Product?
    }

    static func barcode(_ text: String) -> String? {
        let digits = text.filter { !$0.isWhitespace }
        guard [8, 12, 13, 14].contains(digits.count),
              digits.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }

        let sum = digits.utf8.reversed().enumerated().reduce(0) { total, item in
            total + Int(item.element - 48) * (item.offset.isMultiple(of: 2) ? 1 : 3)
        }
        return sum.isMultiple(of: 10) ? digits : nil
    }

    static func find(_ barcode: String) async throws -> Product? {
        var url = URLComponents()
        url.scheme = "https"
        url.host = "world.openfoodfacts.org"
        url.path = "/api/v2/product/\(barcode)"
        url.queryItems = [URLQueryItem(name: "fields", value:
            "product_name,brands,lang,ingredients_text_en,ingredients_text,allergens_tags,traces_tags")]
        guard let endpoint = url.url else { throw URLError(.badURL) }

        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.setValue("PackCheckPrototype/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 404 { return nil }
        guard http.statusCode == 200 else { throw URLError(.badServerResponse) }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.status == 1 ? decoded.product : nil
    }
}
