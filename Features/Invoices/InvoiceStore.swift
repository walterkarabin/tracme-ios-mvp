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
  let itemService: ItemService

  init(invoiceService: InvoiceService, itemService: ItemService) {
    self.invoiceService = invoiceService
    self.itemService = itemService
  }

  func getInvoices() async {
    invoices = await invoiceService.getInvoices()
  }

  /// Appends a newly created invoice (e.g. from ImageStore after OCR/upload) to the local list.
  func addInvoice(_ invoice: Invoice) {
    invoices.append(invoice)
  }

  func updateInvoice(_ invoice: Invoice) async {
    guard let updatedInvoice = await invoiceService.updateInvoice(invoice) else {
      print("Failed to update invoice")
      return
    }
    if let index = invoices.firstIndex(where: { $0.mongoId == updatedInvoice.mongoId }) {
      invoices[index] = updatedInvoice
    }
  }

  // MARK: - Items (delegate to ItemService)

  /// GET /items/invoice/:invoice_id
  func getItems(invoiceId: String) async -> [Item] {
    await itemService.getItems(invoiceId: invoiceId)
  }

  /// GET /items/project/:project_id
  func getItems(projectId: String) async -> [Item] {
    await itemService.getItems(projectId: projectId)
  }

  /// GET /items/:item_id
  func getItem(itemId: String) async -> Item? {
    await itemService.getItem(itemId: itemId)
  }

  /// POST /items
  func createItem(_ item: Item) async -> Item? {
    await itemService.createItem(item)
  }

  /// PUT /items/:item_id
  func updateItem(_ item: Item) async -> Item? {
    await itemService.updateItem(item)
  }

  /// DELETE /items/:item_id
  func deleteItem(itemId: String) async -> Bool {
    await itemService.deleteItem(itemId: itemId)
  }
}
