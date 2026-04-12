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

struct LSWDailyTask: Codable, Identifiable, Equatable {
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

// MARK: - Project Models

struct LSWProjectUpdate: Codable, Identifiable {
    let id: String
    let text: String
    let fontColor: String?
    let fontItalic: Bool?
    let cellColor: String?
    let cellColorIntensity: Int?
    let sortOrder: Int?
}

struct LSWProject: Codable, Identifiable {
    let id: String
    let name: String
    let updates: [LSWProjectUpdate]
    let fontColor: String?
    let fontFamily: String?
    let fontBold: Bool?
    let fontItalic: Bool?
    let cellColor: String?
    let cellColorIntensity: Int?
    let defaultUpdateFontColor: String?
    let defaultUpdateFontItalic: Bool?
    let defaultUpdateCellColor: String?
    let defaultUpdateCellColorIntensity: Int?
    let sortOrder: Int?
    let isActive: Bool?
}

struct LSWProjectsResponse: Codable {
    let success: Bool
    let data: [LSWProject]
}

struct LSWProjectSingleResponse: Codable {
    let success: Bool
    let data: LSWProject
}

struct LSWProjectUpdateSingleResponse: Codable {
    let success: Bool
    let data: LSWProjectUpdate
}

// MARK: - Follow-Up Models

struct LSWFollowUpResponsibleUser: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
}

struct LSWFollowUp: Codable, Identifiable {
    let id: String
    let task: String
    let dueDate: String
    let responsibleUserId: String?
    let responsibleName: String?
    let responsibleUser: LSWFollowUpResponsibleUser?
    let comments: String?
    let completed: Bool?
    let sortOrder: Int?
    let isActive: Bool?
    
    var displayResponsible: String {
        if let name = responsibleName, !name.isEmpty { return name }
        if let user = responsibleUser {
            return "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespaces)
        }
        return ""
    }
    
    var dueDateFormatted: String {
        let raw = dueDate.prefix(10)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: String(raw)) {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
        return String(raw)
    }
    
    var isOverdue: Bool {
        let raw = String(dueDate.prefix(10))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: raw) else { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }
}

struct LSWFollowUpsResponse: Codable {
    let success: Bool
    let data: [LSWFollowUp]
}

struct LSWFollowUpSingleResponse: Codable {
    let success: Bool
    let data: LSWFollowUp
}

// MARK: - RCA Trigger Models

struct LSWRcaTrigger: Codable, Identifiable {
    let id: String
    let trigger: String
    let eventDate: String?
    let comments: String?
    let sortOrder: Int?
    let isActive: Bool?
    
    var eventDateFormatted: String {
        guard let raw = eventDate?.prefix(10), !raw.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: String(raw)) {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
        return String(raw)
    }
}

struct LSWRcaTriggersResponse: Codable {
    let success: Bool
    let data: [LSWRcaTrigger]
}

struct LSWRcaTriggerSingleResponse: Codable {
    let success: Bool
    let data: LSWRcaTrigger
}

// MARK: - Service

class LSWService: ObservableObject {
    static let shared = LSWService()
    
    private let baseURL = "https://dashmet-rca-api.onrender.com/api"
    
    @Published var dailyTasks: [LSWDailyTask] = []
    @Published var calendarConfig = LSWCalendarConfig(calendarYearStartMonth: 1, calendarYearStartDay: 1)
    @Published var workDaysPerWeek: Int = 5
    @Published var isLoading = false
    @Published var isChangingWeek = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var earlyCompletionLogs: [LSWEarlyCompletionLog] = []
    @Published var projects: [LSWProject] = []
    @Published var isLoadingProjects = false
    @Published var followUps: [LSWFollowUp] = []
    @Published var isLoadingFollowUps = false
    @Published var rcaTriggers: [LSWRcaTrigger] = []
    @Published var isLoadingTriggers = false
    
    // WebSocket sync state
    private var activeWeekNumber: Int?
    private var activeYear: Int?
    private var webSocketConnected = false
    
    // Fetch generation counter — used to discard stale responses during rapid week navigation
    private var fetchGeneration: Int = 0
    
    private init() {}
    
