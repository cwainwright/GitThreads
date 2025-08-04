//
//  ContentView.swift
//  GitThreads
//
//  Created by Christopher Wainwright on 03/06/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: Session
    
    var body: some View {
        Group {
            switch session.sessionState {
            case .loading:
                ProgressView()
            case .loggedOut:
                Login()
            case .loggedIn(let user):
                LoggedInView(user: user)
            }
        }
            .task {
                try? await session.login()
            }
    }
}

#Preview {
    ContentView()
}
