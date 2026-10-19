import AppKit

public enum DocumentListStyle: String, CaseIterable, Identifiable {
    case none, bullet, numbered
    public var id: String { rawValue }
}

public enum DocumentLists {
    public static func prefix(in paragraph: String) -> String? {
        guard let range = paragraph.range(of: #"^\t?(?:[•◦▪]|[0-9]+[.)])\t"#, options: .regularExpression) else { return nil }
        return String(paragraph[range])
    }

    /// Real paragraph list metadata plus visible markers: both TextKit and the
    /// system DOCX writer receive the same content. One call is one undo step.
    @discardableResult
    public static func apply(_ style: DocumentListStyle, to text: NSMutableAttributedString,
                             selection: NSRange) -> NSRange {
        // NSIntersectionRange returns {0, 0} for an insertion point. Preserve
        // the caret's location, or a list action edits the first paragraph.
        let start = min(selection.location, text.length)
        var requested = NSRange(location: start, length: min(selection.length, text.length - start))
        if requested.length > 0, (text.string as NSString).substring(with: requested).hasSuffix("\n") { requested.length -= 1 }
        let range = (text.string as NSString).paragraphRange(for: requested)
        let source = text.attributedSubstring(from: range)
        let result = NSMutableAttributedString(string: "")
        var offset = 0, number = 1
        repeat {
            let local = (source.string as NSString).paragraphRange(for: NSRange(location: offset, length: 0))
            let paragraph = NSMutableAttributedString(attributedString: source.attributedSubstring(from: local))
            let existing = paragraph.length > 0 ? paragraph.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle : nil
            if !(existing?.textLists.isEmpty ?? true), let marker = prefix(in: paragraph.string) {
                paragraph.deleteCharacters(in: NSRange(location: 0, length: (marker as NSString).length))
            }
            let attributes = paragraph.length > 0 ? paragraph.attributes(at: 0, effectiveRange: nil) : DocumentImporter.defaultAttributes
            let paragraphStyle = (existing?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            paragraphStyle.textLists = []
            paragraphStyle.firstLineHeadIndent = 0; paragraphStyle.headIndent = 0
            if style != .none {
                let list = NSTextList(markerFormat: style == .bullet ? .disc : .decimal, options: 0)
                paragraphStyle.textLists = [list]
                paragraphStyle.headIndent = 18
                paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: 18)]
                let marker = style == .bullet ? "•\t" : "\(number).\t"
                paragraph.insert(NSAttributedString(string: marker, attributes: attributes), at: 0)
            }
            paragraph.addAttribute(.paragraphStyle, value: paragraphStyle.copy() as! NSParagraphStyle,
                                   range: NSRange(location: 0, length: paragraph.length))
            result.append(paragraph); number += 1
            offset = NSMaxRange(local)
        } while offset < source.length
        text.replaceCharacters(in: range, with: result)
        return selection.length == 0 ? NSRange(location: range.location + result.length - (result.string.hasSuffix("\n") ? 1 : 0), length: 0)
            : NSRange(location: range.location, length: result.length)
    }
}
