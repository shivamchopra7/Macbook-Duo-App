import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: 48))
            Text("Macbook Duo App")
                .font(.title)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ContentView()
}
