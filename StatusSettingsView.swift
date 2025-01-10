// StatusSettingsView.swift
import SwiftUI

struct StatusSettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @State private var isAddingStatus = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedStyleIndex = 0
    
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
            .background(
                KeyboardNavigationView { event in
                    handleKeyboardNavigation(event)
                }
            )
            
            // Custom Status Section
            HStack {
                Text("Custom Status")
                    .font(.headline)
                
                Spacer()
                
                Button("Add Status") {
                    isAddingStatus = true
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
                ], spacing: 12) {
                    ForEach(settings.customStatus) { status in
                        CustomStatusView(
                            status: status,
                            style: settings.statusStyle,
                            onDelete: {
                                settings.removeCustomStatus(id: status.id)
                            }
                        )
                    }
                }
            }
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.return)
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $isAddingStatus) {
            AddCustomStatusView(
                isPresented: $isAddingStatus,
                settings: settings,
                showError: { message in
                    errorMessage = message
                    showingError = true
                }
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleKeyboardNavigation(_ event: NSEvent) {
        let styleCount = StatusStyle.allCases.count
        
        switch event.keyCode {
        case 123: // Left arrow
            if selectedStyleIndex > 0 {
                selectedStyleIndex -= 1
                settings.statusStyle = StatusStyle.allCases[selectedStyleIndex]
            }
        case 124: // Right arrow
            if selectedStyleIndex < styleCount - 1 {
                selectedStyleIndex += 1
                settings.statusStyle = StatusStyle.allCases[selectedStyleIndex]
            }
        case 36: // Return
            dismiss()
        case 53: // Escape
            dismiss()
        default:
            break
        }
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

struct CustomStatusView: View {
    let status: CustomStatus
    let style: StatusStyle
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                VStack {
                    style.apply(
                        to: Text(status.rawValue),
                        color: status.color,
                        fontSize: 11
                    )
                    
                    Text(status.name)
                        .font(.caption)
                }
                .padding(12)
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                        .background(Color.white.clipShape(Circle()))
                }
                .buttonStyle(.plain)
                
            }
        }
    }
}

struct AddCustomStatusView: View {
    @Binding var isPresented: Bool
    @ObservedObject var settings: AppSettings
    let showError: (String) -> Void
    
    @State private var name = ""
    @State private var rawValue = ""
    @State private var selectedColor = Color.blue
    @State private var hex = "#0000FF"
    @State private var isEditingHex = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Custom Status")
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
                    
                    if !settings.addCustomStatus(name: name, rawValue: rawValue, colorHex: hex) {
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
