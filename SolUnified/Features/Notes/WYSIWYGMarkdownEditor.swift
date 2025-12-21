//
//  WYSIWYGMarkdownEditor.swift
//  SolUnified
//
//  WYSIWYG markdown editor with live formatting
//

import SwiftUI
import AppKit

struct WYSIWYGMarkdownEditor: View {
    @Binding var fileURL: URL?
    @State private var content: String = ""
    @State private var saveTimer: Timer?
    @State private var lastSaved: Date?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let url = fileURL {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.brutalistAccent)
                        
                        Text(url.lastPathComponent)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.brutalistTextPrimary)
                    }
                } else {
                    Text("SELECT A FILE")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let lastSaved = lastSaved {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 4, height: 4)
                        Text("SAVED \(timeAgo(lastSaved).uppercased())")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                VisualEffectView(material: .headerView, blendingMode: .withinWindow)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.brutalistBorder),
                alignment: .bottom
            )
            
            // Editor
            if fileURL != nil {
                MarkdownTextEditor(text: $content)
                    .onChange(of: content) { _ in
                        scheduleAutoSave()
                    }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.secondary.opacity(0.3))
                    
                    Text("Select a file from the sidebar to start editing")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.brutalistBgPrimary)
            }
        }
        .background(Color.brutalistBgPrimary)
        .onChange(of: fileURL) { newURL in
            loadFile(newURL)
        }
        .onAppear {
            loadFile(fileURL)
        }
    }
    
    private func loadFile(_ url: URL?) {
        guard let url = url else {
            content = ""
            return
        }
        
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            content = "Error loading file: \(error.localizedDescription)"
        }
    }
    
    private func scheduleAutoSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            saveFile()
        }
    }
    
    private func saveFile() {
        guard let url = fileURL else { return }
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            lastSaved = Date()
        } catch {
            print("Error saving file: \(error)")
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}

