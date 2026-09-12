import SwiftUI

/// The MacBook chassis around the Metal preview: a black lid with a notch,
/// a slim base, and a soft glow on the backdrop underneath.
struct MacBookPreview: View {
    @ObservedObject var model: AppModel
    let width: CGFloat
    @Environment(\.colorScheme) private var scheme

    /// Height of the whole chassis for a given width, used by the layout.
    static func height(forWidth width: CGFloat) -> CGFloat { (width-14)/1.54+21 }

    var body: some View {
        VStack(spacing:0) {
            MetalPreview(model:model)
                .frame(width:width-14,height:(width-14)/1.54)
                .overlay(alignment:.top) {
                    UnevenRoundedRectangle(bottomLeadingRadius:5,bottomTrailingRadius:5)
                        .fill(.black).frame(width:width*0.16,height:9)
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius:12,bottomLeadingRadius:2,bottomTrailingRadius:2,topTrailingRadius:12))
                .padding(7).background(.black,in:UnevenRoundedRectangle(topLeadingRadius:18,topTrailingRadius:18))
                .overlay(UnevenRoundedRectangle(topLeadingRadius:18,topTrailingRadius:18)
                    .strokeBorder(Color.white.opacity(scheme == .dark ? 0.16 : 0.10),lineWidth:1))
            RoundedRectangle(cornerRadius:3)
                .fill(LinearGradient(colors:[Color(white:0.42),Color(white:0.26)],startPoint:.top,endPoint:.bottom))
                .frame(height:7).padding(.horizontal,-5)
                .overlay(alignment:.top) {
                    Capsule().fill(Color(white:0.55)).frame(width:width*0.18,height:2).padding(.top,1)
                }
        }
        .frame(width:width)
        .shadow(color:GlassPalette.electricBlue.opacity(scheme == .dark ? 0.35 : 0.22),radius:28,x:0,y:14)
        .shadow(color:Color.black.opacity(scheme == .dark ? 0.5 : 0.18),radius:10,x:0,y:6)
        .accessibilityLabel("Macbook Duo")
    }
}
