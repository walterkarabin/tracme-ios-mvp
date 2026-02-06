//
//  InvoicesListView.swift
//  ClientServerBasic
//

import SwiftUI

struct InvoicesListView: View {
    @EnvironmentObject private var invoiceStore: InvoiceStore
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && invoiceStore.invoices.isEmpty {
                ProgressView("Loading invoices…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Unable to Load Invoices", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadInvoices() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if invoiceStore.invoices.isEmpty {
                ContentUnavailableView(
                    "No Invoices",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Invoices will appear here once you add them.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(invoiceStore.invoices) { invoice in
                        NavigationLink {
                            InvoiceView(
                                invoice: invoice,
                                onDismiss: nil,
                                onSave: { updated in
                                    await invoiceStore.updateInvoice(updated)
                                }
                            )
                        } label: {
                            InvoiceCard(invoice: invoice)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Invoices")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await loadInvoices()
        }
        .task {
            await loadInvoices()
        }
    }

    private func loadInvoices() async {
        isLoading = true
        errorMessage = nil
        await invoiceStore.getInvoices()
        isLoading = false
        // Optionally set errorMessage if invoices failed to load (InvoiceStore doesn't expose errors yet)
    }
}

#Preview {
    NavigationStack {
        InvoicesListView()
            .environmentObject(InvoiceStore(invoiceService: InvoiceService(authManager: AuthManager()), itemService: ItemService(authManager: AuthManager())))
    }
}
