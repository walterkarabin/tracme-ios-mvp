//
//  AnalyticsView.swift
//  ClientServerBasic
//
//  View for visualizing invoice data with pie/bar charts and filters (vendor, project, creationDate).
//

import Charts
import SwiftUI

// MARK: - Chart data models

struct VendorAmount: Identifiable {
  let id = UUID()
  let vendor: String
  let amount: Double
}

struct ProjectAmount: Identifiable {
  let id = UUID()
  let project: String
  let amount: Double
}

struct MonthAmount: Identifiable {
  let id = UUID()
  let monthKey: String  // "2026-01"
  let label: String    // "Jan 2026"
  let amount: Double
}

// MARK: - Analytics View

struct AnalyticsView: View {
  @EnvironmentObject private var invoiceStore: InvoiceStore

  @State private var filterVendor: String?
  @State private var filterProject: String?
  @State private var filterDateFrom: Date?
  @State private var filterDateTo: Date?
  @State private var showVendorFilter = false
  @State private var showProjectFilter = false
  @State private var showDateFilter = false

  private var filteredInvoices: [Invoice] {
    var list = invoiceStore.invoices
    if let v = filterVendor, !v.isEmpty {
      list = list.filter { ($0.vendor ?? "").isEmpty ? false : $0.vendor == v }
    }
    if let p = filterProject, !p.isEmpty {
      list = list.filter { ($0.project ?? "").isEmpty ? false : $0.project == p }
    }
    if let from = filterDateFrom {
      list = list.filter { ($0.creationDateObject ?? .distantPast) >= from }
    }
    if let to = filterDateTo {
      let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: to) ?? to
      list = list.filter { ($0.creationDateObject ?? .distantFuture) <= endOfDay }
    }
    return list
  }

  private var vendorAmounts: [VendorAmount] {
    let grouped = Dictionary(grouping: filteredInvoices) { $0.vendor ?? "Unknown" }
    return grouped.map { VendorAmount(vendor: $0.key, amount: $0.value.reduce(0) { $0 + $1.totalAmount }) }
      .sorted { $0.amount > $1.amount }
  }

  private var projectAmounts: [ProjectAmount] {
    let grouped = Dictionary(grouping: filteredInvoices) { $0.project ?? "No project" }
    return grouped.map { ProjectAmount(project: $0.key, amount: $0.value.reduce(0) { $0 + $1.totalAmount }) }
      .sorted { $0.amount > $1.amount }
  }

  private var monthAmounts: [MonthAmount] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: filteredInvoices) { inv -> String in
      guard let d = inv.creationDateObject else { return "Unknown" }
      let comps = calendar.dateComponents([.year, .month], from: d)
      return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM yyyy"
    return grouped.compactMap { key, invs -> MonthAmount? in
      guard key != "Unknown",
            let first = invs.first,
            let d = first.creationDateObject else { return nil }
      let comps = calendar.dateComponents([.year, .month], from: d)
      guard let date = calendar.date(from: comps) else { return nil }
      let label = formatter.string(from: date)
      let amount = invs.reduce(0.0) { $0 + $1.totalAmount }
      return MonthAmount(monthKey: key, label: label, amount: amount)
    }.sorted { $0.monthKey < $1.monthKey }
  }

  private var uniqueVendors: [String] {
    Array(Set(invoiceStore.invoices.compactMap { $0.vendor }.filter { !$0.isEmpty })).sorted()
  }

  private var uniqueProjects: [String] {
    Array(Set(invoiceStore.invoices.compactMap { $0.project }.filter { !$0.isEmpty })).sorted()
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        filtersSection
        if filteredInvoices.isEmpty {
          emptyState
        } else {
          summaryCard
          chartsSection
        }
      }
      .padding()
    }
    .navigationTitle("Analytics")
    .navigationBarTitleDisplayMode(.large)
    .task {
      await invoiceStore.getInvoices()
    }
  }

  private var filtersSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Filters")
        .font(.headline)

      // Vendor filter
      DisclosureGroup(isExpanded: $showVendorFilter) {
        Picker("Vendor", selection: $filterVendor) {
          Text("All vendors").tag(nil as String?)
          ForEach(uniqueVendors, id: \.self) { v in
            Text(v).tag(v as String?)
          }
        }
        .pickerStyle(.menu)
      } label: {
        HStack {
          Image(systemName: "building.2")
          Text(filterVendor ?? "All vendors")
            .foregroundStyle(filterVendor != nil ? .primary : .secondary)
        }
      }

      // Project filter
      DisclosureGroup(isExpanded: $showProjectFilter) {
        Picker("Project", selection: $filterProject) {
          Text("All projects").tag(nil as String?)
          ForEach(uniqueProjects, id: \.self) { p in
            Text(p).tag(p as String?)
          }
        }
        .pickerStyle(.menu)
      } label: {
        HStack {
          Image(systemName: "folder")
          Text(filterProject ?? "All projects")
            .foregroundStyle(filterProject != nil ? .primary : .secondary)
        }
      }

      // Creation date range
      DisclosureGroup(isExpanded: $showDateFilter) {
        HStack(spacing: 16) {
          DatePicker("From", selection: Binding(
            get: { filterDateFrom ?? Date() },
            set: { filterDateFrom = $0 }
          ), displayedComponents: .date)
          DatePicker("To", selection: Binding(
            get: { filterDateTo ?? Date() },
            set: { filterDateTo = $0 }
          ), displayedComponents: .date)
        }
        Button("Clear date range") {
          filterDateFrom = nil
          filterDateTo = nil
        }
        .font(.subheadline)
      } label: {
        HStack {
          Image(systemName: "calendar")
          Text(dateFilterLabel)
            .foregroundStyle((filterDateFrom != nil || filterDateTo != nil) ? .primary : .secondary)
        }
      }

      Button("Clear all filters") {
        filterVendor = nil
        filterProject = nil
        filterDateFrom = nil
        filterDateTo = nil
      }
      .font(.subheadline)
    }
    .padding()
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var dateFilterLabel: String {
    if let from = filterDateFrom, let to = filterDateTo {
      return "\(shortDate(from)) – \(shortDate(to))"
    }
    if filterDateFrom != nil { return "From \(shortDate(filterDateFrom!))" }
    if filterDateTo != nil { return "Until \(shortDate(filterDateTo!))" }
    return "Any date"
  }

  private func shortDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .short
    return f.string(from: d)
  }

  private var emptyState: some View {
    ContentUnavailableView(
      "No data",
      systemImage: "chart.pie",
      description: Text("No invoices match the current filters. Adjust filters or add invoices.")
    )
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }

  private var summaryCard: some View {
    let total = filteredInvoices.reduce(0.0) { $0 + $1.totalAmount }
    return Group {
      Text("Summary")
        .font(.headline)
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(filteredInvoices.count) invoice(s)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text(total, format: .currency(code: "USD"))
            .font(.title2.bold())
        }
        Spacer()
      }
      .padding()
      .background(Color(.secondarySystemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  @ViewBuilder
  private var chartsSection: some View {
    Text("Charts")
      .font(.headline)

    if !vendorAmounts.isEmpty {
      Chart(vendorAmounts) { item in
        SectorMark(
          angle: .value("Amount", item.amount),
          innerRadius: .ratio(0.5),
          angularInset: 1.5
        )
        .foregroundStyle(by: .value("Vendor", item.vendor))
        .cornerRadius(4)
      }
      .frame(height: 220)
      .chartLegend(position: .bottom, alignment: .center, spacing: 8)
      .padding()
      .background(Color(.secondarySystemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 12))

      Text("Spending by vendor")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    if !monthAmounts.isEmpty {
      Chart(monthAmounts) { item in
        BarMark(
          x: .value("Month", item.label),
          y: .value("Amount", item.amount)
        )
        .foregroundStyle(.blue.gradient)
        .cornerRadius(6)
      }
      .frame(height: 220)
      .chartXAxis {
        AxisMarks(values: .automatic) { _ in
          AxisValueLabel()
            .font(.caption2)
        }
      }
      .padding()
      .background(Color(.secondarySystemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 12))

      Text("Spending by month (creation date)")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    if !projectAmounts.isEmpty {
      Chart(projectAmounts) { item in
        BarMark(
          x: .value("Amount", item.amount),
          y: .value("Project", item.project)
        )
        .foregroundStyle(.green.gradient)
        .cornerRadius(6)
      }
      .frame(height: max(120, CGFloat(projectAmounts.count) * 32))
      .chartXAxis {
        AxisMarks(values: .automatic) { _ in
          AxisValueLabel()
            .font(.caption2)
        }
      }
      .padding()
      .background(Color(.secondarySystemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 12))

      Text("Spending by project")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    AnalyticsView()
      .environmentObject(InvoiceStore(invoiceService: InvoiceService(authManager: AuthManager()), itemService: ItemService(authManager: AuthManager())))
  }
}
