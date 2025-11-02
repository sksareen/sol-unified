//
//  NotesListView.swift
//  SolUnified
//
//  List of all saved notes
//

import SwiftUI

struct NotesListView: View {
    @ObservedObject var store = NotesStore.shared
    @State private var searchQuery = ""
    @State private var showingNewNote = false
    @State private var editingNote: Note?
    
    var filteredNotes: [Note] {
        if searchQuery.isEmpty {
            return store.notes
        }
        return store.searchNotes(query: searchQuery)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search and new button
            VStack(spacing: Spacing.md) {
                HStack {
                    Text("NOTES")
                        .font(.system(size: Typography.headingSize, weight: .semibold))
                        .foregroundColor(Color.brutalistTextPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        editingNote = Note(title: "New Note", content: "")
                        showingNewNote = true
                        InternalAppTracker.shared.trackNoteCreate(title: "New Note")
                    }) {
                        Text("+ NEW NOTE")
                            .font(.system(size: Typography.bodySize, weight: .medium))
                    }
                    .buttonStyle(BrutalistPrimaryButtonStyle())
                }
                
                // Search bar
                TextField("Search notes...", text: $searchQuery)
                    .textFieldStyle(BrutalistTextFieldStyle())
                    .onChange(of: searchQuery) { newValue in
                        if !newValue.isEmpty {
                            InternalAppTracker.shared.trackNoteSearch(query: newValue)
                        }
                    }
            }
            .padding(Spacing.lg)
            .background(Color.brutalistBgSecondary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Notes list
            if filteredNotes.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Text("No notes yet")
                        .font(.system(size: Typography.headingSize))
                        .foregroundColor(Color.brutalistTextMuted)
                    
                    Text("Click 'NEW NOTE' to create your first note")
                        .font(.system(size: Typography.bodySize))
                        .foregroundColor(Color.brutalistTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(filteredNotes) { note in
                            NoteCard(note: note)
                                .onTapGesture {
                                    editingNote = note
                                    showingNewNote = true
                                    InternalAppTracker.shared.trackNoteView(id: note.id, title: note.title)
                                }
                                .contextMenu {
                                    Button("Delete") {
                                        InternalAppTracker.shared.trackNoteDelete(id: note.id, title: note.title)
                                        _ = store.deleteNote(id: note.id)
                                    }
                                }
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
        }
        .sheet(isPresented: $showingNewNote) {
            if let note = editingNote {
                NoteEditor(note: note, isPresented: $showingNewNote)
            }
        }
        .onAppear {
            store.loadAllNotes()
        }
    }
}

struct NoteCard: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(note.title)
                .font(.system(size: Typography.bodySize, weight: .semibold))
                .foregroundColor(Color.brutalistTextPrimary)
            
            Text(note.content)
                .font(.system(size: Typography.bodySize))
                .foregroundColor(Color.brutalistTextSecondary)
                .lineLimit(2)
            
            Text(formatDate(note.updatedAt))
                .font(.system(size: Typography.smallSize))
                .foregroundColor(Color.brutalistTextMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.brutalistBgSecondary)
        .cornerRadius(BorderRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.md)
                .stroke(Color.brutalistBorder, lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct NoteEditor: View {
    @ObservedObject var store = NotesStore.shared
    @State var note: Note
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(note.id == 0 ? "NEW NOTE" : "EDIT NOTE")
                    .font(.system(size: Typography.headingSize, weight: .semibold))
                    .foregroundColor(Color.brutalistTextPrimary)
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(BrutalistSecondaryButtonStyle())
                
                Button("Save") {
                    var updatedNote = note
                    updatedNote.updatedAt = Date()
                    _ = store.saveNote(updatedNote)
                    if note.id == 0 {
                        InternalAppTracker.shared.trackNoteCreate(title: note.title)
                    } else {
                        InternalAppTracker.shared.trackNoteEdit(id: note.id, title: note.title)
                    }
                    isPresented = false
                }
                .buttonStyle(BrutalistPrimaryButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.brutalistBgSecondary)
            
            // Content
            VStack(alignment: .leading, spacing: Spacing.md) {
                TextField("Title", text: $note.title)
                    .textFieldStyle(BrutalistTextFieldStyle())
                    .font(.system(size: Typography.headingSize, weight: .semibold))
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $note.content)
                        .font(.system(size: Typography.bodySize))
                        .lineSpacing(Typography.lineHeight * Typography.bodySize - Typography.bodySize)
                        .foregroundColor(Color.brutalistTextPrimary)
                        .frame(maxHeight: .infinity)
                        .padding(Spacing.md)
                        .background(Color.brutalistBgSecondary)
                        .scrollContentBackground(.hidden)
                        .cornerRadius(BorderRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: BorderRadius.sm)
                                .stroke(Color.brutalistBorder, lineWidth: 1)
                        )
                    
                    if note.content.isEmpty {
                        Text("Write your note here...")
                            .font(.system(size: Typography.bodySize))
                            .foregroundColor(Color.brutalistTextMuted)
                            .padding(Spacing.md)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .frame(width: 600, height: 500)
        .background(Color.brutalistBgPrimary)
    }
}

