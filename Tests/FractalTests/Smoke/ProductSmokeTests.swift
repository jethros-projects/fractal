@testable import FractalCore
import Testing
import Foundation

struct ProductSmokeTests {
    @MainActor
    @Test
    func testCoreObjectsCanColdStartTogether() {
        let rig = makeRig()

        XCTAssertEqual(rig.settings.blockLengthMinutes, 15)
        XCTAssertTrue(rig.historyStore.sessions.isEmpty)
        XCTAssertEqual(rig.timer.state, .idle)
        XCTAssertEqual(rig.timer.displayClock, "15:00")
    }

    @MainActor
    @Test
    func testTimerCanStartAndResetWithoutHistorySideEffects() {
        let rig = makeRig(blockLengthMinutes: 5)

        rig.timer.topic = "Smoke"
        rig.timer.startOrResume()
        rig.timer.reset()

        XCTAssertEqual(rig.timer.state, .idle)
        XCTAssertEqual(rig.timer.remainingSeconds, 300)
        XCTAssertTrue(rig.historyStore.sessions.isEmpty)
    }

    @Test
    func testInfoPlistDeclaresMenuBarOnlyAppBundle() throws {
        let plistURL = packageRootURL()
            .appendingPathComponent("Support")
            .appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any]
        )

        XCTAssertEqual(plist["CFBundleName"] as? String, "Fractal")
        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "Fractal")
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "app.fractal.focus")
        XCTAssertEqual(plist["LSMinimumSystemVersion"] as? String, "13.0")
        XCTAssertEqual(plist["LSUIElement"] as? Bool, true)
        XCTAssertEqual(plist["NSHighResolutionCapable"] as? Bool, true)
    }

    @Test
    func testPackageAppScriptIsExecutableAndUsesReleaseBuild() throws {
        let scriptURL = packageRootURL()
            .appendingPathComponent("Scripts")
            .appendingPathComponent("package-app.sh")

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: scriptURL.path))

        let script = try String(contentsOf: scriptURL)
        XCTAssertTrue(script.contains("set -euo pipefail"))
        XCTAssertTrue(script.contains("swift build -c release"))
        XCTAssertTrue(script.contains("Support/Info.plist"))
        XCTAssertTrue(script.contains("Fractal.app"))
    }

    @Test
    func testPackageManifestDefinesExecutableAndTestTargets() throws {
        let manifestURL = packageRootURL().appendingPathComponent("Package.swift")
        let manifest = try String(contentsOf: manifestURL)

        XCTAssertTrue(manifest.contains(".executable(name: \"Fractal\""))
        XCTAssertTrue(manifest.contains("name: \"FractalCore\""))
        XCTAssertTrue(manifest.contains(".executableTarget("))
        XCTAssertTrue(manifest.contains("name: \"Fractal\""))
        XCTAssertTrue(manifest.contains(".testTarget("))
        XCTAssertTrue(manifest.contains("name: \"FractalTests\""))
    }

    @Test
    func testReadmeDocumentsLocalRunPackageAndTestCommands() throws {
        let readmeURL = packageRootURL().appendingPathComponent("README.md")
        let readme = try String(contentsOf: readmeURL)

        XCTAssertTrue(readme.contains("swift run Fractal"))
        XCTAssertTrue(readme.contains("bash Scripts/package-app.sh"))
        XCTAssertTrue(readme.contains("swift test"))
    }
}
