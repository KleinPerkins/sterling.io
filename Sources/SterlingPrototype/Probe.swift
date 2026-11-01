import AppKit
import MetalKit
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
    var renderChecks: [[String: Any]] = []
    for screen in NSScreen.screens {
      let v = screen.visibleFrame
      overlay.setFrameOrigin(NSPoint(x: max(v.minX, v.maxX - 540), y: v.minY + 12))
      let rendered = await waitForRenderedFrames(
        renderer: overlayRenderer, view: overlayView, scale: screen.backingScaleFactor)
      displayChecks.append([
        "expectedScale": screen.backingScaleFactor, "actualScale": overlay.backingScaleFactor,
        "withinVisibleBounds": v.contains(overlay.frame),
      ])
      var renderCheck = renderBounds(renderer: overlayRenderer, view: overlayView)
      renderCheck["renderedAfterTransition"] = rendered
      renderCheck["passed"] = rendered && renderCheck["passed"] as? Bool == true
      renderChecks.append(renderCheck)
    }
    results["displayPlacementChecks"] = displayChecks
    results["displayRenderBoundsChecks"] = renderChecks
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
    let careRendered = await waitForRenderedFrames(
      renderer: careRenderer, view: careMat, scale: care?.backingScaleFactor ?? 0)
    var careRenderCheck = renderBounds(renderer: careRenderer, view: careMat)
    careRenderCheck["renderedAfterTransition"] = careRendered
    careRenderCheck["passed"] = careRendered && careRenderCheck["passed"] as? Bool == true
    results["careRenderBoundsCheck"] = careRenderCheck
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
    await pendingOperation?.value
    timer?.invalidate()
    timer = nil

    let pointerStart = ProcessInfo.processInfo.systemUptime
    let generationBeforeBackground = interactionGeneration
    careMat?.mode = .pet
    careMat?.handlePointerDown(
      point: CGPoint(x: 10, y: 10), timestamp: pointerStart, region: .outside)
    let backgroundOnlyStayedLocal = careMat?.currentToken == nil
      && interactionGeneration == generationBeforeBackground
    careMat?.handlePointerDrag(
      point: CGPoint(x: 26, y: 10), timestamp: pointerStart + 0.1, region: .head)
    let pointerToken = careMat?.currentToken
    let generationAfterBody = interactionGeneration
    careMat?.handlePointerDrag(
      point: CGPoint(x: 42, y: 10), timestamp: pointerStart + 0.2, region: .head)
    let bodyTransitionMintedOnce = pointerToken != nil
      && careMat?.currentToken == pointerToken
      && generationAfterBody == generationBeforeBackground + 1
      && interactionGeneration == generationAfterBody
    await pendingOperation?.value

    let freshPointerStep = careMat?.nextStep(
      elapsedSeconds: 0.1, now: pointerStart + 0.3)
    let expiredPointerStep = careMat?.nextStep(
      elapsedSeconds: 0.1, now: pointerStart + 0.5)
    let pointerQualityFresh: Bool
    if case .some(.step(_, _, .pet(_, .some))) = freshPointerStep {
      pointerQualityFresh = true
    } else {
      pointerQualityFresh = false
    }
    let pointerQualityExpired: Bool
    if case .some(.step(_, _, .pet(_, .none))) = expiredPointerStep {
      pointerQualityExpired = true
    } else {
      pointerQualityExpired = false
    }
    results["petBackgroundOnlyStayedLocal"] = backgroundOnlyStayedLocal
    results["petBackgroundToBodyMintedOneToken"] = bodyTransitionMintedOnce
    results["pointerPetQualityFreshBefore250ms"] = pointerQualityFresh
    results["pointerPetQualityExpiredAfter250ms"] = pointerQualityExpired
    careMat?.cancelGesture(reason: .cancelled)
    await pendingOperation?.value

    _ = careMat?.handleKey(code: 49)
    await pendingOperation?.value
    let farFuture = ProcessInfo.processInfo.systemUptime + 10
    let keyboardStep = careMat?.nextStep(elapsedSeconds: 0.1, now: farFuture)
    let keyboardQualityPersists: Bool
    if case .some(.step(_, _, .pet(_, .some(let quality)))) = keyboardStep {
      keyboardQualityPersists = quality == 0.9
    } else {
      keyboardQualityPersists = false
    }
    results["keyboardPetQualityPersists"] = keyboardQualityPersists
    let ingressBefore = timerIngressSubmissions
    let interactionBefore = interactionStepSubmissions
    let ordinaryBefore = ordinaryAdvanceSubmissions
    let sequenceBeforeTimer = snapshot.acceptedRuntimeSequence
    let activeSecondsBeforeTimer = snapshot.activeSeconds
    startTimer()
    try? await Task.sleep(for: .seconds(1))
    await pendingOperation?.value
    let ingressDelta = timerIngressSubmissions - ingressBefore
    let interactionDelta = interactionStepSubmissions - interactionBefore
    let ordinaryDelta = ordinaryAdvanceSubmissions - ordinaryBefore
    let acceptedSequenceDelta = snapshot.acceptedRuntimeSequence - sequenceBeforeTimer
    let oneInteractionStepPerTimerIngress = ingressDelta > 0
      && interactionDelta == ingressDelta && ordinaryDelta == 0
      && acceptedSequenceDelta == UInt64(interactionDelta)
      && snapshot.activeSeconds > activeSecondsBeforeTimer
      && snapshot.interaction?.lastAcceptedOrdinal == careMat?.currentOrdinal
    results["oneInteractionStepPerTimerIngress"] = oneInteractionStepPerTimerIngress
    let keyboardPetting = snapshot.activity == .petting
    results["keyboardPetting"] = keyboardPetting
    timer?.invalidate()
    timer = nil
    _ = careMat?.handleKey(code: 49)
    await pendingOperation?.value
    let keyboardStopsContact = !(careMat?.keyboardContact ?? true)
    results["keyboardStopsContact"] = keyboardStopsContact
    let oldTerminalResult = lastAppliedResult
    careMat?.mode = .play
    _ = careMat?.handleKey(code: 49)
    await pendingOperation?.value
    let newerToken = careMat?.currentToken
    if let oldTerminalResult { consumeTerminalTokens(oldTerminalResult.terminals) }
    let staleTerminalPreservedNewToken = newerToken != nil && careMat?.currentToken == newerToken
    results["staleTerminalPreservedNewerHostToken"] = staleTerminalPreservedNewToken
    startTimer()
    try? await Task.sleep(for: .milliseconds(300))
    await pendingOperation?.value
    let keyboardPlay = snapshot.activity == .playing && careMat?.keyboardContact == true
    results["keyboardPlay"] = keyboardPlay
    _ = careMat?.handleKey(code: 49)
    await pendingOperation?.value
    let keyboardStopsPlay = snapshot.activity != .playing && careMat?.keyboardContact == false
    results["keyboardStopsPlay"] = keyboardStopsPlay
    _ = careMat?.handleKey(code: 53)
    let escapeClosesCare = care == nil
    results["escapeClosesCare"] = escapeClosesCare
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
    let renderBoundsPassed = !renderChecks.isEmpty
      && renderChecks.allSatisfy { $0["passed"] as? Bool == true }
      && careRenderCheck["passed"] as? Bool == true
    results["renderBoundsPassed"] = renderBoundsPassed
    let sessionHandlerChecksPassed = backgroundOnlyStayedLocal && bodyTransitionMintedOnce
      && pointerQualityFresh && pointerQualityExpired && keyboardQualityPersists
      && oneInteractionStepPerTimerIngress && keyboardPetting && keyboardStopsContact
      && staleTerminalPreservedNewToken && keyboardPlay && keyboardStopsPlay && escapeClosesCare
    results["sessionHandlerChecksPassed"] = sessionHandlerChecksPassed
    if let path = argument("--output") {
      do {
        let data = try JSONSerialization.data(
          withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
      } catch { print("Probe receipt failed: \(error)") }
    }
    // This native check owns its failure exit; the shell probe also rejects nonzero exits.
    if !renderBoundsPassed || !sessionHandlerChecksPassed { exit(1) }
    NSApp.terminate(nil)
  }

  /// Wait for drawable conversion, then two completed frames; a fixed delay may inspect stale state.
  private func waitForRenderedFrames(renderer: CatRenderer?, view: MTKView?, scale: CGFloat) async
    -> Bool
  {
    guard let renderer, let view, scale > 0 else { return false }
    var baseline: Int?
    for _ in 0..<100 {
      let drawableMatches = view.bounds.width > 0 && view.bounds.height > 0
        && view.window?.backingScaleFactor == scale
        && abs(view.drawableSize.width - view.bounds.width * scale) < 1
        && abs(view.drawableSize.height - view.bounds.height * scale) < 1
      if drawableMatches {
        let frames = renderer.metrics.summary().frames
        if let baseline {
          if frames >= baseline + 2 { return true }
        } else {
          baseline = frames
        }
      } else {
        baseline = nil
      }
      try? await Task.sleep(for: .milliseconds(20))
    }
    return false
  }

  /// Inspect only our scene and view. Window placement alone cannot detect clipped content.
  private func renderBounds(renderer: CatRenderer?, view: MTKView?) -> [String: Any] {
    guard let renderer, let view else { return ["passed": false] }
    let scene = renderer.scene
    let bounds = CGRect(origin: .zero, size: scene.size)
    let cat = scene.cat.calculateAccumulatedFrame()
    let decorationsFit = [scene.nook, scene.shadow].allSatisfy {
      $0.isHidden || bounds.contains($0.calculateAccumulatedFrame())
    }
    let matchesView = scene.size == view.bounds.size
    let contentFits = !cat.isEmpty && bounds.contains(cat) && decorationsFit
    return [
      "sceneWidth": scene.size.width, "sceneHeight": scene.size.height,
      "viewWidth": view.bounds.width, "viewHeight": view.bounds.height,
      "drawableWidth": view.drawableSize.width, "drawableHeight": view.drawableSize.height,
      "sceneMatchesLogicalView": matchesView, "characterAndGroundFit": contentFits,
      "passed": matchesView && contentFits,
    ]
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
