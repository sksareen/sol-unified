//
//  PersonDetailView.swift
//  SolUnified
//
//  Detail view for viewing and editing a person
//

import SwiftUI

struct PersonDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var store = PeopleStore.shared

    let person: Person?
    @State private var isEditing: Bool

    @State private var name: String = ""
    @State private var oneLiner: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var linkedin: String = ""
    @State private var notes: String = ""
    @State private var location: String = ""
    @State private var currentCity: String = ""
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var isBoardPriority: Bool = false

    // For new contacts - quick company entry
    @State private var companyName: String = ""
    @State private var companyRole: String = ""

    @State private var showAddConnection = false
    @State private var showAddOrganization = false
    @State private var showDeleteConfirmation = false

    init(person: Person?, isEditing: Bool = false) {
        self.person = person
        self._isEditing = State(initialValue: person == nil || isEditing)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Basic Info Section
                    basicInfoSection

                    Divider()

                    // Contact Info Section
                    contactInfoSection

                    Divider()

                    // Tags Section
                    tagsSection

                    if let person = person {
                        Divider()

                        // Organizations Section
                        organizationsSection(person: person)

                        Divider()

                        // Connections Section
                        connectionsSection(person: person)
                    }

                    Divider()

                    // Notes Section
                    notesSection
                }
                .padding(24)
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .background(Color.brutalistBgPrimary)
        .onAppear {
            loadPersonData()
        }
        .sheet(isPresented: $showAddOrganization) {
            if let person = person {
                AddOrganizationSheet(person: person)
            }
        }
        .sheet(isPresented: $showAddConnection) {
            if let person = person {
                AddConnectionSheet(person: person)
            }
        }
        .alert("Delete Person", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePerson()
            }
        } message: {
            Text("Are you sure you want to delete \(person?.name ?? "this person")? This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(person == nil ? "Add Person" : (isEditing ? "Edit Person" : person!.name))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.brutalistTextPrimary)

                if let person = person, !isEditing {
                    if let oneLiner = person.oneLiner, !oneLiner.isEmpty {
                        Text(oneLiner)
                            .font(.system(size: 13))
                            .foregroundColor(.brutalistTextSecondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 12) {
                // Delete button (only for existing people)
                if person != nil {
                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Delete this person")
                }

                if isEditing {
                    Button("Cancel") {
                        if person != nil {
                            // If editing existing person, go back to view mode
                            isEditing = false
                            loadPersonData()
                        } else {
                            dismiss()
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Save") {
                        savePerson()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.isEmpty)
                } else {
                    Button("Edit") {
                        isEditing = true
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .padding(20)
        .background(Color.brutalistBgSecondary)
    }

    // MARK: - Sections

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Info")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.brutalistTextMuted)

            if isEditing {
                VStack(alignment: .leading, spacing: 12) {
                    FormField(label: "Name", text: $name, placeholder: "Full name")
                    FormField(label: "One-liner", text: $oneLiner, placeholder: "Brief description or title")

                    // Company fields - shown for new contacts or if no organizations yet
                    if person == nil || (person?.organizations.isEmpty ?? true) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Company")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.brutalistTextMuted)
                                TextField("Company name", text: $companyName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 13))
                                    .padding(8)
                                    .background(Color.brutalistBgTertiary)
                                    .cornerRadius(6)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Role")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.brutalistTextMuted)
                                TextField("Job title", text: $companyRole)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 13))
                                    .padding(8)
                                    .background(Color.brutalistBgTertiary)
                                    .cornerRadius(6)
                            }
                        }
                    }

                    FormField(label: "Location", text: $location, placeholder: "City, Country")
                    FormField(label: "Current City", text: $currentCity, placeholder: "Where they live now")

                    Toggle(isOn: $isBoardPriority) {
                        Text("Priority Contact")
                            .font(.system(size: 13))
                            .foregroundColor(.brutalistTextPrimary)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                }
            } else if let person = person {
                VStack(alignment: .leading, spacing: 8) {
                    if let location = person.location {
                        InfoRow(label: "Location", value: location)
                    }
                    if let currentCity = person.currentCity {
                        InfoRow(label: "Current City", value: currentCity)
                    }
                    if person.boardPriority == "TRUE" || person.boardPriority == "true" {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text("Priority Contact")
                                .font(.system(size: 13))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
    }

    private var contactInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact Info")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.brutalistTextMuted)

            if isEditing {
                VStack(alignment: .leading, spacing: 12) {
                    FormField(label: "Email", text: $email, placeholder: "email@example.com")
                    FormField(label: "Phone", text: $phone, placeholder: "+1 555-555-5555")
                    FormField(label: "LinkedIn", text: $linkedin, placeholder: "linkedin.com/in/username")
                }
            } else if let person = person {
                VStack(alignment: .leading, spacing: 8) {
                    if let email = person.email, !email.isEmpty {
                        InfoRow(label: "Email", value: email, isLink: true)
                    }
                    if let phone = person.phone, !phone.isEmpty {
                        InfoRow(label: "Phone", value: phone)
                    }
                    if let linkedin = person.linkedin, !linkedin.isEmpty {
                        InfoRow(label: "LinkedIn", value: linkedin, isLink: true)
                    }
                }
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.brutalistTextMuted)

            PeopleFlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.system(size: 12))
                        if isEditing {
                            Button(action: { tags.removeAll { $0 == tag } }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .foregroundColor(.brutalistTextPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.brutalistBgTertiary)
                    .cornerRadius(4)
                }

                if isEditing {
                    HStack(spacing: 4) {
                        TextField("Add tag", text: $newTag)
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(width: 80)
                            .onSubmit {
                                addTag()
                            }
                        Button(action: addTag) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(newTag.isEmpty)
                    }
                    .foregroundColor(.brutalistTextSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.brutalistBorder.opacity(0.3))
                    .cornerRadius(4)
                }
            }
        }
    }

    private func organizationsSection(person: Person) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Organizations")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.brutalistTextMuted)
                Spacer()
                if isEditing {
                    Button(action: { showAddOrganization = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if person.organizations.isEmpty {
                Text("No organizations")
                    .font(.system(size: 13))
                    .foregroundColor(.brutalistTextMuted)
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(person.organizations) { personOrg in
                        if let org = personOrg.organization {
                            HStack {
                                Image(systemName: org.type.icon)
                                    .foregroundColor(org.type.color)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(org.name)
                                        .font(.system(size: 13, weight: .medium))
                                    if let role = personOrg.role {
                                        Text(role)
                                            .font(.system(size: 11))
                                            .foregroundColor(.brutalistTextSecondary)
                                    }
                                }
                                Spacer()
                                if personOrg.isCurrent {
                                    Text("Current")
                                        .font(.system(size: 10))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(3)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func connectionsSection(person: Person) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Connections (\(person.connections.count))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.brutalistTextMuted)
                Spacer()
                if isEditing {
                    Button(action: { showAddConnection = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if person.connections.isEmpty {
                Text("No connections yet")
                    .font(.system(size: 13))
                    .foregroundColor(.brutalistTextMuted)
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(person.connections.prefix(10)) { connection in
                        if let connectedPerson = connection.connectedPerson {
                            HStack {
                                Circle()
                                    .fill(connection.connectionType.color)
                                    .frame(width: 8, height: 8)
                                Text(connectedPerson.name)
                                    .font(.system(size: 13))
                                Spacer()
                                if let context = connection.context {
                                    Text(context)
                                        .font(.system(size: 11))
                                        .foregroundColor(.brutalistTextMuted)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    if person.connections.count > 10 {
                        Text("+ \(person.connections.count - 10) more")
                            .font(.system(size: 11))
                            .foregroundColor(.brutalistTextMuted)
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.brutalistTextMuted)

            if isEditing {
                TextEditor(text: $notes)
                    .font(.system(size: 13))
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.brutalistBgTertiary)
                    .cornerRadius(6)
            } else if let person = person, let personNotes = person.notes, !personNotes.isEmpty {
                Text(personNotes)
                    .font(.system(size: 13))
                    .foregroundColor(.brutalistTextSecondary)
            } else {
                Text("No notes")
                    .font(.system(size: 13))
                    .foregroundColor(.brutalistTextMuted)
                    .italic()
            }
        }
    }

    // MARK: - Actions

    private func loadPersonData() {
        guard let person = person else { return }
        name = person.name
        oneLiner = person.oneLiner ?? ""
        email = person.email ?? ""
        phone = person.phone ?? ""
        linkedin = person.linkedin ?? ""
        notes = person.notes ?? ""
        location = person.location ?? ""
        currentCity = person.currentCity ?? ""
        tags = person.tags
        isBoardPriority = person.boardPriority == "TRUE" || person.boardPriority == "true"
    }

    private func savePerson() {
        var updatedPerson = person ?? Person(name: name)
        let personId = updatedPerson.id // Capture ID before creating new instance

        updatedPerson = Person(
            id: personId,
            name: name,
            oneLiner: oneLiner.isEmpty ? nil : oneLiner,
            notes: notes.isEmpty ? nil : notes,
            location: location.isEmpty ? nil : location,
            currentCity: currentCity.isEmpty ? nil : currentCity,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            linkedin: linkedin.isEmpty ? nil : linkedin,
            boardPriority: isBoardPriority ? "TRUE" : nil,
            createdAt: person?.createdAt ?? Date(),
            updatedAt: Date()
        )
        updatedPerson.tags = tags

        _ = store.savePerson(updatedPerson)

        // If company name was provided, create/find organization and link it
        if !companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedCompany = companyName.trimmingCharacters(in: .whitespacesAndNewlines)

            // Check if organization already exists
            store.loadOrganizations()
            let existingOrg = store.organizations.first { $0.name.lowercased() == trimmedCompany.lowercased() }

            let organization: Organization
            if let existing = existingOrg {
                organization = existing
            } else {
                // Create new organization
                organization = Organization(name: trimmedCompany, type: .company)
                _ = store.saveOrganization(organization)
            }

            // Link person to organization
            let role = companyRole.trimmingCharacters(in: .whitespacesAndNewlines)
            store.linkPersonToOrganization(
                personId: personId,
                organizationId: organization.id,
                role: role.isEmpty ? nil : role,
                isCurrent: true
            )
        }

        dismiss()
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
        }
        newTag = ""
    }

    private func deletePerson() {
        guard let person = person else { return }
        _ = store.deletePerson(id: person.id)
        dismiss()
    }
}

// MARK: - Helper Views

struct FormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.brutalistTextMuted)
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 13))
                .padding(8)
                .background(Color.brutalistBgTertiary)
                .cornerRadius(4)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var isLink: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.brutalistTextMuted)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(isLink ? .blue : .brutalistTextPrimary)
        }
    }
}

struct PeopleFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: width, height: y + rowHeight)
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.brutalistAccent)
            .cornerRadius(6)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.brutalistTextPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.brutalistBgTertiary)
            .cornerRadius(6)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Add Organization Sheet

