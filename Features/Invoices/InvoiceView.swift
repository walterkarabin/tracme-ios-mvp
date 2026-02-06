//
//  InvoiceView.swift
//  tracme-alpha
//

import SwiftUI

struct InvoiceView: View {
    @Binding var invoice: Invoice
    @State private var isEditing = false
    @State private var editName = ""
    @State private var editVendor = ""
    @State private var editDateValue: Date = Date()
    @State private var editTotalAmount = ""
    @State private var selectedItem: Item?

    var onDismiss: (() -> Void)?
    var onSave: ((Invoice) async -> Void)?
    /// Called when an item is saved from ItemView; parent should persist the item and refetch the invoice.
    var onItemSaved: ((Item, Invoice) async -> Void)?

    init(invoice: Binding<Invoice>, onDismiss: (() -> Void)? = nil, onSave: ((Invoice) async -> Void)? = nil, onItemSaved: ((Item, Invoice) async -> Void)? = nil) {
        _invoice = invoice
        self.onDismiss = onDismiss
        self.onSave = onSave
        self.onItemSaved = onItemSaved
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    totalCard
                    overviewCard
                    if !invoice.items.isEmpty { itemsCard }
                    if !invoice.taxes.isEmpty { taxesCard }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if onDismiss != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done", action: { onDismiss?() })
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isEditing {
                            if hasEditsChanged {
                                applyEdits()
                                Task { await onSave?(invoice) }
                            }
                        }
                        isEditing.toggle()
                    } label: {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                            .font(.title2)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .onChange(of: isEditing) { _, editing in
                if editing {
                    editName = invoice.name ?? ""
                    editVendor = invoice.vendor ?? ""
                    editDateValue = invoice.dateObject ?? Date()
                    editTotalAmount = String(invoice.totalAmount)
                }
            }
            .sheet(item: $selectedItem) { item in
                ItemView(
                    item: item,
                    onDismiss: { selectedItem = nil },
                    onSave: { updated in
                        guard let idx = invoice.items.firstIndex(where: { $0.id == updated.id }) else {
                            selectedItem = nil
                            return
                        }
                        var updatedInvoice = invoice
                        updatedInvoice.items[idx] = updated
                        invoice = updatedInvoice
                        if let onItemSaved {
                            Task {
                                await onItemSaved(updated, updatedInvoice)
                            }
                        } else {
                            Task { await onSave?(invoice) }
                        }
                        selectedItem = nil
                    }
                )
            }
        }
    }

    // MARK: - Total card (hero amount, Wealthsimple-style)

    private var totalCard: some View {
        VStack(spacing: 8) {
            Text("Total")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Group {
                if isEditing {
                    TextField("0", text: $editTotalAmount)
                        .textFieldStyle(.plain)
                        .keyboardType(.decimalPad)
                } else {
                    Text(formatPrice(invoice.totalAmount))
                }
            }
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - Overview card (same layout in view and edit; values are editable in place)

    private var overviewCard: some View {
        InvoiceDetailCard(title: "Overview") {
            VStack(spacing: 0) {
                overviewRow("Name", value: invoice.name ?? "—", isEditing: isEditing, editValue: $editName)
                overviewRow("Vendor", value: invoice.vendor ?? "—", isEditing: isEditing, editValue: $editVendor)
                dateRow
                overviewRow("Total", value: formatPrice(invoice.totalAmount), isEditing: isEditing, editValue: $editTotalAmount, valueBold: true)
            }
        }
    }

    private var dateRow: some View {
        HStack {
            Text("Date")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Group {
                if isEditing {
                    DatePicker("", selection: $editDateValue, displayedComponents: .date)
                        .labelsHidden()
                } else {
                    Text(invoice.displayDate)
                        .multilineTextAlignment(.trailing)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Items card (selectable ItemViewCards)

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Line items")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
            VStack(spacing: 10) {
                ForEach(invoice.items) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        ItemViewCard(item: item, compact: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Taxes card

    private var taxesCard: some View {
        InvoiceDetailCard(title: "Taxes") {
            VStack(spacing: 0) {
                ForEach(Array(invoice.taxes.enumerated()), id: \.element.id) { index, tax in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 0)
                    }
                    HStack {
                        Text(tax.taxName)
                            .font(.subheadline)
                        Spacer()
                        Text(formatPrice(tax.amount))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - Helpers (same row layout; value is Text or editable TextField)

    private func overviewRow(_ label: String, value: String, isEditing: Bool, editValue: Binding<String>, valueBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Group {
                if isEditing {
                    TextField(label, text: editValue)
                        .textFieldStyle(.plain)
                        .keyboardType(label == "Total" ? .decimalPad : .default)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(value)
                        .multilineTextAlignment(.trailing)
                }
            }
            .font(.subheadline)
            .fontWeight(valueBold ? .semibold : .regular)
        }
        .padding(.vertical, 8)
    }

    /// True if any edited value differs from the current invoice.
    private var hasEditsChanged: Bool {
        if editName != (invoice.name ?? "") { return true }
        if editVendor != (invoice.vendor ?? "") { return true }
        let invoiceDate = invoice.dateObject ?? Date()
        if !Calendar.current.isDate(editDateValue, inSameDayAs: invoiceDate) { return true }
        let editedTotal = Double(editTotalAmount) ?? invoice.totalAmount
        if editedTotal != invoice.totalAmount { return true }
        return false
    }

    private func applyEdits() {
        var inv = invoice
        inv.name = editName.isEmpty ? nil : editName
        inv.vendor = editVendor.isEmpty ? nil : editVendor
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        inv.date = formatter.string(from: editDateValue)
        inv.totalAmount = Double(editTotalAmount) ?? invoice.totalAmount
        invoice = inv
    }

    private func formatPrice(_ value: Double) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .currency)
    }

    private func formatQuantity(_ value: Double) -> String {
        value == floor(value) ? "\(Int(value))" : String(format: "%.2f", value)
    }
}

// MARK: - Reusable card container

private struct InvoiceDetailCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }
}

#Preview {
    let inv = Invoice(
        mongoId: nil, name: "Sample", vendor: "Vendor Co", file: "", files: [],
        items: [
            Item(mongoId: nil, name: "Item", price: 9.99, quantity: 2, description: "", categories: [], project: nil, files: [], date: "", creationDate: "", creator: "", archived: false),
            Item(mongoId: nil, name: "Another line", price: 24.50, quantity: 1, description: "", categories: [], project: nil, files: [], date: "", creationDate: "", creator: "", archived: false),
        ],
        totalAmount: 19.98, taxes: [Tax(taxName: "VAT", amount: 2)], project: nil, date: ISO8601DateFormatter().string(from: Date()), creationDate: "", creator: "", archived: false
    )
    return InvoiceView(invoice: .constant(inv))
}
