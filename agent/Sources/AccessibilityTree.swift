import XCTest

/// Recursively traverses the XCUITest element hierarchy and returns a JSON-serializable tree.
class AccessibilityTree {

    private let maxDepth = 10

    struct ElementNode: Encodable {
        let type: String
        let identifier: String
        let label: String
        let value: String?
        let frame: FrameInfo
        let isEnabled: Bool
        let isSelected: Bool
        let children: [ElementNode]
    }

    struct FrameInfo: Encodable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    /// Get the UI tree for a given app, or SpringBoard if no bundleId provided.
    func getTree(bundleId: String?) -> [String: Any] {
        var result: [String: Any] = [:]
        let work = {
            let app: XCUIApplication
            if let bundleId = bundleId, !bundleId.isEmpty {
                app = XCUIApplication(bundleIdentifier: bundleId)
            } else {
                app = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            }

            let rootNode = self.traverse(element: app, depth: 0)
            if let data = try? JSONEncoder().encode(rootNode),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                result = dict
            } else {
                result = ["error": "Failed to encode tree"]
            }
        }

        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync { work() }
        }

        return result
    }

    private func traverse(element: XCUIElement, depth: Int) -> ElementNode {
        let frame = element.frame
        let frameInfo = FrameInfo(
            x: Double(frame.origin.x),
            y: Double(frame.origin.y),
            width: Double(frame.size.width),
            height: Double(frame.size.height)
        )

        var children: [ElementNode] = []
        if depth < maxDepth {
            let childElements = element.children(matching: .any)
            for i in 0..<childElements.count {
                let child = childElements.element(boundBy: i)
                children.append(traverse(element: child, depth: depth + 1))
            }
        }

        return ElementNode(
            type: elementTypeName(element.elementType),
            identifier: element.identifier,
            label: element.label,
            value: element.value as? String,
            frame: frameInfo,
            isEnabled: element.isEnabled,
            isSelected: element.isSelected,
            children: children
        )
    }

    private func elementTypeName(_ type: XCUIElement.ElementType) -> String {
        switch type {
        case .any: return "any"
        case .other: return "other"
        case .application: return "application"
        case .group: return "group"
        case .window: return "window"
        case .sheet: return "sheet"
        case .drawer: return "drawer"
        case .alert: return "alert"
        case .dialog: return "dialog"
        case .button: return "button"
        case .radioButton: return "radioButton"
        case .radioGroup: return "radioGroup"
        case .checkBox: return "checkBox"
        case .disclosureTriangle: return "disclosureTriangle"
        case .popUpButton: return "popUpButton"
        case .comboBox: return "comboBox"
        case .menuButton: return "menuButton"
        case .toolbarButton: return "toolbarButton"
        case .popover: return "popover"
        case .keyboard: return "keyboard"
        case .key: return "key"
        case .navigationBar: return "navigationBar"
        case .tabBar: return "tabBar"
        case .tabGroup: return "tabGroup"
        case .toolbar: return "toolbar"
        case .statusBar: return "statusBar"
        case .table: return "table"
        case .tableRow: return "tableRow"
        case .tableColumn: return "tableColumn"
        case .outline: return "outline"
        case .outlineRow: return "outlineRow"
        case .browser: return "browser"
        case .collectionView: return "collectionView"
        case .slider: return "slider"
        case .pageIndicator: return "pageIndicator"
        case .progressIndicator: return "progressIndicator"
        case .activityIndicator: return "activityIndicator"
        case .segmentedControl: return "segmentedControl"
        case .picker: return "picker"
        case .pickerWheel: return "pickerWheel"
        case .switch: return "switch"
        case .toggle: return "toggle"
        case .link: return "link"
        case .image: return "image"
        case .icon: return "icon"
        case .searchField: return "searchField"
        case .scrollView: return "scrollView"
        case .scrollBar: return "scrollBar"
        case .staticText: return "staticText"
        case .textField: return "textField"
        case .secureTextField: return "secureTextField"
        case .datePicker: return "datePicker"
        case .textView: return "textView"
        case .menu: return "menu"
        case .menuItem: return "menuItem"
        case .menuBar: return "menuBar"
        case .menuBarItem: return "menuBarItem"
        case .map: return "map"
        case .webView: return "webView"
        case .incrementArrow: return "incrementArrow"
        case .decrementArrow: return "decrementArrow"
        case .timeline: return "timeline"
        case .ratingIndicator: return "ratingIndicator"
        case .valueIndicator: return "valueIndicator"
        case .splitGroup: return "splitGroup"
        case .splitter: return "splitter"
        case .relevanceIndicator: return "relevanceIndicator"
        case .colorWell: return "colorWell"
        case .helpTag: return "helpTag"
        case .matte: return "matte"
        case .dockItem: return "dockItem"
        case .ruler: return "ruler"
        case .rulerMarker: return "rulerMarker"
        case .grid: return "grid"
        case .levelIndicator: return "levelIndicator"
        case .cell: return "cell"
        case .layoutArea: return "layoutArea"
        case .layoutItem: return "layoutItem"
        case .handle: return "handle"
        case .stepper: return "stepper"
        case .tab: return "tab"
        case .touchBar: return "touchBar"
        case .statusItem: return "statusItem"
        @unknown default: return "unknown(\(type.rawValue))"
        }
    }
}
