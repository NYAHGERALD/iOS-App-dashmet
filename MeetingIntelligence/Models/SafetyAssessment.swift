import Foundation

// MARK: - Safety Assessment Models

enum WSAStatus: String, Codable {
    case draft = "DRAFT"
    case submitted = "SUBMITTED"
    case completed = "COMPLETED"
}

enum ItemAssessmentStatus: String, Codable {
    case acceptable = "A"
    case unacceptable = "U"
    case notApplicable = "NA"
}

struct SafetyAssessment: Codable, Identifiable {
    let id: String
    let assessmentNumber: String
    let version: String
    let date: String
    let department: String?
    let departmentId: String?
    let teamLeaderName: String
    let teamLeaderSignature: String?
    let employeeName: String?
    let employeeSignature: String?
    let operationManagerName: String?
    let operationManagerSignature: String?
    let plantManagerName: String?
    let plantManagerSignature: String?
    let safetyManagerName: String?
    let safetyManagerSignature: String?
    let status: WSAStatus
    let organizationId: String
    let facilityId: String?
    let createdById: String
    let createdAt: String?
    let updatedAt: String?
    let submittedAt: String?
    let completedAt: String?
    
    // Relations
    let Department: DepartmentInfo?
    let Facility: FacilityBasicInfo?
    let CreatedBy: UserBasicProfile?
    let Sections: [WSASection]?
    let Photos: [WSAPhoto]?
    
    // Count helper
    let _count: AssessmentCounts?
    
    enum CodingKeys: String, CodingKey {
        case id, assessmentNumber, version, date, department, departmentId
        case teamLeaderName, teamLeaderSignature, employeeName, employeeSignature
        case operationManagerName, operationManagerSignature
        case plantManagerName, plantManagerSignature
        case safetyManagerName, safetyManagerSignature
        case status, organizationId, facilityId, createdById
        case createdAt, updatedAt, submittedAt, completedAt
        case Department, Facility, CreatedBy, Sections, Photos
        case _count
    }
}

struct AssessmentCounts: Codable {
    let Sections: Int?
    let Photos: Int?
}

struct UserBasicProfile: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String?
}

struct WSASection: Codable, Identifiable {
    let id: String
    let assessmentId: String?
    let sectionId: String
    let title: String
    let sortOrder: Int
    let Items: [WSAItem]?
    
    enum CodingKeys: String, CodingKey {
        case id, assessmentId, sectionId, title, sortOrder, Items
    }
}

struct WSAItem: Codable, Identifiable {
    let id: String
    let sectionId: String?
    let itemId: String
    let description: String
    var status: String?
    var deficiency: String?
    var correctiveAction: String?
    var dynamicEntries: [DynamicEntry]?
    var workOrderPlaced: Bool?
    var reportedViaSafetyApp: Bool?
    var safetyAppReportDate: String?
    var workOrderDateCreated: String?
    var workOrderAssignedTo: String?
    var workOrderAttachment: WorkOrderAttachmentData?
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id, sectionId, itemId, description, status, deficiency, correctiveAction
        case dynamicEntries, workOrderPlaced, reportedViaSafetyApp
        case safetyAppReportDate, workOrderDateCreated, workOrderAssignedTo
        case workOrderAttachment, sortOrder
    }
}

struct DynamicEntry: Codable, Identifiable {
    let id: String
    var employeeName: String?
    var equipmentName: String?
}

struct WorkOrderAttachmentData: Codable {
    let id: String
    let name: String
    let fileUrl: String?
}

struct WSAPhoto: Codable, Identifiable {
    let id: String
    let assessmentId: String
    let itemId: String?
    let sectionId: String?
    let fileName: String
    let fileUrl: String
    let fileSize: Int?
    let mimeType: String?
    let caption: String?
    let uploadedAt: String?
}

// MARK: - API Response Types

struct SafetyAssessmentsResponse: Codable {
    let success: Bool
    let data: AssessmentsData
}

struct AssessmentsData: Codable {
    let assessments: [SafetyAssessment]
}

struct SafetyAssessmentResponse: Codable {
    let success: Bool
    let data: AssessmentDetailData
    let message: String?
    let isUpdate: Bool?
}

