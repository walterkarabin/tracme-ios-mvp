//
//  AuthManagerModel.swift
//  tracme-alpha
//
//  Created by Walter Karabin on 2026-01-23.
//

import Combine
import KeychainAccess
import SwiftUI

// --- Helper for reading variables from your Info.plist ---
// Renamed from `Environment` to avoid shadowing SwiftUI's `@Environment` property wrapper.
enum AppEnvironment {
  // Private closure to load the dictionary once
  private static let infoDictionary: [String: Any] = {
    guard let dict = Bundle.main.infoDictionary else {
      fatalError("Info.plist file not found")
    }
    return dict
  }()

  // Static variable to get the API host URL
  static let apiHost: URL = {
    guard let apiHostString = AppEnvironment.infoDictionary["ApiHost"] as? String else {
      fatalError("ApiHost not set in Info.plist for this environment")
    }
    // Ensure the string can be converted to a valid URL
    guard let url = URL(string: apiHostString) else {
      fatalError("ApiHost URL is not valid")
    }
    return url
  }()
}

// --- NEW: A struct to decode the server's JSON response ---
struct LoginResponse: Codable {
  let accessToken: String
  let refreshToken: String

  // Map snake_case keys from JSON to camelCase properties
  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
  }
}

class AuthManager: ObservableObject, AuthProvider {
    static let shared = AuthManager()
    
  // Track last login error type
  enum LoginErrorType {
    case serverError, unauthorized, network, unknown
  }
  static var lastLoginError: LoginErrorType? = nil
  // MARK: - AuthProvider Protocol
  var accessToken: String? {
    try? keychain.get("access_token")
  }
  var refreshToken: String? {
    try? keychain.get("refresh_token")
  }

