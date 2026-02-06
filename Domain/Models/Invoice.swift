//
//  Invoice.swift
//  ClientServerBasic
//
//  Created by Walter Karabin on 2026-01-23.
//

import Foundation
//
//// MARK: - Category Model
//struct Category: Identifiable, Codable, Equatable, Hashable {
//  let id: String
//  let categoryId: String
//  var name: String
//  var description: String?
//  let creator: String?
//  let archived: Bool?
//
//  enum CodingKeys: String, CodingKey {
//    case id = "_id"
//    case categoryId = "category_id"
//    case name
//    case description
//    case creator
//    case archived
//  }
//
//  // For creating new categories locally
//  init(
//    id: String = UUID().uuidString, categoryId: String = UUID().uuidString, name: String,
//    description: String? = nil, creator: String? = nil, archived: Bool? = false
//  ) {
//    self.id = id
//    self.categoryId = categoryId
//    self.name = name
//    self.description = description
//    self.creator = creator
//    self.archived = archived
//  }
//
//  static func == (lhs: Category, rhs: Category) -> Bool {
//    lhs.id == rhs.id
//  }
//
//  func hash(into hasher: inout Hasher) {
//    hasher.combine(id)
//  }
//}
//
//// MARK: - File Attachment Model
//struct FileAttachment: Identifiable, Codable, Equatable {
//  let id: String
//  var name: String
//  var type: String
//  var key: String
//  var url: String?
//  let creationDate: Date?
//  let creator: String?
//  let archived: Bool?
//
//  enum CodingKeys: String, CodingKey {
//    case id = "_id"
//    case name
//    case type
//    case key
//    case url
//    case creationDate = "creation_date"
//    case creator
//    case archived
//  }
//
//  // For local file attachments before upload
//  init(
//    id: String = UUID().uuidString, name: String, type: String = "image/jpeg", key: String = "",
//    url: String? = nil, creationDate: Date? = nil, creator: String? = nil, archived: Bool? = false
//  ) {
//    self.id = id
//    self.name = name
//    self.type = type
//    self.key = key
//    self.url = url
//    self.creationDate = creationDate
//    self.creator = creator
//    self.archived = archived
//  }
//
//  static func == (lhs: FileAttachment, rhs: FileAttachment) -> Bool {
//    lhs.id == rhs.id
//  }
//}
//
//// MARK: - Invoice Response Model
//struct InvoiceResponse: Codable {
//  struct Item: Identifiable, Codable, Equatable {
//    let id: UUID
//    var name: String
//    var quantity: Int
//    var price: Double
//    var description: String
//    var date: String
//    var categories: [Category]?
//    var files: [FileAttachment]?
//
//    // Custom init with default UUID
//    init(
//      name: String = "", quantity: Int = 1, price: Double = 0.0, description: String = "",
//      date: String = "", categories: [Category]? = nil, files: [FileAttachment]? = nil
//    ) {
//      self.id = UUID()
//      self.name = name
//      self.quantity = quantity
//      self.price = price
//      self.description = description
//      self.date = date
//      self.categories = categories
//      self.files = files
//    }
//
//    // Include id in equality so SwiftUI diffing can correctly distinguish items.
//    static func == (lhs: Item, rhs: Item) -> Bool {
//      lhs.id == rhs.id && lhs.name == rhs.name && lhs.quantity == rhs.quantity
//        && lhs.price == rhs.price && lhs.description == rhs.description && lhs.date == rhs.date
//        && lhs.categories == rhs.categories
//    }
//
//    enum CodingKeys: String, CodingKey {
//      case id, name, quantity, price, description, date, categories, files
//    }
//
//    init(from decoder: Decoder) throws {
//      let container = try decoder.container(keyedBy: CodingKeys.self)
//      // Try to decode id, or generate one if not present
//      self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
//      self.name = try container.decode(String.self, forKey: .name)
//      self.quantity = try container.decode(Int.self, forKey: .quantity)
//      self.price = try container.decode(Double.self, forKey: .price)
//      self.description = try container.decode(String.self, forKey: .description)
//      self.date = try container.decode(String.self, forKey: .date)
//      self.categories = try container.decodeIfPresent([Category].self, forKey: .categories)
//      self.files = try container.decodeIfPresent([FileAttachment].self, forKey: .files)
//    }
//
//    func encode(to encoder: Encoder) throws {
//      var container = encoder.container(keyedBy: CodingKeys.self)
//      // Don't encode UUID - server doesn't expect it
//      try container.encode(name, forKey: .name)
//      try container.encode(quantity, forKey: .quantity)
//      try container.encode(price, forKey: .price)
//      try container.encode(description, forKey: .description)
//      try container.encode(date, forKey: .date)
//      try container.encodeIfPresent(categories, forKey: .categories)
//      try container.encodeIfPresent(files, forKey: .files)
//    }
//  }
//
//  struct Tax: Identifiable, Codable, Equatable {
//    let id: UUID
//    var taxName: String
//    var amount: Double
//
//    init(taxName: String = "", amount: Double = 0.0) {
//      self.id = UUID()
//      self.taxName = taxName
//      self.amount = amount
//    }
//
//    static func == (lhs: Tax, rhs: Tax) -> Bool {
//      lhs.id == rhs.id && lhs.taxName == rhs.taxName && lhs.amount == rhs.amount
//    }
//
//    enum CodingKeys: String, CodingKey {
//      case id, taxName, amount
//    }
//
//    init(from decoder: Decoder) throws {
//      let container = try decoder.container(keyedBy: CodingKeys.self)
//      self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
//      self.taxName = try container.decode(String.self, forKey: .taxName)
//      self.amount = try container.decode(Double.self, forKey: .amount)
//    }
//
//    func encode(to encoder: Encoder) throws {
//      var container = encoder.container(keyedBy: CodingKeys.self)
//      // Don't encode UUID - server doesn't expect it
//      try container.encode(taxName, forKey: .taxName)
//      try container.encode(amount, forKey: .amount)
//    }
//  }
//
//  // Invoice-level fields (new)
//  var invoiceName: String?
//  var vendor: String?
//
//  // Existing fields
//  var items: [Item]
//  var subTotal: Double
//  var taxesTotal: [Tax]
//  var totalCost: Double
//
//  // Default initializer
//  init(
//    invoiceName: String? = nil, vendor: String? = nil, items: [Item] = [], subTotal: Double = 0,
//    taxesTotal: [Tax] = [], totalCost: Double = 0
//  ) {
//    self.invoiceName = invoiceName
//    self.vendor = vendor
//    self.items = items
//    self.subTotal = subTotal
//    self.taxesTotal = taxesTotal
//    self.totalCost = totalCost
//  }
//}
//
//// MARK: - Derived values
//extension InvoiceResponse {
//  var calculatedSubtotal: Double {
//    items.reduce(0) { $0 + Double($1.quantity) * $1.price }
//  }
//  var calculatedTaxes: Double {
//    taxesTotal.reduce(0) { $0 + $1.amount }
//  }
//  var calculatedTotalCost: Double {
//    calculatedSubtotal + calculatedTaxes
//  }
//  // Returns a copy with updated stored subtotal & total cost reflecting current line items & taxes.
//  func updatingStoredTotals() -> InvoiceResponse {
//    var copy = self
//    copy.subTotal = items.reduce(0) { $0 + Double($1.quantity) * $1.price }
//    copy.totalCost = taxesTotal.reduce(0) { $0 + $1.amount } + copy.subTotal
//    return copy
//  }
//}
//
//struct ProcessResponse: Decodable {
//  let data: InvoiceResponse
//  let valid: Bool
//}
//
//// MARK: - New Invoice Response Model
//struct NewInvoiceResponse: Codable, Identifiable {
//  let id: String
//  let file: String
//  let files: [String]
//  let items: [InvoiceItem]
//  let totalAmount: Double
//  let taxes: [TaxItem]
//  let project: [String]
//  let creationDate: String
//  let creator: String
//  let archived: Bool
//  let date: String
//  let v: Int
//  let name: String?
//  let vendor: String?
//
//  enum CodingKeys: String, CodingKey {
//    case id = "_id"
//    case file
//    case files
//    case items
//    case totalAmount
//    case taxes
//    case project
//    case creationDate = "creation_date"
//    case creator
//    case archived
//    case date
//    case v = "__v"
//    case name
//    case vendor
//  }
//}
//
//// MARK: - Invoice File Model
//struct InvoiceFile: Codable, Identifiable {
//  let id: String
//  let name: String
//  let type: String
//  let key: String
//  let processedInfo: ProcessedInfo
//  let project: String
//  let creationDate: String
//  let creator: String
//  let v: Int
//
//  enum CodingKeys: String, CodingKey {
//    case id = "_id"
//    case name
//    case type
//    case key
//    case processedInfo
//    case project
//    case creationDate = "creation_date"
//    case creator
//    case v = "__v"
//  }
//}
//
//// MARK: - Processed Info Model
//struct ProcessedInfo: Codable {
//  let items: [ProcessedItem]
//  let subTotal: Double
//  let taxesTotal: [TaxItem]
//  let totalCost: Double
//}
//
//// MARK: - Processed Item Model (from file processing)
//struct ProcessedItem: Codable {
//  let name: String
//  let quantity: Int
//  let price: Double
//  let description: String
//  let date: String
//}
//
//// MARK: - Invoice Item Model (full item from database)
//struct InvoiceItem: Codable, Identifiable {
//  let id: String
//  var price: Double
//  var name: String
//  var description: String
//  var categories: [String]  // Category IDs (not populated in invoice list)
//  let project: String
//  var date: String
//  let creationDate: String?
//  let creator: String
//  var files: [String]  // File IDs (not populated in invoice list)
//  let archived: Bool
//  let v: Int
//
//  enum CodingKeys: String, CodingKey {
//    case id = "_id"
//    case price
//    case name
//    case description
//    case categories
//    case project
//    case date
//    case creationDate = "creation_date"
//    case creator
//    case files
//    case archived
//    case v = "__v"
//  }
//}
//
//// MARK: - Tax Item Model
//struct TaxItem: Codable, Identifiable {
//  let id: String
//  var taxName: String
//  var amount: Double
//
//  enum CodingKeys: String, CodingKey {
//    case taxName
//    case amount
//  }
//
//  // For creating new tax items locally
//  init(id: String = UUID().uuidString, taxName: String, amount: Double) {
//    self.id = id
//    self.taxName = taxName
//    self.amount = amount
//  }
//
//  init(from decoder: Decoder) throws {
//    let container = try decoder.container(keyedBy: CodingKeys.self)
//    self.id = UUID().uuidString
//    self.taxName = try container.decode(String.self, forKey: .taxName)
//    self.amount = try container.decode(Double.self, forKey: .amount)
//  }
//
//  func encode(to encoder: Encoder) throws {
//    var container = encoder.container(keyedBy: CodingKeys.self)
//    try container.encode(taxName, forKey: .taxName)
//    try container.encode(amount, forKey: .amount)
//  }
//}

