import SwiftUI

struct ItemRowView: View {
    let id: UUID
    let viewModel: TaskListViewModel
    let item: Item
    let isSelected: Bool
    let isEditing: Bool
    let editingDirection: TaskListViewModel.EditDirection
    let onTitleChange: (String) -> Void
    let fontSize: Double
    let statusFontSize: Double
    let level: Int
    let onToggleCollapse: () -> Void
    
    @State private var editingTitle: String = ""
    @State private var statusScale: Double = 1.0
    @FocusState private var isDeleteConfirmationFocused: Bool
    @FocusState var isNewItemFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Collapse indicator e status (mantém igual)...
            if item.subItems != nil && !item.subItems!.isEmpty {
                Image(systemName: item.isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: statusFontSize))
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            onToggleCollapse()
                        }
                    }
            } else {
                Image(systemName: "circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.clear)
            }
            
            // Status indicator
            Text(item.status.rawValue)
                .font(.system(size: statusFontSize, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .foregroundStyle(statusColor.opacity(1))
                .background(statusColor.opacity(0.2))
                .cornerRadius(4)
                .scaleEffect(statusScale)
            
            // Task counter
            if item.status == .proj || item.status == .subProj {
                let counts = item.taskCounts
                TaskCounterView(
                    completed: counts.completed,
                    total: counts.total,
                    fontSize: statusFontSize
                )
            }
            
            // Title area
            if isEditing {
                if viewModel.isShowingDeleteConfirmation {
                    ZStack {
                        HStack(spacing: 12) {
                            
                            Text("Delete this item?")
                                .foregroundColor(.secondary)
                            
                            Text("YES")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(viewModel.deleteConfirmationOption == .yes ? Color.red : Color.gray.opacity(0.2))
                                .foregroundColor(viewModel.deleteConfirmationOption == .yes ? .white : .primary)
                                .cornerRadius(4)
                            
                            Text("NO")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(viewModel.deleteConfirmationOption == .no ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(viewModel.deleteConfirmationOption == .no ? .white : .primary)
                                .cornerRadius(4)
                            
                        }
                        .font(.system(size: fontSize))
                        
                        DeleteConfirmationNSView(
                            viewModel: viewModel,
                            fontSize: fontSize,
                            isNewItemFieldFocused: _isNewItemFieldFocused
                        )
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                    }
                } else {
                    CustomTextField(
                        text: $editingTitle,
                        onSubmit: { onTitleChange(editingTitle) },
                        cursorPosition: editingDirection,
                        fontSize: fontSize,
                        onEmptyDelete: {
                            if editingTitle.isEmpty {
                                viewModel.isShowingDeleteConfirmation = true
                            }
                        }
                    )
                    .onAppear { editingTitle = item.title }
                }
            } else {
                Text(item.title)
                    .font(.system(size: fontSize))
            }
        }
        .padding(.leading, CGFloat(level) * 20)
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var statusColor: Color {
        item.status.color
    }
}

struct TaskCounterView: View {
    let completed: Int
    let total: Int
    let fontSize: Double
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Text("\(completed)/\(total)")
            .font(.system(size: fontSize, design: .monospaced))
            .foregroundColor(completed == total && total > 0 ? .green : .white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.black)
            .cornerRadius(4)
            .scaleEffect(scale)
            .onChange(of: completed) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1.2
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        scale = 1.0
                    }
                }
            }
    }
}

struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let cursorPosition: TaskListViewModel.EditDirection
    let fontSize: Double
    var onEmptyDelete: (() -> Void)? = nil
    
    @State private var hasPositionedCursor = false
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField
        
        init(_ parent: CustomTextField) {
            self.parent = parent
            super.init()
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                control.window?.makeFirstResponder(nil)
                DispatchQueue.main.async {
                    self.parent.onSubmit()
                }
                return true
            }
            
            // Handle delete/backspace when text is empty
            if (commandSelector == #selector(NSResponder.deleteBackward(_:)) ||
                commandSelector == #selector(NSResponder.deleteForward(_:))) &&
                textView.string.isEmpty {
                parent.onEmptyDelete?()
                return true
            }
            
            return false
        }
    }
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.isBezeled = false
        textField.font = .systemFont(ofSize: fontSize)
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        nsView.font = .systemFont(ofSize: fontSize)
        
        if !hasPositionedCursor {
            DispatchQueue.main.async {
                guard let window = nsView.window else { return }
                window.makeFirstResponder(nsView)
                
                if let fieldEditor = window.fieldEditor(true, for: nsView) as? NSTextView {
                    switch cursorPosition {
                    case .left:
                        fieldEditor.selectedRange = NSRange(location: 0, length: 0)
                    case .right:
                        fieldEditor.selectedRange = NSRange(location: text.count, length: 0)
                    }
                }
                hasPositionedCursor = true
            }
        }
    }
}

struct DeleteConfirmationNSView: NSViewRepresentable {
    @ObservedObject var viewModel: TaskListViewModel
    let fontSize: Double
    @FocusState var isNewItemFieldFocused: Bool
    
    class Coordinator: NSResponder {
        var parent: DeleteConfirmationNSView
        
        init(_ parent: DeleteConfirmationNSView) {
            self.parent = parent
            super.init()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 123, 124: // Left arrow (123) or right arrow (124)
                parent.viewModel.deleteConfirmationOption.toggle()
            case 36: // Return
                let wasYes = parent.viewModel.deleteConfirmationOption == .yes
                parent.viewModel.handleDeleteConfirmation(confirmed: wasYes)
                DispatchQueue.main.async {
                    self.parent.isNewItemFieldFocused = true
                }
            case 53: // Escape
                parent.viewModel.isShowingDeleteConfirmation = false
                parent.viewModel.editingItemId = nil
                DispatchQueue.main.async {
                    self.parent.isNewItemFieldFocused = true
                }
            default:
                break
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.nextResponder = context.coordinator
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(context.coordinator)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(context.coordinator)
        }
    }
}
