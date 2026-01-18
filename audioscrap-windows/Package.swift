// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "AudioScrapWindows",
    platforms: [.windows(.v10)],
    products: [
        .executable(name: "AudioScrapWindows", targets: ["AudioScrapWindows"]),
    ],
    dependencies: [
        // SwiftWin32 provides SwiftUI-like APIs on Windows
        .package(url: "https://github.com/compnerd/swift-win32.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "AudioScrapWindows",
            dependencies: [
                .product(name: "SwiftWin32", package: "swift-win32")
            ],
            path: "Sources/AudioScrapWindows"
        )
    ]
)
