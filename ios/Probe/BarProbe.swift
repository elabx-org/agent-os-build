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

    @MainActor func testLayout() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        for width in [466.0, 951.0] {
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: width, height: 400)
            window.isHidden = false
            let bar = KeyboardBar()
            bar.frame = CGRect(x: 0, y: 300, width: width, height: 52)
            window.addSubview(bar)
            bar.setKeys(context: "claude-up", ids: ids)
            for _ in 0..<3 {
                bar.setNeedsLayout()
                window.layoutIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            }
            print("PROBE ===== width \(width)")
            dump(bar)
            window.isHidden = true
        }
    }
}
