import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            TaskListView()
            CRTOverlayView()
        }
    }
}

#Preview {
    ContentView()
}
