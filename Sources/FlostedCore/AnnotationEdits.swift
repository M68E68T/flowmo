import Foundation

/// Content dialogs resolve a specific frame, never whichever element happens
/// to be selected. Unfinished frames are deliberately absent from history.
public enum AnnotationEdits {
    public static func text(_ annotations: [Annotation], id: UUID, value: String?,
                            committed: [Annotation]) -> [Annotation] {
        guard let index = annotations.firstIndex(where: { $0.id == id }),
              case .text = annotations[index].kind else { return annotations }
        var next = annotations
        if let value {
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { next.remove(at: index) }
            else { next[index].kind = .text(value) }
        } else if let original = committed.first(where: { $0.id == id }) {
            next[index] = original
        } else { next.remove(at: index) }
        return next
    }
}