struct AddOrganizationSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var store = PeopleStore.shared

    let person: Person

    @State private var selectedOrganization: Organization?
    @State private var newOrgName: String = ""
    @State private var newOrgType: OrganizationType = .company
    @State private var role: String = ""
    @State private var isCurrent: Bool = true
    @State private var isCreatingNew: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Organization")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(20)
            .background(Color.brutalistBgSecondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Toggle between existing and new
                    Picker("", selection: $isCreatingNew) {
                        Text("Select Existing").tag(false)
                        Text("Create New").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    if isCreatingNew {
                        // Create new organization
                        VStack(alignment: .leading, spacing: 12) {
                            FormField(label: "Organization Name", text: $newOrgName, placeholder: "Company or school name")

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Type")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.brutalistTextMuted)
                                Picker("Type", selection: $newOrgType) {
                                    ForEach(OrganizationType.allCases, id: \.self) { type in
                                        HStack {
                                            Image(systemName: type.icon)
                                            Text(type.rawValue.capitalized)
                                        }.tag(type)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                        }
                    } else {
                        // Select existing organization
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Organization")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.brutalistTextMuted)

                            if store.organizations.isEmpty {
                                Text("No organizations yet. Create a new one.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.brutalistTextMuted)
                                    .italic()
                            } else {
                                ForEach(store.organizations) { org in
                                    Button(action: { selectedOrganization = org }) {
                                        HStack {
                                            Image(systemName: org.type.icon)
                                                .foregroundColor(org.type.color)
                                            Text(org.name)
                                                .font(.system(size: 13))
                                            Spacer()
                                            if selectedOrganization?.id == org.id {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.brutalistAccent)
                                            }
                                        }
                                        .padding(10)
                                        .background(selectedOrganization?.id == org.id ? Color.brutalistAccent.opacity(0.1) : Color.brutalistBgTertiary)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }

                    Divider()

                    // Role and current status
                    FormField(label: "Role/Title", text: $role, placeholder: "e.g., Software Engineer, Student")

                    Toggle(isOn: $isCurrent) {
                        Text("Currently at this organization")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))

                    Spacer()

                    // Save button
                    Button(action: saveOrganization) {
                        Text("Add Organization")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isCreatingNew ? newOrgName.isEmpty : selectedOrganization == nil)
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 500)
        .background(Color.brutalistBgPrimary)
        .onAppear {
            store.loadOrganizations()
        }
    }

    private func saveOrganization() {
        var organization: Organization

        if isCreatingNew {
            // Create new organization
            organization = Organization(name: newOrgName, type: newOrgType)
            _ = store.saveOrganization(organization)
        } else if let selected = selectedOrganization {
            organization = selected
        } else {
            return
        }

        // Link person to organization
        store.linkPersonToOrganization(
            personId: person.id,
            organizationId: organization.id,
            role: role.isEmpty ? nil : role,
            isCurrent: isCurrent
        )

        dismiss()
    }
}

// MARK: - Add Connection Sheet

struct AddConnectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var store = PeopleStore.shared

    let person: Person

    @State private var searchQuery: String = ""
    @State private var selectedPerson: Person?
    @State private var connectionType: ConnectionType = .known
    @State private var context: String = ""

    private var filteredPeople: [Person] {
        let others = store.people.filter { $0.id != person.id }
        if searchQuery.isEmpty {
            return others
        }
        return others.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Connection")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(20)
            .background(Color.brutalistBgSecondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Search for person
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect to Person")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.brutalistTextMuted)

                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.brutalistTextMuted)
                            TextField("Search people...", text: $searchQuery)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(10)
                        .background(Color.brutalistBgTertiary)
                        .cornerRadius(6)
                    }

                    // People list
                    if filteredPeople.isEmpty {
                        Text("No other people found")
                            .font(.system(size: 13))
                            .foregroundColor(.brutalistTextMuted)
                            .italic()
                    } else {
                        VStack(spacing: 4) {
                            ForEach(filteredPeople.prefix(10)) { p in
                                Button(action: { selectedPerson = p }) {
                                    HStack {
                                        Circle()
                                            .fill(Color.brutalistAccent.opacity(0.3))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Text(String(p.name.prefix(1)).uppercased())
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(.brutalistAccent)
                                            )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.name)
                                                .font(.system(size: 13, weight: .medium))
                                            if let oneLiner = p.oneLiner {
                                                Text(oneLiner)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.brutalistTextMuted)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        if selectedPerson?.id == p.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.brutalistAccent)
                                        }
                                    }
                                    .padding(10)
                                    .background(selectedPerson?.id == p.id ? Color.brutalistAccent.opacity(0.1) : Color.brutalistBgTertiary)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    Divider()

                    // Connection type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connection Type")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.brutalistTextMuted)

                        Picker("Type", selection: $connectionType) {
                            ForEach(ConnectionType.allCases, id: \.self) { type in
                                HStack {
                                    Circle()
                                        .fill(type.color)
                                        .frame(width: 8, height: 8)
                                    Text(type.rawValue.capitalized)
                                }.tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }

                    // Context
                    FormField(label: "Context (how you know them)", text: $context, placeholder: "e.g., Met at conference, College roommate")

                    Spacer()

                    // Save button
                    Button(action: saveConnection) {
                        Text("Add Connection")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedPerson == nil)
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 550)
        .background(Color.brutalistBgPrimary)
    }

    private func saveConnection() {
        guard let selectedPerson = selectedPerson else { return }

        store.addConnection(
            personAId: person.id,
            personBId: selectedPerson.id,
            context: context.isEmpty ? nil : context,
            type: connectionType
        )

        dismiss()
    }
}
