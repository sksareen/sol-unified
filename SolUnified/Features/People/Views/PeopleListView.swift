//
//  PeopleListView.swift
//  SolUnified
//
//  List view for people with grouping and search
//

import SwiftUI

struct PeopleListView: View {
    let people: [Person]
    @Binding var selectedPerson: Person?
    @State private var groupBy: PeopleGroupBy = .alphabetical

    var body: some View {
        VStack(spacing: 0) {
            // Group selector bar
            HStack {
                ForEach(PeopleGroupBy.allCases, id: \.self) { option in
                    Button(action: { groupBy = option }) {
                        Text(option.rawValue)
                            .font(.system(size: 11, weight: groupBy == option ? .bold : .medium))
                            .foregroundColor(groupBy == option ? .brutalistTextPrimary : .brutalistTextSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(groupBy == option ? Color.brutalistBgTertiary : Color.clear)
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
                Text("\(people.count) people")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.brutalistTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.brutalistBgSecondary)

            // List
            if people.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedPeople, id: \.key) { group in
                            Section(header: sectionHeader(group.key)) {
                                ForEach(group.value) { person in
                                    PersonRowView(
                                        person: person,
                                        isSelected: selectedPerson?.id == person.id
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedPerson = person
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundColor(.brutalistTextMuted)
            Text("No people yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.brutalistTextSecondary)
            Text("Add people to start building your network")
                .font(.system(size: 13))
                .foregroundColor(.brutalistTextMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var groupedPeople: [(key: String, value: [Person])] {
        switch groupBy {
        case .alphabetical:
            return Dictionary(grouping: people) {
                String($0.name.prefix(1)).uppercased()
            }.sorted { $0.key < $1.key }

        case .company:
            return Dictionary(grouping: people) {
                $0.organizations.first(where: { $0.isCurrent })?.organization?.name
                    ?? $0.organizations.first?.organization?.name
                    ?? "No Company"
            }.sorted { $0.key < $1.key }

        case .tag:
            // Group by first tag, or "No Tags"
            return Dictionary(grouping: people) {
                $0.tags.first ?? "No Tags"
            }.sorted { $0.key < $1.key }

        case .recent:
            // Single group sorted by updated date
            return [("All", people.sorted { $0.updatedAt > $1.updatedAt })]
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.brutalistTextMuted)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.brutalistBgSecondary)
    }
}

// MARK: - Preview

#if DEBUG
struct PeopleListView_Previews: PreviewProvider {
    static var previews: some View {
        PeopleListView(
            people: [
                Person(name: "Alice Anderson", oneLiner: "Engineer at Apple"),
                Person(name: "Bob Brown", oneLiner: "Designer"),
                Person(name: "Charlie Chen")
            ],
            selectedPerson: .constant(nil)
        )
        .background(Color.brutalistBgPrimary)
    }
}
#endif
