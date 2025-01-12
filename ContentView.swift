import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        TaskListView()
            .modifier(CRTEffectModifier().opacity(settings.crtEffectEnabled ? 1 : 0))
    }
}

#Preview {
    ContentView()
}
