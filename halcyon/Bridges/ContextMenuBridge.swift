//
//  ContextMenuBridge.swift
//  halcyon
//
//  Bridges SwiftUI views to a fully-custom NSMenu so we can
//  embed a search field and a "Create folder" action inside
//  the Move-to-Folder submenu, matching native macOS behavior.
//

import SwiftUI
import AppKit

// MARK: - SwiftUI wrapper that supplies a custom NSMenu on right-click

struct ContextMenuBridge<Content: View>: NSViewRepresentable {
    let content: Content
    let makeMenu: (Coordinator) -> NSMenu
    let onPrimaryClick: ((NSEvent.ModifierFlags) -> Void)?

    init(@ViewBuilder content: () -> Content,
         makeMenu: @escaping (Coordinator) -> NSMenu,
         onPrimaryClick: ((NSEvent.ModifierFlags) -> Void)? = nil) {
        self.content = content()
        self.makeMenu = makeMenu
        self.onPrimaryClick = onPrimaryClick
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = HostingMenuView(rootView: content)
        view.menuProvider = { [weak coordinator = context.coordinator] in
            guard let coordinator else { return NSMenu() }
            return makeMenu(coordinator)
        }
        view.onPrimaryClick = onPrimaryClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? HostingMenuView<Content>)?.updateRootView(content)
    }

    // MARK: - Coordinator retains submenu controllers for lifecycle
    class Coordinator {
        var moveSubmenuController: MoveToFolderSubmenuController?
    }
}

// MARK: - NSView that hosts SwiftUI and provides an NSMenu on right-click

private final class HostingMenuView<Content: View>: NSView {
    private let hosting: NSHostingView<Content>
    var menuProvider: (() -> NSMenu)?
    var onPrimaryClick: ((NSEvent.ModifierFlags) -> Void)?

    init(rootView: Content) {
        hosting = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func menu(for event: NSEvent) -> NSMenu? { menuProvider?() }

    func updateRootView(_ rootView: Content) { hosting.rootView = rootView }

    override func mouseDown(with event: NSEvent) {
        if let onPrimaryClick {
            onPrimaryClick(event.modifierFlags)
        } else {
            super.mouseDown(with: event)
        }
    }
}

// MARK: - Submenu controller with NSSearchField and dynamic folder list

final class MoveToFolderSubmenuController: NSObject, NSSearchFieldDelegate {
    private(set) var submenu: NSMenu
    private let allFolders: [Folder]
    private let onSelectFolder: (Folder) -> Void
    private let onCreateFolder: (String) -> Void

    private let searchField = NSSearchField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
    private let headerIndex = 0
    private let createIndex = 1
    private let separatorIndex = 2

    init(allFolders: [Folder], onSelectFolder: @escaping (Folder) -> Void, onCreateFolder: @escaping (String) -> Void) {
        self.allFolders = allFolders
        self.onSelectFolder = onSelectFolder
        self.onCreateFolder = onCreateFolder
        self.submenu = NSMenu(title: "Move to Folder")
        super.init()
        buildInitialMenu()
    }

    private func buildInitialMenu() {
        submenu.items.removeAll()

        // Search header
        searchField.placeholderString = "Find a folder"
        searchField.delegate = self
        // Ensure we react on each keystroke
        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.sendsWholeSearchString = false
            cell.sendsSearchStringImmediately = true
        }
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))
        let searchItem = NSMenuItem()
        searchItem.view = searchField
        submenu.addItem(searchItem)

        // Create folder
        let createItem = NSMenuItem(title: "Create folder", action: #selector(createFolderTapped), keyEquivalent: "")
        createItem.target = self
        if let plus = NSImage(systemSymbolName: "plus", accessibilityDescription: nil) {
            createItem.image = plus
        }
        submenu.addItem(createItem)

        // Separator
        submenu.addItem(NSMenuItem.separator())

        // Initial folder items
        rebuildFolderItems(filter: "")
    }

    @objc private func createFolderTapped() {
        let alert = NSAlert()
        alert.messageText = "Create New Folder"
        alert.informativeText = "Enter a name for the new folder."
        alert.alertStyle = .informational
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        alert.accessoryView = field
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { onCreateFolder(name) }
        }
    }

    @objc private func searchChanged(_ sender: NSSearchField) { rebuildFolderItems(filter: sender.stringValue) }

    // Live search as you type
    func controlTextDidChange(_ obj: Notification) { rebuildFolderItems(filter: searchField.stringValue) }

    private func rebuildFolderItems(filter: String) {
        // Remove previous folder items (everything after the separator)
        while submenu.items.count > separatorIndex + 1 {
            submenu.removeItem(at: submenu.items.count - 1)
        }
        let filtered = allFolders
            .filter { $0.name != "Library" }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }

        if filtered.isEmpty {
            let noItem = NSMenuItem(title: "No matches", action: nil, keyEquivalent: "")
            noItem.isEnabled = false
            submenu.addItem(noItem)
        } else {
            for folder in filtered {
                let item = NSMenuItem(title: folder.name, action: #selector(selectFolder(_:)), keyEquivalent: "")
                item.representedObject = folder
                item.target = self
                submenu.addItem(item)
            }
        }
    }

    @objc private func selectFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? Folder else { return }
        onSelectFolder(folder)
    }
}

// Shared helper: route NSMenuItem.representedObject closures
extension NSApplication {
    @objc func performRepresentedClosure(_ sender: NSMenuItem) { (sender.representedObject as? () -> Void)?() }
    @objc func doNothing() {}
}
