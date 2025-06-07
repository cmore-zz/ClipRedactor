import AppKit

class ClipboardManager {
    static let shared = ClipboardManager()

    private var lastOriginalText: String?
    private var lastFullContents: [[NSPasteboard.PasteboardType: Data]]?

    func storeOriginal(_ text: String) {
        lastOriginalText = text
        storeFullPasteboardContents()
        print("Setting lastOriginalText: \(String(describing: lastOriginalText))")
    }

    private func storeFullPasteboardContents() {
        guard let items = NSPasteboard.general.pasteboardItems else {
            lastFullContents = nil
            return
        }

        lastFullContents = items.map { item in
            var typeMap = [NSPasteboard.PasteboardType: Data]()
            for type in item.types {
                if let data = item.data(forType: type) {
                    typeMap[type] = data
                }
            }
            return typeMap
        }
    }

    func restoreLastPreRedactionValue() {
        print("Restoring last clipboard contents")

        guard let savedItems = lastFullContents else {
            print("⚠️ No full clipboard contents to restore.")
            return
        }

        let pb = NSPasteboard.general
        pb.clearContents()

        let restoredItems: [NSPasteboardItem] = savedItems.map { typeMap in
            let item = NSPasteboardItem()
            for (type, data) in typeMap {
                item.setData(data, forType: type)
            }
            return item
        }

        pb.writeObjects(restoredItems)
        ClipboardWatcher.shared?.updateChangeCount()

        print("✅ Restored full pasteboard, including types: \(savedItems.flatMap { $0.keys })")
    }

    func getLastOriginalText() -> String? {
        return lastOriginalText
    }
}
