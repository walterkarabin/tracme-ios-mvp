import Foundation

class InvoiceService {
  let authManager: AuthManager
  let apiClient: APIClient
  var errorMessage: String? = nil

  init(authManager: AuthManager) {
    self.authManager = authManager
    self.apiClient = APIClient(authProvider: authManager)
  }

  // MARK: - Get Invoices
  func getInvoices(projectId: String? = nil) async -> [Invoice] {
    print("InvoiceService: Fetching invoices from API.")
    var endpoint = AppEnvironment.apiHost.appendingPathComponent("/api/invoices")
    if let projectId = projectId {
      endpoint = endpoint.appendingPathComponent("?projectId=\(projectId)")
    }

    do {
      let invoices: [Invoice] = try await apiClient.request(
        endpoint: endpoint,
        method: "GET",
        responseType: [Invoice].self
      )
      return invoices
    } catch {
      errorMessage = "Error fetching invoices: \(error.localizedDescription)"
      return []
    }
  }

  /// GET /api/invoices/:id – fetch a single invoice by id.
  func getInvoice(id: String) async -> Invoice? {
    let endpoint = AppEnvironment.apiHost.appendingPathComponent("/api/invoices/\(id)")
    do {
      let invoice: Invoice = try await apiClient.request(
        endpoint: endpoint,
        method: "GET",
        responseType: Invoice.self
      )
      return invoice
    } catch {
      errorMessage = "Error fetching invoice: \(error.localizedDescription)"
      return nil
    }
  }

  // MARK: - Update Invoice
    func updateInvoice(_ invoice: Invoice) async -> Invoice? {
        guard let mongoId = invoice.mongoId else {
            errorMessage = "Invoice has no mongoId; cannot update."
            return nil
        }
        print("InvoiceService: Updating invoice with ID \(mongoId).")
        let endpoint = AppEnvironment.apiHost.appendingPathComponent("/api/invoices/\(mongoId)")
        do {
            let body = try JSONEncoder().encode(invoice)
            let response: InvoiceDTO = try await apiClient.request(
                endpoint: endpoint,
                method: "PUT",
                body: body,
                responseType: InvoiceDTO.self
            )
            
            print("updateInvoice: \(response)")
            
            let updatedInvoice: Invoice = response.invoice
            return updatedInvoice
        } catch {
            errorMessage = "Error updating invoice: \(error.localizedDescription)"
            return nil
        }
    }
    
    func createInvoice(_ invoice: Invoice) async -> Invoice? {
        print("InvoiceService: Creating invoice.")
        let endpoint = AppEnvironment.apiHost.appendingPathComponent("/api/invoices")
        do {
            let body = try JSONEncoder().encode(invoice)
            let createdInvoice: Invoice = try await apiClient.request(
                endpoint: endpoint,
                method: "POST",
                body: body,
                responseType: Invoice.self
            )
            return createdInvoice
        }
        catch {
            errorMessage = "Error creating invoice: \(error.localizedDescription)"
            return nil
        }
    }
}

struct InvoiceDTO: Codable {
    var invoice: Invoice
    var message: String
    var error: Bool?
}
