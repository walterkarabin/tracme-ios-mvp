//
//  InvoiceStore.swift
//  ClientServerBasic
//
//  Created by Walter Karabin on 2026-01-23.
//

import Foundation

@MainActor
class InvoiceStore: ObservableObject {
  @Published var invoices: [Invoice] = []
  let invoiceService: InvoiceService

  init(invoiceService: InvoiceService) {
    self.invoiceService = invoiceService
  }

  func getInvoices() async {
    self.invoices = await invoiceService.getInvoices()
  }

  /// Appends a newly created invoice (e.g. from ImageStore after OCR/upload) to the local list.
  func addInvoice(_ invoice: Invoice) {
    invoices.append(invoice)
  }

  func updateInvoice(_ invoice: Invoice) async {
    // Update the invoice using the service
    guard let updatedInvoice = await invoiceService.updateInvoice(invoice) else {
      print("Failed to update invoice")
      return
    }
    // Find the index of the invoice to be updated
    if let index = invoices.firstIndex(where: { $0.id == updatedInvoice.id }) {
      invoices[index] = updatedInvoice
    }
  }
}
