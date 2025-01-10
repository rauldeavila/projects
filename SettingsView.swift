import SwiftUI
import AppKit

struct KeyboardNavigationView: NSViewRepresentable {
    let onKeyPress: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyboardView()
        view.onKeyPress = onKeyPress
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyboardView {
            view.onKeyPress = onKeyPress
        }
    }
    
    class KeyboardView: NSView {
        var onKeyPress: ((NSEvent) -> Void)?
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.acceptsTouchEvents = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            onKeyPress?(event)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @State private var selectedColorIndex = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title)
                .padding(.bottom)
            
            Text("Accent Color")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)
            ], spacing: 12) {
                ForEach(Array(AppSettings.availableColors.enumerated()), id: \.element.name) { index, colorOption in
                    ColorOptionView(
                        name: colorOption.name,
                        color: colorOption.color,
                        isSelected: settings.selectedColorName == colorOption.name,
                        hasFocus: selectedColorIndex == index
                    )
                    .onTapGesture {
                        selectedColorIndex = index
                        settings.updateAccentColor(colorOption.name)
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
        .background(
            KeyboardNavigationView { event in
                switch event.keyCode {
                case 123: // Left arrow
                    if selectedColorIndex > 0 {
                        selectedColorIndex -= 1
                        updateSelectedColor()
                    }
                case 124: // Right arrow
                    if selectedColorIndex < AppSettings.availableColors.count - 1 {
                        selectedColorIndex += 1
                        updateSelectedColor()
                    }
                case 125: // Down arrow
                    let colorsPerRow = 4 // Ajustado para 4 cores por linha
                    let currentRow = selectedColorIndex / colorsPerRow
                    let currentCol = selectedColorIndex % colorsPerRow
                    let totalRows = (AppSettings.availableColors.count + colorsPerRow - 1) / colorsPerRow
                    
                    if currentRow < totalRows - 1 {
                        // Calculate the index in the row below
                        let targetIndex = (currentRow + 1) * colorsPerRow + currentCol
                        if targetIndex < AppSettings.availableColors.count {
                            selectedColorIndex = targetIndex
                            updateSelectedColor()
                        }
                    }
                case 126: // Up arrow
                    let colorsPerRow = 4 // Ajustado para 4 cores por linha
                    let currentRow = selectedColorIndex / colorsPerRow
                    let currentCol = selectedColorIndex % colorsPerRow
                    
                    if currentRow > 0 {
                        // Calculate the index in the row above
                        selectedColorIndex = (currentRow - 1) * colorsPerRow + currentCol
                        updateSelectedColor()
                    }
                case 36: // Return
                    dismiss()
                default:
                    break
                }
            }
        )
        .onAppear {
            // Set initial selected index
            selectedColorIndex = AppSettings.availableColors.firstIndex(where: { $0.name == settings.selectedColorName }) ?? 0
        }
    }
    
    private func updateSelectedColor() {
        let colorOption = AppSettings.availableColors[selectedColorIndex]
        settings.updateAccentColor(colorOption.name)
    }
}

struct ColorOptionView: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let hasFocus: Bool
    
    var body: some View {
        VStack {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .bold))
                    }
                }
            
            Text(name)
                .font(.system(size: 12))
        }
        .frame(height: 60)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(hasFocus ? color : (isSelected ? color : Color.clear), lineWidth: 2)
        )
    }
}
