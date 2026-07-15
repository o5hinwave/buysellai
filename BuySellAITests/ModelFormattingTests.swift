import XCTest
@testable import BuySellAI

final class ModelFormattingTests: XCTestCase {
    func testDecimalCurrencyFormattingAvoidsDoublePrecisionLoss() throws {
        let value = try XCTUnwrap(Decimal(string: "9007199254740993"))

        XCTAssertEqual(
            value.currency(),
            value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        )
        XCTAssertNotEqual(
            value.currency(),
            value.doubleValue.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        )
    }

    func testDecimalCurrencyFormattingSupportsFractionDigits() throws {
        let value = try XCTUnwrap(Decimal(string: "45.5"))

        XCTAssertEqual(
            value.currency(fractionLength: 2),
            value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
        )
    }
}
