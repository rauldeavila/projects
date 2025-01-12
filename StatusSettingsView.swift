import SwiftUI

struct StatusSettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedStyleIndex = 0
    @State private var draggedStatus: CustomStatus?
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Status Settings")
                .font(.title)
                .padding(.bottom)
            
            // Status Style Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Status Style")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    ForEach(Array(StatusStyle.allCases.enumerated()), id: \.element) { index, style in
                        StatusStylePreview(
                            style: style,
                            isSelected: settings.statusStyle == style,
                            hasFocus: selectedStyleIndex == index
                        )
                        .onTapGesture {
                            selectedStyleIndex = index
                            settings.statusStyle = style
                        }
                    }
                }
            }
            
            // Status Categories Grid
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(StatusCategory.allCases, id: \.self) { category in
                    StatusCategoryColumn(
                        category: category,
                        statuses: settings.getStatus(for: category),
                        settings: settings,
                        style: settings.statusStyle,
                        onError: { message in
                            errorMessage = message
                            showingError = true
                        }
                    )
                }
            }
            .padding(.vertical)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.return)
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct StatusCategoryColumn: View {
    let category: StatusCategory
    let statuses: [CustomStatus]
    let settings: AppSettings
    let style: StatusStyle
    let onError: (String) -> Void
    
    @State private var isAddingStatus = false
    @State private var draggedStatus: CustomStatus?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text(category.rawValue)
                .font(.headline)
            
            // Status List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(statuses) { status in
                        StatusItemView(
                            status: status,
                            style: style,
                            onDelete: {
                                settings.removeCustomStatus(id: status.id)
                            }
                        )
                        .onDrag {
                            self.draggedStatus = status
                            return NSItemProvider(object: status.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: DropViewDelegate(
                            item: status,
                            draggedItem: $draggedStatus,
                            items: statuses,
                            category: category,
                            settings: settings
                        ))
                    }
                    
                    // Add Status Button
                    Button(action: { isAddingStatus = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Status")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
                }
                .padding()
            }
            .frame(height: 300)
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .sheet(isPresented: $isAddingStatus) {
            AddCustomStatusView(
                isPresented: $isAddingStatus,
                settings: settings,
                category: category,
                showError: onError
            )
        }
    }
}

struct DropViewDelegate: DropDelegate {
    let item: CustomStatus
    @Binding var draggedItem: CustomStatus?
    let items: [CustomStatus]
    let category: StatusCategory
    let settings: AppSettings
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedItem = self.draggedItem else { return false }
        guard draggedItem.category == category else { return false }
        
        let fromIndex = items.firstIndex(where: { $0.id == draggedItem.id }) ?? 0
        let toIndex = items.firstIndex(where: { $0.id == item.id }) ?? 0
        
        withAnimation {
            settings.updateOrder(in: category, oldIndex: fromIndex, newIndex: toIndex)
        }
        
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

struct StatusItemView: View {
    let status: CustomStatus
    let style: StatusStyle
    var onDelete: (() -> Void)? = nil
    var isDragging: Bool = false
    
    var body: some View {
        HStack {
            style.apply(
                to: Text(status.rawValue),
                color: status.color,
                status: .custom(status.rawValue, colorHex: status.colorHex),
                fontSize: 12
            )
            
            Spacer()
            
            Text(status.name)
                .foregroundStyle(.secondary)
                .font(.caption)
            
            if !status.isDefault, let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(isDragging ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

struct StatusStylePreview: View {
    let style: StatusStyle
    let isSelected: Bool
    let hasFocus: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            style.apply(
                to: Text("SAMPLE"),
                color: .blue,
                status: .todo,
                fontSize: 11
            )
            
            Text(style.rawValue)
                .font(.caption)
        }
        .padding(8)
        .frame(width: 120)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(hasFocus ? Color.accentColor : (isSelected ? Color.accentColor.opacity(0.5) : Color.clear), lineWidth: 2)
        )
    }
}

struct AddCustomStatusView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: AppSettings
    let category: StatusCategory
    let showError: (String) -> Void
    
    @State private var name = ""
    @State private var rawValue = ""
    @State private var selectedColor = Color.blue
    @State private var hex = "#0000FF"
    @State private var isEditingHex = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add \(category.rawValue) Status")
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.headline)
                TextField("e.g. In Progress", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Status Code")
                    .font(.headline)
                TextField("e.g. INPROG", text: $rawValue)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: rawValue) { newValue in
                        rawValue = newValue.uppercased()
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.headline)
                
                ColorPicker("Select Color", selection: $selectedColor)
                    .labelsHidden()
                    .onChange(of: selectedColor) { newColor in
                        if let hexString = newColor.toHex() {
                            isEditingHex = true
                            hex = hexString
                        }
                    }
                
                TextField("#000000", text: $hex)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: hex) { newValue in
                        if !isEditingHex {
                            if let color = Color(hex: newValue) {
                                selectedColor = color
                            }
                        }
                        isEditingHex = false
                    }
                
                // Preview
                HStack {
                    ForEach(StatusStyle.allCases, id: \.self) { style in
                        style.apply(
                            to: Text(rawValue.isEmpty ? "STATUS" : rawValue),
                            color: selectedColor,
                            status: .custom(rawValue.isEmpty ? "STATUS" : rawValue, colorHex: hex),
                            fontSize: 11
                        )
                    }
                }
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                
                Button("Add") {
                    guard !name.isEmpty else {
                        showError("Please enter a status name")
                        return
                    }
                    
                    guard !rawValue.isEmpty else {
                        showError("Please enter a status code")
                        return
                    }
                    
                    if !settings.addCustomStatus(
                        name: name,
                        rawValue: rawValue,
                        colorHex: hex,
                        category: category
                    ) {
                        showError("Status name or code already exists")
                        return
                    }
                    
                    isPresented = false
                }
                .keyboardShortcut(.return)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 400)
    }
}
