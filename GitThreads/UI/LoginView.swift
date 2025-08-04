//
//  Login.swift
//  GitThreads
//
//  Created by Christopher Wainwright on 04/06/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct Login: View {
    @EnvironmentObject var session: Session
    @State var deviceCode: DeviceCodeResponse?
    @State var errorMessage: String?
    @State var secondsRemaining = 0
    
    @State private var task: Task<Void, Never>? = nil
    
    @State private var users: [String] = []
    
    func login() async {
        do {
            errorMessage = nil
            let user = try await GitHubAuthorization.authorize { code in
                self.deviceCode = code
                self.secondsRemaining = code.expiresIn
            }
            try await session.login(user: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func restartLogin() {
        task?.cancel()
        
        task = Task {
            await login()
        }
    }
    
    var body: some View {
        VStack (alignment: .leading) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Register Device Code")
                    Spacer()
                    if (deviceCode == nil) {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark.circle.fill").renderingMode(.template).foregroundStyle(.green)
                    }
                }
                
                Divider()
                
                HStack {
                    Text("GitHub Sign In")
                    Spacer()
                    switch session.sessionState {
                    case .loggedIn(_):
                        Image(systemName: "checkmark.circle.fill").renderingMode(.template).foregroundStyle(.green)
                    default:
                        ProgressView()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            
            VStack (spacing: 10){
                Text("Instructions").font(.title2)
                VStack (alignment: .leading, spacing: 15) {
                    switch session.sessionState {
                    case .loggedIn(let user):
                        Text("User is \(user.username)")
                    default:
                        if let deviceCode = deviceCode {
                            if let url = URL(string: deviceCode.verificationUri) {
                                Text("Visit the following link and enter the code below:")
                                Divider()
                                if secondsRemaining > 0 {
                                    ProgressView("Code valid for \(secondsRemaining)s", value: Float(secondsRemaining)/Float(deviceCode.expiresIn))
                                        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { input in
                                            secondsRemaining -= 1
                                        }
                                    ViewThatFits (in: .horizontal) {
                                        HStack {
                                            Button {
                                                UIApplication.shared.open(url)
                                            } label: {
                                                Label("Open GitHub", systemImage: "safari")
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background()
                                            .cornerRadius(10)
                                            
                                            Button {
                                                UIPasteboard.general.setValue(deviceCode.userCode, forPasteboardType: UTType.plainText.identifier)
                                            } label: {
                                                Label(
                                                    deviceCode.userCode,
                                                    systemImage: "document.on.document"
                                                )
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background()
                                            .cornerRadius(10)
                                        }
                                        VStack {
                                            Button {
                                                UIApplication.shared.open(url)
                                            } label: {
                                                Label("Open GitHub", systemImage: "safari")
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background()
                                            .cornerRadius(10)
                                            
                                            Button {
                                                UIPasteboard.general.setValue(deviceCode.userCode, forPasteboardType: UTType.plainText.identifier)
                                            } label: {
                                                Label(
                                                    deviceCode.userCode,
                                                    systemImage: "document.on.document"
                                                )
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background()
                                            .cornerRadius(10)
                                        }
                                    }
                                    
                                } else {
                                    Text("Code Expired")
                                    Button {
                                        restartLogin()
                                    } label: {
                                        Label("Retry", systemImage: "arrow.clockwise")
                                    }
                                }
                            } else {
                                Text("Error: URL Invalid")
                            }
                        } else if let error = errorMessage {
                            Text("Error: \(error)")
                        } else {
                            Text("Awaiting response from GitHub Servers")
                        }
                    }
                    
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            
            VStack (spacing: 10) {
                List {
                    ForEach(users, id: \.self) { user in
                        Button(user) {
                            Task {
                                try? await session.switchUser(username: user)
                            }
                        }
                    }
                }
            }
            
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .task {
            restartLogin()
        }
        .task {
            users = session.getUsers()
        }
        .onDisappear()
        {
            task?.cancel()
        }
    }
}

#Preview {
    Login()
}
