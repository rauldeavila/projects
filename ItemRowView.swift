//import SwiftUI
//
///// View for a single item row
//struct ItemRowView: View {
//    let item: Item
//    
//    var body: some View {
//        HStack(spacing: 8) {
//            // Status indicator
//            Text(item.status.rawValue)
//                .font(.system(.caption, design: .monospaced))
//                .padding(.horizontal, 4)
//                .padding(.vertical, 2)
//                .background(statusColor.opacity(0.2))
//                .cornerRadius(4)
//            
//            // Title with appropriate indentation
//            Text(item.title)
//                .padding(.leading, CGFloat(item.nestingLevel) * 20)
//        }
//        .padding(.vertical, 2)
//        .padding(.horizontal, 8)
//        .frame(maxWidth: .infinity, alignment: .leading)
//    }
//    
//    private var statusColor: Color {
//        switch item.status {
//        case .todo:
//            return .blue
//        case .doing:
//            return .orange
//        case .done:
//            return .green
//        case .proj, .subProj:
//            return .purple
//        case .someday, .maybe, .future:
//            return .gray
//        }
//    }
//}
