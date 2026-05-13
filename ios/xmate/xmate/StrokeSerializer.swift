// C-003 StrokeSerializer
//
// Converts PKDrawing to and from its on-disk binary representation.
//
// v0: thin pass-through to PKDrawing.dataRepresentation() and
// PKDrawing(data:). Future versions may add wrapper metadata such as
// schema version, compression, or encryption for F-048 Lock note.

import Foundation
import PencilKit

enum StrokeSerializer {
    /// Encode a PKDrawing to its on-disk binary form.
    static func encode(_ drawing: PKDrawing) -> Data {
        drawing.dataRepresentation()
    }

    /// Decode a PKDrawing from on-disk binary data. Returns nil if the
    /// data is corrupted or in an incompatible format.
    static func decode(_ data: Data) -> PKDrawing? {
        try? PKDrawing(data: data)
    }
}
