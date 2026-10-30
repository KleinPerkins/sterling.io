import AppKit
import MetalKit
import SterlingCore

@MainActor final class PassivePanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}
@MainActor final class CarePanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}
@MainActor final class TransparentMetalView: MTKView { override var isOpaque: Bool { false } }

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  let runtime = SimulationRuntime()
  var snapshot = Simulation().snapshot
  var statusItem: NSStatusItem!
  var appUpdater: AppUpdater?
  var pauseItem: NSMenuItem?
  var focusItem: NSMenuItem?
  var motionItem: NSMenuItem?
  var overlay: PassivePanel!
  var overlayView: TransparentMetalView!
  var overlayRenderer: CatRenderer!
  var care: CarePanel?
  var careMat: CareMat?
  var careRenderer: CatRenderer?
  var careStatus: NSTextField?
  var timer: Timer?
  var lastUptime = ProcessInfo.processInfo.systemUptime
  var quality: Double?
  var qualityTime = 0.0
  var pendingOperation: Task<Void, Never>?
  var updating = false
  var sessionSuspended = false
  var suspendedAt: Date?
  var isClosingCare = false
  var observers: [NSObjectProtocol] = []
  let launchForeground = NSWorkspace.shared.frontmostApplication?.processIdentifier
  let isProbe = CommandLine.arguments.contains("--probe")

  func applicationDidFinishLaunching(_ notification: Notification) {
    do {
      try makeOverlay()
      appUpdater = AppUpdater(isProbe: isProbe)
      makeMenu()
      observeEnvironment()
      startTimer()
      overlay.orderFrontRegardless()
      if isProbe { Task { await runProbe() } }
    } catch {
      let alert = NSAlert()
      alert.messageText = "Sterling couldn't start the preview."
      alert.informativeText =
        "A Metal-capable display is required. No desktop permissions were requested."
      alert.runModal()
      NSApp.terminate(nil)
    }
  }
  func makeOverlay() throws {
    let usable = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_024, height: 768)
    let frame = NSRect(x: usable.maxX - 540, y: usable.minY + 12, width: 520, height: 210)
    overlay = PassivePanel(
      contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
      defer: false)
    overlay.title = "Sterling passive preview"
    overlay.backgroundColor = .clear
    overlay.isOpaque = false
    overlay.hasShadow = false
    overlay.hidesOnDeactivate = false
    overlay.ignoresMouseEvents = true
    overlay.level = .floating
    overlay.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    overlay.isReleasedWhenClosed = false
    overlayView = TransparentMetalView(frame: NSRect(origin: .zero, size: frame.size), device: nil)
    overlay.contentView = overlayView
    overlayRenderer = try CatRenderer(view: overlayView, interactive: false)
    overlayView.setAccessibilityElement(false)
    overlayView.preferredFramesPerSecond = 12
  }
  func makeMenu() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = NSImage(
      systemSymbolName: "pawprint.fill", accessibilityDescription: "Sterling")
    let menu = NSMenu()
    func item(_ title: String, _ selector: Selector, _ key: String = "") {
      let i = NSMenuItem(title: title, action: selector, keyEquivalent: key)
      i.target = self
      menu.addItem(i)
    }
    item("Care for Sterling…", #selector(openCare))
    item("Show Sterling", #selector(showSterling))
    item("Settle in your nook", #selector(settle))
    menu.addItem(.separator())
    item("Hide", #selector(hideSterling))
    item("Resume", #selector(resumeSterling))
    item("Pause Sterling", #selector(togglePause))
    pauseItem = menu.items.last
    item("Focus mode", #selector(toggleFocus))
    focusItem = menu.items.last
    item("Reduce motion", #selector(toggleMotion))
    motionItem = menu.items.last
    menu.addItem(.separator())
    let label = NSMenuItem(
      title: "Feasibility preview · temporary artwork", action: nil, keyEquivalent: "")
    label.isEnabled = false
    menu.addItem(label)
    appUpdater?.addMenuItems(to: menu)
    item("Quit Sterling", #selector(quit), "q")
    statusItem.menu = menu
  }
  func button(_ title: String, _ selector: Selector) -> NSButton {
    let b = NSButton(title: title, target: self, action: selector)
    b.bezelStyle = .rounded
    b.setAccessibilityLabel(title)
    return b
  }
  @objc func openCare() {
    guard !snapshot.policy.hidden else {
      Task {
        apply(await runtime.send(.resume))
        openCare()
      }
      return
    }
    if let care {
      care.makeKeyAndOrderFront(nil)
      return
    }
    do {
      let panel = CarePanel(
        contentRect: NSRect(x: 0, y: 0, width: 560, height: 456),
        styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
      panel.title = "A little time with Sterling"
      panel.hidesOnDeactivate = false
      panel.isReleasedWhenClosed = false
      panel.delegate = self
      panel.backgroundColor = .windowBackgroundColor
      let root = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 456))
      panel.contentView = root
      let title = NSTextField(labelWithString: "A little time together")
      title.font = .systemFont(ofSize: 22, weight: .semibold)
      let subtitle = NSTextField(
        wrappingLabelWithString: "Stroke his head or back, or invite him to play.")
      subtitle.font = .systemFont(ofSize: 13)
      subtitle.textColor = .secondaryLabelColor
      let modes = NSSegmentedControl(
        labels: ["Pet", "Play"], trackingMode: .selectOne, target: self,
        action: #selector(changeMode(_:)))
      modes.selectedSegment = 0
      let mat = CareMat(frame: NSRect(x: 0, y: 0, width: 512, height: 258), device: nil)
      let renderer = try CatRenderer(view: mat, interactive: true)
      mat.catRenderer = renderer
      mat.onCommand = { [weak self] in self?.send($0) }
      mat.onQuality = { [weak self] q in
        self?.quality = q
        self?.qualityTime = ProcessInfo.processInfo.systemUptime
      }
      mat.onDismiss = { [weak self] in self?.closeCare() }
      let status = NSTextField(wrappingLabelWithString: snapshot.notice)
      status.font = .systemFont(ofSize: 13)
      status.setAccessibilityLabel("Sterling's response")
      let controls = NSStackView(views: [
        button("Offer basic food", #selector(feed)), button("Settle", #selector(settle)),
        button("Done", #selector(closeCare)),
      ])
      controls.spacing = 8
      let hint = NSTextField(
        wrappingLabelWithString:
          "Space: gentle stroke or play · Arrow keys: move toy · Esc: done\nTemporary shape study. No sound or desktop access."
      )
      hint.font = .systemFont(ofSize: 11)
      hint.textColor = .secondaryLabelColor
      let stack = NSStackView(views: [title, subtitle, modes, mat, status, controls, hint])
      stack.orientation = .vertical
      stack.alignment = .leading
      stack.spacing = 10
      stack.translatesAutoresizingMaskIntoConstraints = false
      root.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
        stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
        stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
        stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -16),
        mat.widthAnchor.constraint(equalTo: stack.widthAnchor),
        mat.heightAnchor.constraint(equalToConstant: 248),
      ])
      panel.setContentSize(NSSize(width: 560, height: 500))
      panel.center()
      care = panel
      careMat = mat
      careRenderer = renderer
      careStatus = status
      renderer.scene.snapshot = snapshot
      overlay.orderOut(nil)
      overlayView.isPaused = true
      panel.makeKeyAndOrderFront(nil)
      panel.makeFirstResponder(mat)
    } catch { careStatus?.stringValue = "The care preview could not open. Try Show Sterling." }
  }
  @objc func changeMode(_ sender: NSSegmentedControl) {
    careMat?.cancelGesture()
    careMat?.mode = sender.selectedSegment == 0 ? .pet : .play
    care?.makeFirstResponder(careMat)
  }
  @objc func closeCare() {
    guard !isClosingCare else { return }
    isClosingCare = true
    careMat?.cancelGesture()
    careMat?.isPaused = true
    care?.orderOut(nil)
    care?.delegate = nil
    care?.close()
    care = nil
    careMat = nil
    careRenderer = nil
    careStatus = nil
    if !snapshot.policy.hidden {
      overlay.orderFrontRegardless()
      overlayView.isPaused = snapshot.policy.paused
    }
    isClosingCare = false
  }
  func windowWillClose(_ notification: Notification) { closeCare() }
  func windowDidResignKey(_ notification: Notification) { careMat?.cancelGesture() }
  @objc func showSterling() {
    send(.resume)
    send(.settle)
    relocateOverlay()
  }
  @objc func hideSterling() {
    careMat?.cancelGesture()
    send(.hide)
  }
  @objc func resumeSterling() { send(.resume) }
  @objc func togglePause() {
    careMat?.cancelGesture()
    send(snapshot.policy.paused ? .unpause : .pause)
  }
  @objc func toggleFocus() { send(.setFocus(!snapshot.policy.focused)) }
  @objc func toggleMotion() { send(.setReducedMotion(!snapshot.policy.reducedMotion)) }
  @objc func feed() { send(.offerBasicFood) }
  @objc func settle() {
    careMat?.cancelGesture()
    send(.settle)
  }
  @objc func quit() { NSApp.terminate(nil) }
  func send(_ command: SimulationCommand) {
    enqueue { runtime in await runtime.send(command) }
  }
  /// Preserve UI event order across actor suspension, including cancel then restart.
  func enqueue(_ operation: @escaping @Sendable (SimulationRuntime) async -> SimulationSnapshot) {
    let previous = pendingOperation
    pendingOperation = Task {
      await previous?.value
      guard !Task.isCancelled else { return }
      apply(await operation(runtime))
    }
  }
  func apply(_ updated: SimulationSnapshot) {
    snapshot = updated
    overlayRenderer.scene.snapshot = updated
    careRenderer?.scene.snapshot = updated
    careStatus?.stringValue = updated.notice
    pauseItem?.title = updated.policy.paused ? "Continue Sterling" : "Pause Sterling"
    focusItem?.state = updated.policy.focused ? .on : .off
    motionItem?.state = updated.policy.reducedMotion ? .on : .off
    careMat?.setAccessibilityValue(updated.notice)
    if updated.policy.hidden || sessionSuspended {
      overlay.orderOut(nil)
      overlayView.isPaused = true
      careMat?.isPaused = true
      care?.orderOut(nil)
      timer?.invalidate()
      timer = nil
      quality = nil
    } else {
      if let care {
        if !care.isVisible { care.orderFront(nil) }
      } else if !overlay.isVisible {
        overlay.orderFrontRegardless()
      }
      overlayView.isPaused = updated.policy.paused || care != nil
      careMat?.isPaused = updated.policy.paused
      if updated.policy.paused {
        timer?.invalidate()
        timer = nil
        quality = nil
      } else if timer == nil {
        startTimer()
      }
    }
    let active =
      updated.activity == .playing || updated.activity == .walking || updated.activity == .petting
    let fps = ProcessInfo.processInfo.isLowPowerModeEnabled ? (active ? 30 : 6) : (active ? 60 : 12)
    overlayView.preferredFramesPerSecond = fps
    careMat?.preferredFramesPerSecond = fps
  }
  func startTimer() {
    timer?.invalidate()
    lastUptime = ProcessInfo.processInfo.systemUptime
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tick() }
    }
    timer?.tolerance = 0.01
  }
  func tick() {
    guard !updating else { return }
    updating = true
    let now = ProcessInfo.processInfo.systemUptime
    let elapsed = max(0, now - lastUptime)
    lastUptime = now
    let q = (careMat?.keyboardContact == true || now - qualityTime < 0.25) ? quality : nil
    let inputGeneration = careMat?.inputGeneration
    let previous = pendingOperation
    pendingOperation = Task {
      await previous?.value
      defer { updating = false }
      guard !Task.isCancelled, !sessionSuspended else { return }
      let updated = await runtime.advance(seconds: elapsed, contactQuality: q)
      apply(updated)
      // A stale tick must not cancel a newer input gesture.
      if inputGeneration == careMat?.inputGeneration,
        updated.activity != .petting && updated.activity != .playing
      {
        quality = nil
        careMat?.keyboardContact = false
      }
    }
  }
  func relocateOverlay() {
    guard let screen = NSScreen.main ?? NSScreen.screens.first else {
      send(.hide)
      return
    }
    let v = screen.visibleFrame
    overlay.setFrameOrigin(NSPoint(x: max(v.minX, v.maxX - 540), y: v.minY + 12))
  }
  func observeEnvironment() {
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.careMat?.cancelGesture()
          self?.relocateOverlay()
        }
      })
    let workspace = NSWorkspace.shared.notificationCenter
    observers.append(
      workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) {
        [weak self] _ in MainActor.assumeIsolated { self?.suspendSession() }
      })
    observers.append(
      workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) {
        [weak self] _ in MainActor.assumeIsolated { self?.resumeSession() }
      })
    observers.append(
      workspace.addObserver(
        forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.careMat?.cancelGesture()
          self?.relocateOverlay()
        }
      })
    observers.append(
      workspace.addObserver(
        forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main
      ) { [weak self] _ in MainActor.assumeIsolated { self?.suspendSession() } })
    observers.append(
      workspace.addObserver(
        forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
      ) { [weak self] _ in MainActor.assumeIsolated { self?.resumeSession() } })
    observers.append(
      workspace.addObserver(
        forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.send(.setReducedMotion(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion))
        }
      })
    let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    send(.setReducedMotion(reduced))
  }
  func suspendSession() {
    guard !sessionSuspended else { return }
    sessionSuspended = true
    suspendedAt = Date()
    careMat?.cancelGesture()
    timer?.invalidate()
    timer = nil
    overlayView.isPaused = true
    careMat?.isPaused = true
  }
  func resumeSession() {
    guard sessionSuspended else { return }
    let elapsed = suspendedAt.map { max(0, Date().timeIntervalSince($0)) } ?? 0
    sessionSuspended = false
    suspendedAt = nil
    relocateOverlay()
    enqueue { runtime in await runtime.reconcileReturn(absenceSeconds: elapsed) }
  }
  func applicationWillTerminate(_ notification: Notification) {
    timer?.invalidate()
    timer = nil
    pendingOperation?.cancel()
    careMat?.onCommand = nil
    careMat?.cancelGesture()
    careMat?.isPaused = true
    overlayView?.isPaused = true
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    overlay?.orderOut(nil)
    care?.orderOut(nil)
    if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
  }
}
