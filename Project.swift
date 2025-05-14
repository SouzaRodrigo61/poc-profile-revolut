import ProjectDescription

let project = Project(
    name: "poc",
    targets: [
        .target(
            name: "poc",
            destinations: .iOS,
            product: .app,
            bundleId: "io.tuist.poc",
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            sources: ["poc/Sources/**"],
            resources: ["poc/Resources/**"],
            dependencies: []
        ),
        .target(
            name: "pocTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.tuist.pocTests",
            infoPlist: .default,
            sources: ["poc/Tests/**"],
            resources: [],
            dependencies: [.target(name: "poc")]
        ),
    ]
)
