// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Penumbra",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Penumbra",
            path: "Sources/Penumbra",
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("ServiceManagement")]
        )
    ]
)
