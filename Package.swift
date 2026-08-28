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
    platforms: [.macOS(.v13)],
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
