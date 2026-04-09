import Testing
@testable import Echo

@Suite("MSSQLDataTypePicker")
struct MSSQLDataTypePickerTests {

    @Test func preservesBareUnicodeTypeWithoutInjectingDefaultLength() {
        let state = MSSQLDataTypePicker.selectionState(for: "nvarchar")

        #expect(state.baseType == "nvarchar")
        #expect(state.sizeParam.isEmpty)
        #expect(state.isCustom == false)
    }

    @Test func preservesExplicitLengthForParameterizedType() {
        let state = MSSQLDataTypePicker.selectionState(for: "nvarchar(4000)")

        #expect(state.baseType == "nvarchar")
        #expect(state.sizeParam == "4000")
        #expect(state.isCustom == false)
    }
}
