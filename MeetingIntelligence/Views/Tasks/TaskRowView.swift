//
//  TaskRowView.swift
//  MeetingIntelligence
//
//  Phase 2.2 - Task Row Component
//

import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
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
                
                // Progress bar (only show if progress > 0)
                if task.progressValue > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Progress")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(task.progressValue)%")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(progressColor)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                
                                // Filled progress with gradient
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(progressGradient)
                                    .frame(width: geometry.size.width * CGFloat(task.progressValue) / 100.0, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.top, 4)
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
    
    private var progressColor: Color {
        let progress = task.progressValue
        // Color ranges: 0-20% Red, 20-50% Yellow/Orange, 50-80% Green, 80-100% Blue
        if progress <= 20 { return .red }
        if progress <= 50 { return .orange }
        if progress <= 80 { return .green }
        return .blue
    }
    
    private var progressGradient: LinearGradient {
        let progress = Double(task.progressValue)
        
        if progress <= 20 {
            return LinearGradient(colors: [.red], startPoint: .leading, endPoint: .trailing)
        } else if progress <= 50 {
            let redEnd = 20.0 / progress
            return LinearGradient(
                stops: [
                    .init(color: .red, location: 0.0),
                    .init(color: .red, location: redEnd),
                    .init(color: .orange, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if progress <= 80 {
            let redEnd = 20.0 / progress
            let orangeEnd = 50.0 / progress
            return LinearGradient(
                stops: [
                    .init(color: .red, location: 0.0),
                    .init(color: .red, location: redEnd),
                    .init(color: .orange, location: orangeEnd),
                    .init(color: .green, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            let redEnd = 20.0 / progress
            let orangeEnd = 50.0 / progress
            let greenEnd = 80.0 / progress
            return LinearGradient(
                stops: [
                    .init(color: .red, location: 0.0),
                    .init(color: .red, location: redEnd),
                    .init(color: .orange, location: orangeEnd),
                    .init(color: .green, location: greenEnd),
                    .init(color: .blue, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
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
        let sampleTask = TaskItem(
            id: "1",
            title: "Review meeting notes and prepare summary",
            description: "Go through the meeting recording and extract key action items",
            status: .pending,
            priority: .high,
            startDate: nil,
            dueDate: Date().addingTimeInterval(3600 * 24), // Tomorrow
            completedAt: nil,
            progress: 25,
            sourceText: nil,
            isAiExtracted: false,
            ownerId: "user1",
            owner: TaskUser(id: "user1", firstName: "John", lastName: "Doe", email: "john@example.com", profilePicture: nil),
            assigneeId: "user2",
            assignee: TaskUser(id: "user2", firstName: "Jane", lastName: "Smith", email: "jane@example.com", profilePicture: nil),
            assignees: nil,
            organizationId: "org1",
            facilityId: nil,
            departmentId: nil,
            department: nil,
            meetingId: nil,
            meeting: nil,
            groupName: nil,
            comments: nil,
            evidence: nil,
            _count: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        VStack(spacing: 0) {
            TaskRowView(task: sampleTask)
            Divider()
            TaskRowView(task: TaskItem(
                id: "2",
                title: "Completed task example",
                description: nil,
                status: .completed,
                priority: .low,
                startDate: nil,
                dueDate: nil,
                completedAt: Date(),
                progress: 100,
                sourceText: nil,
                isAiExtracted: true,
                ownerId: "user1",
                owner: nil,
                assigneeId: nil,
                assignee: nil,
                assignees: nil,
                organizationId: "org1",
                facilityId: nil,
                departmentId: nil,
                department: nil,
                meetingId: nil,
                meeting: nil,
                groupName: nil,
                comments: nil,
                evidence: nil,
                _count: nil,
                createdAt: Date(),
                updatedAt: Date()
            ))
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
