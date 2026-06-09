// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Dango",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Dango",
            path: "Dango",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets"),
                .process("Supporting Files/Assets/chime_bell.mp3"),
            ]
        ),
        .testTarget(
            name: "DangoTests",
            dependencies: ["Dango"],
            path: "DangoTests"
        ),
    ]
)
