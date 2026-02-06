//
//  ItemService.swift
//  ClientServerBasic
//

import Foundation

class ItemService {
  let authManager: AuthManager
  let apiClient: APIClient
  var errorMessage: String?

  init(authManager: AuthManager) {
    self.authManager = authManager
    self.apiClient = APIClient(authProvider: authManager)
  }

  private var itemsBase: URL {
    AppEnvironment.apiHost.appendingPathComponent("/api/items")
  }

  // MARK: - Get Items

  /// GET /items/invoice/:invoice_id
  func getItems(invoiceId: String) async -> [Item] {
    print("ItemService: Fetching items from API by invoiceId: \(invoiceId).")
    let endpoint = itemsBase.appendingPathComponent("invoice").appendingPathComponent(invoiceId)
    return await fetchItems(endpoint: endpoint, label: "invoice \(invoiceId)")
  }

  /// GET /items/project/:project_id
  func getItems(projectId: String) async -> [Item] {
    print("ItemService: Fetching items from API by projectId: \(projectId).")
    let endpoint = itemsBase.appendingPathComponent("project").appendingPathComponent(projectId)
    return await fetchItems(endpoint: endpoint, label: "project \(projectId)")
  }

  /// GET /items/:item_id
  func getItem(itemId: String) async -> Item? {
    print("ItemService: Fetching item from API by itemId: \(itemId).")
    let endpoint = itemsBase.appendingPathComponent(itemId)
    do {
      let item: Item = try await apiClient.request(
        endpoint: endpoint,
        method: "GET",
        responseType: Item.self
      )
      return item
    } catch {
      errorMessage = "Error fetching item: \(error.localizedDescription)"
      return nil
    }
  }

  private func fetchItems(endpoint: URL, label: String) async -> [Item] {
    do {
      print("ItemService: Fetching items from API by endpoint: \(endpoint).")
      let items: [Item] = try await apiClient.request(
        endpoint: endpoint,
        method: "GET",
        responseType: [Item].self
      )
      return items
    } catch {
      errorMessage = "Error fetching items for \(label): \(error.localizedDescription)"
      return []
    }
  }

  // MARK: - Create Item

  /// POST /items
  func createItem(_ item: Item) async -> Item? {
    let endpoint = itemsBase
    do {
      let body = try JSONEncoder().encode(item)
      let created: Item = try await apiClient.request(
        endpoint: endpoint,
        method: "POST",
        body: body,
        responseType: Item.self
      )
      return created
    } catch {
      errorMessage = "Error creating item: \(error.localizedDescription)"
      return nil
    }
  }

  // MARK: - Update Item

  /// PUT /items/:item_id
  func updateItem(_ item: Item) async -> Item? {
    guard let itemId = item.mongoId else {
      errorMessage = "Item has no mongoId; cannot update."
      return nil
    }
    let endpoint = itemsBase.appendingPathComponent(itemId)
    do {
      let body = try JSONEncoder().encode(item)
      let updated: Item = try await apiClient.request(
        endpoint: endpoint,
        method: "PUT",
        body: body,
        responseType: Item.self
      )
      return updated
    } catch {
      errorMessage = "Error updating item: \(error.localizedDescription)"
      return nil
    }
  }

  // MARK: - Delete Item

  /// DELETE /items/:item_id
  func deleteItem(itemId: String) async -> Bool {
    let endpoint = itemsBase.appendingPathComponent(itemId)
    do {
      _ = try await apiClient.request(
        endpoint: endpoint,
        method: "DELETE",
        body: nil,
        responseType: DeleteResponse.self
      )
      return true
    } catch {
      errorMessage = "Error deleting item: \(error.localizedDescription)"
      return false
    }
  }
}

/// Use when API returns JSON body for DELETE (e.g. { "ok": true }). If API returns 204 No Content, APIClient would need a variant that accepts empty response.
private struct DeleteResponse: Codable {
  var ok: Bool?
  var deleted: Bool?
}
