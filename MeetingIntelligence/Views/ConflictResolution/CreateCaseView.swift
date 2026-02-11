//
//  CreateCaseView.swift
//  MeetingIntelligence
//
//  Step 2: Create New Conflict Case
//

import SwiftUI

struct CreateCaseView: View {
    @StateObject private var manager = ConflictResolutionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Form State
    @State private var selectedCaseType: CaseType = .conflict
    @State private var incidentDate = Date()
    @State private var location = ""
    @State private var department = ""
    @State private var shift = ""
    
    // Employees
    @State private var employees: [InvolvedEmployee] = []
    @State private var showAddEmployee = false
    @State private var newEmployeeName = ""
    @State private var newEmployeeRole = ""
    @State private var newEmployeeDepartment = ""
    @State private var newEmployeeIsComplainant = true
    
    // Validation
    @State private var showValidationError = false
    @State private var validationMessage = ""
    
    // Adaptive colors
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var textTertiary: Color {
        colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
    
    private var inputBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Case Type Selection
                        caseTypeSection
                        
                        // Incident Details
                        incidentDetailsSection
                        
                        // Involved Employees
                        employeesSection
                        
                        // Active Policy Notice
                        if manager.activePolicy != nil {
                            activePolicyNotice
                        } else {
                            noPolicyWarning
                        }
                        
                        // Create Button
                        createButton
                    }
                    .padding()
                }
            }
            .navigationTitle("New Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }
            }
            .sheet(isPresented: $showAddEmployee) {
                addEmployeeSheet
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.warning.opacity(0.15))
                    .frame(width: 72, height: 72)
                
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.warning)
            }
            
            Text("Create New Case")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(textPrimary)
            
            Text("Start a new conflict resolution case with System-assisted analysis")
                .font(.system(size: 14))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Case Type Section
    private var caseTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CASE TYPE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textTertiary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CaseType.allCases) { type in
                    CaseTypeCard(
                        type: type,
                        isSelected: selectedCaseType == type,
                        colorScheme: colorScheme
                    ) {
                        selectedCaseType = type
                    }
                }
            }
        }
    }
    
    // MARK: - Incident Details Section
    private var incidentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("INCIDENT DETAILS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textTertiary)
            
            // Date of Incident
            VStack(alignment: .leading, spacing: 8) {
                Text("Date of Incident")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(textSecondary)
                    
                    DatePicker("", selection: $incidentDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(AppColors.primary)
                }
                .padding(14)
                .background(inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cardBorder, lineWidth: 1)
                )
            }
            
            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
                
                TextField("e.g., Building A, Floor 2", text: $location)
                    .textFieldStyle(CustomTextFieldStyle(colorScheme: colorScheme))
            }
            
            // Department & Shift
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Department")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textSecondary)
                    
                    TextField("e.g., Sales", text: $department)
                        .textFieldStyle(CustomTextFieldStyle(colorScheme: colorScheme))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shift (Optional)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textSecondary)
                    
                    TextField("e.g., Day", text: $shift)
                        .textFieldStyle(CustomTextFieldStyle(colorScheme: colorScheme))
                }
            }
        }
    }
    
    // MARK: - Employees Section
    private var employeesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INVOLVED EMPLOYEES")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textTertiary)
                
                Spacer()
                
                Button {
                    showAddEmployee = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            
            if employees.isEmpty {
                emptyEmployeesState
            } else {
                ForEach(employees) { employee in
                    EmployeeRowView(
                        employee: employee,
                        colorScheme: colorScheme,
                        onDelete: {
                            employees.removeAll { $0.id == employee.id }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Empty Employees State
    private var emptyEmployeesState: some View {
        Button {
            showAddEmployee = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "person.2.badge.gearshape")
                    .font(.system(size: 28))
                    .foregroundColor(textTertiary)
                
                Text("Add Involved Employees")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
                
                Text("Tap to add employees involved in the incident")
                    .font(.system(size: 12))
                    .foregroundColor(textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundColor(cardBorder)
            )
        }
    }
    
    // MARK: - Active Policy Notice
    private var activePolicyNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 20))
                .foregroundColor(AppColors.success)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Active Policy Available")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textPrimary)
                
                Text(manager.activePolicy?.name ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(AppColors.success.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - No Policy Warning
    private var noPolicyWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppColors.warning)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("No Active Policy")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textPrimary)
                
                Text("Upload a policy to enable System-powered analysis")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(AppColors.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Create Button
    private var createButton: some View {
        Button {
            createCase()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 18))
                Text("Create Case")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isFormValid ? AppColors.primary : AppColors.primary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isFormValid)
        .padding(.top, 8)
    }
    
    // MARK: - Add Employee Sheet
    private var addEmployeeSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Role Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ROLE")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textTertiary)
                        
                        HStack(spacing: 12) {
                            RoleToggleButton(
                                title: "Complainant",
                                icon: "person.fill",
                                isSelected: newEmployeeIsComplainant,
                                colorScheme: colorScheme
                            ) {
                                newEmployeeIsComplainant = true
                            }
                            
                            RoleToggleButton(
                                title: "Witness",
                                icon: "eye.fill",
                                isSelected: !newEmployeeIsComplainant,
                                colorScheme: colorScheme
                            ) {
                                newEmployeeIsComplainant = false
                            }
                        }
                    }
                    
                    // Employee Details
                    VStack(alignment: .leading, spacing: 20) {
                        Text("EMPLOYEE DETAILS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textTertiary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textSecondary)
                            
                            TextField("Full name", text: $newEmployeeName)
                                .textFieldStyle(CustomTextFieldStyle(colorScheme: colorScheme))
                        }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Role/Position")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(textSecondary)
                                
                                TextField("e.g., Manager", text: $newEmployeeRole)
                                    .textFieldStyle(CustomTextFieldStyle(colorScheme: colorScheme))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Department")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(textSecondary)
                                
                                TextField("e.g., Sales", text: $newEmployeeDepartment)
                                    .textFieldStyle(CustomTextFieldStyle(colorScheme: colorScheme))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Add Button
                    Button {
                        addEmployee()
                    } label: {
                        Text("Add Employee")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(newEmployeeName.isEmpty ? AppColors.primary.opacity(0.5) : AppColors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(newEmployeeName.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Add Employee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        resetEmployeeForm()
                        showAddEmployee = false
                    }
                    .foregroundColor(textSecondary)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private var isFormValid: Bool {
        !location.trimmingCharacters(in: .whitespaces).isEmpty &&
        !department.trimmingCharacters(in: .whitespaces).isEmpty &&
        employees.count >= 2
    }
    
    private func addEmployee() {
        let employee = InvolvedEmployee(
            name: newEmployeeName,
            role: newEmployeeRole,
            department: newEmployeeDepartment,
            isComplainant: newEmployeeIsComplainant
        )
        employees.append(employee)
        resetEmployeeForm()
        showAddEmployee = false
    }
    
    private func resetEmployeeForm() {
        newEmployeeName = ""
        newEmployeeRole = ""
        newEmployeeDepartment = ""
        newEmployeeIsComplainant = true
    }
    
    private func createCase() {
        // Validate
        if employees.filter({ $0.isComplainant }).count < 2 {
            validationMessage = "Please add at least two complainants involved in the conflict."
            showValidationError = true
            return
        }
        
        // Create case
        let newCase = manager.createCase(
            type: selectedCaseType,
            incidentDate: incidentDate,
            location: location,
            department: department,
            shift: shift.isEmpty ? nil : shift,
            involvedEmployees: employees
        )
        
        // Navigate to case detail or close
        dismiss()
    }
}

// MARK: - Case Type Card
struct CaseTypeCard: View {
    let type: CaseType
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : type.color)
                
                Text(type.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? type.color : cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : type.color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Employee Row View
struct EmployeeRowView: View {
    let employee: InvolvedEmployee
    let colorScheme: ColorScheme
    let onDelete: () -> Void
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var textSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(employee.isComplainant ? AppColors.warning.opacity(0.15) : AppColors.info.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Text(employee.name.prefix(1).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(employee.isComplainant ? AppColors.warning : AppColors.info)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(employee.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(textPrimary)
                
                HStack(spacing: 6) {
                    Text(employee.isComplainant ? "Complainant" : "Witness")
                        .font(.system(size: 12))
                        .foregroundColor(employee.isComplainant ? AppColors.warning : AppColors.info)
                    
                    if !employee.role.isEmpty {
                        Text("•")
                            .foregroundColor(textSecondary)
                        Text(employee.role)
                            .font(.system(size: 12))
                            .foregroundColor(textSecondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(textSecondary)
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Role Toggle Button
struct RoleToggleButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    private var textPrimary: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? AppColors.primary : cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Preview
#Preview {
    CreateCaseView()
}
