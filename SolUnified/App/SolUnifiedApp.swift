//
//  SolUnifiedApp.swift
//  SolUnified
//
//  Main app entry point
//

import SwiftUI

@main
struct SolUnifiedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

