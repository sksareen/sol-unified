//
//  PeopleModels.swift
//  SolUnified
//
//  Models for the People CRM feature
//

import Foundation
import SwiftUI

// MARK: - Person Model

struct Person: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var oneLiner: String?
    var notes: String?
    var location: String?
    var currentCity: String?
    var email: String?
    var phone: String?
    var linkedin: String?
    var boardPriority: String?
    let createdAt: Date
    var updatedAt: Date

    // Loaded relationships (not stored directly in people table)
    var tags: [String] = []
    var organizations: [PersonOrganization] = []
    var connections: [PersonConnection] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        oneLiner: String? = nil,
        notes: String? = nil,
        location: String? = nil,
        currentCity: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        linkedin: String? = nil,
        boardPriority: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.oneLiner = oneLiner
        self.notes = notes
        self.location = location
        self.currentCity = currentCity
        self.email = email
        self.phone = phone
        self.linkedin = linkedin
        self.boardPriority = boardPriority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Hashable conformance excluding loaded relationships
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Person, rhs: Person) -> Bool {
        lhs.id == rhs.id
    }

    // Coding keys for JSON encoding/decoding
    enum CodingKeys: String, CodingKey {
        case id, name, oneLiner, notes, location, currentCity
        case email, phone, linkedin, boardPriority, createdAt, updatedAt
    }
}

// MARK: - Organization Model

struct Organization: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var type: OrganizationType
    var industry: String?
    var location: String?
    var website: String?
    var description: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        type: OrganizationType,
        industry: String? = nil,
        location: String? = nil,
        website: String? = nil,
        description: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.industry = industry
        self.location = location
        self.website = website
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum OrganizationType: String, Codable, CaseIterable {
    case company
    case school
    case community
    case other

    var displayName: String {
        switch self {
        case .company: return "Company"
        case .school: return "School"
        case .community: return "Community"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .company: return "building.2"
        case .school: return "graduationcap"
        case .community: return "person.3"
        case .other: return "building"
        }
    }

    var color: Color {
        switch self {
        case .company: return Color(hex: "FFA07A") // Salmon
        case .school: return Color(hex: "98D8C8") // Mint
        case .community: return Color(hex: "87CEEB") // Sky blue
        case .other: return Color.gray
        }
    }
}

// MARK: - Person-Organization Relationship

struct PersonOrganization: Identifiable, Codable, Hashable {
    let id: String
    let personId: String
    let organizationId: String
    var role: String?
    var degreeType: String?
    var startDate: String?
    var endDate: String?
    var graduationYear: String?
    var isCurrent: Bool

    // Loaded for display
    var organization: Organization?

    init(
        id: String = UUID().uuidString,
        personId: String,
        organizationId: String,
        role: String? = nil,
        degreeType: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        graduationYear: String? = nil,
        isCurrent: Bool = true
    ) {
        self.id = id
        self.personId = personId
        self.organizationId = organizationId
        self.role = role
        self.degreeType = degreeType
        self.startDate = startDate
        self.endDate = endDate
        self.graduationYear = graduationYear
        self.isCurrent = isCurrent
    }

    // Hashable - exclude loaded organization
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PersonOrganization, rhs: PersonOrganization) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id, personId, organizationId, role, degreeType
        case startDate, endDate, graduationYear, isCurrent
    }
}

// MARK: - Connection Model

struct PersonConnection: Identifiable, Codable, Hashable {
    let id: String
    let personAId: String
    let personBId: String
    var context: String?
    var connectionType: ConnectionType
    var strength: Int
    let createdAt: Date

    // Loaded for display - the other person in the connection
    var connectedPerson: Person?

    init(
        id: String = UUID().uuidString,
        personAId: String,
        personBId: String,
        context: String? = nil,
        connectionType: ConnectionType = .known,
        strength: Int = 1,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.personAId = personAId
        self.personBId = personBId
        self.context = context
        self.connectionType = connectionType
        self.strength = strength
        self.createdAt = createdAt
    }

    // Hashable - exclude loaded person
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PersonConnection, rhs: PersonConnection) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id, personAId, personBId, context, connectionType, strength, createdAt
    }
}

enum ConnectionType: String, Codable, CaseIterable {
    case known
    case friend
    case colleague
    case family
    case mentor
    case introduced

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .known: return .gray
        case .friend: return .green
        case .colleague: return .blue
        case .family: return .red
        case .mentor: return .purple
        case .introduced: return .orange
        }
    }
}

// MARK: - Network Event Model

struct NetworkEvent: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var location: String?
    var startDate: String?
    var endDate: String?
    var description: String?
    let createdAt: Date
    var updatedAt: Date

    // Loaded relationships
    var attendees: [EventAttendee] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        location: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        description: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: NetworkEvent, rhs: NetworkEvent) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id, name, location, startDate, endDate, description, createdAt, updatedAt
    }
}

struct EventAttendee: Identifiable, Codable, Hashable {
    var id: String { "\(eventId)-\(personId)" }
    let eventId: String
    let personId: String
    var role: String?
    var notes: String?

    // Loaded for display
    var person: Person?

    init(eventId: String, personId: String, role: String? = nil, notes: String? = nil) {
        self.eventId = eventId
        self.personId = personId
        self.role = role
        self.notes = notes
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(eventId)
        hasher.combine(personId)
    }

    static func == (lhs: EventAttendee, rhs: EventAttendee) -> Bool {
        lhs.eventId == rhs.eventId && lhs.personId == rhs.personId
    }

    enum CodingKeys: String, CodingKey {
        case eventId, personId, role, notes
    }
}

// MARK: - Graph Visualization Models

struct PersonGraphNode: Identifiable {
    let id: String
    let person: Person
    var position: CGPoint
    var velocity: CGPoint = .zero
    var isFixed: Bool = false
    var isSelected: Bool = false

    var radius: CGFloat {
        // Size based on connection count
        let baseSize: CGFloat = 20
        let connectionBonus = CGFloat(person.connections.count) * 2
        return min(baseSize + connectionBonus, 50)
    }

    var color: Color {
        if person.boardPriority == "TRUE" || person.boardPriority == "true" {
            return .orange
        } else if !person.connections.isEmpty {
            return Color.brutalistAccent.opacity(0.8)
        }
        return Color.brutalistTextSecondary.opacity(0.6)
    }
}

struct PersonGraphEdge: Identifiable {
    let id: String
    let connection: PersonConnection
    let sourceId: String
    let targetId: String

    var color: Color {
        connection.connectionType.color.opacity(0.4)
    }
}

// MARK: - View Mode

enum PeopleViewMode: String, CaseIterable {
    case list
    case graph

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .graph: return "chart.dots.scatter"
        }
    }
}

// MARK: - Grouping Options

enum PeopleGroupBy: String, CaseIterable {
    case alphabetical = "A-Z"
    case company = "Company"
    case tag = "Tag"
    case recent = "Recent"
}
