//
//  LSWService.swift
//  MeetingIntelligence
//
//  Service for Leader Standard Work - connects to backend API
//

import Foundation
import Combine
import FirebaseAuth

// MARK: - Models

struct LSWDailyTask: Codable, Identifiable {
    let id: String
    let userId: String?
    let facilityId: String?
    let departmentId: String?
    let task: String
    let minutes: Int?
    let time: String
    let monday: Bool
    let tuesday: Bool
    let wednesday: Bool
    let thursday: Bool
    let friday: Bool
    let saturday: Bool
    let sunday: Bool
    let sortOrder: Int?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct CreateDailyTaskRequest: Codable {
    let task: String
    let time: String
    let minutes: Int
    let monday: Bool
    let tuesday: Bool
    let wednesday: Bool
    let thursday: Bool
    let friday: Bool
    let saturday: Bool
    let sunday: Bool
}

struct LSWDailyTasksResponse: Codable {
    let success: Bool
    let data: [LSWDailyTask]
}

struct LSWDailyTaskSingleResponse: Codable {
    let success: Bool
    let data: LSWDailyTask
}

struct LSWDailyTaskCompletion: Codable, Identifiable {
    let id: String
    let dailyTaskId: String
    let weekNumber: Int
    let year: Int
    let monday: Bool
    let tuesday: Bool
    let wednesday: Bool
    let thursday: Bool
    let friday: Bool
    let saturday: Bool
    let sunday: Bool
}

struct LSWCompletionResponse: Codable {
    let success: Bool
    let data: LSWDailyTaskCompletion
}

struct ToggleCompletionRequest: Codable {
    let weekNumber: Int
    let year: Int
    let day: String
    let value: Bool
}

struct LSWCalendarConfig: Codable {
    let calendarYearStartMonth: Int
    let calendarYearStartDay: Int
}

struct LSWUserPreferences: Codable {
    let workDaysPerWeek: Int
}

struct LSWDataResponse: Codable {
    let success: Bool
    let data: LSWDataPayload
}

struct LSWDataPayload: Codable {
    let calendarConfig: LSWCalendarConfig?
    let userPreferences: LSWUserPreferences?
}

struct LSWWorkDaysUpdateResponse: Codable {
    let success: Bool
}

// MARK: - Early Completion Models

struct LSWEarlyCompletionLog: Codable, Identifiable {
    let id: String
    let dailyTaskId: String
    let dayKey: String
    let dayLabel: String
    let weekNumber: Int
    let year: Int
}

struct LSWEarlyCompletionLogsResponse: Codable {
    let success: Bool
    let data: [LSWEarlyCompletionLog]
}

struct LSWEarlyCompletionLogSingleResponse: Codable {
    let success: Bool
    let data: LSWEarlyCompletionLog
}

struct CreateEarlyCompletionLogRequest: Codable {
    let dailyTaskId: String
    let taskName: String
    let taskTime: String
    let dayKey: String
    let dayLabel: String
    let weekNumber: Int
    let year: Int
    let scheduledDate: String
}

// MARK: - Service

class LSWService: ObservableObject {
    static let shared = LSWService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    @Published var dailyTasks: [LSWDailyTask] = []
    @Published var calendarConfig = LSWCalendarConfig(calendarYearStartMonth: 1, calendarYearStartDay: 1)
    @Published var workDaysPerWeek: Int = 5
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var earlyCompletionLogs: [LSWEarlyCompletionLog] = []
    
    // WebSocket sync state
    private var activeWeekNumber: Int?
    private var activeYear: Int?
    private var webSocketConnected = false
    
    private init() {}
    
    // MARK: - WebSocket Real-Time Sync
    
    func connectWebSocket() {
        guard !webSocketConnected else { return }
        
        let userId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        let orgId = UserDefaults.standard.string(forKey: "organization_id") ?? ""
        
        guard !userId.isEmpty, !orgId.isEmpty else { return }
        
        SocketIOClient.shared.on("lsw:completion-changed") { [weak self] data in
            guard let self = self,
                  let dict = data as? [String: Any],
                  let week = dict["weekNumber"] as? Int,
                  let year = dict["year"] as? Int else { return }
            
            // Only refetch if it matches our active week/year
            if week == self.activeWeekNumber && year == self.activeYear {
                Task {
                    await self.fetchDailyTasks(weekNumber: week, year: year)
                    await self.fetchEarlyCompletionLogs(weekNumber: week, year: year)
                }
            }
        }
        
        SocketIOClient.shared.connect(userId: userId, organizationId: orgId)
        webSocketConnected = true
    }
    
    func disconnectWebSocket() {
        SocketIOClient.shared.removeAllHandlers()
        SocketIOClient.shared.disconnect()
        webSocketConnected = false
    }
    
    func setActiveWeek(weekNumber: Int, year: Int) {
        activeWeekNumber = weekNumber
        activeYear = year
    }
    
