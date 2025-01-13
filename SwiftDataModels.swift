import SwiftData
import SwiftUI

@Model
final class CustomColorModel {
    var id: UUID
    var name: String
    var hex: String
    
    init(id: UUID = UUID(), name: String, hex: String) {
        self.id = id
        self.name = name
        self.hex = hex
    }
    
    var toDomain: CustomColor {
        CustomColor(id: id, name: name, hex: hex)
    }
    
    static func fromDomain(_ color: CustomColor) -> CustomColorModel {
        CustomColorModel(id: color.id, name: color.name, hex: color.hex)
    }
}

@Model
final class CustomStatusModel {
    var id: UUID
    var name: String
    var rawValue: String
    var colorHex: String
    var category: String
    var order: Int
    var isDefault: Bool
    var showCounter: Bool
    var backgroundColor: String
    var textColor: String
    var forceCustomColors: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        rawValue: String,
        colorHex: String,
        category: String,
        order: Int,
        isDefault: Bool,
        showCounter: Bool = false,
        backgroundColor: String = "#000000",
        textColor: String = "#FFFFFF",
        forceCustomColors: Bool = false
    ) {
        self.id = id
        self.name = name
        self.rawValue = rawValue
        self.colorHex = colorHex
        self.category = category
        self.order = order
        self.isDefault = isDefault
        self.showCounter = showCounter
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.forceCustomColors = forceCustomColors
    }
    
    var toDomain: CustomStatus {
        CustomStatus(
            id: id,
            name: name,
            rawValue: rawValue,
            colorHex: colorHex,
            category: StatusCategory(rawValue: category) ?? .task,
            order: order,
            isDefault: isDefault,
            showCounter: showCounter,
            backgroundColor: backgroundColor,
            textColor: textColor,
            forceCustomColors: forceCustomColors  // Usa o valor salvo
        )
    }
    
    static func fromDomain(_ status: CustomStatus) -> CustomStatusModel {
        CustomStatusModel(
            id: status.id,
            name: status.name,
            rawValue: status.rawValue,
            colorHex: status.colorHex,
            category: status.category.rawValue,
            order: status.order,
            isDefault: status.isDefault,
            showCounter: status.showCounter,
            backgroundColor: status.backgroundColor,
            textColor: status.textColor,
            forceCustomColors: status.forceCustomColors
        )
    }
}


@Model
final class AppData {
    var selectedColorName: String
    var statusStyle: Int
    @Relationship(deleteRule: .cascade) var customColors: [CustomColorModel]
    @Relationship(deleteRule: .cascade) var customStatus: [CustomStatusModel]
    
    init(
        selectedColorName: String = "System",
        statusStyle: Int = 0,
        customColors: [CustomColorModel] = [],
        customStatus: [CustomStatusModel] = []
    ) {
        self.selectedColorName = selectedColorName
        self.statusStyle = statusStyle
        self.customColors = customColors
        self.customStatus = customStatus
    }
}

@Model
final class ItemModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCollapsed: Bool
    var statusRawValue: String
    var statusIsCustom: Bool
    var statusColorHex: String?
    var createdAt: Date
    var modifiedAt: Date
    var completedAt: Date?
    var order: Int
    
    @Relationship(deleteRule: .nullify)
    var parent: ItemModel?
    
    // Mantemos cascade apenas nos filhos
    @Relationship(deleteRule: .cascade)
    var subItems: [ItemModel]?
    
    
    init(item: Item, order: Int) {
        self.id = item.id
        self.title = item.title
        self.isCollapsed = item.isCollapsed
        self.statusRawValue = item.status.rawValue
        self.statusIsCustom = item.status.isCustom
        self.statusColorHex = item.status.colorHex
        self.createdAt = item.createdAt
        self.modifiedAt = item.modifiedAt
        self.completedAt = item.completedAt
        self.order = order
        
        if let subItems = item.subItems {
            let subModels = subItems.enumerated().map { index, item in
                ItemModel(item: item, order: index)
            }
            self.subItems = subModels
            subModels.forEach { $0.parent = self }
        }
    }
    
    var toDomain: Item {
        var item = Item(
            id: id,
            title: title,
            isCollapsed: isCollapsed,
            status: .custom(statusRawValue, colorHex: statusColorHex ?? "#808080"),
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            completedAt: completedAt
        )
        
        if let subItems = subItems?.sorted(by: { $0.order < $1.order }) {
            item.subItems = subItems.map { $0.toDomain }
        }
        
        return item
    }
}
