import AppKit
import ScreenCaptureKit

struct CaptureService {
    enum CaptureError: LocalizedError {
        case noDisplay, noWindow, cropFailed
        var errorDescription: String? {
            switch self {
            case .noDisplay: return "The selected display is no longer available."
            case .noWindow: return "The selected window is no longer available."
            case .cropFailed: return "The selected region could not be cropped. Try a larger selection."
            }
        }
    }
    func content() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }
    func captureDisplay(_ id: CGDirectDisplayID) async throws -> CGImage {
        let content = try await content()
        guard let display = content.displays.first(where: { $0.displayID == id }) else { throw CaptureError.noDisplay }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        let mode = CGDisplayCopyDisplayMode(id)
        configuration.width = mode?.pixelWidth ?? display.width
        configuration.height = mode?.pixelHeight ?? display.height
        configuration.showsCursor = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }
    func captureWindow(_ id: CGWindowID) async throws -> CGImage {
        let content = try await content()
        guard let window = content.windows.first(where: { $0.windowID == id }) else { throw CaptureError.noWindow }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int((filter.contentRect.width * CGFloat(filter.pointPixelScale)).rounded(.up)))
        configuration.height = max(1, Int((filter.contentRect.height * CGFloat(filter.pointPixelScale)).rounded(.up)))
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }
}
