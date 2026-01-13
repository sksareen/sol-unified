//
//  PersonRowView.swift
//  SolUnified
//
//  List row component for displaying a person
//

import SwiftUI

struct PersonRowView: View {
    let person: Person
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(avatarColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(initials)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(person.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.brutalistTextPrimary)

                    if person.boardPriority == "TRUE" || person.boardPriority == "true" {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }

                if let oneLiner = person.oneLiner, !oneLiner.isEmpty {
                    Text(oneLiner)
                        .font(.system(size: 12))
                        .foregroundColor(.brutalistTextSecondary)
                        .lineLimit(1)
                } else if let company = primaryOrganization {
                    Text(company)
                        .font(.system(size: 12))
                        .foregroundColor(.brutalistTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Tags (show first 2)
            HStack(spacing: 4) {
                ForEach(person.tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 9))
                        .foregroundColor(.brutalistTextSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brutalistBgTertiary)
                        .cornerRadius(3)
                }
            }

            // Connection count
            if !person.connections.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "link")
                        .font(.system(size: 10))
                    Text("\(person.connections.count)")
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundColor(.brutalistTextMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.brutalistBgTertiary : Color.brutalistBgPrimary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.brutalistBorder.opacity(0.5)),
            alignment: .bottom
        )
    }

    private var initials: String {
        let parts = person.name.components(separatedBy: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(person.name.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        // Generate consistent color based on name
        let hash = person.name.hashValue
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .cyan, .indigo, .mint
        ]
        return colors[abs(hash) % colors.count].opacity(0.8)
    }

    private var primaryOrganization: String? {
        if let org = person.organizations.first(where: { $0.isCurrent }),
           let name = org.organization?.name {
            if let role = org.role {
                return "\(role) at \(name)"
            }
            return name
        }
        return person.organizations.first?.organization?.name
    }
}

// MARK: - Preview

#if DEBUG
struct PersonRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            PersonRowView(person: Person(
                name: "John Doe",
                oneLiner: "Building the future of AI",
                email: "john@example.com"
            ))

            PersonRowView(person: Person(
                name: "Jane Smith",
                boardPriority: "TRUE"
            ), isSelected: true)
        }
        .background(Color.brutalistBgPrimary)
    }
}
#endif
