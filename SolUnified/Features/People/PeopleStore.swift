//
//  PeopleStore.swift
//  SolUnified
//
//  Data store for People CRM - CRUD operations and relationship queries
//

import Foundation
import Combine

class PeopleStore: ObservableObject {
    static let shared = PeopleStore()

    @Published var people: [Person] = []
    @Published var organizations: [Organization] = []
    @Published var events: [NetworkEvent] = []
    @Published var allTags: [String] = []
    @Published var isLoading = false

    private let db = Database.shared

    private init() {
        loadAll()
    }

    // MARK: - Load All Data

    func loadAll() {
        isLoading = true
        loadPeople()
        loadOrganizations()
        loadEvents()
        loadAllTags()
        isLoading = false
    }

    // MARK: - People CRUD

    func loadPeople() {
        let results = db.query("SELECT * FROM people ORDER BY name ASC")
        var loadedPeople = results.compactMap { personFromRow($0) }

        // Load relationships for each person
        for i in 0..<loadedPeople.count {
            loadedPeople[i].tags = loadTags(forPersonId: loadedPeople[i].id)
            loadedPeople[i].organizations = loadPersonOrganizations(forPersonId: loadedPeople[i].id)
            loadedPeople[i].connections = loadConnections(forPersonId: loadedPeople[i].id)
        }

        DispatchQueue.main.async { [weak self] in
            self?.people = loadedPeople
        }
    }

