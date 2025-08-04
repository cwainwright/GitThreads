//
//  GitThreadsApp.swift
//  GitThreads
//
//  Created by Christopher Wainwright on 03/06/2025.
//

import SwiftUI

@main
struct GitThreadsApp: App {
    @StateObject private var session = Session()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}
