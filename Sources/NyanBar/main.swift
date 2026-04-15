import AppKit
import Foundation
import ImageIO
import ServiceManagement

@main
final class NyanBarApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var animator: GIFStatusItemAnimator?
    private let startupManager = StartupManager()

    static func main() {
        let app = NSApplication.shared
        let delegate = NyanBarApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        startupManager.enableLaunchAtLogin()
        loadBundledGIF()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        button.title = "Nyan"
        button.toolTip = "Nyan Bar"

        let menu = NSMenu(title: "Nyan Bar")
        menu.addItem(withTitle: "Reload GIF", action: #selector(reloadGIF), keyEquivalent: "r").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Nyan Bar", action: #selector(quitApp), keyEquivalent: "q").target = self
        statusItem.menu = menu

        animator = GIFStatusItemAnimator(button: button, statusItem: statusItem)
    }

    @objc
    private func reloadGIF() {
        loadBundledGIF()
    }

    @objc
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func loadBundledGIF() {
        guard let data = loadBundledGIFData() else { return }
        animator?.loadGIFData(data)
    }

    private func loadBundledGIFData() -> Data? {
        let bundledURL = Bundle.main.url(forResource: "original", withExtension: "gif")

        let fallbackPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Assets/original.gif", isDirectory: false)

        let candidates = [bundledURL, fallbackPath]

        for url in candidates.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                return data
            }
        }

        return nil
    }
}

final class GIFStatusItemAnimator {
    private weak var button: NSStatusBarButton?
    private weak var statusItem: NSStatusItem?
    private var frames: [NSImage] = []
    private var frameDurations: [TimeInterval] = []
    private var frameIndex: Int = 0
    private var timer: Timer?

    init(button: NSStatusBarButton, statusItem: NSStatusItem) {
        self.button = button
        self.statusItem = statusItem
    }

    func loadGIFData(_ data: Data) {
        guard let decoded = decodeGIF(data: data) else { return }

        timer?.invalidate()
        frames = decoded.images
        frameDurations = decoded.durations
        frameIndex = 0

        guard let first = frames.first else { return }
        button?.image = first
        button?.imagePosition = .imageOnly
        button?.title = ""

        let width = max(22, first.size.width)
        statusItem?.length = width

        scheduleNextFrame()
    }

    private func scheduleNextFrame() {
        guard !frames.isEmpty else { return }

        let delay = frameDurations[frameIndex]
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.advanceFrame()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func advanceFrame() {
        guard !frames.isEmpty else { return }

        frameIndex = (frameIndex + 1) % frames.count
        button?.image = frames[frameIndex]
        scheduleNextFrame()
    }

    private func decodeGIF(data: Data) -> (images: [NSImage], durations: [TimeInterval])? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }

        let targetHeight: CGFloat = 18
        var images: [NSImage] = []
        var durations: [TimeInterval] = []
        images.reserveCapacity(frameCount)
        durations.reserveCapacity(frameCount)

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }

            let duration = frameDuration(for: index, from: source)
            let scaledSize = scaledImageSize(for: cgImage, targetHeight: targetHeight)
            let image = NSImage(cgImage: cgImage, size: scaledSize)
            image.isTemplate = false

            images.append(image)
            durations.append(duration)
        }

        guard !images.isEmpty else { return nil }
        return (images, durations)
    }

    private func frameDuration(for index: Int, from source: CGImageSource) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return 0.1
        }

        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double
        let duration = unclamped ?? clamped ?? 0.1

        return duration < 0.02 ? 0.1 : duration
    }

    private func scaledImageSize(for image: CGImage, targetHeight: CGFloat) -> NSSize {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard height > 0 else { return NSSize(width: targetHeight, height: targetHeight) }

        let scaledWidth = max(targetHeight, (width / height) * targetHeight)
        return NSSize(width: scaledWidth, height: targetHeight)
    }
}

final class StartupManager {
    private let fileManager = FileManager.default

    func enableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                return
            } catch {
                // Fall through to LaunchAgent registration if ServiceManagement registration fails.
            }
        }

        installLaunchAgentFallback()
    }

    private func installLaunchAgentFallback() {
        guard let executablePath = Bundle.main.executablePath ?? CommandLine.arguments.first else { return }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.local.nyanbar"
        let label = "\(bundleID).login"

        let launchAgentsDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let plistURL = launchAgentsDirectory.appendingPathComponent("\(label).plist", isDirectory: false)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "LimitLoadToSessionType": ["Aqua"],
            "ProcessType": "Interactive"
        ]

        do {
            try fileManager.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: [.atomic])
        } catch {
            // Startup registration is best effort.
        }
    }
}
