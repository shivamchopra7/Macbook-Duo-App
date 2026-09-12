import SwiftUI

/// Identity, version, credit, source, and the manual update check.
struct AboutTab: View {
    @ObservedObject var updater: AppUpdater
    @Environment(\.colorScheme) private var scheme
    private static let repository = URL(string:"https://github.com/shivamchopra7/Macbook-Duo-App")!

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
                Text("Macbook Duo").font(.system(size:20,weight:.semibold,design:.rounded))
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
                Button { updater.checkForUpdates() } label: {
                    HStack(spacing:5) { Image(systemName:"arrow.triangle.2.circlepath").font(.system(size:10,weight:.bold));Text(updater.buttonTitle) }
                }
                .buttonStyle(.glassProminent).disabled(updater.isBusy)
                .accessibilityLabel(updater.buttonTitle)
            }
            .padding(.top,4)
            Spacer(minLength:0)
        }
        .frame(maxWidth:.infinity,maxHeight:.infinity)
        .multilineTextAlignment(.center)
    }
}
