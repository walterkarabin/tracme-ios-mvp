//
//  GoogleSignInManager.swift
//  ClientServerBasic
//
//  Created by Walter Karabin on 2026-01-23.
//

import SwiftUI
import AuthenticationServices

// GoogleSignInManager handles the OAuth flow with Google
// using ASWebAuthenticationSession
class GoogleSignInManager: NSObject, ObservableObject {

    @Published var authToken: String?
    @Published var refreshToken: String?
    @Published var error: Error?
    @Published var errorId = UUID() // Used to trigger UI updates when error changes
    @Published var isAuthenticating = false

    private var authSession: ASWebAuthenticationSession?

    // The callback URL scheme that matches our Info.plist configuration
    private let callbackURLScheme = "com.walterkarabin.tracme"

    // Initiate Google OAuth flow
    func signInWithGoogle() {
        // Get API host from Info.plist
        guard let apiHost = Bundle.main.object(forInfoDictionaryKey: "ApiHost") as? String else {
            self.error = GoogleSignInError.missingConfiguration
            self.errorId = UUID()
            return
        }

        // Construct the Google OAuth URL with client parameter
        // The backend will know to redirect to the iOS app based on client=ios
        guard let url = URL(string: "\(apiHost)/api/auth/google?client=ios") else {
            self.error = GoogleSignInError.invalidURL
            self.errorId = UUID()
            return
        }

        let expectedCallbackURI = "\(callbackURLScheme)://auth/callback"
        print("GoogleSignInManager: Starting OAuth with URL: \(url.absoluteString)")
        print("GoogleSignInManager: Expecting callback to: \(expectedCallbackURI)")

        isAuthenticating = true
        error = nil

        // Create authentication session
        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackURLScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }

            self.isAuthenticating = false

            if let error = error {
                // Check if user cancelled
                if case ASWebAuthenticationSessionError.canceledLogin = error {
                    print("GoogleSignInManager: User cancelled sign-in")
                    self.error = GoogleSignInError.userCancelled
                } else {
                    print("GoogleSignInManager: Authentication error: \(error.localizedDescription)")
                    self.error = error
                }
                self.errorId = UUID()
                return
            }

            // Parse the callback URL to extract tokens
            if let callbackURL = callbackURL {
                print("GoogleSignInManager: Received callback URL: \(callbackURL.absoluteString)")
                self.parseCallback(url: callbackURL)
            } else {
                print("GoogleSignInManager: No callback URL received")
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
            print("GoogleSignInManager: Failed to parse callback URL components")
            self.error = GoogleSignInError.invalidCallback
            self.errorId = UUID()
            return
        }

        // Extract tokens from query parameters
        // Expected format: com.walterkarabin.tracme://auth/callback?access_token=xxx&refresh_token=yyy
        // or: com.walterkarabin.tracme://auth/callback?token=xxx (if backend returns single token)
        let queryItems = components.queryItems ?? []
        print("GoogleSignInManager: Callback query items: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: ", "))")

        if let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value {
            print("GoogleSignInManager: Successfully extracted access_token")
            self.authToken = accessToken
            self.refreshToken = queryItems.first(where: { $0.name == "refresh_token" })?.value
            if self.refreshToken != nil {
                print("GoogleSignInManager: Successfully extracted refresh_token")
            }
        } else if let token = queryItems.first(where: { $0.name == "token" })?.value {
            // If backend returns a single token parameter
            print("GoogleSignInManager: Successfully extracted token")
            self.authToken = token
        } else {
            print("GoogleSignInManager: No token found in callback URL")
            self.error = GoogleSignInError.missingToken
            self.errorId = UUID()
        }
    }

    // Cancel ongoing authentication
    func cancel() {
        authSession?.cancel()
        isAuthenticating = false
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension GoogleSignInManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the main window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Error Types
enum GoogleSignInError: LocalizedError {
    case missingConfiguration
    case invalidURL
    case invalidCallback
    case missingToken
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "API configuration is missing"
        case .invalidURL:
            return "Invalid authentication URL"
        case .invalidCallback:
            return "Invalid callback URL"
        case .missingToken:
            return "No authentication token received"
        case .userCancelled:
            return "Sign in was cancelled"
        }
    }
}
