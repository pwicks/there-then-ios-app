import XCTest

extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard self.exists && self.isHittable else { return }
        self.tap()
        let current = self.value as? String ?? ""
        if !current.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
            self.typeText(deleteString)
        }
        self.typeText(text)
    }
}