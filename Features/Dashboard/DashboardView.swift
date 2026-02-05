//
//  DashboardView.swift
//  ClientServerBasic
//
//  Created by Walter Karabin on 2026-01-23.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var invoiceStore: InvoiceStore

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Image OCR", destination: ImageView(invoiceStore: invoiceStore))
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(InvoiceStore(invoiceService: InvoiceService(authManager: AuthManager())))
}