struct AssessmentDetailData: Codable {
    let assessment: SafetyAssessment
    let completionStats: CompletionStats?
}

struct CompletionStats: Codable {
    let totalItems: Int
    let completedItems: Int
    let pendingItems: Int
    let completionPercentage: Int
    let incompleteSections: [IncompleteSectionInfo]?
    let unacceptableCount: Int
}

struct IncompleteSectionInfo: Codable {
    let id: String
    let title: String
    let totalItems: Int
    let completedItems: Int
    let pendingItemIds: [String]?
}

// MARK: - Request Types

struct SaveAssessmentRequest: Codable {
    let assessmentNumber: String
    let version: String
    let date: String
    let departmentId: String?
    let teamLeaderName: String
    let employeeName: String?
    let teamLeaderSignature: String?
    let employeeSignature: String?
    let sections: [SectionPayload]
}

struct SectionPayload: Codable {
    let id: String
    let title: String
    let items: [ItemPayload]
}

struct ItemPayload: Codable {
    let id: String
    let description: String
    let status: String?
    let deficiency: String?
    let correctiveAction: String?
    let dynamicEntries: [DynamicEntry]?
    let workOrderPlaced: Bool?
    let reportedViaSafetyApp: Bool?
    let safetyAppReportDate: String?
    let workOrderDateCreated: String?
    let workOrderAssignedTo: String?
    let workOrderAttachment: WorkOrderAttachmentData?
}

// MARK: - Local Assessment Template

struct AssessmentTemplate {
    
    struct Section: Identifiable {
        let id: String
        let title: String
        let iconName: String // SF Symbol name
        var items: [Item]
    }
    
    struct Item: Identifiable {
        let id: String
        let description: String
        var status: ItemAssessmentStatus?
        var deficiency: String
        var correctiveAction: String
        var dynamicEntries: [DynamicEntry]?
        var workOrderPlaced: Bool
        var reportedViaSafetyApp: Bool
        var safetyAppReportDate: String?
        var workOrderDateCreated: String?
        var workOrderAssignedTo: String?
    }
    
