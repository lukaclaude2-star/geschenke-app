/// Entfernt Emojis aus einem Anzeigetext, z. B. „🍳 Kochen“ → „Kochen“. Stichwort-Labels vom
/// Server tragen ein Emoji vorn, die App zeigt keine (DESIGN.md 4). Gespeicherte Profile
/// behalten ihre Labels, deshalb wird erst beim Anzeigen gefiltert.
public func ohneEmoji(_ text: String) -> String {
    let ohne = text.filter { zeichen in
        !zeichen.unicodeScalars.contains { skalar in
            // Ziffern, # und * zählen technisch als Emoji, bleiben aber normale Zeichen
            skalar.properties.isEmojiPresentation || (skalar.properties.isEmoji && skalar.value > 0x7F)
        }
    }
    return ohne.split(separator: " ").joined(separator: " ")
}
