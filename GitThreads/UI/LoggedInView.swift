//
//  LoggedInView.swift
//  GitThreads
//
//  Created by Christopher Wainwright on 03/08/2025.
//

import SwiftUI

struct LoggedInView: View {
    @EnvironmentObject var session: Session
    
    let user: User
    
    var body: some View {
            Text("Logged In User: \(user.username)")
            
            Button("Log Out") {
                Task {
                    try? await session.logout()
                }
            }
            .buttonStyle(.bordered)
            
            Button("Switch User") {
                Task {
                    try? await session.logout(removeUser: false)
                }
            }
            .buttonStyle(.borderedProminent)
    }
}
