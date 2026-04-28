import Foundation
import SwiftUI
@testable import Sentinel

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum Fixture {
    static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
    static let secondaryDate = referenceDate.addingTimeInterval(60 * 60)
    static let tertiaryDate = referenceDate.addingTimeInterval(2 * 60 * 60)
    static let quaternaryDate = referenceDate.addingTimeInterval(3 * 60 * 60)

    static let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let secondUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let eventID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let secondEventID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let chatID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    static let messageID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    static let levelID = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
    static let secondLevelID = UUID(uuidString: "40000000-0000-0000-0000-000000000002")!

    static func date(hours: Double) -> Date {
        referenceDate.addingTimeInterval(hours * 60 * 60)
    }
}

final class Box<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

@MainActor
func render<ViewType: View>(_ view: ViewType) {
    #if canImport(UIKit)
    let controller = UIHostingController(rootView: view)
    controller.loadViewIfNeeded()
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()
    #elseif canImport(AppKit)
    let controller = NSHostingController(rootView: view)
    _ = controller.view
    controller.view.layoutSubtreeIfNeeded()
    #endif
    _ = view.body
}
