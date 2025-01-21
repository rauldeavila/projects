import SwiftUI

/// Gerencia comandos digitados pelo usuário
class CommandManager: ObservableObject {

    enum Command: String, CaseIterable {
        case settings = "/settings"
        case status = "/status"
        case logbook = "/logbook"
        
        var description: String {
            switch self {
            case .settings:
                return "Settings menu"
            case .status:
                return "Manage status syles and create new status"
            case .logbook:
                return "View completed tasks"
            }
        }
    }
    
    /// Estado do comando atual
    enum State {
        case inactive
        case active(String)
        
        var isActive: Bool {
            switch self {
            case .inactive:
                return false
            case .active:
                return true
            }
        }
    }
    
    @Published var state: State = .inactive
    @Published var showingSettings = false
    @Published var showingStatusSettings = false
    @Published var showingLogbook = false
    
    /// Processa o texto digitado para identificar comandos
    func processInput(_ text: String) {
        if text.starts(with: "/") {
            state = .active(text)
        } else {
            state = .inactive
        }
    }
    
    /// Retorna comandos filtrados baseado no input atual
    func filteredCommands(_ input: String) -> [Command] {
        Command.allCases.filter { $0.rawValue.contains(input.lowercased()) }
    }
    
    /// Executa um comando
    func executeCommand(_ command: Command) {
        switch command {
        case .settings:
            showingSettings = true
        case .status:
            showingStatusSettings = true
        case .logbook:
            showingLogbook = true
        }
    }
}