    // MARK: - WebSocket Real-Time Sync
    
    func connectWebSocket() {
        guard !webSocketConnected else { return }
        
        let userId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        let orgId = UserDefaults.standard.string(forKey: "organization_id") ?? ""
        
        guard !userId.isEmpty, !orgId.isEmpty else {
            print("⚠️ [LSW] WebSocket: missing userId or orgId in UserDefaults, skipping connect")
            return
        }
        
        print("🔌 [LSW] Connecting WebSocket for user \(userId.prefix(8))... org \(orgId.prefix(8))...")
        
        SocketIOClient.shared.on("lsw:completion-changed") { [weak self] data in
            guard let self = self,
                  let dict = data as? [String: Any],
                  let week = dict["weekNumber"] as? Int,
                  let year = dict["year"] as? Int else { return }
            
            // Only process if it matches our active week/year
            guard week == self.activeWeekNumber && year == self.activeYear else { return }
            
            // If the event includes task details, apply directly — no API call needed
            if let taskId = dict["taskId"] as? String,
               let day = dict["day"] as? String,
               let value = dict["value"] as? Bool {
                
                Task { @MainActor in
                    // Apply checkbox change directly to local state
                    if let idx = self.dailyTasks.firstIndex(where: { $0.id == taskId }) {
                        let t = self.dailyTasks[idx]
                        self.dailyTasks[idx] = LSWDailyTask(
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
                    
                    // Handle early completion log changes
                    let action = dict["action"] as? String
                    let dayKey = self.dbDayToUIKey(day)
                    
                    if action == "early-complete", let earlyLogDict = dict["earlyLog"] as? [String: Any] {
                        if let logData = try? JSONSerialization.data(withJSONObject: earlyLogDict),
                           let log = try? JSONDecoder().decode(LSWEarlyCompletionLog.self, from: logData),
                           !self.earlyCompletionLogs.contains(where: { $0.id == log.id }) {
                            self.earlyCompletionLogs.insert(log, at: 0)
                        }
                    } else if action == "uncheck" {
                        self.earlyCompletionLogs.removeAll {
                            $0.dailyTaskId == taskId && $0.dayKey == dayKey && $0.weekNumber == week && $0.year == year
                        }
                    }
                }
                return
            }
            
            // Fallback: full re-fetch for legacy events without task details
            Task {
                await self.fetchDailyTasks(weekNumber: week, year: year)
                await self.fetchEarlyCompletionLogs(weekNumber: week, year: year)
            }
        }
        
        SocketIOClient.shared.connect(userId: userId, organizationId: orgId)
        webSocketConnected = true
    }
    
    // MARK: - WebSocket Project Sync
    
    func connectProjectWebSocket() {
        let userId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        let orgId = UserDefaults.standard.string(forKey: "organization_id") ?? ""
        
        guard !userId.isEmpty, !orgId.isEmpty else { return }
        
        SocketIOClient.shared.on("lsw:project-changed") { [weak self] data in
            guard let self = self,
                  let dict = data as? [String: Any],
                  let action = dict["action"] as? String else { return }
            
            Task { @MainActor in
                switch action {
                case "project-created":
                    if let projectDict = dict["project"] as? [String: Any],
                       let projectData = try? JSONSerialization.data(withJSONObject: projectDict),
                       let project = try? JSONDecoder().decode(LSWProject.self, from: projectData) {
                        if !self.projects.contains(where: { $0.id == project.id }) {
                            self.projects.append(project)
                        }
                    }
                    
                case "project-updated":
                    if let projectDict = dict["project"] as? [String: Any],
                       let projectData = try? JSONSerialization.data(withJSONObject: projectDict),
                       let project = try? JSONDecoder().decode(LSWProject.self, from: projectData) {
                        if let idx = self.projects.firstIndex(where: { $0.id == project.id }) {
                            self.projects[idx] = project
                        }
                    }
                    
                case "project-deleted":
                    if let projectId = dict["projectId"] as? String {
                        self.projects.removeAll { $0.id == projectId }
                    }
                    
                case "update-created":
                    if let projectId = dict["projectId"] as? String,
                       let updateDict = dict["update"] as? [String: Any],
                       let updateData = try? JSONSerialization.data(withJSONObject: updateDict),
                       let update = try? JSONDecoder().decode(LSWProjectUpdate.self, from: updateData) {
                        if let idx = self.projects.firstIndex(where: { $0.id == projectId }) {
                            let p = self.projects[idx]
                            var newUpdates = p.updates
                            if !newUpdates.contains(where: { $0.id == update.id }) {
                                newUpdates.append(update)
                            }
                            self.projects[idx] = LSWProject(
                                id: p.id, name: p.name, updates: newUpdates,
                                fontColor: p.fontColor, fontFamily: p.fontFamily,
                                fontBold: p.fontBold, fontItalic: p.fontItalic,
                                cellColor: p.cellColor, cellColorIntensity: p.cellColorIntensity,
                                defaultUpdateFontColor: p.defaultUpdateFontColor,
                                defaultUpdateFontItalic: p.defaultUpdateFontItalic,
                                defaultUpdateCellColor: p.defaultUpdateCellColor,
                                defaultUpdateCellColorIntensity: p.defaultUpdateCellColorIntensity,
                                sortOrder: p.sortOrder, isActive: p.isActive
                            )
                        }
                    }
                    
                case "update-updated":
                    if let updateDict = dict["update"] as? [String: Any],
                       let updateData = try? JSONSerialization.data(withJSONObject: updateDict),
                       let update = try? JSONDecoder().decode(LSWProjectUpdate.self, from: updateData) {
                        for (pIdx, project) in self.projects.enumerated() {
                            if let uIdx = project.updates.firstIndex(where: { $0.id == update.id }) {
                                var newUpdates = project.updates
                                newUpdates[uIdx] = update
                                let p = project
                                self.projects[pIdx] = LSWProject(
                                    id: p.id, name: p.name, updates: newUpdates,
                                    fontColor: p.fontColor, fontFamily: p.fontFamily,
                                    fontBold: p.fontBold, fontItalic: p.fontItalic,
                                    cellColor: p.cellColor, cellColorIntensity: p.cellColorIntensity,
                                    defaultUpdateFontColor: p.defaultUpdateFontColor,
                                    defaultUpdateFontItalic: p.defaultUpdateFontItalic,
                                    defaultUpdateCellColor: p.defaultUpdateCellColor,
                                    defaultUpdateCellColorIntensity: p.defaultUpdateCellColorIntensity,
                                    sortOrder: p.sortOrder, isActive: p.isActive
                                )
                                break
                            }
                        }
                    }
                    
                case "update-deleted":
                    if let updateId = dict["updateId"] as? String {
                        for (pIdx, project) in self.projects.enumerated() {
                            if project.updates.contains(where: { $0.id == updateId }) {
                                var newUpdates = project.updates.filter { $0.id != updateId }
                                let p = project
                                self.projects[pIdx] = LSWProject(
                                    id: p.id, name: p.name, updates: newUpdates,
                                    fontColor: p.fontColor, fontFamily: p.fontFamily,
                                    fontBold: p.fontBold, fontItalic: p.fontItalic,
                                    cellColor: p.cellColor, cellColorIntensity: p.cellColorIntensity,
                                    defaultUpdateFontColor: p.defaultUpdateFontColor,
                                    defaultUpdateFontItalic: p.defaultUpdateFontItalic,
                                    defaultUpdateCellColor: p.defaultUpdateCellColor,
                                    defaultUpdateCellColorIntensity: p.defaultUpdateCellColorIntensity,
                                    sortOrder: p.sortOrder, isActive: p.isActive
                                )
                                break
                            }
                        }
                    }
                    
                default:
                    // Fallback: full re-fetch
                    Task { await self.fetchProjects() }
                }
            }
        }
        
        // Ensure WebSocket is connected
        if !webSocketConnected {
            SocketIOClient.shared.connect(userId: userId, organizationId: orgId)
            webSocketConnected = true
        }
    }
    
    // MARK: - WebSocket Follow-Up Sync
    
    func connectFollowUpWebSocket() {
        let userId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        let orgId = UserDefaults.standard.string(forKey: "organization_id") ?? ""
        
        guard !userId.isEmpty, !orgId.isEmpty else { return }
        
        SocketIOClient.shared.on("lsw:follow-up-changed") { [weak self] data in
            guard let self = self,
                  let dict = data as? [String: Any],
                  let action = dict["action"] as? String else { return }
            
            Task { @MainActor in
                switch action {
                case "follow-up-created":
                    if let fuDict = dict["followUp"] as? [String: Any],
                       let fuData = try? JSONSerialization.data(withJSONObject: fuDict),
                       let followUp = try? JSONDecoder().decode(LSWFollowUp.self, from: fuData) {
                        if !self.followUps.contains(where: { $0.id == followUp.id }) {
                            self.followUps.append(followUp)
                        }
                    }
                    
                case "follow-up-updated":
                    if let fuDict = dict["followUp"] as? [String: Any],
                       let fuData = try? JSONSerialization.data(withJSONObject: fuDict),
                       let followUp = try? JSONDecoder().decode(LSWFollowUp.self, from: fuData) {
                        if let idx = self.followUps.firstIndex(where: { $0.id == followUp.id }) {
                            self.followUps[idx] = followUp
                        }
                    }
                    
                case "follow-up-deleted":
                    if let followUpId = dict["followUpId"] as? String {
                        self.followUps.removeAll { $0.id == followUpId }
                    }
                    
                default:
                    Task { await self.fetchFollowUps() }
                }
            }
        }
        
        // Ensure WebSocket is connected
        if !webSocketConnected {
            SocketIOClient.shared.connect(userId: userId, organizationId: orgId)
            webSocketConnected = true
        }
    }
    
    // MARK: - WebSocket Trigger Sync
    
    func connectTriggerWebSocket() {
        let userId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        let orgId = UserDefaults.standard.string(forKey: "organization_id") ?? ""
        
        guard !userId.isEmpty, !orgId.isEmpty else { return }
        
        SocketIOClient.shared.on("lsw:trigger-changed") { [weak self] data in
            guard let self = self,
                  let dict = data as? [String: Any],
                  let action = dict["action"] as? String else { return }
            
            Task { @MainActor in
                switch action {
                case "trigger-created":
                    if let tDict = dict["trigger"] as? [String: Any],
                       let tData = try? JSONSerialization.data(withJSONObject: tDict),
                       let trigger = try? JSONDecoder().decode(LSWRcaTrigger.self, from: tData) {
                        if !self.rcaTriggers.contains(where: { $0.id == trigger.id }) {
                            self.rcaTriggers.append(trigger)
                        }
                    }
                    
                case "trigger-updated":
                    if let tDict = dict["trigger"] as? [String: Any],
                       let tData = try? JSONSerialization.data(withJSONObject: tDict),
                       let trigger = try? JSONDecoder().decode(LSWRcaTrigger.self, from: tData) {
                        if let idx = self.rcaTriggers.firstIndex(where: { $0.id == trigger.id }) {
                            self.rcaTriggers[idx] = trigger
                        }
                    }
                    
                case "trigger-deleted":
                    if let triggerId = dict["triggerId"] as? String {
                        self.rcaTriggers.removeAll { $0.id == triggerId }
                    }
                    
                default:
                    Task { await self.fetchRcaTriggers() }
                }
            }
        }
        
        // Ensure WebSocket is connected
        if !webSocketConnected {
            SocketIOClient.shared.connect(userId: userId, organizationId: orgId)
            webSocketConnected = true
        }
    }
    
    func disconnectWebSocket() {
        SocketIOClient.shared.removeAllHandlers()
        SocketIOClient.shared.disconnect()
        webSocketConnected = false
    }
    
    func setActiveWeek(weekNumber: Int, year: Int) {
        activeWeekNumber = weekNumber
        activeYear = year
        fetchGeneration += 1  // Invalidate any in-flight fetches
    }
    
    /// Maps backend day names (monday, tuesday, etc.) to frontend/UI keys (M, T, etc.)
    private func dbDayToUIKey(_ day: String) -> String {
        switch day {
        case "monday": return "M"
        case "tuesday": return "T"
        case "wednesday": return "W"
        case "thursday": return "H"
        case "friday": return "F"
        case "saturday": return "S1"
        case "sunday": return "S2"
        default: return day
        }
    }
    
    // MARK: - Auth Helper
    private func authorizedRequest(url: URL, method: String = "GET") async throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let token = try await FirebaseAuthService.shared.getIDToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            print("⚠️ [LSW] Failed to get auth token: \(error.localizedDescription)")
        }
        return request
    }
    
