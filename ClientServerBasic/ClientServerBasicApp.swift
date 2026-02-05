//
//  ClientServerBasicApp.swift
//  ClientServerBasic
//
//  Created by Walter Karabin on 2026-01-23.
//

import SwiftUI

@main
struct ClientServerBasicApp: App {
    @StateObject private var authManager: AuthManager
    private var developmentMode: Bool = false
    private var notificationCenter = NotificationCenter.default
    @State private var showingModal = false  // State to control modal visibility
    
    private var invoiceService: InvoiceService
    
    init() {
        // Observe the UserDidLogout notification
        let sharedAuthManager = AuthManager()
        
        // B. Initialize the StateObject manually using the raw instance
        // The underscore (_authManager) accesses the wrapper itself, not the value inside.
        self._authManager = StateObject(wrappedValue: sharedAuthManager)
        // C. Pass that SAME instance to the service
        self.invoiceService = InvoiceService(authManager: sharedAuthManager)
        
        // D. Setup Development Mode
        // developmentMode = Bundle.main.infoDictionary?["DevelopmentMode"] as? Bool ?? false
        developmentMode = false
        
        // E. Setup Notification Observer
        // We use 'sharedAuthManager' here (the raw object), which is safe in init.
        notificationCenter.addObserver(
            forName: Notification.Name("UserDidLogout"),
            object: nil,
            queue: .main
        ) { [weak sharedAuthManager] _ in
            sharedAuthManager?.isAuthenticated = true
        }
        if authManager.isAuthenticated {
            print("main")
        } else if developmentMode {
            print("dev mode")
        } else {
            print("login")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                // 2. This is the router. It checks the @Published property from the manager.
                if authManager.isAuthenticated {
                    // If TRUE: Show the main app.
                    DashboardView()
                    // We pass the manager into the environment so all sub-views
                    // (like LibraryView) can access it later if needed (e.g., for logout).
                        .environmentObject(authManager)
                        .environmentObject(
                            InvoiceStore(invoiceService: invoiceService)
                        )
                } else if developmentMode {
                    // If in development mode, bypass login for easier testing
                    //                    Button("Show Modal") {
                    //                        showingModal.toggle()  // Toggle the state to show/hide the modal
                    //                    }
                    DashboardView()
                        .environmentObject(authManager)
                        .environmentObject(
                            InvoiceStore(invoiceService: invoiceService)
                        )
                    // .sheet(isPresented: $showingModal) {
                    //   InvoiceView(
                    //     authManager: authManager, invoice: $sampleInvoice, fileKey: "sample_file_key_123")
                    //   // .environmentObject(authManager)
                    // }
                } else {
                    // If FALSE: Show the login screen.
                    LoginView()
                    // We pass the manager here so the "Sign In" button can call its login() function.
                        .environmentObject(authManager)
                }
            }
            // Handle deep link callbacks from OAuth and registration flows
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
    }
    
    /// Handle deep link URLs for authentication callbacks
    private func handleDeepLink(_ url: URL) {
        print("Deep link received: \(url.absoluteString)")
        
        // Parse the URL components
        guard
            let components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )
        else {
            print("Failed to parse deep link URL")
            return
        }
        
        // Check if this is an auth callback
        // Expected format: com.walterkarabin.tracme://auth/callback?access_token=xxx&refresh_token=yyy
        guard url.scheme == "com.walterkarabin.tracme",
              url.host == "auth" || url.pathComponents.contains("auth"),
              let queryItems = components.queryItems
        else {
            print("Deep link URL does not match expected auth callback format")
            return
        }
        
        // Extract tokens from query parameters
        let accessToken =
        queryItems.first(where: { $0.name == "access_token" })?.value
        ?? queryItems.first(where: { $0.name == "token" })?.value
        
        let refreshToken = queryItems.first(where: {
            $0.name == "refresh_token"
        })?.value
        
        // If we have an access token, attempt auto-login
        if let accessToken = accessToken {
            print("Auto-login with token from deep link")
            let success = authManager.loginWithTokens(
                accessToken: accessToken,
                refreshToken: refreshToken
            )
            if success {
                print("Auto-login successful")
            } else {
                print("Auto-login failed")
            }
        } else {
            print("No access token found in deep link callback")
        }
    }
}
