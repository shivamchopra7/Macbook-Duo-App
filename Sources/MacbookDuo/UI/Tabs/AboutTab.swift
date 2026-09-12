import SwiftUI

/// Identity, version, credit, source, and either the manual update check
/// (direct-download build) or a review link (App Store build).
struct AboutTab: View {
    @ObservedObject var updater: AppUpdater
    @Environment(\.colorScheme) private var scheme
    private static let repository = URL(string:"https://github.com/shivamchopra7/Macbook-Duo-App")!
    /// The app's numeric Apple ID, assigned by App Store Connect. While it is
    /// the placeholder the review link would open the store on no product, so
    /// the button is left out of the build entirely.
    static let placeholderAppStoreID = "0000000000"
    static let appStoreID = "6811408285"
    private static let reviewPage = URL(string:"macappstore://apps.apple.com/app/id\(appStoreID)?action=write-review")!

    private var version: String {
        let raw = Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
        return (raw?.isEmpty == false ? raw : nil) ?? "dev"
    }

    var body: some View {
        VStack(spacing:12) {
            Spacer(minLength:0)
            Image(nsImage:AppBrand.icon).resizable().scaledToFit().frame(width:84,height:84)
                .shadow(color:GlassPalette.electricBlue.opacity(0.45),radius:16,y:6)
                .accessibilityHidden(true)
            VStack(spacing:4) {
                Text(AppBrand.name).font(.system(size:20,weight:.semibold,design:.rounded))
                Text(L10n.format("Version %@",version))
                    .font(.system(size:11,weight:.medium,design:.monospaced))
                    .foregroundStyle(GlassPalette.secondaryText(scheme))
            }
            VStack(spacing:3) {
                Text(L10n.text("Twelve ways to close your lid.")).font(.system(size:12.5,weight:.medium))
                Text(L10n.text("Made by Shivam Chopra")).font(.system(size:11.5))
                    .foregroundStyle(GlassPalette.secondaryText(scheme))
            }
            HStack(spacing:8) {
                Button { NSWorkspace.shared.open(Self.repository) } label: {
                    HStack(spacing:5) { Image(systemName:"chevron.left.forwardslash.chevron.right").font(.system(size:10,weight:.bold));Text(L10n.text("Open source on GitHub")) }
                }
                .buttonStyle(.glassQuiet)
                .accessibilityLabel(L10n.text("Open source on GitHub"))
                .help(Self.repository.absoluteString)
                if !AppUpdater.isAppStoreBuild {
                    updateButton
                } else if Self.appStoreID != Self.placeholderAppStoreID {
                    rateButton
                }
            }
            .padding(.top,4)
            Spacer(minLength:0)
        }
        .frame(maxWidth:.infinity,maxHeight:.infinity)
        .multilineTextAlignment(.center)
    }

    /// Direct-download builds check GitHub for a newer release on request.
    private var updateButton: some View {
        Button { updater.checkForUpdates() } label: {
            HStack(spacing:5) { Image(systemName:"arrow.triangle.2.circlepath").font(.system(size:10,weight:.bold));Text(updater.buttonTitle) }
        }
        .buttonStyle(.glassProminent).disabled(updater.isBusy)
        .accessibilityLabel(updater.buttonTitle)
    }

    /// App Store builds get their updates from the store, so the slot invites a review instead.
    private var rateButton: some View {
        Button { NSWorkspace.shared.open(Self.reviewPage) } label: {
            HStack(spacing:5) { Image(systemName:"star").font(.system(size:10,weight:.bold));Text(L10n.text("Rate on the App Store")) }
        }
        .buttonStyle(.glassQuiet)
        .accessibilityLabel(L10n.text("Rate on the App Store"))
    }
}
