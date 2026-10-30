import AppKit
import SterlingCore

extension AppDelegate {
  func argument(_ name: String) -> String? {
    guard let i = CommandLine.arguments.firstIndex(of: name), i + 1 < CommandLine.arguments.count
    else { return nil }
    return CommandLine.arguments[i + 1]
  }
  func runProbe() async {
    var results: [String: Any] = [
      "kind": "sterling-native-feasibility/v1",
      "os": ProcessInfo.processInfo.operatingSystemVersionString,
      "physicalInputIntegrity": "NOT VERIFIED — no global events injected",
      "likeness": "Temporary shape study; not approved art",
      "notarization": "NOT VERIFIED — no signing identity",
    ]
    try? await Task.sleep(for: .seconds(2))
    let before = overlayRenderer.metrics.summary()
    results["inactiveRenderingFrames"] = before.frames
    results["appWasInactiveWhileRendering"] = !NSApp.isActive
    results["foregroundUnchanged"] =
      launchForeground == NSWorkspace.shared.frontmostApplication?.processIdentifier
    results["overlayIgnoresMouseEvents"] = overlay.ignoresMouseEvents
    results["overlayCannotBecomeKey"] = !overlay.canBecomeKey
    results["displays"] = NSScreen.screens.map { s in
      ["width": s.frame.width, "height": s.frame.height, "scale": s.backingScaleFactor]
    }
    if let path = argument("--preview") {
      do {
        try overlayRenderer.exportPNG(to: URL(fileURLWithPath: path))
        results["previewWritten"] = true
      } catch {
        results["previewWritten"] = false
        results["previewError"] = String(describing: error)
      }
    }
    var displayChecks: [[String: Any]] = []
    for screen in NSScreen.screens {
      let v = screen.visibleFrame
      overlay.setFrameOrigin(NSPoint(x: max(v.minX, v.maxX - 540), y: v.minY + 12))
      try? await Task.sleep(for: .milliseconds(200))
      displayChecks.append([
        "expectedScale": screen.backingScaleFactor, "actualScale": overlay.backingScaleFactor,
        "withinVisibleBounds": v.contains(overlay.frame),
      ])
    }
    results["displayPlacementChecks"] = displayChecks
    relocateOverlay()
    apply(await runtime.send(.hide))
    try? await Task.sleep(for: .milliseconds(200))
    let hiddenStart = overlayRenderer.metrics.summary().frames
    try? await Task.sleep(for: .seconds(1))
    results["hiddenFramesStopped"] = overlayRenderer.metrics.summary().frames == hiddenStart
    results["hiddenTimerStopped"] = timer == nil
    apply(await runtime.send(.resume))
    try? await Task.sleep(for: .seconds(1))
    results["resumeRenders"] = overlayRenderer.metrics.summary().frames > hiddenStart
    apply(await runtime.send(.pause))
    try? await Task.sleep(for: .milliseconds(200))
    let pausedStart = overlayRenderer.metrics.summary().frames
    try? await Task.sleep(for: .seconds(1))
    results["pausedFramesStopped"] = overlayRenderer.metrics.summary().frames == pausedStart
    apply(await runtime.send(.unpause))
    openCare()
    try? await Task.sleep(for: .milliseconds(300))
    if let path = argument("--care-preview") {
      do {
        try exportCarePreview(to: URL(fileURLWithPath: path))
        results["carePreviewWritten"] = true
      } catch {
        results["carePreviewWritten"] = false
        results["carePreviewError"] = String(describing: error)
      }
    }
    results["careControlsFit"] =
      care?.contentView.map { view in view.subviews.allSatisfy { view.bounds.contains($0.frame) } }
      ?? false
    results["careOpaqueWindow"] = care?.isOpaque ?? false
    results["oneVisibleCat"] = !overlay.isVisible && care?.isVisible == true
    _ = careMat?.handleKey(code: 49)
    try? await Task.sleep(for: .seconds(1))
    results["keyboardPetting"] = snapshot.activity == .petting
    _ = careMat?.handleKey(code: 49)
    try? await Task.sleep(for: .milliseconds(200))
    results["keyboardStopsContact"] = !(careMat?.keyboardContact ?? true)
    careMat?.cancelGesture()
    careMat?.mode = .play
    _ = careMat?.handleKey(code: 49)
    try? await Task.sleep(for: .milliseconds(300))
    results["keyboardPlay"] = snapshot.activity == .playing && careMat?.keyboardContact == true
    _ = careMat?.handleKey(code: 49)
    try? await Task.sleep(for: .milliseconds(200))
    results["keyboardStopsPlay"] =
      snapshot.activity != .playing && careMat?.keyboardContact == false
    _ = careMat?.handleKey(code: 53)
    results["escapeClosesCare"] = care == nil
    await pendingOperation?.value
    apply(await runtime.send(.pause))
    suspendSession()
    resumeSession()
    await pendingOperation?.value
    results["wakePreservesManualPause"] = snapshot.policy.paused && timer == nil
    apply(await runtime.send(.unpause))
    suspendSession()
    try? await Task.sleep(for: .milliseconds(150))
    results["suspensionStopsTimer"] = timer == nil && overlayView.isPaused
    resumeSession()
    await pendingOperation?.value
    results["wakeResumesAvailableSession"] = !snapshot.policy.paused && timer != nil
    results["gpuMillisecondsP95"] = overlayRenderer.metrics.summary().p95GPU
    results["buildScope"] = "S0 harness and domain scaffold; no production acceptance claimed"
    if let path = argument("--output") {
      do {
        let data = try JSONSerialization.data(
          withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
      } catch { print("Probe receipt failed: \(error)") }
    }
    NSApp.terminate(nil)
  }
  /// Draw only our own view hierarchy; insert our own scene bitmap because
  /// cacheDisplay cannot read a Metal drawable. This is not a desktop screenshot.
  func exportCarePreview(to url: URL) throws {
    guard let panel = care, let view = panel.contentView,
      let mat = careMat, let renderer = careRenderer
    else { throw PrototypeError.renderFailed }
    let oldAppearance = panel.appearance
    panel.appearance = NSAppearance(named: .aqua)
    view.layoutSubtreeIfNeeded()
    let sceneURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "sterling-care-\(UUID().uuidString).png")
    defer {
      try? FileManager.default.removeItem(at: sceneURL)
      panel.appearance = oldAppearance
    }
    try renderer.exportPNG(
      to: sceneURL, size: CGSize(width: mat.bounds.width * 2, height: mat.bounds.height * 2))
    let image = NSImageView(frame: mat.bounds)
    image.image = NSImage(contentsOf: sceneURL)
    image.imageScaling = .scaleAxesIndependently
    mat.addSubview(image)
    defer { image.removeFromSuperview() }
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
      throw PrototypeError.renderFailed
    }
    view.effectiveAppearance.performAsCurrentDrawingAppearance {
      view.cacheDisplay(in: view.bounds, to: bitmap)
      if let context = NSGraphicsContext(bitmapImageRep: bitmap) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.setBlendMode(.destinationOver)
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
          .fill()
        NSGraphicsContext.restoreGraphicsState()
      }
    }
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
      throw PrototypeError.renderFailed
    }
    try data.write(to: url, options: .atomic)
  }

}
