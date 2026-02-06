//
//  RegistrationManager.swift
//  tracme-alpha
//
//  Created by Walter Karabin on 2026-01-23.
//

import AuthenticationServices
import SwiftUI

// RegistrationManager handles the registration flow with token callback
// using ASWebAuthenticationSession
class RegistrationManager: NSObject, ObservableObject {
    
    @Published var authToken: String?
    @Published var refreshToken: String?
    @Published var error: Error?
    @Published var errorId = UUID()  // Used to trigger UI updates when error changes
    @Published var isRegistering = false
    
    private var authSession: ASWebAuthenticationSession?
    
    // The callback URL scheme that matches our Info.plist configuration
    private let callbackURLScheme = "com.walterkarabin.tracme"
    
    // Start registration flow
    func startRegistration() {
        // Get signup URL from Info.plist
        guard let signupURLString = Bundle.main.object(forInfoDictionaryKey: "SignupURL") as? String
        else {
            self.error = RegistrationError.missingConfiguration
            self.errorId = UUID()
            return
        }
        
        // Add client parameter to tell backend this is iOS registration
        guard let url = URL(string: "\(signupURLString)") else {
            self.error = RegistrationError.invalidURL
            self.errorId = UUID()
            return
        }
        
        let expectedCallbackURI = "\(callbackURLScheme)://auth/callback"
        print("RegistrationManager: Starting registration with URL: \(url.absoluteString)")
        print("RegistrationManager: Expecting callback to: \(expectedCallbackURI)")
        
        isRegistering = true
        error = nil
        
        // Create authentication session
        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackURLScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            self.isRegistering = false
            
            if let error = error {
                // Check if user cancelled
                if case ASWebAuthenticationSessionError.canceledLogin = error {
                    print("RegistrationManager: User cancelled registration")
                    self.error = RegistrationError.userCancelled
                } else {
                    print("RegistrationManager: Registration error: \(error.localizedDescription)")
                    self.error = error
                }
                self.errorId = UUID()
                return
            }
            
            // Parse the callback URL to extract tokens
            if let callbackURL = callbackURL {
                print("RegistrationManager: Received callback URL: \(callbackURL.absoluteString)")
                self.parseCallback(url: callbackURL)
            } else {
                print("RegistrationManager: No callback URL received")
            }
        }
        
        // Important: Set presentation context provider
        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false
        
        // Start the authentication session
        authSession?.start()
    }
    
    // Parse tokens from callback URL
    private func parseCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("RegistrationManager: Failed to parse callback URL components")
            self.error = RegistrationError.invalidCallback
            self.errorId = UUID()
            return
        }
        
        // Extract tokens from query parameters
        // Expected format: com.walterkarabin.tracme://auth/callback?access_token=xxx&refresh_token=yyy
        // or: com.walterkarabin.tracme://auth/callback?token=xxx (if backend returns single token)
        let queryItems = components.queryItems ?? []
        print(
            "RegistrationManager: Callback query items: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: ", "))"
        )
        
        if let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value {
            print("RegistrationManager: Successfully extracted access_token")
            self.authToken = accessToken
            self.refreshToken = queryItems.first(where: { $0.name == "refresh_token" })?.value
            if self.refreshToken != nil {
                print("RegistrationManager: Successfully extracted refresh_token")
            }
        } else if let token = queryItems.first(where: { $0.name == "token" })?.value {
            // If backend returns a single token parameter
            print("RegistrationManager: Successfully extracted token")
            self.authToken = token
        } else {
            print("RegistrationManager: No token found in callback URL")
            self.error = RegistrationError.missingToken
            self.errorId = UUID()
        }
    }
    
    // Cancel ongoing registration
    func cancel() {
        authSession?.cancel()
        isRegistering = false
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension RegistrationManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the main window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Error Types
enum RegistrationError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case invalidCallback
    case missingToken
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Registration URL is missing from configuration"
        case .invalidURL:
            return "Invalid registration URL"
        case .invalidCallback:
            return "Invalid callback URL"
        case .missingToken:
            return "No authentication token received after registration"
        case .userCancelled:
            return "Registration was cancelled"
        }
    }
}