  /// Calls the refresh endpoint to obtain new tokens and updates the keychain.
  @MainActor
  func refreshAccessToken() async -> Bool {
    guard let refreshToken = self.refreshToken else {
      print("AuthManager: No refresh token available.")
      return false
    }
    let endpoint = AppEnvironment.apiHost.appendingPathComponent("/api/refresh")
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body = ["refresh_token": refreshToken]
    do {
      request.httpBody = try JSONEncoder().encode(body)
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        print(
          "AuthManager: Failed to refresh token, status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
        )
        return false
      }
      let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
      try keychain.set(loginResponse.accessToken, key: "access_token")
      try keychain.set(loginResponse.refreshToken, key: "refresh_token")
      print("AuthManager: Successfully refreshed tokens.")
      return true
    } catch {
      print("AuthManager Error: Failed to refresh token - \(error.localizedDescription)")
      return false
    }
  }

  func removeAccessToken() {
    do {
      try keychain.remove("access_token")
      try keychain.remove("user_identifier")
      print("AuthManager: Access token removed from Keychain.")
      self.isAuthenticated = false
      self.currentUserIdentifier = nil

      // Notify the app that the user has logged out
      DispatchQueue.main.async {
        NotificationCenter.default.post(name: Notification.Name("UserDidLogout"), object: nil)
      }
    } catch {
      print("AuthManager Error: Failed to remove access token - \(error.localizedDescription)")
    }
  }

  @Published var isAuthenticated: Bool = false
  @Published var currentUserIdentifier: String? = nil

  // --- NEW: Set up a secure keychain vault for your app ---
  // The service name should be unique to your app, like its bundle ID.
  private let keychain = Keychain(service: "com.coolbeans.demoapp")

  init() {
    // for now, we won't check the initial auth state to avoid complications during testing
    checkInitialAuthState()
  }

  /// Checks the keychain for an existing token to determine if the user is already logged in.
  func checkInitialAuthState() {
    // Try to retrieve the access token. If it exists, the user is authenticated.
    if (try? keychain.get("access_token")) != nil {
      DispatchQueue.main.async {
        self.isAuthenticated = true
        // Also load the current user identifier
        if let userIdentifier = try? self.keychain.get("user_identifier") {
          self.currentUserIdentifier = userIdentifier
        }
        // print("AuthManager: User is already authenticated.")
      }
    } else {
      print("AuthManager: No existing token found. User needs to log in.")
    }
  }

  /// Login with pre-obtained tokens (used for OAuth and registration auto-login)
  @MainActor
  func loginWithTokens(
    accessToken: String, refreshToken: String? = nil, userIdentifier: String? = nil
  ) -> Bool {
    do {
      // Store the access token
      try keychain.set(accessToken, key: "access_token")

      // Store the refresh token if provided
      if let refreshToken = refreshToken {
        try keychain.set(refreshToken, key: "refresh_token")
      }

      // Store the user identifier if provided
      if let userIdentifier = userIdentifier {
        try keychain.set(userIdentifier, key: "user_identifier")
        self.currentUserIdentifier = userIdentifier
      }

      print("AuthManager: Login success with provided tokens. Tokens securely stored in Keychain.")
      self.isAuthenticated = true
      AuthManager.lastLoginError = nil
      return true
    } catch {
      print("AuthManager Error: Failed to save tokens - \(error.localizedDescription)")
      AuthManager.lastLoginError = .unknown
      return false
    }
  }

  @MainActor
  func login(username: String, password: String) async -> Bool {
    print("AuthManager: Attempting login with \(username) to host: \(AppEnvironment.apiHost)")

    let endpoint = AppEnvironment.apiHost.appendingPathComponent("/api/login")
    print("AuthManager: Full request URL will be \(endpoint.absoluteString)")

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let credentials = ["email": username, "password": password]

    do {
      request.httpBody = try JSONEncoder().encode(credentials)
    } catch {
      print("AuthManager Error: Failed to encode credentials - \(error.localizedDescription)")
      return false
    }

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      // --- Refactored Response Handling ---
      guard let httpResponse = response as? HTTPURLResponse else {
        print("AuthManager Error: Invalid response from server.")
        return false
      }

      // Print the raw server response for debugging
      if let responseString = String(data: data, encoding: .utf8) {
        print("AuthManager: Server Response -> \(responseString)")
      }

      switch httpResponse.statusCode {
      case 200:
        // --- NEW: Decode the JSON and save tokens to Keychain ---
        do {
          let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)

          // Securely save the tokens
          try keychain.set(loginResponse.accessToken, key: "access_token")
          try keychain.set(loginResponse.refreshToken, key: "refresh_token")

          // Store the user identifier (username/email)
          try keychain.set(username, key: "user_identifier")
          self.currentUserIdentifier = username
          print("AuthManager: User identifier set to \(username)")

          print("AuthManager: Login success. Tokens securely stored in Keychain.")
          self.isAuthenticated = true
          AuthManager.lastLoginError = nil
        } catch {
          print(
            "AuthManager Error: Failed to decode or save tokens - \(error.localizedDescription)")
          AuthManager.lastLoginError = .unknown
          return false
        }
        return true

      case 401:
        print("AuthManager Error: Unauthorized. Please check your username and password.")
        AuthManager.lastLoginError = .unauthorized
        return false
      case 500...599:
        print("AuthManager Error: Server error (Status code: \(httpResponse.statusCode)).")
        AuthManager.lastLoginError = .serverError
        return false
      default:
        print("AuthManager Error: Unexpected status code \(httpResponse.statusCode).")
        AuthManager.lastLoginError = .unknown
        return false
      }

    } catch {
      print("AuthManager Error: Network request failed - \(error.localizedDescription)")
      print("\n\n\(error)")
      AuthManager.lastLoginError = .network
      return false
    }
  }

  // --- NEW: Function to log the user out ---
  @MainActor
  func logout() {
    do {
      // Remove both tokens from the secure keychain
      try keychain.remove("access_token")
      try keychain.remove("refresh_token")
      try keychain.remove("user_identifier")
      print("AuthManager: Tokens removed from Keychain.")
    } catch {
      print("AuthManager Error: Failed to remove tokens - \(error.localizedDescription)")
    }

    self.isAuthenticated = false
    self.currentUserIdentifier = nil
  }
}
