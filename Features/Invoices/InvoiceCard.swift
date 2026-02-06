//
//  InvoiceCard.swift
//  tracme-alpha
//
//  Styled with a Wealthsimple-inspired look: minimal, warm, amount-forward.
//

import SwiftUI

// Wealthsimple-style accent (warm green)
private let wsGreen = Color(red: 29/255, green: 185/255, blue: 84/255)

struct InvoiceCard: View {
    let invoice: Invoice

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: amount front and centre (Wealthsimple puts value first)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invoice.name?.isEmpty == false ? invoice.name! : "Invoice")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    if let vendor = invoice.vendor, !vendor.isEmpty {
                        Text(vendor)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 12)
                Text(formatPrice(invoice.totalAmount))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(wsGreen)
            }
            .padding(.bottom, 12)

            // Meta: date only, minimal
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text(invoice.displayDate)
                    .font(.caption)
                if !invoice.creationDate.isEmpty {
                    Text("·")
                    Text(formattedCreationDateShort)
                        .font(.caption)
                }
            }
            .foregroundStyle(.tertiary)

            if !invoice.items.isEmpty {
                Divider()
                    .padding(.vertical, 10)
                itemsSection
            }

            if !invoice.taxes.isEmpty || invoice.totalAmount > 0 {
                if !invoice.items.isEmpty {
                    Divider()
                        .padding(.vertical, 6)
                }
                totalsSection
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(invoice.items.prefix(3)) { item in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        if !item.description.isEmpty {
                            Text(item.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let qty = item.quantity, qty != 1 {
                            Text("Qty \(formatQuantity(qty))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(formatPrice(item.price))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
            if invoice.items.count > 3 {
                Text("+\(invoice.items.count - 3) more")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var totalsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(invoice.taxes) { tax in
                HStack {
                    Text(tax.taxName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatPrice(tax.amount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Total")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Text(formatPrice(invoice.totalAmount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
    }

    private var formattedCreationDateShort: String {
        if let date = ISO8601DateFormatter().date(from: invoice.creationDate) {
            let f = DateFormatter()
            f.dateStyle = .short
            return f.string(from: date)
        }
        return invoice.creationDate
    }

    private func formatPrice(_ value: Double) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .currency)
    }

    private func formatQuantity(_ value: Double) -> String {
        value == floor(value) ? "\(Int(value))" : String(format: "%.2f", value)
    }
}

#Preview {
    let tax = Tax(taxName: "VAT", amount: 2)
    let item = Item(mongoId: nil, name: "Consulting", price: 99.50, quantity: 2, description: "Hourly rate", categories: [], project: nil, files: [], date: "", creationDate: "", creator: "", archived: false)
    let inv = Invoice(mongoId: nil, name: "Invoice #1001", vendor: "Acme Co", file: "", files: [], items: [item], totalAmount: 201, taxes: [tax], project: nil, date: ISO8601DateFormatter().string(from: Date()), creationDate: ISO8601DateFormatter().string(from: Date()), creator: "", archived: false)
    return InvoiceCard(invoice: inv)
        .padding()
}