// MARK: - NSTextView Wrapper with Live Markdown Formatting

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        
        // Configure text view
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.controlBackgroundColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        // Add top and bottom padding - 800px at bottom so text isn't stuck at screen bottom
        textView.textContainerInset = NSSize(width: 20, height: 20)
        
        // Configure scroll view for bottom padding
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 800, right: 0)
        scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 800, right: 0)
        
        // Set initial text
        textView.string = text
        applyMarkdownFormatting(to: textView)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            applyMarkdownFormatting(to: textView)
            
            // Restore cursor position
            if selectedRange.location <= textView.string.count {
                textView.setSelectedRange(selectedRange)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func applyMarkdownFormatting(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        // Begin editing to batch changes and prevent flicker
        textStorage.beginEditing()
        
        // Reset to base attributes first
        let baseFont = NSFont.systemFont(ofSize: 15, weight: .regular)
        textStorage.addAttribute(.font, value: baseFont, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        
        // Remove any existing background colors
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
        
        // Headers - make # symbols grey and de-emphasized
        let headerPatterns: [(String, CGFloat, CGFloat)] = [
            ("^(#{1}) (.+)$", 28, 700),  // H1
            ("^(#{2}) (.+)$", 24, 700),  // H2
            ("^(#{3}) (.+)$", 20, 600),  // H3
            ("^(#{4}) (.+)$", 17, 600),  // H4
            ("^(#{5}) (.+)$", 15, 600),  // H5
            ("^(#{6}) (.+)$", 15, 500)   // H6
        ]
        
        for (pattern, fontSize, weight) in headerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                let matches = regex.matches(in: textStorage.string, range: fullRange)
                for match in matches {
                    // Grey out the # symbols
                    if match.numberOfRanges > 1 {
                        let hashRange = match.range(at: 1)
                        textStorage.addAttributes([
                            .foregroundColor: NSColor.secondaryLabelColor,
                            .font: NSFont.systemFont(ofSize: 13, weight: .regular)
                        ], range: hashRange)
                    }
                    
                    // Make the header text large and bold
                    if match.numberOfRanges > 2 {
                        let textRange = match.range(at: 2)
                        textStorage.addAttributes([
                            .font: NSFont.systemFont(ofSize: fontSize, weight: .init(rawValue: weight)),
                            .foregroundColor: NSColor.labelColor
                        ], range: textRange)
                    }
                }
            }
        }
        
        // Bold - grey out ** and make text bold
        if let regex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: []) {
            let matches = regex.matches(in: textStorage.string, range: fullRange)
            for match in matches {
                // Grey out the ** markers
                let fullText = (textStorage.string as NSString).substring(with: match.range)
                if fullText.hasPrefix("**") {
                    let startMarker = NSRange(location: match.range.location, length: 2)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: startMarker)
                    
                    let endMarker = NSRange(location: match.range.location + match.range.length - 2, length: 2)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: endMarker)
                }
                
                // Make the content bold
                if match.numberOfRanges > 1 {
                    let contentRange = match.range(at: 1)
                    textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 15, weight: .semibold), range: contentRange)
                }
            }
        }
        
        // Italic - grey out * and make text italic
        if let regex = try? NSRegularExpression(pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", options: []) {
            let matches = regex.matches(in: textStorage.string, range: fullRange)
            for match in matches {
                // Grey out the * markers
                let startMarker = NSRange(location: match.range.location, length: 1)
                textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: startMarker)
                
                let endMarker = NSRange(location: match.range.location + match.range.length - 1, length: 1)
                textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: endMarker)
                
                // Make the content italic
                if match.numberOfRanges > 1 {
                    let contentRange = match.range(at: 1)
                    let italicFont = NSFont.systemFont(ofSize: 15, weight: .regular).italic()
                    textStorage.addAttributes([
                        .font: italicFont,
                        .obliqueness: 0.15 as NSNumber
                    ], range: contentRange)
                }
            }
        }
        
        // Inline code - grey out backticks and add background
        if let regex = try? NSRegularExpression(pattern: "`([^`]+)`", options: []) {
            let matches = regex.matches(in: textStorage.string, range: fullRange)
            for match in matches {
                // Grey out backticks
                let startMarker = NSRange(location: match.range.location, length: 1)
                textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: startMarker)
                
                let endMarker = NSRange(location: match.range.location + match.range.length - 1, length: 1)
                textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: endMarker)
                
                // Style the code content
                if match.numberOfRanges > 1 {
                    let contentRange = match.range(at: 1)
                    textStorage.addAttributes([
                        .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                        .backgroundColor: NSColor.quaternaryLabelColor,
                        .foregroundColor: NSColor.systemRed
                    ], range: contentRange)
                }
            }
        }
        
        // Links - show link text prominently, grey out markdown syntax
        if let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)", options: []) {
            let matches = regex.matches(in: textStorage.string, range: fullRange)
            for match in matches {
                // Grey out [ ] ( ) markers
                let openBracket = NSRange(location: match.range.location, length: 1)
                textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openBracket)
                
                if match.numberOfRanges > 1 {
                    let linkTextRange = match.range(at: 1)
                    let closeBracket = NSRange(location: linkTextRange.location + linkTextRange.length, length: 1)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeBracket)
                    
                    // Style link text
                    textStorage.addAttributes([
                        .foregroundColor: NSColor.systemBlue,
                        .underlineStyle: NSUnderlineStyle.single.rawValue as NSNumber
                    ], range: linkTextRange)
                }
                
                if match.numberOfRanges > 2 {
                    let urlRange = match.range(at: 2)
                    let openParen = NSRange(location: urlRange.location - 1, length: 1)
                    let closeParen = NSRange(location: urlRange.location + urlRange.length, length: 1)
                    
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: openParen)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: closeParen)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: urlRange)
                }
            }
        }
        
        // List items - keep dash visible but with proper spacing
        if let regex = try? NSRegularExpression(pattern: "^([-*+]) (.+)$", options: [.anchorsMatchLines]) {
            let matches = regex.matches(in: textStorage.string, range: fullRange)
            for match in matches {
                if match.numberOfRanges > 1 {
                    let bulletRange = match.range(at: 1)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: bulletRange)
                }
            }
        }
        
        // End editing to apply all changes at once
        textStorage.endEditing()
        
        // Force layout invalidation to prevent disappearing text
        textView.layoutManager?.invalidateLayout(forCharacterRange: fullRange, actualCharacterRange: nil)
        textView.setNeedsDisplay(textView.bounds)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextEditor
        private var isApplyingFormatting = false
        
        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Prevent infinite loop from formatting triggering textDidChange
            guard !isApplyingFormatting else { return }
            
            // Update parent text immediately for saving
            parent.text = textView.string
            
            // Apply formatting instantly without debouncing
            // Using textStorage directly prevents flicker
            isApplyingFormatting = true
            parent.applyMarkdownFormatting(to: textView)
            isApplyingFormatting = false
        }
    }
}

// MARK: - NSFont Extension for Italic
extension NSFont {
    func italic() -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
