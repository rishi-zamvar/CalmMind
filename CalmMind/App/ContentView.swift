import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "heart.fill")
                .imageScale(.large)
                .foregroundStyle(.pink)
            Text("CalmMind")
                .font(.title)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
