import Foundation
import Testing
@testable import Echo

@Suite("ResultExportFormat")
struct ResultExportFormatTests {

    // MARK: - Case Count

    @Test func allCasesIncludesXlsx() {
        #expect(ResultExportFormat.allCases.contains(.xlsx))
        #expect(ResultExportFormat.allCases.count == 6)
    }

    // MARK: - Copy Formats

    @Test func copyFormatsExcludesXlsx() {
        #expect(!ResultExportFormat.copyFormats.contains(.xlsx))
        #expect(ResultExportFormat.copyFormats.count == 5)
    }

    @Test func copyFormatsContainsAllTextFormats() {
        #expect(ResultExportFormat.copyFormats.contains(.tsv))
        #expect(ResultExportFormat.copyFormats.contains(.csv))
        #expect(ResultExportFormat.copyFormats.contains(.json))
        #expect(ResultExportFormat.copyFormats.contains(.sqlInsert))
        #expect(ResultExportFormat.copyFormats.contains(.markdown))
    }

    // MARK: - Menu Titles

    @Test func xlsxMenuTitle() {
        #expect(ResultExportFormat.xlsx.menuTitle == "Excel (.xlsx)")
    }

    // MARK: - File Extensions

    @Test func xlsxFileExtension() {
        #expect(ResultExportFormat.xlsx.fileExtension == "xlsx")
    }

    @Test func allFormatsHaveExtensions() {
        for format in ResultExportFormat.allCases {
            #expect(!format.fileExtension.isEmpty)
        }
    }

    // MARK: - Binary Format Flag

    @Test func xlsxIsBinaryFormat() {
        #expect(ResultExportFormat.xlsx.isBinaryFormat)
    }

    @Test func textFormatsAreNotBinary() {
        for format in ResultExportFormat.copyFormats {
            #expect(!format.isBinaryFormat)
        }
    }

    // MARK: - Format Dispatch

    @Test func formatDispatchHandlesXlsx() {
        // xlsx via format() should fall back to CSV (not crash)
        let result = ResultTableExportFormatter.format(.xlsx, headers: ["a"], rows: [["1"]])
        #expect(!result.isEmpty)
    }
}
