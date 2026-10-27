import UIKit
import XCTest
@testable import AgentOS

final class BarProbe: XCTestCase {
    let ids = ["paste", "snippets", "image", "char-slash/char-at/", "shift-tab/tab/",
               "arrow-up/page-up/repeat", "arrow-down/page-down/repeat", "arrow-left//repeat",
               "arrow-right//repeat", "esc/ctrl-c/", "enter//", "newline//", "more",
               "ctrl-c//", "ctrl-d//", "ctrl-r//", "ctrl-l//", "ctrl-z//", "page-up", "page-down",
               "home", "end", "esc-esc", "char-tilde", "char-pipe"]

    func describe(_ view: UIView) -> String {
        var name = String(describing: type(of: view))
        if let button = view as? UIButton {
            let title = button.configuration?.attributedTitle.map { String($0.characters) } ?? ""
            name += " '\(title)' intrinsic=\(button.intrinsicContentSize.width)"
            if let label = button.titleLabel { name += " titleLabel=\(label.frame.width)" }
        }
        if let label = view as? UILabel { name += " '\(label.text ?? "")'" }
        return name
    }

    func dump(_ view: UIView, _ depth: Int = 0) {
        let pad = String(repeating: "  ", count: depth)
        let f = view.convert(view.bounds, to: nil)
        print("PROBE \(pad)\(describe(view)) x=\(Int(f.minX)) w=\(Int(f.width)) amb=\(view.hasAmbiguousLayout)")
        if view is UIButton, view.bounds.width > 70 {
            for c in view.constraintsAffectingLayout(for: .horizontal) {
                print("PROBE \(pad)  ↳ \(c)")
            }
        }
        if depth < 6, !(view is UIButton) || depth < 5 {
            for sub in view.subviews { dump(sub, depth + 1) }
        }
    }

    func snap(_ view: UIView, _ name: String) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        let dir = ProcessInfo.processInfo.environment["PROBE_OUT"] ?? NSTemporaryDirectory()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? image.pngData()?.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
        print("PROBE saved \(dir)/\(name).png")
    }

    func keys(_ view: UIView) -> [UIButton] {
        view.subviews.flatMap { sub -> [UIButton] in
            if let button = sub as? UIButton { return [button] }
            return keys(sub)
        }
    }

    func settle(_ window: UIWindow) {
        for _ in 0..<3 {
            window.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        }
    }

    let rows: [(String, [String])] = [
        ("asks", ["paste", "snippets", "image", "digit-1", "digit-2", "digit-3", "esc/ctrl-c/", "enter/newline/", "more"]),
        ("shell", ["paste", "snippets", "image", "tab/shift-tab/", "arrow-up/page-up/repeat",
                   "arrow-down/page-down/repeat", "enter/newline/", "ctrl-c/ctrl-d/menu", "more"]),
    ]

    @MainActor func testLayout() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        for (row, rowIds) in [("idle", ids)] + rows {
        for width in [466.0, 951.0] {
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: width, height: 400)
            window.isHidden = false
            let bar = KeyboardBar()
            bar.frame = CGRect(x: 0, y: 300, width: width, height: 52)
            window.addSubview(bar)
            bar.setKeys(context: "claude-up", ids: rowIds)
            for _ in 0..<3 {
                bar.setNeedsLayout()
                window.layoutIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            }
            print("PROBE ===== \(row) width \(width)")
            dump(bar)
            window.overrideUserInterfaceStyle = .dark
            window.backgroundColor = UIColor(white: 0.08, alpha: 1)
            settle(window)
            snap(bar, "\(row)-\(Int(width))-rest")
            let all = keys(bar)
            // Held: the accent
            if let slash = all.first(where: { ($0.configuration?.attributedTitle).map { String($0.characters) } == "/" }) {
                slash.isHighlighted = true
                slash.setNeedsUpdateConfiguration()
                settle(window)
                snap(bar, "\(row)-\(Int(width))-held-slash")
                slash.isHighlighted = false
                // Flicked past the point: the flick title
                (slash as? KeyButton)?.armed = true
                settle(window)
                snap(bar, "\(row)-\(Int(width))-armed-slash")
            }
            // Scrolled to the end: the rest of the row
            if let scroll = bar.subviews.compactMap({ $0 as? UIScrollView }).first {
                scroll.contentOffset.x = max(0, scroll.contentSize.width - scroll.bounds.width)
                settle(window)
                snap(bar, "\(row)-\(Int(width))-scrolled-end")
            }
            window.isHidden = true
        }
        }
    }
}
