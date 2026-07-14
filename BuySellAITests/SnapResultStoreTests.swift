import XCTest
@testable import BuySellAI

@MainActor
final class SnapResultStoreTests: XCTestCase {
    func testCommitEditsTrimsNameAndNormalizesPrice() {
        let store = SnapResultStore(imageData: Data())
        store.item = DetectedItem(
            name: "Lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
        store.nameText = "  Brass lamp  "
        store.priceText = " $52.40 "

        store.commitEdits()

        XCTAssertEqual(store.item?.name, "Brass lamp")
        XCTAssertEqual(store.item?.priceEstimate, Decimal(52))
        XCTAssertEqual(store.priceText, "52")
    }
}
