import Foundation

/// Sprache der Oberfläche: Deutsch oder Englisch, je nach Systemsprache (auch pro App in
/// Systemeinstellungen › Allgemein › Sprache & Region einstellbar). Alles außer Deutsch → Englisch.
enum L10n {
    // forPreferences: nil liefert ohne .lproj-Ordner immer „en" – daher die Nutzer-Sprachen explizit übergeben.
    static let isGerman = Bundle.preferredLocalizations(from: ["en", "de"],
                                                        forPreferences: Locale.preferredLanguages).first == "de"
}

/// Text je nach Sprache: `tr("Akku", "Battery")`. Deutsch zuerst, wie der restliche Code.
func tr(_ german: String, _ english: String) -> String {
    L10n.isGerman ? german : english
}
