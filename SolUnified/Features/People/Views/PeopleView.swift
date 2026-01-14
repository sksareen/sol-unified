//
//  PeopleView.swift
//  SolUnified
//
//  Main container view for People tab with list/graph toggle
//

import SwiftUI

struct PeopleView: View {
    @StateObject private var store = PeopleStore.shared
    @State private var viewMode: PeopleViewMode = .list
    @State private var searchQuery = ""
    @State private var selectedPerson: Person?
    @State private var showAddPerson = false
    @State private var personToEdit: Person?

    var body: some View {
        VStack(spacing: 0) {
            // Header with search and controls
            headerBar

            // Content
            Group {
                switch viewMode {
                case .list:
                    PeopleListView(
                        people: filteredPeople,
                        selectedPerson: $selectedPerson
                    )
                case .graph:
                    PeopleGraphView(
                        selectedPerson: $selectedPerson
                    )
                }
            }
        }
        .background(Color.brutalistBgPrimary)
        .sheet(isPresented: $showAddPerson) {
            PersonDetailView(person: nil, isEditing: true)
        }
        .sheet(item: $selectedPerson) { person in
            PersonDetailView(person: person, isEditing: false)
        }
        .onAppear {
            store.loadAll()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Title
                Text("People")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.brutalistTextPrimary)

                // Stats badge
                if !store.people.isEmpty {
                    Text("\(store.people.count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.brutalistTextMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brutalistBgTertiary)
                        .cornerRadius(4)
                }

                Spacer()

                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.brutalistTextMuted)
                    TextField("Search people, companies, tags...", text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.brutalistBgTertiary)
                .cornerRadius(6)
                .frame(maxWidth: 300)

                // View toggle
                HStack(spacing: 0) {
                    ForEach(PeopleViewMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewMode = mode
                            }
                        } label: {
                            Image(systemName: mode.icon)
                                .font(.system(size: 12))
                                .foregroundColor(viewMode == mode ? .brutalistTextPrimary : .brutalistTextMuted)
                                .frame(width: 32, height: 28)
                                .background(viewMode == mode ? Color.brutalistBgTertiary : Color.clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                    }
                }
                .background(Color.brutalistBgSecondary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.brutalistBorder, lineWidth: 1)
                )

                // Add button
                Button(action: { showAddPerson = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brutalistAccent)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
        }
        .background(Color.brutalistBgPrimary)
    }

    // MARK: - Computed Properties

    private var filteredPeople: [Person] {
        if searchQuery.isEmpty {
            return store.people
        }
        return store.searchPeople(query: searchQuery)
    }
}

// MARK: - Preview

#if DEBUG
struct PeopleView_Previews: PreviewProvider {
    static var previews: some View {
        PeopleView()
            .frame(width: 900, height: 600)
    }
}
#endif
