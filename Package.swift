// swift-tools-version: 6.0
import Foundation
import PackageDescription

let commandLineToolsFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let commandLineToolsLibraries = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
let needsCommandLineToolsTestPaths = !FileManager.default.fileExists(atPath: "/Applications/Xcode.app")
let testSwiftSettings: [SwiftSetting] = needsCommandLineToolsTestPaths ? [.unsafeFlags(["-F", commandLineToolsFrameworks])] : []
let testLinkerSettings: [LinkerSetting] = needsCommandLineToolsTestPaths ? [.unsafeFlags([
    "-F", commandLineToolsFrameworks,
    "-Xlinker", "-rpath", "-Xlinker", commandLineToolsFrameworks,
    "-Xlinker", "-rpath", "-Xlinker", commandLineToolsLibraries,
])] : []

let package = Package(
    name: "mac-control-mcp",
    // macOS 14, not 13. The installed Testing.framework is built for 14, so a package
    // targeting 13 links the test bundle and then runs nothing: `swift test` exited 0
    // for a day while executing no tests at all. Claiming 13 also claimed something
    // never built or run there. Raising it makes the suite real.
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MacControlCore", targets: ["MacControlCore"]),
        .executable(name: "mac-control-mcp", targets: ["MacControlMCP"]),
        .executable(name: "mac-control-self-test", targets: ["MacControlSelfTest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1"),
    ],
    targets: [
        .target(name: "MacControlCore"),
        .executableTarget(
            name: "MacControlMCP",
            dependencies: [
                "MacControlCore",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
        .executableTarget(name: "MacControlSelfTest", dependencies: ["MacControlCore"]),
        .testTarget(
            name: "MacControlCoreTests",
            dependencies: ["MacControlCore"],
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
