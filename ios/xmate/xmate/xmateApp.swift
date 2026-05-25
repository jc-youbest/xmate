//
//  xmateApp.swift
//  xmate
//
//  Created by chao on 13/5/2026.
//

import SwiftUI

@main
struct xmateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(NoteStore.shared)
        }
    }
}
