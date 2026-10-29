import SwiftUI
import UIKit
import XCTest
@testable import AgentOS

/// Renders the app's column for sample pages and saves PNGs (probe only)
final class ColumnProbe: XCTestCase {
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

    func settle(_ window: UIWindow, _ seconds: Double = 1.5) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            window.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
    }

    func labels(_ view: UIView) -> [String] {
        var out: [String] = []
        if let label = view.accessibilityLabel, !label.isEmpty, view.isAccessibilityElement || view is UIControl {
            out.append(label)
        }
        for sub in view.subviews { out += labels(sub) }
        return out
    }

    func json(_ text: String) -> Any { try! JSONSerialization.jsonObject(with: Data(text.utf8)) }

    let base = #""type":"state","viewMode":"chat","waiting":2,"changes":3,"background":"rgb(0, 0, 0)","accent":"rgb(124, 58, 237)","scheme":"dark""#

    // As lib/column-spec.ts nativeColumn() posts them (closed Duo)
    let now = #"[{"id":"new","symbol":"plus","label":"New session","prominent":true},{"id":"inbox","symbol":"tray","label":"Needs you","badge":2,"badgeTone":"amber","selected":true},{"id":"projects","symbol":"folder","label":"Projects"},{"id":"search","symbol":"magnifyingglass","label":"Find"},{"id":"settings","symbol":"gearshape","label":"Settings","sep":true}]"#
    let session = #"[{"id":"back","symbol":"chevron.left","label":"Back to Now"},{"id":"terminal","symbol":"terminal","label":"Show terminal","sep":true},{"id":"git","symbol":"arrow.triangle.branch","label":"Changes","badge":3,"badgeTone":"neutral"},{"id":"files","symbol":"doc","label":"Files","selected":true},{"id":"live","symbol":"waveform.path.ecg","label":"Live activity"},{"id":"more","symbol":"ellipsis","label":"More","sep":true}]"#

    @MainActor func testColumn() throws {
        let device = ProcessInfo.processInfo.environment["PROBE_DEVICE"] ?? "device"
        print("PROBE model \(ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "?")")
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let model = AppModel()
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        let host = UIHostingController(rootView: ProbeRoot(model: model))
        window.rootViewController = host
        window.overrideUserInterfaceStyle = .dark
        window.makeKeyAndVisible()
        print("PROBE window \(window.bounds.size)")
        settle(window)

        let cases: [(String, String?)] = [
            ("a-no-column", nil),
            ("b-now", #"{\#(base),"surface":"now","column":\#(now),"canGoBack":false}"#),
            ("c-session", #"{\#(base),"surface":"session","column":\#(session),"canGoBack":true}"#),
            ("d-empty", #"{\#(base),"surface":"now","column":[],"canGoBack":false}"#),
            ("e-null", #"{\#(base),"surface":"now","column":null}"#),
            ("f-now-light", #"{"type":"state","viewMode":"chat","waiting":12,"changes":0,"accent":"rgb(37, 99, 235)","scheme":"light","surface":"now","column":\#(now.replacingOccurrences(of: "\"badge\":2", with: "\"badge\":12"))}"#),
        ]
        for (name, extra) in cases {
            model.receive(json(extra ?? "{\(base)}"))
            window.overrideUserInterfaceStyle = model.scheme == .light ? .light : .dark
            settle(window)
            print("PROBE \(name) column=\(model.column.map { "\($0.count) items" } ?? "nil") hidden=\(model.columnHidden) duo=\(String(describing: model.duo))")
            print("PROBE \(name) labels \(labels(window))")
            snap(window, "\(device)-\(name)")
        }
        for symbol in ["terminal", "doc", "waveform.path.ecg", "tray", "nope.not.a.symbol"] {
            print("PROBE symbol \(symbol) exists=\(UIImage(systemName: symbol) != nil)")
        }
        window.isHidden = true
    }
}

struct ProbeRoot: View {
    let model: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                Text("page").foregroundStyle(.gray)
            }
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .ignoresSafeArea(.all, edges: .trailing)
            .toolbarTitleDisplayMode(.inline)
            .navColumn(model: model, wide: sizeClass == .regular)
            .modifier(HingeReader { present in
                print("PROBE hinge present=\(present)")
                model.hinge(present: present)
            })
        }
    }
}
