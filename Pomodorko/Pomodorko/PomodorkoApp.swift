import SwiftUI

extension NSImage.Name {
    static let idle = Self("BarIconIdle")
    static let work = Self("BarIconWork")
    static let `break` = Self("BarIconBreak")
}

private let digitFont = NSFont.monospacedDigitSystemFont(ofSize: 0, weight: .regular)

struct PomodorkoApp: App {
    @NSApplicationDelegateAdaptor(PKStatusItem.self) var appDelegate

    init() {
        PKStatusItem.shared = appDelegate
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class PKStatusItem: NSObject, NSApplicationDelegate {
    private var popover = NSPopover()
    private var statusBarItem: NSStatusItem?
    static var shared: PKStatusItem?

    func applicationDidFinishLaunching(_: Notification) {
        let view = PKPopoverView()

        popover.behavior = .transient
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: view)

        if let contentViewController = popover.contentViewController {
            popover.contentSize.height = contentViewController.view.intrinsicContentSize.height
            popover.contentSize.width = 280
        }

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem?.button?.imagePosition = .imageLeft
        setIcon(name: .idle)
        statusBarItem?.button?.action = #selector(PKStatusItem.togglePopover(_:))
    }

    func setTitle(title: String?) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 0.9
        paragraphStyle.alignment = .center

        let attributedTitle = NSAttributedString(
            string: title != nil ? " \(title!)" : "",
            attributes: [
                .font: digitFont,
                .paragraphStyle: paragraphStyle
            ]
        )
        statusBarItem?.button?.attributedTitle = attributedTitle
    }

    func setIcon(name: NSImage.Name) {
        statusBarItem?.button?.image = NSImage(named: name)
    }

    func showPopover(_ sender: AnyObject?) {
        if let button = statusBarItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
}