    // MARK: - Fetch Calendar Config & Preferences
    func fetchConfig() async {
        // Use current ISO week/year for config fetch (config itself is org-level)
        let cal = Calendar(identifier: .iso8601)
        let now = Date()
        let wk = cal.component(.weekOfYear, from: now)
        let yr = cal.component(.yearForWeekOfYear, from: now)
        guard let url = URL(string: "\(baseURL)/lsw/data?weekNumber=\(wk)&year=\(yr)") else { return }
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("⚠️ [LSW] fetchConfig: no HTTP response")
                return
            }
            guard httpResponse.statusCode == 200 else {
                print("⚠️ [LSW] fetchConfig: HTTP \(httpResponse.statusCode)")
                if let body = String(data: data, encoding: .utf8) { print("⚠️ [LSW] fetchConfig body: \(body.prefix(300))") }
                return
            }
            let result = try JSONDecoder().decode(LSWDataResponse.self, from: data)
            await MainActor.run {
                if let config = result.data.calendarConfig {
                    self.calendarConfig = config
                }
                if let prefs = result.data.userPreferences {
                    self.workDaysPerWeek = max(5, min(7, prefs.workDaysPerWeek))
                }
            }
            print("✅ [LSW] Config loaded successfully")
        } catch {
            print("❌ [LSW] fetchConfig error: \(error.localizedDescription)")
        }
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
        let myGeneration = fetchGeneration
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        var urlString = "\(baseURL)/lsw/daily-tasks"
        if let wn = weekNumber, let yr = year {
            urlString += "?weekNumber=\(wn)&year=\(yr)"
        }
        print("📋 [LSW] Fetching daily tasks: \(urlString) (gen \(myGeneration))")
        guard let url = URL(string: urlString) else { return }
        
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Discard if user navigated to a different week while this request was in-flight
            guard myGeneration == fetchGeneration else {
                print("📋 [LSW] Discarding stale response for gen \(myGeneration), current gen \(fetchGeneration)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [LSW] No HTTP response for daily tasks")
                await MainActor.run { errorMessage = "No HTTP response"; isLoading = false; isChangingWeek = false }
                return
            }
            
            print("📋 [LSW] Daily tasks HTTP status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("❌ [LSW] Daily tasks failed: HTTP \(httpResponse.statusCode) - \(body.prefix(300))")
                await MainActor.run { errorMessage = "Failed to load tasks (HTTP \(httpResponse.statusCode))"; isLoading = false; isChangingWeek = false }
                return
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(LSWDailyTasksResponse.self, from: data)
            
            let activeTasks = result.data.filter { $0.isActive != false }
            print("✅ [LSW] Loaded \(activeTasks.count) active daily tasks for week \(weekNumber ?? 0) year \(year ?? 0)")
            
            // Log first task's checkbox state for debugging
            if let first = activeTasks.first {
                print("📋 [LSW] First task '\(first.task.prefix(30))' M:\(first.monday) T:\(first.tuesday) W:\(first.wednesday) H:\(first.thursday) F:\(first.friday)")
            }
            
            await MainActor.run {
                self.dailyTasks = activeTasks
                self.isLoading = false
                self.isChangingWeek = false
            }
        } catch {
            guard myGeneration == fetchGeneration else { return }
            print("❌ [LSW] Daily tasks error: \(error.localizedDescription)")
            await MainActor.run { errorMessage = error.localizedDescription; isLoading = false; isChangingWeek = false }
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
    
    // MARK: - Improvement Projects API
    
    func fetchProjects() async {
        await MainActor.run { isLoadingProjects = true }
        guard let url = URL(string: "\(baseURL)/lsw/projects") else {
            await MainActor.run { isLoadingProjects = false }
            return
        }
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { isLoadingProjects = false }
                return
            }
            let result = try JSONDecoder().decode(LSWProjectsResponse.self, from: data)
            await MainActor.run {
                self.projects = result.data
                self.isLoadingProjects = false
            }
        } catch {
            print("❌ [LSW] fetchProjects error: \(error.localizedDescription)")
            await MainActor.run { isLoadingProjects = false }
        }
    }
    
    func createProject(name: String) async -> LSWProject? {
        guard let url = URL(string: "\(baseURL)/lsw/projects") else { return nil }
        let body: [String: Any] = [
            "name": name,
            "initialUpdateText": "",
            "fontColor": "#1f2937",
            "fontFamily": "Inter",
            "fontBold": false,
            "fontItalic": false,
            "cellColor": "#3b82f6",
            "cellColorIntensity": 20,
            "defaultUpdateFontColor": "#4b5563",
            "defaultUpdateFontItalic": false,
            "defaultUpdateCellColor": "#10b981",
            "defaultUpdateCellColorIntensity": 10
        ]
        do {
            var request = try await authorizedRequest(url: url, method: "POST")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else { return nil }
            let result = try JSONDecoder().decode(LSWProjectSingleResponse.self, from: data)
            return result.data
        } catch {
            print("❌ [LSW] createProject error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateProject(id: String, data: [String: Any]) async -> LSWProject? {
        guard let url = URL(string: "\(baseURL)/lsw/projects/\(id)") else { return nil }
        do {
            var request = try await authorizedRequest(url: url, method: "PUT")
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            let result = try JSONDecoder().decode(LSWProjectSingleResponse.self, from: responseData)
            return result.data
        } catch {
            print("❌ [LSW] updateProject error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func deleteProject(id: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/lsw/projects/\(id)") else { return false }
        do {
            let request = try await authorizedRequest(url: url, method: "DELETE")
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return false }
            return true
        } catch {
            print("❌ [LSW] deleteProject error: \(error.localizedDescription)")
            return false
        }
    }
    
    func addProjectUpdate(projectId: String, text: String = "") async -> LSWProjectUpdate? {
        guard let url = URL(string: "\(baseURL)/lsw/projects/\(projectId)/updates") else { return nil }
        // Use project defaults for new update styling
        let project = await MainActor.run { projects.first { $0.id == projectId } }
        var body: [String: Any] = ["text": text]
        if let fc = project?.defaultUpdateFontColor { body["fontColor"] = fc }
        if let fi = project?.defaultUpdateFontItalic { body["fontItalic"] = fi }
        if let cc = project?.defaultUpdateCellColor { body["cellColor"] = cc }
        if let ci = project?.defaultUpdateCellColorIntensity { body["cellColorIntensity"] = ci }
        do {
            var request = try await authorizedRequest(url: url, method: "POST")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else { return nil }
            let result = try JSONDecoder().decode(LSWProjectUpdateSingleResponse.self, from: data)
            return result.data
        } catch {
            print("❌ [LSW] addProjectUpdate error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateProjectUpdate(updateId: String, data: [String: Any]) async -> LSWProjectUpdate? {
        guard let url = URL(string: "\(baseURL)/lsw/project-updates/\(updateId)") else { return nil }
        do {
            var request = try await authorizedRequest(url: url, method: "PUT")
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            let result = try JSONDecoder().decode(LSWProjectUpdateSingleResponse.self, from: responseData)
            return result.data
        } catch {
            print("❌ [LSW] updateProjectUpdate error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func deleteProjectUpdate(updateId: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/lsw/project-updates/\(updateId)") else { return false }
        do {
            let request = try await authorizedRequest(url: url, method: "DELETE")
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return false }
            return true
        } catch {
            print("❌ [LSW] deleteProjectUpdate error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Follow-Ups API
    
    func fetchFollowUps() async {
        await MainActor.run { isLoadingFollowUps = true }
        guard let url = URL(string: "\(baseURL)/lsw/follow-ups") else {
            await MainActor.run { isLoadingFollowUps = false }
            return
        }
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { isLoadingFollowUps = false }
                return
            }
            let result = try JSONDecoder().decode(LSWFollowUpsResponse.self, from: data)
            await MainActor.run {
                self.followUps = result.data
                self.isLoadingFollowUps = false
            }
        } catch {
            print("❌ [LSW] fetchFollowUps error: \(error.localizedDescription)")
            await MainActor.run { isLoadingFollowUps = false }
        }
    }
    
    func createFollowUp(task: String, dueDate: String, responsibleName: String, comments: String) async -> LSWFollowUp? {
        guard let url = URL(string: "\(baseURL)/lsw/follow-ups") else { return nil }
        let body: [String: Any] = [
            "task": task,
            "dueDate": dueDate,
            "responsibleName": responsibleName,
            "comments": comments
        ]
        do {
            var request = try await authorizedRequest(url: url, method: "POST")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else { return nil }
            let result = try JSONDecoder().decode(LSWFollowUpSingleResponse.self, from: data)
            return result.data
        } catch {
            print("❌ [LSW] createFollowUp error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateFollowUp(id: String, data: [String: Any]) async -> LSWFollowUp? {
        guard let url = URL(string: "\(baseURL)/lsw/follow-ups/\(id)") else { return nil }
        do {
            var request = try await authorizedRequest(url: url, method: "PUT")
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            let result = try JSONDecoder().decode(LSWFollowUpSingleResponse.self, from: responseData)
            return result.data
        } catch {
            print("❌ [LSW] updateFollowUp error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func deleteFollowUp(id: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/lsw/follow-ups/\(id)") else { return false }
        do {
            let request = try await authorizedRequest(url: url, method: "DELETE")
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return false }
            return true
        } catch {
            print("❌ [LSW] deleteFollowUp error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - RCA Triggers API
    
    func fetchRcaTriggers() async {
        await MainActor.run { isLoadingTriggers = true }
        guard let url = URL(string: "\(baseURL)/lsw/rca-triggers") else {
            await MainActor.run { isLoadingTriggers = false }
            return
        }
        do {
            let request = try await authorizedRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { isLoadingTriggers = false }
                return
            }
            let result = try JSONDecoder().decode(LSWRcaTriggersResponse.self, from: data)
            await MainActor.run {
                self.rcaTriggers = result.data
                self.isLoadingTriggers = false
            }
        } catch {
            print("❌ [LSW] fetchRcaTriggers error: \(error.localizedDescription)")
            await MainActor.run { isLoadingTriggers = false }
        }
    }
    
    func createRcaTrigger(trigger: String, eventDate: String?, comments: String?) async -> LSWRcaTrigger? {
        guard let url = URL(string: "\(baseURL)/lsw/rca-triggers") else { return nil }
        var body: [String: Any] = ["trigger": trigger]
        if let eventDate = eventDate, !eventDate.isEmpty { body["eventDate"] = eventDate }
        if let comments = comments, !comments.isEmpty { body["comments"] = comments }
        do {
            var request = try await authorizedRequest(url: url, method: "POST")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...201).contains(httpResponse.statusCode) else { return nil }
            let result = try JSONDecoder().decode(LSWRcaTriggerSingleResponse.self, from: data)
            return result.data
        } catch {
            print("❌ [LSW] createRcaTrigger error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateRcaTrigger(id: String, data: [String: Any]) async -> LSWRcaTrigger? {
        guard let url = URL(string: "\(baseURL)/lsw/rca-triggers/\(id)") else { return nil }
        do {
            var request = try await authorizedRequest(url: url, method: "PUT")
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            let result = try JSONDecoder().decode(LSWRcaTriggerSingleResponse.self, from: responseData)
            return result.data
        } catch {
            print("❌ [LSW] updateRcaTrigger error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func deleteRcaTrigger(id: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/lsw/rca-triggers/\(id)") else { return false }
        do {
            let request = try await authorizedRequest(url: url, method: "DELETE")
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return false }
            return true
        } catch {
            print("❌ [LSW] deleteRcaTrigger error: \(error.localizedDescription)")
            return false
        }
    }
}
