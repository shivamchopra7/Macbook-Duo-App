import Foundation

/// Use the packaged resource bundle for both SwiftUI and AppKit strings.
/// Development builds fall back to the English source key without embedding
/// SwiftPM's absolute build-machine resource path in the executable.
enum L10n {
    private static let bundle: Bundle = {
        if let url = Bundle.main.url(forResource:"MacbookDuo_MacbookDuo",withExtension:"bundle"),
           let packaged = Bundle(url:url) { return packaged }
        return Bundle.main
    }()

    static func text(_ key: String) -> String {
        bundle.localizedString(forKey:key,value:key,table:nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format:text(key),locale:Locale.current,arguments:arguments)
    }
}
