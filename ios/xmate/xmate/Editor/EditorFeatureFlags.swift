// EditorFeatureFlags
//
// Development-only switches for parallel Editor prototypes. Release builds
// always use the established production paths.

enum EditorFeatureFlags {
    /// Stage 0/1 Continuous native-scroll shell.
    ///
    /// Local device-test switch: change this one DEBUG value to `false` to
    /// return to the legacy ContinuousPagesView. Release builds are permanently
    /// locked to the legacy path until the prototype passes device acceptance.
    #if DEBUG
    static let continuousNativeZoomEnabled = true
    #else
    static let continuousNativeZoomEnabled = false
    #endif
}
