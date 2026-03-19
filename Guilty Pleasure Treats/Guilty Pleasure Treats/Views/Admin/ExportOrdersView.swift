//
//  ExportOrdersView.swift
//  Guilty Pleasure Treats
//
//  Admin: export orders as CSV (bakery feature). Uses AdminViewModel.exportOrdersCSV and ordersExportData.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ExportOrdersView: View {
    @EnvironmentObject var viewModel: AdminViewModel
    @State private var fromDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var toDate = Date()
    @State private var isExporting = false
    @State private var showShareSheet = false

    var body: some View {
        let vm = viewModel
        return Form {
            Section {
                DatePicker("From", selection: $fromDate, displayedComponents: .date)
                DatePicker("To", selection: $toDate, displayedComponents: .date)
            } header: {
                Text("Date range")
            }

            Section {
                Button(action: export) {
                    HStack {
                        Text("Export CSV")
                        Spacer()
                        if isExporting { ProgressView().scaleEffect(0.8) }
                    }
                }
                .disabled(isExporting)
            }

            if vm.ordersExportData != nil {
                Section {
                    Button("Share / Save CSV") { showShareSheet = true }
                    Button("Clear", role: .destructive) { vm.clearOrdersExport() }
                }
            }
        }
        .navigationTitle("Export orders")
        #if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            if let data = vm.ordersExportData {
                ShareSheet(items: [data])
            }
        }
        #endif
    }

    private func export() {
        let vm = viewModel
        isExporting = true
        Task {
            await vm.exportOrdersCSV(from: fromDate, to: toDate)
            isExporting = false
            if vm.ordersExportData != nil { showShareSheet = true }
        }
    }
}

#if os(iOS)
/// Share sheet for CSV Data (writes to temp file and shares URL).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("orders-export.csv")
        if let data = items.first as? Data {
            try? data.write(to: url)
        }
        let activityItems: [Any] = items.first is Data ? [url] : items
        return UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
