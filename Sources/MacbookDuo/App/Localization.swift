import Foundation

/// Use the packaged resource bundle for both SwiftUI and AppKit strings.
/// Development builds fall back to the English source key without embedding
/// SwiftPM's absolute build-machine resource path in the executable.
enum L10n {
    private static var bundle: Bundle { AppResources.bundle }

    static func text(_ key: String) -> String {
        bundle.localizedString(forKey:key,value:key,table:nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format:text(key),locale:Locale.current,arguments:arguments)
    }
}
