import Foundation

/// Snapshot-based undo. Values are whole states rather than deltas, which is
/// plenty for the handful of annotations an editor holds and avoids an inverse
/// operation for every edit.
public struct UndoStack<Value> {
    private var past: [Value]
    private var future: [Value]
    private var present: Value
    private let limit: Int

    public init(_ initial: Value, limit: Int = 50) {
        present = initial
        past = []
        future = []
        self.limit = max(1, limit)
    }

    public var current: Value { present }
    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }

    /// Records a new state. Anything that was undone is dropped: continuing
    /// from an earlier point makes the abandoned branch unreachable.
    public mutating func commit(_ value: Value) {
        past.append(present)
        if past.count > limit { past.removeFirst(past.count - limit) }
        present = value
        future.removeAll()
    }

    public mutating func undo() -> Value? {
        guard let previous = past.popLast() else { return nil }
        future.append(present)
        present = previous
        return present
    }

    public mutating func redo() -> Value? {
        guard let next = future.popLast() else { return nil }
        past.append(present)
        present = next
        return present
    }
}

public extension UndoStack where Value: Equatable {
    /// A click without a move, or restoring an unchanged draft, is not an edit.
    mutating func commitIfChanged(_ value: Value) {
        guard value != current else { return }
        commit(value)
    }
}
