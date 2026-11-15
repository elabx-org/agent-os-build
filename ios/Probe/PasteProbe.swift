import UIKit
import XCTest
@testable import AgentOS

/// Does the keyboard bar's paste survive text that arrives off the main thread
/// (as it does when it was copied in another app)?
@MainActor
final class PasteProbe: XCTestCase {
    func provider(background: Bool) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: "public.utf8-plain-text", visibility: .all
        ) { done in
            let data = Data("hello from the clipboard".utf8)
            if background {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { done(data, nil) }
            } else {
                done(data, nil)
            }
            return nil
        }
        return provider
    }

    func run(_ name: String, background: Bool) {
        print("PROBE \(name) start")
        let bar = KeyboardBar()
        let got = expectation(description: "paste")
        bar.onPaste = { text in
            print("PROBE \(name) pasted '\(text)' main=\(Thread.isMainThread)")
            got.fulfill()
        }
        bar.paste(itemProviders: [provider(background: background)])
        wait(for: [got], timeout: 5)
        print("PROBE \(name) done")
    }

    func testA_sameThread() { run("A same thread", background: false) }
    func testB_background() { run("B background", background: true) }
}
