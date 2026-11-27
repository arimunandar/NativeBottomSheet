// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NativeBottomSheet",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "NativeBottomSheet", targets: ["NativeBottomSheet"]),
    ],
    targets: [
        .target(name: "NativeBottomSheet"),
        .testTarget(name: "NativeBottomSheetTests", dependencies: ["NativeBottomSheet"]),
    ]
)
