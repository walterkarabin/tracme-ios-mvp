//
//  SafariView.swift
//  ClientServerBasic
//
//  Created by Walter Karabin on 2026-01-23.
//

import SafariServices
import SwiftUI

// SafariView wraps SFSafariViewController to provide in-app browser functionality
// for the registration flow
struct SafariView: UIViewControllerRepresentable {

  let url: URL
  @Binding var isPresented: Bool

  func makeUIViewController(context: Context) -> SFSafariViewController {
    let config = SFSafariViewController.Configuration()
    config.entersReaderIfAvailable = false

    let safari = SFSafariViewController(url: url, configuration: config)
    print("LoginView: Opening registration URL: \(url)")
    safari.delegate = context.coordinator
    safari.preferredControlTintColor = .systemBlue

    return safari
  }

  func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    // No updates needed
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  class Coordinator: NSObject, SFSafariViewControllerDelegate {
    var parent: SafariView

    init(parent: SafariView) {
      self.parent = parent
    }

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
      // User dismissed the Safari view (tapped "Done")
      parent.isPresented = false
    }
  }
}
