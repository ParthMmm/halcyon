//
//  halcyonApp.swift
//  halcyon
//
//  Created by Parth Mangrola on 10/1/25.
//

 import SwiftUI

@main
struct halcyonApp: App {
    var body: some Scene {
        Window("Halcyon", id: "main") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .undoRedo) { }
        }
    }
}
