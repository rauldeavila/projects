import SwiftUI

enum BreadcrumbNavigation {
    case previous
    case next
    case goToRoot
}

struct BreadcrumbItem: Identifiable {
    let id: UUID
    let title: String
    let status: ItemStatus
    let level: Int
}

struct BreadcrumbItemView: View {
    let item: BreadcrumbItem
    let settings: AppSettings
    let onItemSelected: (UUID) -> Void
    let isSelected: Bool
    let isFocused: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { onItemSelected(item.id) }) {
            HStack(spacing: 4) {
                settings.statusStyle.apply(
                    to: Text(item.status.rawValue),
                    color: item.status.color,
                    status: item.status,
                    fontSize: 11
                )
                
                Text(truncateMiddle(item.title, maxLength: 20))
                    .foregroundColor(isHovered ? settings.accentColor : settings.textColor)
                    .lineLimit(1)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
            .help(item.title)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    isFocused ? settings.accentColor.opacity(0.2) :
                    isHovered ? settings.accentColor.opacity(0.1) :
                    Color.secondary.opacity(0.1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? settings.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation {
                isHovered = hovering
            }
        }
    }
    
    // Função de truncar texto movida para dentro da struct
    private func truncateMiddle(_ str: String, maxLength: Int) -> String {
        guard str.count > maxLength else { return str }
        
        let half = maxLength / 2
        let leftSide = String(str.prefix(half - 1))
        let rightSide = String(str.suffix(half - 1))
        
        return "\(leftSide)…\(rightSide)"
    }
}

struct BreadcrumbView: View {
    let path: [BreadcrumbItem]
    let settings: AppSettings
    let onItemSelected: (UUID) -> Void
    let selectedIndex: Int // Novo parâmetro
    let isFocused: Bool   // Novo parâmetro
    
    private let chevronPadding: CGFloat = 8
    private let maxItemWidth: CGFloat = 150
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: chevronPadding) {
                ForEach(Array(path.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .imageScale(.small)
                    }
                    
                    BreadcrumbItemView(
                        item: item,
                        settings: settings,
                        onItemSelected: onItemSelected,
                        isSelected: index == selectedIndex,
                        isFocused: isFocused && index == selectedIndex
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(settings.backgroundColor)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