    // MARK: - Auth Helper
    private func authorizedRequest(url: URL, method: String = "GET") async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = try? await FirebaseAuthService.shared.getIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    // MARK: - Fetch Calendar Config & Preferences
    func fetchConfig() async {
        guard let url = URL(string: "\(baseURL)/lsw/data?weekNumber=1&year=2026") else { return }
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            let result = try JSONDecoder().decode(LSWDataResponse.self, from: data)
            await MainActor.run {
                if let config = result.data.calendarConfig {
                    self.calendarConfig = config
                }
                if let prefs = result.data.userPreferences {
                    self.workDaysPerWeek = max(5, min(7, prefs.workDaysPerWeek))
                }
            }
        } catch { }
    }
    
    // MARK: - Update Work Days Per Week
    func updateWorkDays(_ days: Int) async {
        let clamped = max(5, min(7, days))
        await MainActor.run { self.workDaysPerWeek = clamped }
        
        guard let url = URL(string: "\(baseURL)/lsw/preferences/work-days") else { return }
        do {
            var request = try await authorizedRequest(url: url, method: "PUT")
            request.httpBody = try JSONEncoder().encode(["workDaysPerWeek": clamped])
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { self.workDaysPerWeek = 5 }
                return
            }
        } catch {
            await MainActor.run { self.workDaysPerWeek = 5 }
        }
    }
    
    // MARK: - Org Calendar Week Calculation
    func orgWeekNumber(for date: Date) -> Int {
        let m = calendarConfig.calendarYearStartMonth
        let d = calendarConfig.calendarYearStartDay
        
        // ISO 8601 default
        if m == 1 && d == 1 {
            let calendar = Calendar(identifier: .iso8601)
            return calendar.component(.weekOfYear, from: date)
        }
        
        let cycleStart = orgYearStart(for: date)
        let diffDays = Calendar.current.dateComponents([.day], from: cycleStart, to: date).day ?? 0
        return (diffDays / 7) + 1
    }
    
    func orgYear(for date: Date) -> Int {
        let m = calendarConfig.calendarYearStartMonth
        let d = calendarConfig.calendarYearStartDay
        
        if m == 1 && d == 1 {
            let calendar = Calendar(identifier: .iso8601)
            return calendar.component(.yearForWeekOfYear, from: date)
        }
        
        var yearCandidate = Calendar.current.component(.year, from: date)
        let candidate = Calendar.current.date(from: DateComponents(year: yearCandidate, month: m, day: d))!
        if date < candidate {
            yearCandidate -= 1
        }
        return yearCandidate
    }
    
    private func orgYearStart(for date: Date) -> Date {
        let m = calendarConfig.calendarYearStartMonth
        let d = calendarConfig.calendarYearStartDay
        let calendar = Calendar.current
        var yearCandidate = calendar.component(.year, from: date)
        let candidate = calendar.date(from: DateComponents(year: yearCandidate, month: m, day: d))!
        if date < candidate {
            yearCandidate -= 1
        }
        return calendar.date(from: DateComponents(year: yearCandidate, month: m, day: d))!
    }
    
    func weekDates(weekNumber: Int, year: Int) -> (start: Date, end: Date) {
        let m = calendarConfig.calendarYearStartMonth
        let d = calendarConfig.calendarYearStartDay
        let calendar = Calendar.current
        
        if m == 1 && d == 1 {
            // ISO week dates
            var comps = DateComponents()
            comps.yearForWeekOfYear = year
            comps.weekOfYear = weekNumber
            comps.weekday = 2 // Monday
            let monday = calendar.date(from: comps) ?? Date()
            let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? Date()
            return (monday, sunday)
        }
        
        let cycleStart = calendar.date(from: DateComponents(year: year, month: m, day: d))!
        let start = calendar.date(byAdding: .day, value: (weekNumber - 1) * 7, to: cycleStart)!
        let end = calendar.date(byAdding: .day, value: 6, to: start)!
        return (start, end)
    }
    
    // MARK: - Fetch Daily Tasks
    func fetchDailyTasks(weekNumber: Int? = nil, year: Int? = nil) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        var urlString = "\(baseURL)/lsw/daily-tasks"
        if let wn = weekNumber, let yr = year {
            urlString += "?weekNumber=\(wn)&year=\(yr)"
        }
        guard let url = URL(string: urlString) else { return }
        
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run { errorMessage = "No HTTP response"; isLoading = false }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                await MainActor.run { errorMessage = "Failed to load tasks"; isLoading = false }
                return
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(LSWDailyTasksResponse.self, from: data)
            
            let activeTasks = result.data.filter { $0.isActive != false }
            
            await MainActor.run {
                self.dailyTasks = activeTasks
                self.isLoading = false
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
        }
    }
    
    // MARK: - Create Daily Task
    func createDailyTask(_ taskRequest: CreateDailyTaskRequest) async -> Bool {
        await MainActor.run { isSubmitting = true; errorMessage = nil }
        
        guard let url = URL(string: "\(baseURL)/lsw/daily-tasks") else {
            await MainActor.run { errorMessage = "Invalid URL"; isSubmitting = false }
            return false
        }
        
        do {
            var request = try await authorizedRequest(url: url, method: "POST")
            request.httpBody = try JSONEncoder().encode(taskRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else {
                await MainActor.run { errorMessage = "Failed to create task"; isSubmitting = false }
                return false
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(LSWDailyTaskSingleResponse.self, from: data)
            
            await MainActor.run {
                self.dailyTasks.append(result.data)
                self.isSubmitting = false
            }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isSubmitting = false }
            return false
        }
    }
    
    // MARK: - Toggle Completion
    func toggleCompletion(taskId: String, weekNumber: Int, year: Int, day: String, value: Bool) async {
        
        // Optimistic update on the task in dailyTasks array
        await MainActor.run {
            if let idx = dailyTasks.firstIndex(where: { $0.id == taskId }) {
                let t = dailyTasks[idx]
                dailyTasks[idx] = LSWDailyTask(
                    id: t.id, userId: t.userId, facilityId: t.facilityId, departmentId: t.departmentId,
                    task: t.task, minutes: t.minutes, time: t.time,
                    monday: day == "monday" ? value : t.monday,
                    tuesday: day == "tuesday" ? value : t.tuesday,
                    wednesday: day == "wednesday" ? value : t.wednesday,
                    thursday: day == "thursday" ? value : t.thursday,
                    friday: day == "friday" ? value : t.friday,
                    saturday: day == "saturday" ? value : t.saturday,
                    sunday: day == "sunday" ? value : t.sunday,
                    sortOrder: t.sortOrder, isActive: t.isActive,
                    createdAt: t.createdAt, updatedAt: t.updatedAt
                )
            }
        }
        
        guard let url = URL(string: "\(baseURL)/lsw/daily-tasks/\(taskId)/completion") else { return }
        
        do {
            var request = try await authorizedRequest(url: url, method: "PUT")
            let body = ToggleCompletionRequest(weekNumber: weekNumber, year: year, day: day, value: value)
            request.httpBody = try JSONEncoder().encode(body)
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await fetchDailyTasks(weekNumber: weekNumber, year: year)
                return
            }
            
            if httpResponse.statusCode != 200 {
                await fetchDailyTasks(weekNumber: weekNumber, year: year)
            }
        } catch {
            await fetchDailyTasks(weekNumber: weekNumber, year: year)
        }
    }
    
    // MARK: - Delete Daily Task (soft delete)
    func deleteDailyTask(_ taskId: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/lsw/daily-tasks/\(taskId)") else { return false }
        
        do {
            let request = try await authorizedRequest(url: url, method: "DELETE")
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            
            await MainActor.run {
                self.dailyTasks.removeAll { $0.id == taskId }
            }
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Early Completion Logs
    
    func fetchEarlyCompletionLogs(weekNumber: Int, year: Int) async {
        guard let url = URL(string: "\(baseURL)/lsw/early-completion-logs?weekNumber=\(weekNumber)&year=\(year)") else { return }
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            let result = try JSONDecoder().decode(LSWEarlyCompletionLogsResponse.self, from: data)
            await MainActor.run {
                self.earlyCompletionLogs = result.data
            }
        } catch { }
    }
    
    func logEarlyCompletion(dailyTaskId: String, taskName: String, taskTime: String, dayKey: String, dayLabel: String, weekNumber: Int, year: Int, scheduledDate: Date) async {
        guard let url = URL(string: "\(baseURL)/lsw/early-completion-logs") else { return }
        
        let isoFormatter = ISO8601DateFormatter()
        let body = CreateEarlyCompletionLogRequest(
            dailyTaskId: dailyTaskId,
            taskName: taskName,
            taskTime: taskTime,
            dayKey: dayKey,
            dayLabel: dayLabel,
            weekNumber: weekNumber,
            year: year,
            scheduledDate: isoFormatter.string(from: scheduledDate)
        )
        
        do {
            var request = try await authorizedRequest(url: url, method: "POST")
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else { return }
            if let log = try? JSONDecoder().decode(LSWEarlyCompletionLogSingleResponse.self, from: data) {
                await MainActor.run {
                    self.earlyCompletionLogs.append(log.data)
                }
            }
        } catch { }
    }
    
    func isEarlyCompleted(taskId: String, dayKey: String) -> Bool {
        earlyCompletionLogs.contains { $0.dailyTaskId == taskId && $0.dayKey == dayKey }
    }
    
    func deleteEarlyCompletionLog(dailyTaskId: String, dayKey: String, weekNumber: Int, year: Int) async {
        guard let url = URL(string: "\(baseURL)/lsw/early-completion-logs") else { return }
        
        let body: [String: Any] = [
            "dailyTaskId": dailyTaskId,
            "dayKey": dayKey,
            "weekNumber": weekNumber,
            "year": year
        ]
        
        do {
            var request = try await authorizedRequest(url: url, method: "DELETE")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            await MainActor.run {
                self.earlyCompletionLogs.removeAll { $0.dailyTaskId == dailyTaskId && $0.dayKey == dayKey && $0.weekNumber == weekNumber && $0.year == year }
            }
        } catch { }
    }
}
