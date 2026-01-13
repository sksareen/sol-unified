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

    @State private var showAddConnection = false
    @State private var showAddOrganization = false

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
        updatedPerson = Person(
            id: updatedPerson.id,
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
        dismiss()
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
        }
        newTag = ""
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
