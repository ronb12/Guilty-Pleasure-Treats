//
//  BusinessHoursSettingsView.swift
//  Guilty Pleasure Treats
//
//  Admin: view and edit business hours, lead time, min order, tax rate (bakery feature).
//

import SwiftUI

struct BusinessHoursSettingsView: View {
    @EnvironmentObject var viewModel: AdminViewModel
    @State private var leadTimeHoursStr: String = ""
    @State private var minOrderCentsStr: String = ""
    @State private var taxRatePercentStr: String = ""
    @State private var isSaving = false
    @State private var isLoading = true

    var body: some View {
        Form {
            Section {
                if viewModel.businessHoursSettings == nil && !isLoading {
                    Text("Could not load settings. Pull to retry.")
                } else {
                    HStack {
                        Text("Lead time (hours)")
                        Spacer()
                        TextField("24", text: $leadTimeHoursStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    HStack {
                        Text("Min order (cents)")
                        Spacer()
                        TextField("0", text: $minOrderCentsStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Tax rate (%)")
                        Spacer()
                        TextField("0", text: $taxRatePercentStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
            } header: {
                Text("Business settings")
            } footer: {
                Text("Lead time: hours notice needed for orders. Business hours are stored as JSON on the server.")
            }

            Section {
                Button(action: save) {
                    HStack {
                        Text("Save changes")
                        Spacer()
                        if isSaving { ProgressView().scaleEffect(0.8) }
                    }
                }
                .disabled(isSaving || viewModel.businessHoursSettings == nil)
            }
        }
        .navigationTitle("Business hours")
        .refreshable { await viewModel.loadBusinessHours(); bindFromSettings() }
        .task {
            await viewModel.loadBusinessHours()
            bindFromSettings()
            isLoading = false
        }
        .onChange(of: viewModel.businessHoursSettings) { _ in bindFromSettings() }
    }

    private func bindFromSettings() {
        guard let s = viewModel.businessHoursSettings else { return }
        leadTimeHoursStr = s.leadTimeHours.map { String($0) } ?? ""
        minOrderCentsStr = s.minOrderCents.map { String($0) } ?? ""
        taxRatePercentStr = s.taxRatePercent.map { String($0) } ?? ""
    }

    private func save() {
        let leadTime = Int(leadTimeHoursStr)
        let minOrder = Int(minOrderCentsStr)
        let taxRate = Double(taxRatePercentStr)
        isSaving = true
        Task {
            await viewModel.updateBusinessHours(leadTimeHours: leadTime, businessHours: nil, minOrderCents: minOrder, taxRatePercent: taxRate)
            isSaving = false
        }
    }
}
