//
//  projectsApp.swift
//  projects
//
//  Created by Raul de Avila Junior on 06/01/25.
//

import SwiftUI
import SwiftData

@main
struct ProjectsApp: App {
    init() {
        AppSettings.shared = AppSettings()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppSettings.shared)
        }
    }
}
