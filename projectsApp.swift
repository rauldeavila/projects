import SwiftUI
import SwiftData

@main
struct ProjectsApp: App {
    @StateObject private var appSettings = AppSettings.shared

    init() {
        // Destrói completamente o store antes de iniciar
//        PersistenceManager.destroyPersistentStore()
        
        // Inicializa o singleton do AppSettings
        AppSettings.shared = AppSettings()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
        }
    }
}
