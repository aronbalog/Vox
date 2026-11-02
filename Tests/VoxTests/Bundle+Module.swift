import Foundation

// SwiftPM synthesizes `Bundle.module`. The Xcode test target does not, so the fixture
// lookup in this folder needs the same accessor when the tests are built from the project.
#if !SWIFT_PACKAGE
private final class VoxTestsBundleToken {}

extension Bundle {
    static var module: Bundle {
        Bundle(for: VoxTestsBundleToken.self)
    }
}
#endif
