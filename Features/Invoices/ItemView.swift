//
//  ItemView.swift
//  tracme-alpha
//

import SwiftUI

struct ItemView: View {
    @State private var item: Item
    @State private var isEditing = false
    @State private var editName = ""
    @State private var editPrice = ""
    @State private var editQuantity = ""
    @State private var editDescription = ""
    @State private var editDateValue: Date = Date()

    var onDismiss: (() -> Void)?
    var onSave: ((Item) async -> Void)?

    init(item: Item, onDismiss: (() -> Void)? = nil, onSave: ((Item) async -> Void)? = nil) {
        _item = State(initialValue: item)
        self.onDismiss = onDismiss
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    priceCard
                    overviewCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Item")
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
                                Task { await onSave?(item) }
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
                    editName = item.name
                    editPrice = String(item.price)
                    editQuantity = item.quantity.map { formatQuantityForEdit($0) } ?? ""
                    editDescription = item.description
                    editDateValue = itemDateObject(from: item.date) ?? Date()
                }
            }
        }
    }

    // MARK: - Price card (hero amount)

    private var priceCard: some View {
        VStack(spacing: 8) {
            Text("Price")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Group {
                if isEditing {
                    TextField("0", text: $editPrice)
                        .textFieldStyle(.plain)
                        .keyboardType(.decimalPad)
                } else {
                    Text(formatPrice(item.price))
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

    // MARK: - Overview card

    private var overviewCard: some View {
        ItemDetailCard(title: "Overview") {
            VStack(spacing: 0) {
                overviewRow("Name", value: item.name.isEmpty ? "—" : item.name, isEditing: isEditing, editValue: $editName)
                overviewRow("Price", value: formatPrice(item.price), isEditing: isEditing, editValue: $editPrice, valueBold: true)
                overviewRow("Quantity", value: item.quantity.map { formatQuantityForEdit($0) } ?? "—", isEditing: isEditing, editValue: $editQuantity)
                overviewRow("Description", value: item.description.isEmpty ? "—" : item.description, isEditing: isEditing, editValue: $editDescription)
                dateRow
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
                    Text(itemDisplayDate)
                        .multilineTextAlignment(.trailing)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

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
                        .keyboardType(label == "Price" || label == "Quantity" ? .decimalPad : .default)
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

    private var itemDisplayDate: String {
        guard let date = itemDateObject(from: item.date) else {
            return item.date.isEmpty ? "N/A" : item.date
        }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func itemDateObject(from dateString: String) -> Date? {
        guard !dateString.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: dateString) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    private var hasEditsChanged: Bool {
        if editName != item.name { return true }
        let editedPrice = Double(editPrice) ?? item.price
        if editedPrice != item.price { return true }
        let editedQty = parseQuantity(editQuantity)
        let currentQty = item.quantity
        if editedQty != currentQty { return true }
        if editDescription != item.description { return true }
        let itemDate = itemDateObject(from: item.date) ?? Date()
        if !Calendar.current.isDate(editDateValue, inSameDayAs: itemDate) { return true }
        return false
    }

    private func applyEdits() {
        item.name = editName.isEmpty ? "Item" : editName
        item.price = Double(editPrice) ?? item.price
        item.quantity = parseQuantity(editQuantity)
        item.description = editDescription
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        item.date = formatter.string(from: editDateValue)
    }

    private func formatQuantityForEdit(_ value: Double) -> String {
        value == floor(value) ? "\(Int(value))" : String(format: "%.2f", value)
    }

    private func parseQuantity(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        return Double(t)
    }

    private func formatPrice(_ value: Double) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .currency)
    }
}

// MARK: - Reusable card container

private struct ItemDetailCard<Content: View>: View {
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
        creationDate: "",
        creator: "",
        archived: false
    )
    return ItemView(item: item)
}
