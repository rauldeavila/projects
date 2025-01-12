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
    
    init(
        id: UUID = UUID(),
        name: String,
        rawValue: String,
        colorHex: String,
        category: String,
        order: Int,
        isDefault: Bool
    ) {
        self.id = id
        self.name = name
        self.rawValue = rawValue
        self.colorHex = colorHex
        self.category = category
        self.order = order
        self.isDefault = isDefault
    }
    
    var toDomain: CustomStatus {
        CustomStatus(
            id: id,
            name: name,
            rawValue: rawValue,
            colorHex: colorHex,
            category: StatusCategory(rawValue: category) ?? .task,
            order: order,
            isDefault: isDefault
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
            isDefault: status.isDefault
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
    var order: Int // New property
    
    @Relationship(deleteRule: .cascade, inverse: \ItemModel.subItems)
    var parent: ItemModel?
    
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
            status: statusIsCustom ?
                .custom(statusRawValue, colorHex: statusColorHex ?? "#808080") :
                ItemStatus.allCases.first { $0.rawValue == statusRawValue } ?? .todo,
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
