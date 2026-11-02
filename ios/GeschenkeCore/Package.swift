// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GeschenkeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GeschenkeCore", targets: ["GeschenkeCore"]),
    ],
    targets: [
        .target(name: "GeschenkeCore"),
        .testTarget(name: "GeschenkeCoreTests", dependencies: ["GeschenkeCore"]),
    ],
    // Swift-5-Modus: ohne lokalen Compiler kostet jede strikte Nebenläufigkeits-
    // meldung eine CI-Runde (Lehre aus dem Wecker).
    swiftLanguageModes: [.v5]
)
