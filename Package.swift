// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pingky",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Pingky",
            path: "Sources/Pingky"
        )
    ]
)
