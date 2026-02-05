//
//  TaskRowView.swift
//  MeetingIntelligence
//
//  Phase 2.2 - Task Row Component
//

import SwiftUI

struct TaskRowView: View {
    let task: Task
    var onStatusTap: ((TaskStatus) -> Void)?
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Icon (Tappable)
            Button {
                let nextStatus = getNextStatus()
                onStatusTap?(nextStatus)
            } label: {
                Image(systemName: task.status.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: task.status.color))
            }
            .buttonStyle(.plain)
            
            // Task Details
            VStack(alignment: .leading, spacing: 4) {
                // Title with strikethrough if completed
                Text(task.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(task.status == .completed ? .secondary : .primary)
                    .strikethrough(task.status == .completed, color: .secondary)
                    .lineLimit(2)
                
                // Meta info row
                HStack(spacing: 8) {
                    // Priority badge
                    PriorityBadge(priority: task.priority)
                    
                    // Due date if exists
                    if let dueDateText = task.dueDateFormatted {
                        HStack(spacing: 4) {
                            Image(systemName: task.isOverdue ? "exclamationmark.circle.fill" : "calendar")
                                .font(.caption2)
                            Text(dueDateText)
                                .font(.caption)
                        }
                        .foregroundColor(task.isOverdue ? .red : (task.isDueSoon ? .orange : .secondary))
                    }
                    
                    Spacer()
                }
                
                // Assignee if different from owner
                if let assignee = task.assignee {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(assignee.fullName)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
    
    private func getNextStatus() -> TaskStatus {
        switch task.status {
        case .pending: return .inProgress
        case .inProgress: return .completed
        case .completed: return .pending
        case .cancelled: return .pending
        }
    }
}

// MARK: - Priority Badge
struct PriorityBadge: View {
    let priority: TaskPriority
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: priority.icon)
                .font(.system(size: 8, weight: .bold))
            Text(priority.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(hex: priority.color).opacity(0.15))
        .foregroundColor(Color(hex: priority.color))
        .cornerRadius(4)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: TaskStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: status.color).opacity(0.15))
        .foregroundColor(Color(hex: status.color))
        .cornerRadius(6)
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
#if DEBUG
struct TaskRowView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTask = Task(
            id: "1",
            title: "Review meeting notes and prepare summary",
            description: "Go through the meeting recording and extract key action items",
            status: .pending,
            priority: .high,
            dueDate: Date().addingTimeInterval(3600 * 24), // Tomorrow
            completedAt: nil,
            ownerId: "user1",
            owner: TaskUser(id: "user1", firstName: "John", lastName: "Doe", email: "john@example.com"),
            assigneeId: "user2",
            assignee: TaskUser(id: "user2", firstName: "Jane", lastName: "Smith", email: "jane@example.com"),
            organizationId: "org1",
            facilityId: nil,
            meetingId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        VStack(spacing: 0) {
            TaskRowView(task: sampleTask)
            Divider()
            TaskRowView(task: Task(
                id: "2",
                title: "Completed task example",
                description: nil,
                status: .completed,
                priority: .low,
                dueDate: nil,
                completedAt: Date(),
                ownerId: "user1",
                owner: nil,
                assigneeId: nil,
                assignee: nil,
                organizationId: "org1",
                facilityId: nil,
                meetingId: nil,
                createdAt: Date(),
                updatedAt: Date()
            ))
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
