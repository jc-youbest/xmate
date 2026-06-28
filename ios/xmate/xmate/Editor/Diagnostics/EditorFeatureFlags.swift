// EditorFeatureFlags
//
// Development-only switches for parallel Editor prototypes. Release builds
// always use the established production paths.

enum ContinuousNativeZoomPrototype: Equatable {
    /// Design A experiment: technically smooth native per-page zoom, retained
    /// for comparison after failing Continuous viewport semantics when two page
    /// fragments are visible.
    case perPage
    /// Design B candidate: the outer native scroll will zoom the persistent
    /// Continuous stack so every page fragment in the viewport moves together.
    case stack
}

enum EditorFeatureFlags {
    /// Stage 0/1 Continuous native-scroll shell.
    ///
    /// Local device-test switch: change this one DEBUG value to `false` to
    /// return to the legacy ContinuousPagesView. Release builds are permanently
    /// locked to the legacy path until the prototype passes device acceptance.
    #if DEBUG
    static let continuousNativeZoomEnabled = true
    /// Local A/B switch for the native prototype. The stack path is currently
    /// architecture-only at 1x; bounded native zoom lands in a later increment.
    static let continuousNativeZoomPrototype: ContinuousNativeZoomPrototype = .stack
    #else
    static let continuousNativeZoomEnabled = false
    // Compile-time fallback only; Release cannot enter a native prototype.
    static let continuousNativeZoomPrototype: ContinuousNativeZoomPrototype = .stack
    #endif
}
