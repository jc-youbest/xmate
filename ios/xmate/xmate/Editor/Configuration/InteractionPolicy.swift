// InteractionPolicy
//
// Editor input capabilities derived from the App-selected interaction mode.
// Pencil writing and finger navigation are deliberately independent: a
// read-only letter remains navigable, while a workspace suspension accepts no
// Editor gestures at all.

struct InteractionPolicy: Equatable {
    let pencilWrites: Bool
    let fingersNavigate: Bool

    static let writing = InteractionPolicy(
        pencilWrites: true,
        fingersNavigate: true
    )
    static let readOnly = InteractionPolicy(
        pencilWrites: false,
        fingersNavigate: true
    )
    static let suspended = InteractionPolicy(
        pencilWrites: false,
        fingersNavigate: false
    )
}

enum EditorInteractionMode: Equatable {
    case writing
    case readOnly
    case workspaceSuspended

    var policy: InteractionPolicy {
        switch self {
        case .writing:
            .writing
        case .readOnly:
            .readOnly
        case .workspaceSuspended:
            .suspended
        }
    }
}
