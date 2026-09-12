import SwiftUI

/// The settings window: a glass header under the transparent title bar, the
/// MacBook preview beside a tabbed glass card, and the action footer. Every
/// control stays visible at the window's minimum size; smaller work areas
/// scale the whole layout down instead of scrolling.
struct SettingsRootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updater: AppUpdater
    @State private var tab: SettingsTab

    static let designWidth: CGFloat = 900
    static let designHeight: CGFloat = 530
    private static let paneWidth: CGFloat = 424
    private static let sidePadding: CGFloat = 18
    private static let paneSpacing: CGFloat = 18

    init(model: AppModel, updater: AppUpdater, arguments: [String] = CommandLine.arguments) {
        self.model = model
        self.updater = updater
        _tab = State(initialValue:SettingsTab.fromLaunchArguments(arguments))
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(1,geometry.size.width/Self.designWidth,geometry.size.height/Self.designHeight)
            let width = geometry.size.width/max(scale,0.1)
            let height = geometry.size.height/max(scale,0.1)
            VStack(spacing:0) {
                SettingsHeader(model:model,updater:updater)
                VStack(spacing:10) {
                    HStack(alignment:.top,spacing:Self.paneSpacing) {
                        previewColumn
                        pane
                    }
                    .frame(maxWidth:.infinity,maxHeight:.infinity)
                    SettingsFooter(model:model)
                }
                .padding(.horizontal,Self.sidePadding).padding(.top,12).padding(.bottom,12)
            }
            .frame(width:width,height:height,alignment:.top)
            .scaleEffect(scale,anchor:.topLeading)
        }
        .background(GlassBackdrop())
        .tint(GlassPalette.accent)
        .ignoresSafeArea()
    }

    private var previewColumn: some View {
        GeometryReader { geometry in
            let width = max(240,min(geometry.size.width,(geometry.size.height-21)*1.54+14))
            MacBookPreview(model:model,width:width)
                .frame(maxWidth:.infinity,maxHeight:.infinity)
        }
    }

    private var pane: some View {
        VStack(spacing:8) {
            SettingsTabBar(selection:$tab)
            GlassCard {
                ZStack(alignment:.top) {
                    switch tab {
                    case .effects: EffectsTab(model:model).transition(Self.pageTransition)
                    case .motion: MotionTab(model:model).transition(Self.pageTransition)
                    case .look: LookTab(model:model).transition(Self.pageTransition)
                    case .about: AboutTab(updater:updater).transition(Self.pageTransition)
                    }
                }
                .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.top)
                .clipped()
            }
            .frame(maxHeight:.infinity)
        }
        .frame(width:Self.paneWidth)
        .frame(maxHeight:.infinity)
    }

    private static var pageTransition: AnyTransition {
        .asymmetric(insertion:.opacity.combined(with:.offset(y:10)),
                    removal:.opacity.combined(with:.offset(y:-6)))
    }
}