    static func defaultSections() -> [Section] {
        return [
            Section(
                id: "ppe",
                title: "PPE (Personal Protective Equipment)",
                iconName: "shield.checkered",
                items: [
                    Item(id: "ppe-1", description: "Conduct PPE audit of all employees - verify proper PPE is worn for each job and is in good condition, including footwear. Outer most clothing layer must be over chemical boots.", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "ppe-2", description: "Verify proper PPE is being worn during chemical usage and verify with label / SDS", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                ]
            ),
            Section(
                id: "lockout",
                title: "LOCKOUT",
                iconName: "lock.fill",
                items: [
                    Item(id: "lockout-1", description: "Verify all authorized employees have lockout devices on their person", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "lockout-2", description: "Verify all authorized operators have their name or unique identifier on their lockout locks", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "lockout-3", description: "Verify that employees are not reaching into equipment without proper lockout procedures being completed during setup, tear down, or changeovers", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "lockout-4", description: "Verify all lockout disconnects are labeled with name of equipment they service", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "lockout-5", description: "Verify the proper lockout of equipment by an employee", status: nil, deficiency: "", correctiveAction: "", dynamicEntries: [DynamicEntry(id: "entry-1", employeeName: "", equipmentName: "")], workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "lockout-6", description: "Verify safety switches for alternative lockout procedures are being checked and documented", status: nil, deficiency: "", correctiveAction: "", dynamicEntries: [DynamicEntry(id: "entry-1", equipmentName: "")], workOrderPlaced: false, reportedViaSafetyApp: false),
                ]
            ),
            Section(
                id: "machine-guarding",
                title: "MACHINE GUARDING",
                iconName: "gearshape.fill",
                items: [
                    Item(id: "mg-1", description: "Rotating Motion - shafts, pulleys etc. are fully guarded and secured properly", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "mg-2", description: "Fan guard openings do not exceed 1/4 inch anywhere on fan guard", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "mg-3", description: "Shafts do not extend out greater than 1/2 their diameter, are smooth, with no extended set screws or open keyways", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "mg-4", description: "Traverse Motion - belts, sprockets, pulleys, drums, chains", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "mg-5", description: "Reciprocating Motion - Back and forth, up and down", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "mg-6", description: "Cutting and Shearing Action - Knives, blades, sealing", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "mg-7", description: "Verify all safety switches work on at least one piece of equipment", status: nil, deficiency: "", correctiveAction: "", dynamicEntries: [DynamicEntry(id: "entry-1", equipmentName: "")], workOrderPlaced: false, reportedViaSafetyApp: false),
                ]
            ),
            Section(
                id: "electrical",
                title: "ELECTRICAL",
                iconName: "bolt.fill",
                items: [
                    Item(id: "elec-1", description: "Verify cord insulation and conduits are in good repair and grounding prong is intact", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "elec-2", description: "Verify no power strips are in use, or extension cords as permanent wiring in production areas", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "elec-3", description: "Verify electrical/welding outlet cover plates are in place and in good repair", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "elec-4", description: "Verify electrical panel access is not blocked (ie. pallets, carts)", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                ]
            ),
            Section(
                id: "material-handling",
                title: "Powered Material Handling Equipment",
                iconName: "car.fill",
                items: [
                    Item(id: "mh-1", description: "Verify only authorized employees are operating equipment and wearing seatbelts if applicable", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "mh-2", description: "Operators drive in reverse when load blocks vision", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "mh-3", description: "Operators use horns at intersections or at blind corners", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "mh-4", description: "Operators drive at safe speeds based on environment and facing the direction of travel", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "mh-5", description: "Verify pre-shift inspection sheets are completed prior to use and drivers qualification is current", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "mh-6", description: "Ensure backup horn and lights work if equipped", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "mh-7", description: "Verify all observation mirrors are clean", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                ]
            ),
            Section(
                id: "fall-protection",
                title: "FALL PROTECTION",
                iconName: "figure.fall",
                items: [
                    Item(id: "fp-1", description: "Platforms over 4 foot in height, or where imminent danger of falling is present, have top rail, mid rail, toe board, and swing gate", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "fp-2", description: "Stairs with 4 or more risers have standard railings, includes top tread on platform", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "fp-3", description: "Fixed ladders over 20 feet above a lower level are equipped with a personal fall arrest system, ladder safety system, cage, or well", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                ]
            ),
            Section(
                id: "labeling",
                title: "LABELING",
                iconName: "tag.fill",
                items: [
                    Item(id: "lbl-1", description: "Secondary chemical containers have required GHS labels and are legible", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "lbl-2", description: "Confined spaces are clearly labeled", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "lbl-3", description: "Overhead pipelines are identified with contents", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "lbl-4", description: "Exits labeled with EXIT sign", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                ]
            ),
            Section(
                id: "housekeeping",
                title: "HOUSEKEEPING",
                iconName: "sparkles",
                items: [
                    Item(id: "hk-1", description: "Floors and walkways free of slip and trip hazards - i.e. meat, ice, etc.", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "hk-2", description: "Fixed and portable ladders are in good condition and secured. 6 month inspection is complete", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "hk-3", description: "All chemical containers are secured to prevent unauthorized use", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "hk-4", description: "All lighting in working order and in good repair", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "hk-5", description: "Walkways that are used as exit routes are free of obstructions with a minimum of 28\" of clearance (boxes, pallets, forklifts, etc)", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "hk-6", description: "Eyewash/Showers unobstructed and weekly inspections completed", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "hk-7", description: "Fire extinguishers mounted, inspections up to date, and monthly/yearly tags attached", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                    Item(id: "hk-8", description: "Pallets stored flat and less than 6 feet in height", status: nil, deficiency: "", correctiveAction: "", workOrderPlaced: false, reportedViaSafetyApp: false),
                ]
            ),
            Section(
                id: "emergency-action",
                title: "EMERGENCY ACTION PLAN",
                iconName: "exclamationmark.triangle.fill",
                items: [
                    Item(id: "eap-1", description: "Verify at least two employees know their evacuation routes, central meeting areas, and inclement weather shelters", status: nil, deficiency: "", correctiveAction: "", dynamicEntries: [DynamicEntry(id: "entry-1", employeeName: ""), DynamicEntry(id: "entry-2", employeeName: "")], workOrderPlaced: false, reportedViaSafetyApp: false),
                ]
            ),
        ]
    }
}
