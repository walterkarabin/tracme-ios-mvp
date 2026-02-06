//
//  LoginView.swift
//  tracme-alpha
//
//  Created by Walter Karabin on 2026-01-23.
//

import SwiftUI

struct LoginView: View {
    
    // 1. Get the AuthManager from the environment
    @EnvironmentObject private var authManager: AuthManager
    // Environment helper for opening URLs
    @Environment(\.openURL) private var openURL
    
    @State private var username = ""
    @State private var password = ""
    
    // 2. Add state to show a loading spinner
    @State private var isLoggingIn = false
    // State for showing error alert
    @State private var showLoginError = false
    @State private var loginErrorMessage = "Unable to sign in. Please try again later."
    
    // In-app browser states
    @StateObject private var googleSignInManager = GoogleSignInManager()
    @StateObject private var registrationManager = RegistrationManager()
    
    var body: some View {
        VStack(spacing: 20) {
            
            Spacer()
            Text("Login")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 30)
            
            
            TextField("Username or Email", text: $username)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Spacer()
                .frame(height: 20)
            
            // 3. Update the Button action and label
            Button {
                // Run the async login function in a new Task
                Task {
                    isLoggingIn = true
                    // Call the manager's login function and check result
                    let success = await authManager.login(username: username, password: password)
                    isLoggingIn = false
                    // If login failed, show error
                    if !success {
                        // Show specific message for server error
                        if let lastError = AuthManager.lastLoginError, lastError == .serverError {
                            loginErrorMessage = "Server error. Please try again later."
                        } else {
                            loginErrorMessage =
                            "Unable to login. Please check your credentials or try again later."
                        }
                        showLoginError = true
                    }
                }
            } label: {
                ZStack {
                    // Full-size capsule for hit area
                    Capsule()
                        .fill(Color.blue)
                    // Spinner or text
                    if isLoggingIn {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Login")
                            .fontWeight(.semibold)
                    }
                }
                // Fixed height to prevent vertical expansion
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundColor(.white)
                .contentShape(Capsule())  // Ensures entire capsule is tappable
            }
            .buttonStyle(.plain)  // Prevent default styling overriding our layout
            .disabled(isLoggingIn || username.isEmpty || password.isEmpty)
            .animation(.default, value: isLoggingIn)
            .padding(.horizontal)
            
            // Google Sign-In button
            Button {
                googleSignInManager.signInWithGoogle()
            } label: {
                HStack {
                    Image(systemName: "globe")
                    Text("Sign in with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundColor(.white)
                .background(Color(red: 0.26, green: 0.52, blue: 0.96))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(googleSignInManager.isAuthenticating)
            .padding(.horizontal)
            
            // In-app registration button
            HStack {
                Button {
                    registrationManager.startRegistration()
                } label: {
                    Text("Sign Up")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.85, green: 0.95, blue: 0.85))  // Pastel green
                        .clipShape(Capsule())
                        .accessibilityLabel("Sign Up")
                }
                .disabled(registrationManager.isRegistering)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            
            Spacer()
        }
        .padding()
        // Show alert if login failed
        .alert("Login failed", isPresented: $showLoginError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginErrorMessage)
        }
        // Handle Google Sign-In success
        .onChange(of: googleSignInManager.authToken) { oldValue, newValue in
            if let token = newValue {
                print("LoginView: Received auth token from Google Sign-In")
                // Auto-login with the received token
                let success = authManager.loginWithTokens(
                    accessToken: token,
                    refreshToken: googleSignInManager.refreshToken
                )
                if success {
                    print("LoginView: Auto-login successful")
                } else {
                    print("LoginView: Auto-login failed")
                    loginErrorMessage = "Failed to login with Google. Please try again."
                    showLoginError = true
                }
            }
        }
        // Handle Google Sign-In errors
        .onChange(of: googleSignInManager.errorId) { _, _ in
            if let error = googleSignInManager.error {
                // Only show error if not user cancellation
                if case GoogleSignInError.userCancelled = error {
                    // User cancelled, don't show error
                    return
                }
                loginErrorMessage = error.localizedDescription
                showLoginError = true
            }
        }
        // Handle Registration success
        .onChange(of: registrationManager.authToken) { oldValue, newValue in
            if let token = newValue {
                print("LoginView: Received auth token from registration")
                // Auto-login with the received token
                let success = authManager.loginWithTokens(
                    accessToken: token,
                    refreshToken: registrationManager.refreshToken
                )
                if success {
                    print("LoginView: Auto-login after registration successful")
                } else {
                    print("LoginView: Auto-login after registration failed")
                    loginErrorMessage = "Registration successful but auto-login failed. Please log in manually."
                    showLoginError = true
                }
            }
        }
        // Handle Registration errors
        .onChange(of: registrationManager.errorId) { _, _ in
            if let error = registrationManager.error {
                // Only show error if not user cancellation
                if case RegistrationError.userCancelled = error {
                    // User cancelled, don't show error
                    return
                }
                loginErrorMessage = error.localizedDescription
                showLoginError = true
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())  // Add this to preview to prevent crashes
}
