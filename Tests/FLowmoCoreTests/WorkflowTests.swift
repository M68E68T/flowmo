import XCTest
import AppKit
import PDFKit
import ImageIO
@testable import FLowmoCore

final class WorkflowTests: XCTestCase {
    func testRadialHitTestingAndScreenEdges() {
        let center = CGPoint(x: 180, y: 180)
        XCTAssertNil(RadialGeometry.index(point: center, center: center, inner: 60, outer: 160, count: 4))
        for (point,index) in [(CGPoint(x:180,y:300),0),(CGPoint(x:300,y:180),1),(CGPoint(x:180,y:60),2),(CGPoint(x:60,y:180),3)] {
            XCTAssertEqual(RadialGeometry.index(point: point, center: center, inner: 60, outer: 160, count: 4),index)
        }
        XCTAssertNil(RadialGeometry.index(point: CGPoint(x:500,y:500), center: center, inner:60,outer:160,count:4))
        let screen = CGRect(x:-1920,y:0,width:1920,height:1080)
        let frame = RadialGeometry.frame(around: CGPoint(x:-1919,y:1079), size: CGSize(width:360,height:360), in:screen)
        XCTAssertTrue(screen.contains(frame))
    }
    func testHighlightRotationTakesTheShortWay() {
        let quarter = Double.pi / 2
        XCTAssertEqual(RadialGeometry.rotation(to: 1, count: 4, from: 0), -quarter, accuracy: 1e-9)
        // From the last sector to the first is one step forward, not three back.
        XCTAssertEqual(RadialGeometry.rotation(to: 0, count: 4, from: -3 * quarter), -4 * quarter, accuracy: 1e-9)
        XCTAssertEqual(RadialGeometry.rotation(to: 3, count: 4, from: 0), quarter, accuracy: 1e-9)
        // Stays continuous after many turns instead of snapping back to [0, 2π).
        let wound = -10 * Double.pi
        XCTAssertEqual(RadialGeometry.rotation(to: 0, count: 6, from: wound), wound, accuracy: 1e-9)
    }
    func testHighlightTurnsTheWayThePointerMoved() {
        let quarter = Double.pi / 2
        // Opposite sectors tie on distance; the pointer decides.
        XCTAssertEqual(RadialGeometry.rotation(to: 2, from: 0, count: 4, current: 0, clockwise: true), -2 * quarter, accuracy: 1e-9)
        XCTAssertEqual(RadialGeometry.rotation(to: 2, from: 0, count: 4, current: 0, clockwise: false), 2 * quarter, accuracy: 1e-9)
        // Wrap-around: last to first clockwise is one step, against it three.
        XCTAssertEqual(RadialGeometry.rotation(to: 0, from: 3, count: 4, current: -3 * quarter, clockwise: true), -4 * quarter, accuracy: 1e-9)
        XCTAssertEqual(RadialGeometry.rotation(to: 0, from: 3, count: 4, current: -3 * quarter, clockwise: false), 0, accuracy: 1e-9)
        // No pointer, no direction: the short way, as before.
        XCTAssertEqual(RadialGeometry.rotation(to: 3, from: 0, count: 4, current: 0, clockwise: nil), quarter, accuracy: 1e-9)
    }
    func testPointerTurnCrossesTwelveOClock() {
        let left = RadialGeometry.angle(of: CGPoint(x: -1, y: 10), around: .zero)
        let right = RadialGeometry.angle(of: CGPoint(x: 1, y: 10), around: .zero)
        XCTAssertGreaterThan(RadialGeometry.turn(from: left, to: right), 0, "Über 12 Uhr nach rechts ist Uhrzeigersinn.")
        XCTAssertLessThan(RadialGeometry.turn(from: right, to: left), 0)
        XCTAssertLessThan(abs(RadialGeometry.turn(from: left, to: right)), 0.5)
    }
    func testStalePasteboardCannotActivateMenu() {
        var tracker = DragSessionTracker(pasteboardCount: 7)
        XCTAssertFalse(tracker.update(buttonDown: true,pasteboardCount:7,hasFiles:true))
        XCTAssertTrue(tracker.update(buttonDown:true,pasteboardCount:8,hasFiles:true))
        XCTAssertTrue(tracker.update(buttonDown:true,pasteboardCount:8,hasFiles:true))
        XCTAssertFalse(tracker.update(buttonDown:false,pasteboardCount:8,hasFiles:true))
        XCTAssertFalse(tracker.update(buttonDown:true,pasteboardCount:8,hasFiles:true))
        XCTAssertFalse(tracker.update(buttonDown:true,pasteboardCount:9,hasFiles:false))
        XCTAssertTrue(tracker.update(buttonDown:true,pasteboardCount:9,hasFiles:true))
    }
    func testPDFAllPagesTextAndDOCX() throws {
        let folder = try temporaryFolder(); defer { try? FileManager.default.removeItem(at:folder) }
        let textURL = folder.appendingPathComponent("notes.txt")
        let text = "FLowmo Test ÄÖÜ 123\n" + String(repeating:"A line of text for pagination.\n",count:140)
        try Data(text.utf8).write(to:textURL)
        let pdfURL = try XCTUnwrap(FileConverter.convert(textURL,to:.pdf).first)
        let doc = try FileConverter.pdf(pdfURL)
        XCTAssertGreaterThan(doc.pageCount,1)
        let pages = try FileConverter.convert(pdfURL,to:.png)
        XCTAssertEqual(pages.count,doc.pageCount)
        for page in pages { XCTAssertNotNil(CGImageSourceCreateWithURL(page as CFURL,nil)) }
        let txt = try XCTUnwrap(FileConverter.convert(pdfURL,to:.txt).first)
        XCTAssertTrue(try String(contentsOf:txt).contains("FLowmo Test"))
        let word = try XCTUnwrap(FileConverter.convert(pdfURL,to:.docx).first)
        XCTAssertEqual(try Data(contentsOf:word).prefix(2),Data([0x50,0x4b]))
        let roundTrip = try XCTUnwrap(FileConverter.convert(word,to:.txt).first)
        XCTAssertTrue(try String(contentsOf:roundTrip).contains("FLowmo Test"))
        XCTAssertEqual(try String(contentsOf:textURL),text)
    }
    func testCropUsesBottomLeftSelectionAndBackgroundDimensions() throws {
        let context = try XCTUnwrap(CGContext(data:nil,width:100,height:80,bitsPerComponent:8,bytesPerRow:0,
            space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red:1,green:0,blue:0,alpha:1));context.fill(CGRect(x:0,y:40,width:100,height:40))
        context.setFillColor(CGColor(red:0,green:0,blue:1,alpha:1));context.fill(CGRect(x:0,y:0,width:100,height:40))
        let original = try XCTUnwrap(context.makeImage())
        let bottom = try ImageTools.crop(original,selection:CGRect(x:0,y:0,width:0.5,height:0.5))
        XCTAssertEqual(bottom.width,50);XCTAssertEqual(bottom.height,40)
        let colorData = try XCTUnwrap(bottom.dataProvider?.data)
        let bytes = CFDataGetBytePtr(colorData)!
        XCTAssertGreaterThan(bytes[2],bytes[0])
        var style = BackgroundStyle();style.padding=20;style.aspect=1
        let background = try ImageTools.background(original,style:style)
        XCTAssertEqual(background.width,140);XCTAssertEqual(background.height,140)
        let small = try ImageTools.resize(original,scale:0.5)
        XCTAssertEqual(small.width,50);XCTAssertEqual(small.height,40)
    }
    func testCatalogRejectsMixedAndUnknownFiles() {
        XCTAssertTrue(ActionCatalog.actions(for:[URL(fileURLWithPath:"/tmp/a.pdf"),URL(fileURLWithPath:"/tmp/b.png")],tools:false).isEmpty)
        XCTAssertTrue(ActionCatalog.actions(for:[URL(fileURLWithPath:"/tmp/a.exe")],tools:false).isEmpty)
        XCTAssertEqual(ActionCatalog.actions(for:[URL(fileURLWithPath:"/tmp/a.pdf")],tools:false),[.convert(.docx),.convert(.jpg),.convert(.png),.convert(.txt)])
    }
    private func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true);return url
    }
}
