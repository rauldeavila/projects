import SwiftUI

/// Main view for the task list
struct TaskListView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var commandManager = CommandManager()
    @StateObject private var viewModel: TaskListViewModel
    @FocusState private var isNewItemFieldFocused: Bool
    @SceneStorage("zoomLevel") private var zoomLevel: Double = 1.0
    
    @State private var shakePosition: CGFloat = 0
    
    private let minZoom: Double = 0.5
    private let maxZoom: Double = 2.0
    private let zoomStep: Double = 0.1
    
    
    private let baseTitleSize: Double = 13.0
    private let baseStatusSize: Double = 11.0
    private let baseNewItemSize: Double = 13.0
        
    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _viewModel = StateObject(wrappedValue: TaskListViewModel(settings: settings))
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                
                settings.backgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.buildFlattenedList(items: viewModel.items), id: \.item.id) { itemInfo in
                            ItemRowView(
                                id: itemInfo.item.id,
                                viewModel: viewModel,
                                item: itemInfo.item,
                                isSelected: viewModel.selectedItemId == itemInfo.item.id,
                                isEditing: viewModel.editingItemId == itemInfo.item.id,
                                editingDirection: viewModel.editingDirection,
                                onTitleChange: { newTitle in
                                    viewModel.updateItemTitle(itemInfo.item.id, newTitle: newTitle)
                                    isNewItemFieldFocused = true
                                },
                                fontSize: baseTitleSize * zoomLevel,
                                statusFontSize: baseStatusSize * zoomLevel,
                                level: itemInfo.level,
                                settings: settings,
                                onToggleCollapse: {
                                    if itemInfo.item.id == viewModel.selectedItemId {
                                        viewModel.toggleSelectedItemCollapse()
                                    }
                                },
                                isNewItemFieldFocused: _isNewItemFieldFocused
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(viewModel.selectedItemId == itemInfo.item.id ? settings.accentColor.opacity(settings.accentOpacity) : Color.clear)
                            .modifier(ShakeEffect(position: viewModel.selectedItemId == itemInfo.item.id ? shakePosition : 0))
                            .onChange(of: viewModel.shakeSelected) {
                                guard viewModel.selectedItemId == itemInfo.item.id else { return }
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    shakePosition = 0.6
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    shakePosition = 0
                                    viewModel.shakeSelected = false
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                        
                        Group {
                            Button("") { viewModel.cycleSelectedItemStatus(direction: -1) }
                                .keyboardShortcut(.downArrow, modifiers: [.command])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.cycleSelectedItemStatus(direction: 1) }
                                .keyboardShortcut(.upArrow, modifiers: [.command])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.startEditingSelected(direction: .left) }
                                .keyboardShortcut(.leftArrow, modifiers: [.command])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.startEditingSelected(direction: .right) }
                                .keyboardShortcut(.rightArrow, modifiers: [.command])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") {
                                zoomLevel = min(maxZoom, zoomLevel + zoomStep)
                            }
                            .keyboardShortcut(KeyboardShortcut("=", modifiers: .command))
                            .opacity(0)
                            .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") {
                                zoomLevel = max(minZoom, zoomLevel - zoomStep)
                            }
                            .keyboardShortcut(KeyboardShortcut("-", modifiers: .command))
                            .opacity(0)
                            .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.moveSelectedHierarchyUp() }
                                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.moveSelectedHierarchyDown() }
                                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.toggleFocusMode() }
                                .keyboardShortcut(.return, modifiers: [.command])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)

                            Button("") { viewModel.toggleFocusMode(forceRoot: true) }
                                .keyboardShortcut(.return, modifiers: [.command, .shift])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.toggleSelectedItemCollapse() }
                                .keyboardShortcut(KeyEquivalent("."), modifiers: .command)
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            
                            Button("") { viewModel.toggleAllCollapsed() }
                                .keyboardShortcut(KeyEquivalent("."), modifiers: [.command, .shift])
                                .opacity(0)
                                .frame(maxWidth: 0, maxHeight: 0)
                            // Ativar/desativar navegação do breadcrumb
                            Button("") {
                                viewModel.toggleBreadcrumbFocus()
                            }
                            .keyboardShortcut("b", modifiers: .command)
                            .opacity(0)
                            .frame(maxWidth: 0, maxHeight: 0)

                            // Navegar para a esquerda no breadcrumb
                            Button("") {
                                if viewModel.isBreadcrumbFocused {
                                    viewModel.navigateBreadcrumb(direction: -1)
                                }
                            }
                            .keyboardShortcut(.leftArrow, modifiers: [])
                            .opacity(0)
                            .frame(maxWidth: 0, maxHeight: 0)

                            // Navegar para a direita no breadcrumb
                            Button("") {
                                if viewModel.isBreadcrumbFocused {
                                    viewModel.navigateBreadcrumb(direction: 1)
                                }
                            }
                            .keyboardShortcut(.rightArrow, modifiers: [])
                            .opacity(0)
                            .frame(maxWidth: 0, maxHeight: 0)

                            // Confirmar navegação do breadcrumb
                            Button("") {
                                if viewModel.isBreadcrumbFocused {
                                    viewModel.commitBreadcrumbNavigation()
                                }
                            }
                            .keyboardShortcut(.return, modifiers: [])
                            .opacity(0)
                            .frame(maxWidth: 0, maxHeight: 0)

                            // Sair da navegação do breadcrumb
                            Button("") {
                                if viewModel.isBreadcrumbFocused {
                                    viewModel.toggleBreadcrumbFocus()
                                }
                            }
                            .keyboardShortcut(.escape, modifiers: [])
                            .opacity(0)
                            .frame(maxWidth: 0, maxHeight: 0)
                        } // group
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if viewModel.editingItemId == nil {
                    VStack(spacing: 4) {
                        // Breadcrumb acima do input
                        if viewModel.focusedItemId != nil {
                            if let path = viewModel.buildBreadcrumbPath() {
                                BreadcrumbView(
                                    path: path,
                                    settings: settings,
                                    onItemSelected: { id in
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            viewModel.focusedItemId = id
                                        }
                                    },
                                    selectedIndex: viewModel.selectedBreadcrumbIndex,
                                    isFocused: viewModel.isBreadcrumbFocused
                                )
                            }
                        }
                        
                        // Input bar com botão Focus sobreposto
                        ZStack {
                            // TextField
                            TextField("New item...", text: $viewModel.newItemText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(settings.inputBarBackgroundColor)
                                .foregroundColor(settings.inputBarTextColor)
                                .if(settings.inputBarShowBorder) { view in
                                    view.overlay(
                                        RoundedRectangle(cornerRadius: settings.inputBarCornerRadius)
                                            .stroke(settings.inputBarBorderColor, lineWidth: settings.inputBarBorderWidth)
                                    )
                                }
                                .cornerRadius(settings.inputBarCornerRadius)
                                .textFieldStyle(.plain)
                                .font(.system(size: baseNewItemSize * zoomLevel))
                                .focused($isNewItemFieldFocused)
                                .onChange(of: viewModel.newItemText) { newValue in
                                    commandManager.processInput(newValue)
                                }
                                .onSubmit {
                                    if viewModel.isBreadcrumbFocused {
                                        viewModel.commitBreadcrumbNavigation()
                                    } else {
                                        if case .active(let command) = commandManager.state,
                                           let cmd = CommandManager.Command.allCases.first(where: { $0.rawValue == command }) {
                                            commandManager.executeCommand(cmd)
                                            viewModel.newItemText = ""
                                        } else {
                                            viewModel.commitNewItem()
                                        }
                                    }
                                    isNewItemFieldFocused = true
                                }
                                .padding(.trailing, viewModel.focusedItemId != nil ? 80 : 0) // Espaço para o botão FOCUS
                            
                            // Botão FOCUS sobreposto à direita
                            if viewModel.focusedItemId != nil {
                                HStack {
                                    Spacer()
                                    Button("FOCUS") {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            viewModel.focusedItemId = nil
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 12)
                                    .font(.system(size: 14).bold().monospaced())
                                }
                            }
                            
                            // Command suggestions
                            if case .active(let input) = commandManager.state {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(commandManager.filteredCommands(input), id: \.self) { command in
                                        HStack {
                                            Text(command.rawValue)
                                                .font(.system(.body, design: .monospaced))
                                            Text(command.description)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(command.rawValue == input ? Color.accentColor.opacity(settings.accentOpacity) : Color.clear)
                                        .cornerRadius(4)
                                    }
                                }
                                .padding(8)
                                .background(.black)
                                .cornerRadius(8)
                                .offset(y: -40)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
            .background(Color(.textBackgroundColor))
            .onKeyPress(.upArrow) {
                if viewModel.editingItemId == nil && !viewModel.isBreadcrumbFocused {  // Adicionado check do breadcrumb
                    viewModel.selectPreviousItem()
                    if let selectedId = viewModel.selectedItemId {
                        proxy.scrollTo(selectedId, anchor: .center)
                    }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.downArrow) {
                if viewModel.editingItemId == nil && !viewModel.isBreadcrumbFocused {  // Adicionado check do breadcrumb
                    viewModel.selectNextItem()
                    if let selectedId = viewModel.selectedItemId {
                        proxy.scrollTo(selectedId, anchor: .center)
                    }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.space) {
                if viewModel.editingItemId == nil && !isNewItemFieldFocused {
                    viewModel.startNewItem()
                    isNewItemFieldFocused = true
                    return .handled
                }
                return .ignored
            }
            .onKeyPress("]") {
                viewModel.indentSelectedItem()
                return .handled
            }
            .onKeyPress("[") {
                viewModel.dedentSelectedItem()
                return .handled
            }
        }
        .sheet(isPresented: $commandManager.showingSettings) {
            SettingsView(settings: settings)
        }
        .sheet(isPresented: $commandManager.showingStatusSettings) {
            StatusSettingsView(settings: settings)
        }
        .accentColor(settings.accentColor)
    }
}

// Shake effect modifier
struct ShakeEffect: GeometryEffect {
    let amount: CGFloat
    let shakesPerUnit = 2
    let duration: Double
    
    var position: CGFloat
    
    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }
    
    init(amount: CGFloat = 8, duration: Double = 0.3, position: CGFloat = 0) {
        self.amount = amount
        self.duration = duration
        self.position = position
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(position * .pi * 2 * CGFloat(shakesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// Preview provider for SwiftUI canvas
struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        TaskListView()
    }
}


