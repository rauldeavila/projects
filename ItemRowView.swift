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
    let settings: AppSettings
    let onToggleCollapse: () -> Void
    
    @State private var editingTitle: String = ""
    @State private var statusScale: Double = 1.0
    @FocusState private var isDeleteConfirmationFocused: Bool
    @FocusState var isNewItemFieldFocused: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Collapse indicator
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
            
            // Find the corresponding custom status for additional properties
            let customStatus = settings.customStatus.first { $0.rawValue == item.status.rawValue }
            let itemStatus = customStatus != nil
                ? ItemStatus.custom(item.status.rawValue, colorHex: item.status.colorHex ?? "#000000", customStatus: customStatus)
                : item.status
            
            // Use HStack for horizontal alignment but wrap in a VStack for top alignment
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    settings.statusStyle.apply(
                        to: Text(item.status.rawValue),
                        color: statusColor,
                        status: itemStatus,
                        fontSize: statusFontSize
                    )
                    .scaleEffect(statusScale)
                    
                    // Task counter - only show if the status allows it
                    if !item.isTask && (customStatus?.showCounter ?? true) {
                        TaskCounterView(
                            completed: item.taskCounts.completed,
                            total: item.taskCounts.total,
                            fontSize: statusFontSize
                        )
                    }
                }
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
                    .foregroundColor(settings.textColor)
                    .fixedSize(horizontal: false, vertical: true) // Permite quebra de linha natural
            }
        }
        .padding(.leading, CGFloat(level) * 40)
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
    
    class InlineTextField: NSTextField {
        var onReturn: (() -> Void)?
        var onEmptyDelete: (() -> Void)?
        
        override func textShouldBeginEditing(_ textObject: NSText) -> Bool {
            (self.cell as? NSTextFieldCell)?.wraps = true
            (self.cell as? NSTextFieldCell)?.isScrollable = false
            return true
        }
        
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 36 { // Return key
                onReturn?()
                return
            }
            
            if (event.keyCode == 51 || event.keyCode == 117) && // Delete or Forward Delete
               self.stringValue.isEmpty {
                onEmptyDelete?()
                return
            }
            
            super.keyDown(with: event)
        }
    }
    
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
                
                // Atualiza a altura do campo após a mudança
                if let cell = textField.cell as? NSTextFieldCell {
                    let frame = textField.frame
                    let size = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: frame.width, height: .greatestFiniteMagnitude))
                    if frame.height != size.height {
                        textField.frame.size.height = size.height
                    }
                }
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                control.window?.makeFirstResponder(nil)
                parent.onSubmit()
                return true
            }
            
            if (commandSelector == #selector(NSResponder.deleteBackward(_:)) ||
                commandSelector == #selector(NSResponder.deleteForward(_:))) &&
                textView.string.isEmpty {
                parent.onEmptyDelete?()
                return true
            }
            
            return false
        }
    }
    
    func makeNSView(context: Context) -> InlineTextField {
        let textField = InlineTextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.onReturn = onSubmit
        textField.onEmptyDelete = onEmptyDelete
        
        // Configurações básicas
        textField.font = .systemFont(ofSize: fontSize)
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.lineBreakMode = .byWordWrapping
        textField.cell?.wraps = true
        textField.cell?.isScrollable = false
        textField.cell?.usesSingleLineMode = false
        
        return textField
    }
    
    func updateNSView(_ textField: InlineTextField, context: Context) {
        if textField.stringValue != text {
            textField.stringValue = text
            
            // Atualiza altura se necessário
            if let cell = textField.cell as? NSTextFieldCell {
                let frame = textField.frame
                let size = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: frame.width, height: .greatestFiniteMagnitude))
                if frame.height != size.height {
                    textField.frame.size.height = size.height
                }
            }
        }
        
        // Atualiza fonte se necessário
        let currentSize = Double(textField.font?.pointSize ?? 0)
        if currentSize != fontSize {
            textField.font = .systemFont(ofSize: fontSize)
        }
        
        // Posiciona o cursor se necessário
        if !hasPositionedCursor {
            DispatchQueue.main.async {
                textField.window?.makeFirstResponder(textField)
                if let fieldEditor = textField.window?.fieldEditor(true, for: textField) as? NSTextView {
                    let location = cursorPosition == .left ? 0 : text.count
                    fieldEditor.selectedRange = NSRange(location: location, length: 0)
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
