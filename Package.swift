// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "BreatheServer",
    platforms: [
        .macOS(.v13), .iOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.77.1"),
        .package(url: "https://github.com/Awesomeplayer165/BreatheShared", .branch("main")),
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.7.1")),
        .package(url: "https://github.com/GEOSwift/GEOSwift", .upToNextMajor(from: "10.1.0")),
        .package(url: "https://github.com/BrettRToomey/Jobs", .upToNextMajor(from: "1.1.2")),
    ],
    targets: [
        .executableTarget(
            name: "BreatheServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"), "Alamofire", "GEOSwift", "BreatheShared", "Jobs"
            ]
        )
    ]
)
