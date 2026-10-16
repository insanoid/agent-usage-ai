public extension Account {
    /// The label without a leading emoji or symbol, first letter capitalised:
    /// "🔵 work" gives "Work". Falls back to the slot when nothing is left.
    var displayName: String {
        let name = label.drop { !$0.isLetter && !$0.isNumber }
        return Self.capitalizingFirst(name.isEmpty ? Substring(slot) : name)
    }

    private static func capitalizingFirst(_ text: Substring) -> String {
        guard let first = text.first else { return "" }
        return first.uppercased() + text.dropFirst()
    }
}
