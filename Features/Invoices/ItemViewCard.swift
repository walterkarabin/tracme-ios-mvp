//
//  ItemViewCard.swift
//  ClientServerBasic
//
//  Styled with a Wealthsimple-inspired look: minimal, warm, amount-forward.
//

import SwiftUI

// Wealthsimple-style accent (warm green)
private let wsGreen = Color(red: 29/255, green: 185/255, blue: 84/255)

struct ItemViewCard: View {
    let item: Item
    /// When true, uses tighter padding and spacing for use in lists (e.g. InvoiceView line items).
    var compact: Bool = false

    private var cardPadding: CGFloat { compact ? 14 : 20 }
    private var namePriceSpacing: CGFloat { compact ? 8 : 12 }
    private var cornerRadius: CGFloat { compact ? 12 : 16 }
    private var shadowRadius: CGFloat { compact ? 6 : 8 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: name and price (amount forward)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    Text(item.name.isEmpty ? "Item" : item.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(compact ? 1 : 2)
                    }
                }
                Spacer(minLength: compact ? 8 : 12)
                Text(formatPrice(item.price))
                    .font(compact ? .headline : .title2)
                    .fontWeight(.bold)
                    .foregroundStyle(wsGreen)
            }
            .padding(.bottom, compact ? 8 : 12)

            // Meta: quantity and date
            HStack(spacing: 4) {
                if let qty = item.quantity, qty != 1 {
                    Text("Qty \(formatQuantity(qty))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if !item.date.isEmpty || !item.creationDate.isEmpty {
                    if item.quantity != nil && item.quantity != 1 {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(displayDate)
                        .font(.caption)
                }
            }
            .foregroundStyle(.tertiary)
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: shadowRadius, x: 0, y: 2)
    }

    private var displayDate: String {
        if !item.date.isEmpty, let date = itemDateObject(from: item.date) {
            let f = DateFormatter()
            f.dateStyle = .short
            return f.string(from: date)
        }
        if !item.creationDate.isEmpty, let date = itemDateObject(from: item.creationDate) {
            let f = DateFormatter()
            f.dateStyle = .short
            return f.string(from: date)
        }
        return item.date.isEmpty ? item.creationDate : item.date
    }

    private func itemDateObject(from dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: dateString) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    private func formatPrice(_ value: Double) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .currency)
    }

    private func formatQuantity(_ value: Double) -> String {
        value == floor(value) ? "\(Int(value))" : String(format: "%.2f", value)
    }
}

#Preview {
    let item = Item(
        mongoId: nil,
        name: "Consulting",
        price: 99.50,
        quantity: 2,
        description: "Hourly rate",
        categories: [],
        project: nil,
        files: [],
        date: ISO8601DateFormatter().string(from: Date()),
        creationDate: ISO8601DateFormatter().string(from: Date()),
        creator: "",
        archived: false
    )
    return ItemViewCard(item: item)
        .padding()
}
