// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceToPrompt",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "VoiceToPrompt",
            path: "Sources/VoiceToPrompt",
            resources: [
                .copy("../../Resources/system_prompt.txt")
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("Carbon"),
                .linkedFramework("Speech"),
                .linkedFramework("AVFoundation"),
            ]
        )
    ]
)
