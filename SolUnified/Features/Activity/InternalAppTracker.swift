//
//  InternalAppTracker.swift
//  SolUnified
//
//  Tracks internal Sol Unified application activity (comprehensive user action tracking)
//

import Foundation
import SwiftUI

class InternalAppTracker {
    static let shared = InternalAppTracker()
    
    // Navigation & UI
    var onTabSwitch: ((AppTab) -> Void)?
    var onSettingsOpen: (() -> Void)?
    var onSettingsClose: (() -> Void)?
    var onFeatureOpen: ((String) -> Void)?
    var onFeatureClose: ((String) -> Void)?
    var onWindowShow: (() -> Void)?
    var onWindowHide: (() -> Void)?
    
    // Notes
    var onNoteCreate: ((String) -> Void)?
    var onNoteEdit: ((Int, String) -> Void)?
    var onNoteDelete: ((Int, String) -> Void)?
    var onNoteView: ((Int, String) -> Void)?
    var onNoteSearch: ((String) -> Void)?
    var onScratchpadEdit: (() -> Void)?
    
    // Clipboard
    var onClipboardCopy: ((String) -> Void)?
    var onClipboardPaste: ((String) -> Void)?
    var onClipboardClear: (() -> Void)?
    var onClipboardSearch: ((String) -> Void)?
    
    // Timer
    var onTimerStart: ((TimeInterval) -> Void)?
    var onTimerStop: (() -> Void)?
    var onTimerReset: (() -> Void)?
    var onTimerSetDuration: ((TimeInterval) -> Void)?
    
    // Screenshots
    var onScreenshotView: ((String) -> Void)?
    var onScreenshotSearch: ((String) -> Void)?
    var onScreenshotAnalyze: ((String) -> Void)?
    
    // Settings
    var onSettingChange: ((String, String) -> Void)?
    
    private init() {}
    
    // MARK: - Navigation & UI
    func trackTabSwitch(to tab: AppTab) {
        onTabSwitch?(tab)
    }
    
    func trackSettingsOpen() {
        onSettingsOpen?()
    }
    
    func trackSettingsClose() {
        onSettingsClose?()
    }
    
    func trackFeatureOpen(_ feature: String) {
        onFeatureOpen?(feature)
    }
    
    func trackFeatureClose(_ feature: String) {
        onFeatureClose?(feature)
    }
    
    func trackWindowShow() {
        onWindowShow?()
    }
    
    func trackWindowHide() {
        onWindowHide?()
    }
    
    // MARK: - Notes
    func trackNoteCreate(title: String) {
        onNoteCreate?(title)
    }
    
    func trackNoteEdit(id: Int, title: String) {
        onNoteEdit?(id, title)
    }
    
    func trackNoteDelete(id: Int, title: String) {
        onNoteDelete?(id, title)
    }
    
    func trackNoteView(id: Int, title: String) {
        onNoteView?(id, title)
    }
    
    func trackNoteSearch(query: String) {
        onNoteSearch?(query)
    }
    
    func trackScratchpadEdit() {
        onScratchpadEdit?()
    }
    
    // MARK: - Clipboard
    func trackClipboardCopy(preview: String) {
        onClipboardCopy?(preview)
    }
    
    func trackClipboardPaste(preview: String) {
        onClipboardPaste?(preview)
    }
    
    func trackClipboardClear() {
        onClipboardClear?()
    }
    
    func trackClipboardSearch(query: String) {
        onClipboardSearch?(query)
    }
    
    // MARK: - Timer
    func trackTimerStart(duration: TimeInterval) {
        onTimerStart?(duration)
    }
    
    func trackTimerStop() {
        onTimerStop?()
    }
    
    func trackTimerReset() {
        onTimerReset?()
    }
    
    func trackTimerSetDuration(duration: TimeInterval) {
        onTimerSetDuration?(duration)
    }
    
    // MARK: - Screenshots
    func trackScreenshotView(filename: String) {
        onScreenshotView?(filename)
    }
    
    func trackScreenshotSearch(query: String) {
        onScreenshotSearch?(query)
    }
    
    func trackScreenshotAnalyze(filename: String) {
        onScreenshotAnalyze?(filename)
    }
    
    // MARK: - Settings
    func trackSettingChange(key: String, value: String) {
        onSettingChange?(key, value)
    }
}