// New Models - manually built
// The model for Invoices
// Codable means going to and from JSON data (necessary for using the API)
struct Invoice: Codable, Identifiable {
  let id = UUID()
  let mongoId: String?
  var name: String?
  var vendor: String?
  // do we need file & files populated?
  var file: String
  var files: [String]
  // I think we need items populated
  // avoid having to do another API call to get the items info
  var items: [Item]
  var totalAmount: Double
  var taxes: [Tax]
  let project: String?
  var date: String
  let creationDate: String
  let creator: String
  var archived: Bool

  enum CodingKeys: String, CodingKey {
    case mongoId = "_id"
    case name
    case vendor
    case file
    case files

    case items

    case totalAmount
    case taxes

    case project
    case date

    case creationDate = "creation_date"
    case creator
    case archived
  }
}

struct Item: Codable, Identifiable {
  let id = UUID()
  let mongoId: String?
  var name: String

  var price: Double
  var quantity: Double?

  var description: String

  var categories: [String]
  let project: String?

  var files: [String]

  var date: String
  let creationDate: String
  let creator: String
  var archived: Bool

  enum CodingKeys: String, CodingKey {
    case mongoId = "_id"
    case name
    case price
    case quantity
    case description

    case categories
    case project

    case date

    case creationDate = "creation_date"
    case creator
    case files

    case archived
  }
}

struct Tax: Codable, Identifiable {
  let id = UUID()
  var taxName: String
  var amount: Double
}

extension Invoice {

  // This computed property returns a clean Date object from your String
  var dateObject: Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: self.date)
  }

  /// Parses `creationDate` (API string) to `Date` for filtering and grouping.
  var creationDateObject: Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = formatter.date(from: creationDate) { return d }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: creationDate)
  }

  // This returns the final String you want to show in the UI
  // e.g., "Jan 10, 2026"
  var displayDate: String {
    guard let date = dateObject else { return "N/A" }

    let displayFormatter = DateFormatter()
    displayFormatter.dateStyle = .medium  // or .short, .long
    displayFormatter.timeStyle = .none
    return displayFormatter.string(from: date)
  }
}
