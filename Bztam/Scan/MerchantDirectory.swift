import Foundation

/// Well-known Moroccan shops and billers, with the category they usually belong to.
enum MerchantDirectory {
    struct Known: Equatable, Sendable {
        let name: String
        let categoryKey: String
    }

    /// (words to find, display name, category key). Checked in order, so longer names come first.
    private static let entries: [(String, String, String)] = [
        ("ASWAK ASSALAM", "Aswak Assalam", "courses"),
        ("LABEL'VIE", "Label'Vie", "courses"), ("LABELVIE", "Label'Vie", "courses"), ("LABEL VIE", "Label'Vie", "courses"),
        ("CARREFOUR MARKET", "Carrefour Market", "courses"), ("CARREFOUR", "Carrefour", "courses"),
        ("MARJANE MARKET", "Marjane Market", "courses"), ("MARJANE", "Marjane", "courses"),
        ("ACIMA", "Acima", "courses"), ("BIM", "BIM", "courses"), ("ATACADAO", "Atacadão", "courses"),
        ("MAROC TELECOM", "Maroc Telecom", "phone"), ("ITISSALAT AL-MAGHRIB", "Maroc Telecom", "phone"),
        ("IAM", "Maroc Telecom", "phone"), ("INWI", "Inwi", "phone"), ("ORANGE", "Orange", "phone"),
        ("LYDEC", "Lydec", "bills"), ("REDAL", "Redal", "bills"), ("AMENDIS", "Amendis", "bills"),
        ("RADEEMA", "Radeema", "bills"), ("RADEEF", "Radeef", "bills"), ("RADEEJ", "Radeej", "bills"),
        ("RAK", "RAK", "bills"), ("ONEE", "ONEE", "bills"),
        ("JUMIA FOOD", "Jumia Food", "food"), ("GLOVO", "Glovo", "food"), ("MCDONALD'S", "McDonald's", "food"),
        ("MCDONALDS", "McDonald's", "food"), ("KFC", "KFC", "food"), ("STARBUCKS", "Starbucks", "food"),
        ("PIZZA HUT", "Pizza Hut", "food"), ("BURGER KING", "Burger King", "food"), ("PAUL", "PAUL", "food"),
        ("AFRIQUIA", "Afriquia", "transport"), ("TOTALENERGIES", "TotalEnergies", "transport"),
        ("SHELL", "Shell", "transport"), ("WINXO", "Winxo", "transport"), ("PETROM", "Petrom", "transport"),
        ("ONCF", "ONCF", "transport"), ("AL BORAQ", "Al Boraq", "transport"), ("CTM", "CTM", "transport"),
        ("CAREEM", "Careem", "transport"), ("INDRIVE", "inDrive", "transport"), ("YASSIR", "Yassir", "transport"),
        ("HEETCH", "Heetch", "transport"), ("ADM", "Autoroutes du Maroc", "transport"),
        ("MEGARAMA", "Megarama", "goingout"), ("PATHE", "Pathé", "goingout"), ("NETFLIX", "Netflix", "goingout"),
        ("SPOTIFY", "Spotify", "goingout"), ("SHAHID", "Shahid", "goingout"),
        ("JUMIA", "Jumia", "other"), ("DECATHLON", "Decathlon", "other"), ("IKEA", "IKEA", "other"),
        ("KITEA", "Kitea", "other"), ("ZARA", "Zara", "other"), ("ELECTROPLANET", "Electroplanet", "other"),
        ("PHARMACIE", "Pharmacie", "other")
    ]

    /// The first known shop found in the first lines (where the header usually is), else anywhere.
    static func match(in lines: [String]) -> Known? {
        let folded = lines.map(ReceiptParser.fold)
        for scope in [Array(folded.prefix(8)), folded] {
            for (words, name, key) in entries where scope.contains(where: { ReceiptParser.containsWord(words, in: $0) }) {
                return Known(name: name, categoryKey: key)
            }
        }
        return nil
    }

    private static let hints: [(String, [String])] = [
        ("food", ["CAFE", "COFFEE", "RESTAURANT", "SNACK", "PIZZA", "BURGER", "PATISSERIE", "BOULANGERIE", "TACOS"]),
        ("transport", ["CARBURANT", "GASOIL", "GAZOIL", "ESSENCE", "SANS PLOMB", "STATION", "PARKING", "TAXI", "PEAGE", "AUTOROUTE"]),
        ("bills", ["ELECTRICITE", "EAU POTABLE", "ASSAINISSEMENT", "CONSOMMATION"]),
        ("phone", ["RECHARGE", "FORFAIT", "INTERNET", "ADSL", "FIBRE", "MOBILE"]),
        ("rent", ["LOYER"]),
        ("goingout", ["CINEMA", "CONCERT", "BILLET"]),
        ("courses", ["SUPERMARCHE", "HYPERMARCHE", "EPICERIE", "MARCHE"])
    ]

    /// A category guessed from words on the receipt, when the shop is unknown.
    static func categoryHint(in lines: [String]) -> String? {
        let folded = lines.map(ReceiptParser.fold)
        for (key, words) in hints where folded.contains(where: { line in words.contains { ReceiptParser.containsWord($0, in: line) } }) {
            return key
        }
        return nil
    }
}
