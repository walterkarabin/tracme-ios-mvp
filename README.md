# Project Structure

```
MyClientServerApp
├── App
│   ├── MyApp.swift              // Entry point (@main)
│   └── AppState.swift           // Global state (like 'isLoggedIn')
│
├── Core                         // Shared code used everywhere
│   ├── Networking
│   │   ├── APIClient.swift      // The actual URLSession wrapper
│   │   ├── APIEndpoint.swift    // Enums for your URLs
│   │   └── HTTPError.swift      // Error handling logic
│   ├── Storage
│   │   └── KeychainManager.swift
│   ├── Extensions               // String+, View+, Date+ helpers
│   └── UIComponents             // Reusable buttons, cards, loaders
│
├── Features                     // The main screens of your app
│   ├── Authentication           // FEATURE: Login/Signup
│   │   ├── AuthViewModel.swift
│   │   ├── LoginView.swift
│   │   ├── SignupView.swift
│   │   └── AuthResponse.swift   // Specific DTO for auth
│   │
│   ├── UserProfile              // FEATURE: Profile
│   │   ├── ProfileViewModel.swift
│   │   ├── ProfileView.swift
│   │   └── EditProfileView.swift
│   │
│   └── Dashboard                // FEATURE: Home Feed
│       ├── DashboardViewModel.swift
│       └── DashboardView.swift
│
├── Domain                       // The "Truth" of your app
│   ├── Models                   // Shared Structs
│   │   ├── User.swift
│   │   └── Post.swift
│   └── Protocols                // Interfaces for dependency injection
│
└── Resources
    ├── Assets.xcassets          // Images and Colors
    └── Info.plist
```


