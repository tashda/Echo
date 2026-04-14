import SwiftUI
import SQLServerKit

struct MSSQLSecurityCertificatesSection: View {
    @Bindable var viewModel: DatabaseSecurityViewModel

    enum SubSection: String, CaseIterable {
        case certificates = "Certificates"
        case asymmetricKeys = "Asymmetric Keys"
    }

    @State private var selectedSubSection: SubSection = .certificates

    var body: some View {
        VStack(spacing: 0) {
            Picker(selection: $selectedSubSection) {
                ForEach(SubSection.allCases, id: \.self) { sub in
                    Text(sub.rawValue).tag(sub)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            .padding(.vertical, SpacingTokens.xs)

            switch selectedSubSection {
            case .certificates:
                certificatesTable
            case .asymmetricKeys:
                asymmetricKeysTable
            }
        }
    }

    // MARK: - Certificates Table

    private var certificatesTable: some View {
        Group {
            if viewModel.certificates.isEmpty && !viewModel.isLoadingCertificates {
                ContentUnavailableView("No Certificates", systemImage: "doc.text", description: Text("No certificates found in this database."))
            } else {
                Table(viewModel.certificates) {
                    TableColumn("Name") { cert in
                        Text(cert.name)
                            .font(TypographyTokens.Table.name)
                    }
                    .width(min: 100, ideal: 200)

                    TableColumn("Subject") { cert in
                        if let subject = cert.subject, !subject.isEmpty {
                            Text(subject)
                                .font(TypographyTokens.Table.secondaryName)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        } else {
                            Text("\u{2014}")
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    }
                    .width(min: 120, ideal: 250)

                    TableColumn("Expiry Date") { cert in
                        if let date = cert.expiryDate, !date.isEmpty {
                            Text(date)
                                .font(TypographyTokens.Table.date)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        } else {
                            Text("\u{2014}")
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    }
                    .width(min: 80, ideal: 140)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .tableColumnAutoResize()
            }
        }
    }

    // MARK: - Asymmetric Keys Table

    private var asymmetricKeysTable: some View {
        Group {
            if viewModel.asymmetricKeys.isEmpty && !viewModel.isLoadingCertificates {
                ContentUnavailableView("No Asymmetric Keys", systemImage: "key", description: Text("No asymmetric keys found in this database."))
            } else {
                Table(viewModel.asymmetricKeys) {
                    TableColumn("Name") { key in
                        Text(key.name)
                            .font(TypographyTokens.Table.name)
                    }
                    .width(min: 100, ideal: 200)

                    TableColumn("Algorithm") { key in
                        if let algo = key.algorithm, !algo.isEmpty {
                            Text(algo)
                                .font(TypographyTokens.Table.category)
                                .foregroundStyle(ColorTokens.Text.secondary)
                        } else {
                            Text("\u{2014}")
                                .foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    }
                    .width(min: 80, ideal: 140)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .tableColumnAutoResize()
            }
        }
    }
}