    @discardableResult
    func savePerson(_ person: Person) -> Bool {
        let sql = """
            INSERT OR REPLACE INTO people
            (id, name, one_liner, notes, location, current_city, email, phone, linkedin, board_priority, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        let success = db.execute(sql, parameters: [
            person.id,
            person.name,
            person.oneLiner ?? NSNull(),
            person.notes ?? NSNull(),
            person.location ?? NSNull(),
            person.currentCity ?? NSNull(),
            person.email ?? NSNull(),
            person.phone ?? NSNull(),
            person.linkedin ?? NSNull(),
            person.boardPriority ?? NSNull(),
            Database.dateToString(person.createdAt),
            Database.dateToString(person.updatedAt)
        ])

        if success {
            // Update tags - remove old, add new
            _ = db.execute("DELETE FROM person_tags WHERE person_id = ?", parameters: [person.id])
            for tag in person.tags {
                _ = db.execute("INSERT OR IGNORE INTO person_tags (person_id, tag) VALUES (?, ?)",
                              parameters: [person.id, tag])
            }
            loadPeople()
            loadAllTags()
        }
        return success
    }

    @discardableResult
    func deletePerson(id: String) -> Bool {
        // Cascading deletes handled by FK constraints
        let success = db.execute("DELETE FROM people WHERE id = ?", parameters: [id])
        if success {
            loadPeople()
        }
        return success
    }

    func getPerson(id: String) -> Person? {
        people.first { $0.id == id }
    }

    func getPersonByName(_ name: String) -> Person? {
        people.first { $0.name.lowercased() == name.lowercased() }
    }

    // MARK: - Organizations CRUD

    func loadOrganizations() {
        let results = db.query("SELECT * FROM organizations ORDER BY name ASC")
        let orgs = results.compactMap { organizationFromRow($0) }
        DispatchQueue.main.async { [weak self] in
            self?.organizations = orgs
        }
    }

    @discardableResult
    func saveOrganization(_ org: Organization) -> Bool {
        let sql = """
            INSERT OR REPLACE INTO organizations
            (id, name, type, industry, location, website, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        let success = db.execute(sql, parameters: [
            org.id,
            org.name,
            org.type.rawValue,
            org.industry ?? NSNull(),
            org.location ?? NSNull(),
            org.website ?? NSNull(),
            org.description ?? NSNull(),
            Database.dateToString(org.createdAt),
            Database.dateToString(org.updatedAt)
        ])

        if success {
            loadOrganizations()
        }
        return success
    }

    func getOrganization(id: String) -> Organization? {
        organizations.first { $0.id == id }
    }

    func getOrganizationByName(_ name: String) -> Organization? {
        organizations.first { $0.name.lowercased() == name.lowercased() }
    }

    func getOrCreateOrganization(name: String, type: OrganizationType) -> Organization {
        if let existing = getOrganizationByName(name) {
            return existing
        }
        let newOrg = Organization(name: name, type: type)
        _ = saveOrganization(newOrg)
        return newOrg
    }

    // MARK: - Person-Organization Links

    func loadPersonOrganizations(forPersonId personId: String) -> [PersonOrganization] {
        let results = db.query("""
            SELECT po.*, o.name as org_name, o.type as org_type, o.industry, o.location as org_location
            FROM person_organizations po
            JOIN organizations o ON po.organization_id = o.id
            WHERE po.person_id = ?
        """, parameters: [personId])

        return results.compactMap { row -> PersonOrganization? in
            guard let id = row["id"] as? String,
                  let orgId = row["organization_id"] as? String else { return nil }

            var personOrg = PersonOrganization(
                id: id,
                personId: personId,
                organizationId: orgId,
                role: row["role"] as? String,
                degreeType: row["degree_type"] as? String,
                startDate: row["start_date"] as? String,
                endDate: row["end_date"] as? String,
                graduationYear: row["graduation_year"] as? String,
                isCurrent: (row["is_current"] as? Int ?? 1) == 1
            )

            // Attach organization data
            if let orgName = row["org_name"] as? String,
               let orgTypeStr = row["org_type"] as? String,
               let orgType = OrganizationType(rawValue: orgTypeStr) {
                personOrg.organization = Organization(
                    id: orgId,
                    name: orgName,
                    type: orgType,
                    industry: row["industry"] as? String,
                    location: row["org_location"] as? String
                )
            }

            return personOrg
        }
    }

    @discardableResult
    func linkPersonToOrganization(personId: String, organizationId: String, role: String? = nil, isCurrent: Bool = true) -> Bool {
        let sql = """
            INSERT OR REPLACE INTO person_organizations
            (id, person_id, organization_id, role, is_current)
            VALUES (?, ?, ?, ?, ?)
        """
        let success = db.execute(sql, parameters: [
            UUID().uuidString,
            personId,
            organizationId,
            role ?? NSNull(),
            isCurrent ? 1 : 0
        ])

        if success {
            loadPeople()
        }
        return success
    }

    // MARK: - Connections

    @discardableResult
    func addConnection(personAId: String, personBId: String, context: String?, type: ConnectionType = .known) -> Bool {
        // Enforce ordering (smaller ID first) to satisfy CHECK constraint
        let (first, second) = personAId < personBId ? (personAId, personBId) : (personBId, personAId)

        let sql = """
            INSERT OR REPLACE INTO person_connections
            (id, person_a_id, person_b_id, context, connection_type, strength, created_at)
            VALUES (?, ?, ?, ?, ?, 1, ?)
        """
        let success = db.execute(sql, parameters: [
            UUID().uuidString,
            first,
            second,
            context ?? NSNull(),
            type.rawValue,
            Database.dateToString(Date())
        ])

        if success {
            loadPeople()
        }
        return success
    }

    func loadConnections(forPersonId personId: String) -> [PersonConnection] {
        let results = db.query("""
            SELECT * FROM person_connections
            WHERE person_a_id = ? OR person_b_id = ?
        """, parameters: [personId, personId])

        return results.compactMap { row -> PersonConnection? in
            guard let id = row["id"] as? String,
                  let personAId = row["person_a_id"] as? String,
                  let personBId = row["person_b_id"] as? String else { return nil }

            let otherId = personAId == personId ? personBId : personAId

            var connection = PersonConnection(
                id: id,
                personAId: personAId,
                personBId: personBId,
                context: row["context"] as? String,
                connectionType: ConnectionType(rawValue: row["connection_type"] as? String ?? "") ?? .known,
                strength: row["strength"] as? Int ?? 1,
                createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date()
            )

            // Load the connected person (lightweight - just from cache)
            connection.connectedPerson = people.first { $0.id == otherId }

            return connection
        }
    }

    @discardableResult
    func removeConnection(id: String) -> Bool {
        let success = db.execute("DELETE FROM person_connections WHERE id = ?", parameters: [id])
        if success {
            loadPeople()
        }
        return success
    }

    // MARK: - Tags

    func loadTags(forPersonId personId: String) -> [String] {
        db.query("SELECT tag FROM person_tags WHERE person_id = ?", parameters: [personId])
            .compactMap { $0["tag"] as? String }
    }

    func loadAllTags() {
        let results = db.query("SELECT DISTINCT tag FROM person_tags ORDER BY tag")
        DispatchQueue.main.async { [weak self] in
            self?.allTags = results.compactMap { $0["tag"] as? String }
        }
    }

    @discardableResult
    func addTag(personId: String, tag: String) -> Bool {
        let success = db.execute(
            "INSERT OR IGNORE INTO person_tags (person_id, tag) VALUES (?, ?)",
            parameters: [personId, tag]
        )
        if success {
            loadPeople()
            loadAllTags()
        }
        return success
    }

    @discardableResult
    func removeTag(personId: String, tag: String) -> Bool {
        let success = db.execute(
            "DELETE FROM person_tags WHERE person_id = ? AND tag = ?",
            parameters: [personId, tag]
        )
        if success {
            loadPeople()
            loadAllTags()
        }
        return success
    }

    // MARK: - Events

    func loadEvents() {
        let results = db.query("SELECT * FROM network_events ORDER BY start_date DESC")
        let loadedEvents = results.compactMap { eventFromRow($0) }
        DispatchQueue.main.async { [weak self] in
            self?.events = loadedEvents
        }
    }

    @discardableResult
    func saveEvent(_ event: NetworkEvent) -> Bool {
        let sql = """
            INSERT OR REPLACE INTO network_events
            (id, name, location, start_date, end_date, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        let success = db.execute(sql, parameters: [
            event.id,
            event.name,
            event.location ?? NSNull(),
            event.startDate ?? NSNull(),
            event.endDate ?? NSNull(),
            event.description ?? NSNull(),
            Database.dateToString(event.createdAt),
            Database.dateToString(event.updatedAt)
        ])

        if success {
            loadEvents()
        }
        return success
    }

    @discardableResult
    func addEventAttendee(eventId: String, personId: String, role: String? = nil, notes: String? = nil) -> Bool {
        let sql = """
            INSERT OR REPLACE INTO event_attendees (event_id, person_id, role, notes)
            VALUES (?, ?, ?, ?)
        """
        return db.execute(sql, parameters: [
            eventId,
            personId,
            role ?? NSNull(),
            notes ?? NSNull()
        ])
    }

    // MARK: - Search

    func searchPeople(query: String) -> [Person] {
        if query.isEmpty { return people }

        let searchPattern = "%\(query)%"
        let results = db.query("""
            SELECT DISTINCT p.* FROM people p
            LEFT JOIN person_tags pt ON p.id = pt.person_id
            LEFT JOIN person_organizations po ON p.id = po.person_id
            LEFT JOIN organizations o ON po.organization_id = o.id
            WHERE p.name LIKE ?
               OR p.email LIKE ?
               OR p.one_liner LIKE ?
               OR p.notes LIKE ?
               OR pt.tag LIKE ?
               OR o.name LIKE ?
            ORDER BY p.name ASC
        """, parameters: Array(repeating: searchPattern, count: 6))

        var foundPeople = results.compactMap { personFromRow($0) }

        // Load relationships for found people
        for i in 0..<foundPeople.count {
            foundPeople[i].tags = loadTags(forPersonId: foundPeople[i].id)
            foundPeople[i].organizations = loadPersonOrganizations(forPersonId: foundPeople[i].id)
            foundPeople[i].connections = loadConnections(forPersonId: foundPeople[i].id)
        }

        return foundPeople
    }

    func getPeopleByTag(_ tag: String) -> [Person] {
        people.filter { $0.tags.contains(tag) }
    }

    func getPeopleByOrganization(_ orgId: String) -> [Person] {
        people.filter { $0.organizations.contains { $0.organizationId == orgId } }
    }

    func getPeopleByOrganizationName(_ name: String) -> [Person] {
        people.filter { person in
            person.organizations.contains { $0.organization?.name.lowercased() == name.lowercased() }
        }
    }

    // MARK: - Network Graph Data

    func getGraphData() -> (nodes: [PersonGraphNode], edges: [PersonGraphEdge]) {
        var nodes: [PersonGraphNode] = []
        var edges: [PersonGraphEdge] = []
        var seenConnections = Set<String>()

        // Create nodes with initial circular layout
        let centerX: CGFloat = 400
        let centerY: CGFloat = 400
        let radius: CGFloat = 300

        for (index, person) in people.enumerated() {
            let angle = (2 * .pi * Double(index)) / Double(max(people.count, 1))
            let position = CGPoint(
                x: centerX + radius * CGFloat(cos(angle)),
                y: centerY + radius * CGFloat(sin(angle))
            )
            nodes.append(PersonGraphNode(id: person.id, person: person, position: position))
        }

        // Create edges from connections
        let allConnections = db.query("SELECT * FROM person_connections")
        for row in allConnections {
            guard let id = row["id"] as? String,
                  let personAId = row["person_a_id"] as? String,
                  let personBId = row["person_b_id"] as? String else { continue }

            let connectionKey = "\(personAId)-\(personBId)"
            if seenConnections.contains(connectionKey) { continue }
            seenConnections.insert(connectionKey)

            let connection = PersonConnection(
                id: id,
                personAId: personAId,
                personBId: personBId,
                context: row["context"] as? String,
                connectionType: ConnectionType(rawValue: row["connection_type"] as? String ?? "") ?? .known,
                strength: row["strength"] as? Int ?? 1,
                createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date()
            )

            edges.append(PersonGraphEdge(id: id, connection: connection, sourceId: personAId, targetId: personBId))
        }

        return (nodes, edges)
    }

    // MARK: - Stats

    func getStats() -> (peopleCount: Int, connectionCount: Int, orgCount: Int, tagCount: Int) {
        let connectionCount = db.query("SELECT COUNT(*) as count FROM person_connections").first?["count"] as? Int ?? 0
        return (people.count, connectionCount, organizations.count, allTags.count)
    }

    // MARK: - Row Parsing Helpers

    private func personFromRow(_ row: [String: Any]) -> Person? {
        guard let id = row["id"] as? String,
              let name = row["name"] as? String else { return nil }

        return Person(
            id: id,
            name: name,
            oneLiner: row["one_liner"] as? String,
            notes: row["notes"] as? String,
            location: row["location"] as? String,
            currentCity: row["current_city"] as? String,
            email: row["email"] as? String,
            phone: row["phone"] as? String,
            linkedin: row["linkedin"] as? String,
            boardPriority: row["board_priority"] as? String,
            createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date(),
            updatedAt: Database.stringToDate(row["updated_at"] as? String ?? "") ?? Date()
        )
    }

    private func organizationFromRow(_ row: [String: Any]) -> Organization? {
        guard let id = row["id"] as? String,
              let name = row["name"] as? String,
              let typeStr = row["type"] as? String,
              let type = OrganizationType(rawValue: typeStr) else { return nil }

        return Organization(
            id: id,
            name: name,
            type: type,
            industry: row["industry"] as? String,
            location: row["location"] as? String,
            website: row["website"] as? String,
            description: row["description"] as? String,
            createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date(),
            updatedAt: Database.stringToDate(row["updated_at"] as? String ?? "") ?? Date()
        )
    }

    private func eventFromRow(_ row: [String: Any]) -> NetworkEvent? {
        guard let id = row["id"] as? String,
              let name = row["name"] as? String else { return nil }

        return NetworkEvent(
            id: id,
            name: name,
            location: row["location"] as? String,
            startDate: row["start_date"] as? String,
            endDate: row["end_date"] as? String,
            description: row["description"] as? String,
            createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date(),
            updatedAt: Database.stringToDate(row["updated_at"] as? String ?? "") ?? Date()
        )
    }
}
