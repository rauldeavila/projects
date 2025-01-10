import Foundation
import SwiftUI

/// Represents the status of an item in the task management system
enum ItemStatus: String, Codable, CaseIterable {
    // Project-related status
    case proj = "PROJ"
    case subProj = "SUB-PROJ"
    
    // Task-related status
    case todo = "TODO"
    case doing = "DOING"
    case done = "DONE"
    case someday = "SOMEDAY"
    case maybe = "MAYBE"
    case future = "FUTURE"
    case read = "READ"
    case bug = "BUG"
    
    var color: Color {
        switch self {
        case .todo: return .blue
        case .doing: return .orange
        case .done: return .green
        case .proj, .subProj: return .purple
        case .someday, .maybe, .future: return .gray
        case .read: return .pink
        case .bug: return .red
        }
    }
    
    /// Returns true if the status is project-related
    var isProjectStatus: Bool {
        switch self {
        case .proj, .subProj:
            return true
        default:
            return false
        }
    }
}

/// Represents an item in the task management system
/// Can be a task, project, or sub-project depending on its position in the hierarchy
/// Error types for Item operations
enum ItemError: Error {
    case maxNestingLevelExceeded
    case invalidHierarchyOperation(String)
}

/// Represents an item in the task management system
/// Can be a task, project, or sub-project depending on its position in the hierarchy
struct Item: Identifiable, Codable {
    /// Unique identifier for the item
    let id: UUID
    
    /// Title of the item
    var title: String
    
    var isCollapsed: Bool = false
    
    /// Current status of the item
    var status: ItemStatus
    
    /// Optional array of sub-items
    var subItems: [Item]?
    
    /// Creation date of the item
    let createdAt: Date
    
    /// Last modification date of the item
    var modifiedAt: Date
    
    /// Completion date of the item (when marked as done)
    var completedAt: Date?
    
    /// Initialize a new item
    init(
        id: UUID = UUID(),
        title: String,
        status: ItemStatus = .todo,
        subItems: [Item]? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.subItems = subItems
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.completedAt = completedAt
    }
    
    /// Returns the nesting level of this item (0-3)
    var nestingLevel: Int {
        guard let subItems = subItems, !subItems.isEmpty else { return 0 }
        
        let maxSubLevel = subItems.map { $0.nestingLevel }.max() ?? 0
        return maxSubLevel + 1
    }
    
    /// Returns true if this item is a task (no sub-items)
    var isTask: Bool {
        subItems == nil || subItems?.isEmpty == true
    }
    
    /// Updates status based on current hierarchy position and children
    mutating func updateStatusBasedOnHierarchy() {
        // If has children, should be a project or subproject
        if !isTask {
            if nestingLevel == 1 {
                status = status == .done ? .done : .proj
            } else if nestingLevel == 2 {
                status = status == .done ? .done : .subProj
            }
        }
        
        // If all children are done, mark as done
        if !isTask, let subItems = subItems, !subItems.isEmpty {
            let allChildrenDone = subItems.allSatisfy { $0.status == .done }
            if allChildrenDone {
                status = .done
            } else if status == .done {
                // If any child is not done, parent can't be done
                status = nestingLevel == 1 ? .proj : .subProj
            }
        }
    }
    
    /// Returns true if this item is a project (has sub-items)
    var isProject: Bool {
        !isTask && nestingLevel == 1
    }
    
    /// Returns true if this item is a sub-project
    var isSubProject: Bool {
        !isTask && nestingLevel == 2
    }
    
    /// Maximum allowed nesting level
    static let maxNestingLevel = 3
    
    /// Adds a sub-item to this item
    /// - Parameter item: The item to add as a sub-item
    /// - Throws: ItemError if adding the item would exceed the maximum nesting level
    mutating func addSubItem(_ item: Item) throws {
        // Calculate what would be the new nesting level
        let potentialNewLevel = max(nestingLevel, item.nestingLevel + 1)
        
        // Check if adding this item would exceed the maximum nesting level
        guard potentialNewLevel <= Self.maxNestingLevel else {
            throw ItemError.maxNestingLevelExceeded
        }
        
        // Initialize subItems if nil
        if subItems == nil {
            subItems = []
        }
        
        // Add the item and update modification date
        subItems?.append(item)
        touch()
    }
    
    /// Removes a sub-item by its ID
    /// - Parameter id: The ID of the sub-item to remove
    /// - Returns: The removed item if found
    /// - Throws: ItemError if the item is not found
    @discardableResult
    mutating func removeSubItem(id: UUID) throws -> Item {
        guard let index = subItems?.firstIndex(where: { $0.id == id }) else {
            throw ItemError.invalidHierarchyOperation("Sub-item not found")
        }
        
        let removedItem = subItems?.remove(at: index)
        touch()
        
        return removedItem!
    }
    
    /// Moves a sub-item to a new index
    /// - Parameters:
    ///   - fromIndex: Current index of the sub-item
    ///   - toIndex: Desired new index for the sub-item
    mutating func moveSubItem(fromIndex: Int, toIndex: Int) throws {
        guard let subItems = subItems,
              fromIndex >= 0, fromIndex < subItems.count,
              toIndex >= 0, toIndex < subItems.count else {
            throw ItemError.invalidHierarchyOperation("Invalid index for move operation")
        }
        
        let item = self.subItems!.remove(at: fromIndex)
        self.subItems!.insert(item, at: toIndex)
        touch()
    }
    
    /// Updates the modification date
    mutating func touch() {
        modifiedAt = Date()
    }
    
    /// Marks the item as done
    mutating func markAsDone() {
        status = .done
        completedAt = Date()
        touch()
    }
}

extension Item {
    /// Returns the count of completed and total direct tasks
    var taskCounts: (completed: Int, total: Int) {
        guard let subItems = subItems else { return (0, 0) }
        
        let total = subItems.count
        let completed = subItems.filter { item in
            switch item.status {
            case .done:
                return true
            case .proj, .subProj:
                // For projects and subprojects, only count as done if all their tasks are done
                let (completedSub, totalSub) = item.taskCounts
                return completedSub == totalSub && totalSub > 0
            default:
                return false
            }
        }.count
        
        return (completed, total)
    }
}
