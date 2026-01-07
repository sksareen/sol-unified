//
//  ContactsStore.swift
//  SolUnified
//
//  Manages contacts storage and retrieval
//

import Foundation
import Combine

class ContactsStore: ObservableObject {
    static let shared = ContactsStore()

    @Published var contacts: [Contact] = []
    @Published var isLoading = false

    private let db = Database.shared

    private init() {
        loadContacts()
    }

    // MARK: - Load

    func loadContacts() {
        let results = db.query("SELECT * FROM contacts ORDER BY name ASC")
        DispatchQueue.main.async { [weak self] in
            self?.contacts = results.compactMap { self?.contactFromRow($0) }
        }
    }

    // MARK: - Save

    @discardableResult
    func saveContact(_ contact: Contact) -> Bool {
        let preferencesJson = try? JSONEncoder().encode(contact.preferences)
        let preferencesStr = preferencesJson.flatMap { String(data: $0, encoding: .utf8) }

        let sql = """
            INSERT OR REPLACE INTO contacts
            (id, name, nickname, email, phone, relationship, company, role, notes, preferences, last_interaction, interaction_count, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        let success = db.execute(sql, parameters: [
            contact.id,
            contact.name,
            contact.nickname ?? NSNull(),
            contact.email ?? NSNull(),
            contact.phone ?? NSNull(),
            contact.relationship.rawValue,
            contact.company ?? NSNull(),
            contact.role ?? NSNull(),
            contact.notes ?? NSNull(),
            preferencesStr ?? NSNull(),
            contact.lastInteraction.map { Database.dateToString($0) } ?? NSNull(),
            contact.interactionCount,
            Database.dateToString(contact.createdAt),
            Database.dateToString(contact.updatedAt)
        ])

        if success {
            loadContacts()
        }
        return success
    }

    // MARK: - Delete

    @discardableResult
    func deleteContact(id: String) -> Bool {
        // First delete interactions
        _ = db.execute("DELETE FROM contact_interactions WHERE contact_id = ?", parameters: [id])
        // Then delete contact
        let success = db.execute("DELETE FROM contacts WHERE id = ?", parameters: [id])
        if success {
            loadContacts()
        }
        return success
    }

    // MARK: - Find

    func findContact(named name: String) -> [Contact] {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)

        if normalized.isEmpty {
            return []
        }

        return contacts.filter { contact in
            contact.name.lowercased().contains(normalized) ||
            (contact.nickname?.lowercased().contains(normalized) ?? false) ||
            (contact.email?.lowercased().contains(normalized) ?? false)
        }
    }

    func getContact(id: String) -> Contact? {
        return contacts.first { $0.id == id }
    }

    func getContactsByRelationship(_ relationship: ContactRelationship) -> [Contact] {
        return contacts.filter { $0.relationship == relationship }
    }

    func getRecentContacts(limit: Int = 10) -> [Contact] {
        return contacts
            .filter { $0.lastInteraction != nil }
            .sorted { ($0.lastInteraction ?? .distantPast) > ($1.lastInteraction ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Search

    func searchContacts(query: String) -> [Contact] {
        if query.isEmpty {
            return contacts
        }

        let results = db.query(
            """
            SELECT * FROM contacts
            WHERE name LIKE ?
               OR nickname LIKE ?
               OR email LIKE ?
               OR company LIKE ?
               OR notes LIKE ?
            ORDER BY name ASC
            """,
            parameters: ["%\(query)%", "%\(query)%", "%\(query)%", "%\(query)%", "%\(query)%"]
        )

        return results.compactMap { contactFromRow($0) }
    }

    // MARK: - Interactions

    @discardableResult
    func recordInteraction(_ interaction: ContactInteraction) -> Bool {
        let sql = """
            INSERT INTO contact_interactions
            (id, contact_id, type, summary, timestamp, context_node_id, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """

        let success = db.execute(sql, parameters: [
            interaction.id,
            interaction.contactId,
            interaction.type.rawValue,
            interaction.summary,
            Database.dateToString(interaction.timestamp),
            interaction.contextNodeId ?? NSNull(),
            interaction.metadata ?? NSNull()
        ])

        if success {
            // Update contact's lastInteraction and interactionCount
            _ = db.execute(
                """
                UPDATE contacts
                SET last_interaction = ?, interaction_count = interaction_count + 1, updated_at = ?
                WHERE id = ?
                """,
                parameters: [
                    Database.dateToString(interaction.timestamp),
                    Database.dateToString(Date()),
                    interaction.contactId
                ]
            )
            loadContacts()
        }

        return success
    }

    func getInteractions(forContactId contactId: String, limit: Int = 20) -> [ContactInteraction] {
        let results = db.query(
            """
            SELECT * FROM contact_interactions
            WHERE contact_id = ?
            ORDER BY timestamp DESC
            LIMIT ?
            """,
            parameters: [contactId, limit]
        )

        return results.compactMap { interactionFromRow($0) }
    }

    // MARK: - Row Parsing

    private func contactFromRow(_ row: [String: Any]) -> Contact? {
        guard let id = row["id"] as? String,
              let name = row["name"] as? String else {
            return nil
        }

        let relationship = ContactRelationship(rawValue: row["relationship"] as? String ?? "other") ?? .other

        var preferences = ContactPreferences()
        if let preferencesStr = row["preferences"] as? String,
           let preferencesData = preferencesStr.data(using: .utf8) {
            preferences = (try? JSONDecoder().decode(ContactPreferences.self, from: preferencesData)) ?? ContactPreferences()
        }

        return Contact(
            id: id,
            name: name,
            nickname: row["nickname"] as? String,
            email: row["email"] as? String,
            phone: row["phone"] as? String,
            relationship: relationship,
            company: row["company"] as? String,
            role: row["role"] as? String,
            notes: row["notes"] as? String,
            preferences: preferences,
            lastInteraction: Database.stringToDate(row["last_interaction"] as? String ?? ""),
            interactionCount: row["interaction_count"] as? Int ?? 0,
            createdAt: Database.stringToDate(row["created_at"] as? String ?? "") ?? Date(),
            updatedAt: Database.stringToDate(row["updated_at"] as? String ?? "") ?? Date()
        )
    }

    private func interactionFromRow(_ row: [String: Any]) -> ContactInteraction? {
        guard let id = row["id"] as? String,
              let contactId = row["contact_id"] as? String,
              let typeStr = row["type"] as? String,
              let type = InteractionType(rawValue: typeStr),
              let summary = row["summary"] as? String else {
            return nil
        }

        return ContactInteraction(
            id: id,
            contactId: contactId,
            type: type,
            summary: summary,
            timestamp: Database.stringToDate(row["timestamp"] as? String ?? "") ?? Date(),
            contextNodeId: row["context_node_id"] as? String,
            metadata: row["metadata"] as? String
        )
    }
}
