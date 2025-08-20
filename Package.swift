// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Mealplannerv3",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "Mealplannerv3",
            targets: ["Mealplannerv3"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.1")
    ],
    targets: [
        .target(
            name: "Mealplannerv3",
            dependencies: [
                "SwiftSoup",
                "Alamofire"
            ],
            path: "Mealplannerv3"
        ),
    ]
)
