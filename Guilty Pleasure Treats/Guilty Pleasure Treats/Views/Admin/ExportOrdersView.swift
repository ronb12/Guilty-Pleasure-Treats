//
//  ExportOrdersView.swift
//  Guilty Pleasure Treats
//
//  Admin: export orders as CSV (bakery feature). Uses AdminViewModel.exportOrdersCSV and ordersExportData.
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
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
                    #if os(iOS)
                    Button("Share / Save CSV") { showShareSheet = true }
                    #elseif os(macOS)
                    Button("Save CSV…") {
                        if let d = vm.ordersExportData {
                            MacCSVSavePanel.presentSave(data: d)
                        }
                    }
                    #endif
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
            await MainActor.run {
                isExporting = false
                guard vm.ordersExportData != nil else { return }
                #if os(iOS)
                showShareSheet = true
                #elseif os(macOS)
                if let d = vm.ordersExportData {
                    MacCSVSavePanel.presentSave(data: d)
                }
                #endif
            }
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

#if os(macOS)
/// Presents `NSSavePanel` for CSV export (sandbox-safe with user-selected destination).
enum MacCSVSavePanel {
    static func presentSave(data: Data, suggestedFilename: String = "orders-export.csv") {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                #if DEBUG
                print("[Export] write failed:", error)
                #endif
            }
        }
    }
}
#endif
