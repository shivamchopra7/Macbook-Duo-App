import Foundation

extension Foundation.Bundle {
    static nonisolated let module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("MacbookDuo_MacbookDuo.bundle").path
        let buildPath = "/Users/macintosh/Github-Shivam/Github - illusionart/Macbook-Duo-App/.build-intel/x86_64-apple-macosx/release/MacbookDuo_MacbookDuo.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            // Users can write a function called fatalError themselves, we should be resilient against that.
            Swift.fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}