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
        let vm = viewModel
        return Form {
            Section {
                if vm.businessHoursSettings == nil && !isLoading {
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
                .disabled(isSaving || vm.businessHoursSettings == nil)
            }
        }
        .navigationTitle("Business hours")
        .refreshable {
            await vm.loadBusinessHours()
            bindFromSettings(vm: vm)
        }
        .task {
            await vm.loadBusinessHours()
            bindFromSettings(vm: vm)
            isLoading = false
        }
        .onChange(of: vm.businessHoursSettings != nil) { _, _ in bindFromSettings(vm: vm) }
    }

    private func bindFromSettings(vm: AdminViewModel) {
        guard let s = vm.businessHoursSettings else { return }
        leadTimeHoursStr = s.leadTimeHours.map { String($0) } ?? ""
        minOrderCentsStr = s.minOrderCents.map { String($0) } ?? ""
        taxRatePercentStr = s.taxRatePercent.map { String($0) } ?? ""
    }

    private func save() {
        let vm = viewModel
        let leadTime = Int(leadTimeHoursStr)
        let minOrder = Int(minOrderCentsStr)
        let taxRate = Double(taxRatePercentStr)
        isSaving = true
        Task {
            await vm.updateBusinessHours(leadTimeHours: leadTime, businessHours: nil, minOrderCents: minOrder, taxRatePercent: taxRate)
            isSaving = false
        }
    }
}
