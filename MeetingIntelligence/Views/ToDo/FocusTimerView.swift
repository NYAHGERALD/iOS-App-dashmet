import SwiftUI

struct FocusTimerView: View {
    @StateObject private var manager = ToDoManager.shared
    @Environment(\.dismiss) private var dismiss
    let colorScheme: ColorScheme
    var linkedTask: ToDoItem? = nil
    
    @State private var selectedDuration: Int = 25
    @State private var selectedTask: ToDoItem? = nil
    @State private var showTaskPicker = false
    
    // Adaptive colors
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var textTertiary: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    // Preset durations
    private let presets: [(name: String, minutes: Int, icon: String)] = [
        ("Pomodoro", 25, "flame.fill"),
        ("Short", 15, "hare.fill"),
        ("Long", 45, "tortoise.fill"),
        ("Hour", 60, "clock.fill")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color(hex: "1a1a2e") : Color(hex: "f8f9fa"),
                        colorScheme == .dark ? Color(hex: "16213e") : Color(hex: "e9ecef")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if manager.currentFocusSession != nil {
                    // Active timer view
                    activeTimerView
                } else {
                    // Setup view
                    setupView
                }
            }
            .navigationTitle("Focus Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }
            }
            .onAppear {
                if let task = linkedTask {
                    selectedTask = task
                }
            }
        }
    }
    
    // MARK: - Setup View
    private var setupView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Timer Display
                timerSetupDisplay
                
                // Duration Presets
                durationPresets
                
                // Custom Duration Slider
                customDurationSlider
                
                // Task Selection
                taskSelectionSection
                
                // Statistics
                statisticsSection
                
                // Start Button
                startButton
            }
            .padding()
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Timer Setup Display
    private var timerSetupDisplay: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(cardBorder, lineWidth: 12)
                    .frame(width: 200, height: 200)
                
                // Animated ring
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(selectedDuration)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)
                    
                    Text("minutes")
                        .font(.title3)
                        .foregroundColor(textSecondary)
                }
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - Duration Presets
    private var durationPresets: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Select")
                .font(.headline)
                .foregroundColor(textPrimary)
            
            HStack(spacing: 12) {
                ForEach(presets, id: \.minutes) { preset in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDuration = preset.minutes
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: preset.icon)
                                .font(.title3)
                            Text("\(preset.minutes)")
                                .font(.headline)
                            Text(preset.name)
                                .font(.caption)
                        }
                        .foregroundColor(selectedDuration == preset.minutes ? .white : textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedDuration == preset.minutes ?
                            LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [cardBackground, cardBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedDuration == preset.minutes ? Color.clear : cardBorder, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Custom Duration Slider
    private var customDurationSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Duration")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                Text("\(selectedDuration) min")
                    .font(.subheadline)
                    .foregroundColor(textSecondary)
            }
            
            Slider(value: Binding(
                get: { Double(selectedDuration) },
                set: { selectedDuration = Int($0) }
            ), in: 5...120, step: 5)
            .tint(.purple)
            
            HStack {
                Text("5 min")
                    .font(.caption)
                    .foregroundColor(textTertiary)
                Spacer()
                Text("2 hours")
                    .font(.caption)
                    .foregroundColor(textTertiary)
            }
        }
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Task Selection
    private var taskSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Link to Task (Optional)")
                .font(.headline)
                .foregroundColor(textPrimary)
            
            Button {
                showTaskPicker = true
            } label: {
                HStack {
                    if let task = selectedTask {
                        Circle()
                            .fill(task.priority.color)
                            .frame(width: 8, height: 8)
                        
                        Text(task.title)
                            .foregroundColor(textPrimary)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.purple)
                        Text("Select a task")
                            .foregroundColor(textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(textTertiary)
                }
                .padding()
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .sheet(isPresented: $showTaskPicker) {
                TaskPickerView(selectedTask: $selectedTask, colorScheme: colorScheme)
            }
        }
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Focus Stats")
                .font(.headline)
                .foregroundColor(textPrimary)
            
            HStack(spacing: 16) {
                FocusStatCard(
                    icon: "flame.fill",
                    value: "\(manager.statistics.totalPomodorosCompleted)",
                    label: "Pomodoros",
                    color: .orange,
                    colorScheme: colorScheme
                )
                
                FocusStatCard(
                    icon: "clock.fill",
                    value: formatMinutes(manager.statistics.totalFocusMinutes),
                    label: "Total Focus",
                    color: .blue,
                    colorScheme: colorScheme
                )
                
                FocusStatCard(
                    icon: "star.fill",
                    value: "\(manager.statistics.currentStreak)",
                    label: "Day Streak",
                    color: .yellow,
                    colorScheme: colorScheme
                )
            }
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
    
    // MARK: - Start Button
    private var startButton: some View {
        Button {
            manager.startFocusTimer(for: selectedTask, duration: selectedDuration)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.title2)
                Text("Start Focus")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.purple.opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Active Timer View
    private var activeTimerView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Timer Ring
            ZStack {
                // Background
                Circle()
                    .stroke(cardBorder, lineWidth: 16)
                    .frame(width: 280, height: 280)
                
                // Progress
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.purple, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerProgress)
                
                // Time display
                VStack(spacing: 8) {
                    Text(formattedTime)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)
                    
                    if let task = selectedTask {
                        Text(task.title)
                            .font(.subheadline)
                            .foregroundColor(textSecondary)
                            .lineLimit(1)
                            .padding(.horizontal, 40)
                    }
                }
            }
            
            // Status
            Text(manager.isTimerRunning ? "Stay focused!" : "Paused")
                .font(.title3)
                .foregroundColor(manager.isTimerRunning ? .green : .orange)
            
            Spacer()
            
            // Controls
            HStack(spacing: 30) {
                // Stop button
                Button {
                    manager.stopTimer()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                
                // Play/Pause button
                Button {
                    if manager.isTimerRunning {
                        manager.pauseTimer()
                    } else {
                        manager.resumeTimer()
                    }
                } label: {
                    Image(systemName: manager.isTimerRunning ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.purple.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                
                // Skip button
                Button {
                    manager.completeFocusSession()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var timerProgress: Double {
        guard let session = manager.currentFocusSession else { return 0 }
        let total = session.durationMinutes * 60
        let remaining = manager.timerRemainingSeconds
        return Double(total - remaining) / Double(total)
    }
    
    private var formattedTime: String {
        let minutes = manager.timerRemainingSeconds / 60
        let seconds = manager.timerRemainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Focus Stat Card
struct FocusStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let colorScheme: ColorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .foregroundColor(textPrimary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Task Picker View
struct TaskPickerView: View {
    @StateObject private var manager = ToDoManager.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTask: ToDoItem?
    let colorScheme: ColorScheme
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
    
    var activeTasks: [ToDoItem] {
        manager.tasks.filter { !$0.isCompleted && !$0.isArchived }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                if activeTasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(textSecondary)
                        
                        Text("No active tasks")
                            .font(.headline)
                            .foregroundColor(textSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            // None option
                            Button {
                                selectedTask = nil
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.gray)
                                    
                                    Text("No task")
                                        .foregroundColor(textSecondary)
                                    
                                    Spacer()
                                    
                                    if selectedTask == nil {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.purple)
                                    }
                                }
                                .padding()
                                .background(cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            ForEach(activeTasks) { task in
                                Button {
                                    selectedTask = task
                                    dismiss()
                                } label: {
                                    HStack {
                                        Circle()
                                            .fill(task.priority.color)
                                            .frame(width: 8, height: 8)
                                        
                                        Text(task.title)
                                            .foregroundColor(textPrimary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        if selectedTask?.id == task.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.purple)
                                        }
                                    }
                                    .padding()
                                    .background(cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }
            }
        }
    }
}

#Preview {
    FocusTimerView(colorScheme: .dark)
}
