import XCTest
import AppKit
import ImageIO

final class CoreTests: XCTestCase {
    private func image() throws -> CGImage {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 256, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(try XCTUnwrap(CGColor(colorSpace: space, components: [1, 0, 0, 1])))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        return try XCTUnwrap(context.makeImage())
    }
    func testRetinaCropAndReverseDrag() {
        let expected = CGRect(x: 20, y: 80, width: 60, height: 80)
        for selection in [CGRect(x: 10, y: 20, width: 30, height: 40), CGRect(x: 40, y: 60, width: -30, height: -40)] {
            XCTAssertEqual(CaptureGeometry.pixelCrop(selection: selection, viewSize: CGSize(width: 100, height: 100), imageSize: CGSize(width: 200, height: 200)), expected)
        }
        XCTAssertNil(CaptureGeometry.pixelCrop(selection: .zero, viewSize: CGSize(width: 100, height: 100), imageSize: CGSize(width: 200, height: 200)))
    }
    func testPNGAndJPEGDimensionsAndColor() throws {
        for format in ImageFormat.allCases {
            let data = try ImageOutput.data(image(), format: format)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(decoded.width, 64); XCTAssertEqual(decoded.height, 48)
            let pixels = try XCTUnwrap(CGContext(data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 256, space: try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            pixels.draw(decoded, in: CGRect(x: 0, y: 0, width: 64, height: 48))
            let bytes = try XCTUnwrap(pixels.data).assumingMemoryBound(to: UInt8.self)
            let offset = (24 * 64 + 32) * 4
            let tolerance = format == .png ? 0 : 3
            XCTAssertLessThanOrEqual(abs(Int(bytes[offset]) - 255), tolerance)
            XCTAssertLessThanOrEqual(Int(bytes[offset + 1]), tolerance)
            XCTAssertLessThanOrEqual(Int(bytes[offset + 2]), tolerance)
        }
    }
    func testSaveFailureAndAutosaveNameReuse() throws {
        let url = URL(fileURLWithPath: "/private/tmp/\(UUID().uuidString)/missing/image.png")
        XCTAssertThrowsError(try ImageOutput.save(image(), format: .png, to: url))
        XCTAssertEqual(ImageOutput.filename(format: .jpeg, savedURL: URL(fileURLWithPath: "/private/tmp/Capture.png")), "Capture.jpeg")
    }
    func testPreferencesPersistence() async throws {
        try await MainActor.run {
            let suite = "com.snapforge.xctest.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let first = Preferences(defaults: defaults)
            XCTAssertTrue(first.automaticScrolling); XCTAssertFalse(first.autoSave)
            first.automaticScrolling = false; first.format = .jpeg; first.regionKey = "r"
            let restored = Preferences(defaults: defaults)
            XCTAssertFalse(restored.automaticScrolling); XCTAssertEqual(restored.format, .jpeg); XCTAssertEqual(restored.regionKey, "r")
        }
    }
    func testUndoRedoSavedStateAndBranch() async throws {
        let source = try image()
        await MainActor.run {
            let document = EditorDocument(image: source)
            let state = EditorState(annotations: [Annotation(tool: .rectangle, start: CGPoint(x: 10, y: 10), end: CGPoint(x: 40, y: 35))])
            document.commit(state); XCTAssertTrue(document.isDirty)
            document.markSaved(to: URL(fileURLWithPath: "/private/tmp/test.png"), state: state)
            XCTAssertFalse(document.isDirty)
            document.undo(); XCTAssertTrue(document.isDirty); XCTAssertTrue(document.canRedo)
            document.redo(); XCTAssertEqual(document.state, state); XCTAssertFalse(document.isDirty)
            document.undo(); document.commit(EditorState(crop: CGRect(x: 0, y: 0, width: 32, height: 24)))
            XCTAssertFalse(document.canRedo); XCTAssertEqual(document.source.width, 64)
        }
    }
    func testCropAndOutOfBoundsRejection() async throws {
        let source = try image()
        try await MainActor.run {
            let cropped = try AnnotationRenderer.render(source: source, state: EditorState(crop: CGRect(x: 5, y: 6, width: 20, height: 15)))
            XCTAssertEqual(cropped.width, 20); XCTAssertEqual(cropped.height, 15)
            XCTAssertThrowsError(try AnnotationRenderer.render(source: source, state: EditorState(crop: CGRect(x: 1000, y: 1000, width: 20, height: 15))))
            XCTAssertEqual(source.width, 64); XCTAssertEqual(source.height, 48)
        }
    }
}
