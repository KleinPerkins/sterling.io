import AppKit
import MetalKit
import SterlingCore

@MainActor final class CareMat: MTKView {
  override var isOpaque: Bool { false }
  override var acceptsFirstResponder: Bool { true }

  var mode: InteractionMode = .pet
  var interpreter = GestureInterpreter()
  weak var catRenderer: CatRenderer?
  var onAcquire: ((InteractionMode, InteractionSource) -> InteractionToken?)?
  var onEnd: ((InteractionInput) -> Void)?
  var onDismiss: (() -> Void)?
  private(set) var keyboardContact = false
  private(set) var currentToken: InteractionToken?
  private(set) var currentOrdinal: UInt64 = 0
  private(set) var latestSample: InteractionSample?
  private(set) var currentSource: InteractionSource?
  private var latestSampleTime: Double?
  private var keyboardTarget = CGPoint(x: 260, y: 90)
  private var endSubmitted = false

  override init(frame: CGRect, device: (any MTLDevice)?) {
    super.init(frame: frame, device: device)
    setAccessibilityElement(true)
    setAccessibilityRole(.group)
    setAccessibilityLabel("Sterling care area")
    setAccessibilityHelp(
      "Stroke Sterling's head or back. Space starts or stops gentle petting. In Play, use arrows to move the toy. Escape closes care."
    )
    setAccessibilityCustomActions([
      NSAccessibilityCustomAction(
        name: "Pet gently", target: self, selector: #selector(accessiblePet)),
      NSAccessibilityCustomAction(
        name: "Stop interaction", target: self, selector: #selector(accessibleStop)),
    ])
  }

  required init(coder: NSCoder) { fatalError("Programmatic view only") }

  private var mat: WorldRect { .init(x: 0, y: 0, width: bounds.width, height: bounds.height) }

  @discardableResult private func acquire(
    mode: InteractionMode, source: InteractionSource, sample: InteractionSample,
    sampleTime: Double? = nil
  ) -> Bool {
    guard currentToken == nil, let token = onAcquire?(mode, source) else { return false }
    currentToken = token
    currentOrdinal = 0
    endSubmitted = false
    latestSample = sample
    currentSource = source
    latestSampleTime = sampleTime
    keyboardContact = source != .pointer
    return true
  }

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    let point = convert(event.locationInWindow, from: nil)
    handlePointerDown(
      point: point, timestamp: event.timestamp,
      region: catRenderer?.scene.region(at: point) ?? .outside)
  }

  override func mouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    handlePointerDrag(
      point: point, timestamp: event.timestamp,
      region: catRenderer?.scene.region(at: point) ?? .outside)
  }

  /// Shared by native handlers and the non-physical probe; it never inspects another app.
  func handlePointerDown(point: CGPoint, timestamp: Double, region: BodyRegion) {
    guard currentToken == nil,
      interpreter.begin(
        point: .init(x: point.x, y: point.y), at: timestamp, mat: mat)
    else { return }
    keyboardContact = false
    if mode == .play {
      _ = acquire(mode: .play, source: .pointer, sample: .play)
      catRenderer?.scene.lureTarget = point
    } else if region != .outside {
      _ = acquire(
        mode: .pet, source: .pointer, sample: .pet(region: region, quality: nil),
        sampleTime: timestamp)
    }
  }

  /// Shared by native handlers and the non-physical probe; input ownership must already be local.
  func handlePointerDrag(point: CGPoint, timestamp: Double, region: BodyRegion) {
    guard interpreter.ownsGesture else { return }
    if mode == .play {
      let clamped = mat.clamped(.init(x: point.x, y: point.y))
      catRenderer?.scene.lureTarget = CGPoint(x: clamped.x, y: clamped.y)
      if currentToken != nil { latestSample = .play }
      return
    }
    let quality = interpreter.stroke(
      point: .init(x: point.x, y: point.y), at: timestamp, region: region,
      bodyLength: 160)
    if currentToken == nil, region != .outside {
      _ = acquire(
        mode: .pet, source: .pointer,
        sample: .pet(region: region, quality: quality), sampleTime: timestamp)
    } else if currentToken != nil {
      latestSample = .pet(region: region, quality: quality)
      latestSampleTime = timestamp
    }
  }

  override func mouseUp(with event: NSEvent) { cancelGesture(reason: .completed) }

  override func keyDown(with event: NSEvent) {
    if event.isARepeat && event.keyCode == 49 { return }
    if !handleKey(code: event.keyCode) { super.keyDown(with: event) }
  }

  @discardableResult func handleKey(code: UInt16) -> Bool {
    switch code {
    case 53:
      cancelGesture(reason: .cancelled)
      onDismiss?()
      return true
    case 49:
      if keyboardContact || currentToken != nil {
        cancelGesture(reason: .completed)
      } else if mode == .pet {
        _ = acquire(
          mode: .pet, source: .keyboard, sample: .pet(region: .head, quality: 0.9))
      } else {
        _ = acquire(mode: .play, source: .keyboard, sample: .play)
      }
      return true
    case 123, 124, 125, 126:
      guard mode == .play else { return false }
      keyboardTarget.x += code == 123 ? -12 : code == 124 ? 12 : 0
      keyboardTarget.y += code == 125 ? -12 : code == 126 ? 12 : 0
      let point = mat.clamped(.init(x: keyboardTarget.x, y: keyboardTarget.y))
      keyboardTarget = CGPoint(x: point.x, y: point.y)
      catRenderer?.scene.lureTarget = keyboardTarget
      if currentToken != nil { latestSample = .play }
      return true
    default: return false
    }
  }

  /// The AppDelegate timer is the only caller and therefore the only effect-step producer.
  func nextStep(elapsedSeconds: Double, now: Double) -> InteractionInput? {
    guard let token = currentToken, !endSubmitted, var sample = latestSample,
      currentOrdinal < UInt64.max - 1
    else { return nil }
    if currentSource == .pointer,
      case .pet(let region, .some) = sample,
      let sampleTime = latestSampleTime,
      !now.isFinite || now - sampleTime >= 0.25
    {
      sample = .pet(region: region, quality: nil)
    }
    currentOrdinal += 1
    return .step(
      stamp: .init(token: token, sourceOrdinal: currentOrdinal),
      elapsedSeconds: elapsedSeconds, sample: sample)
  }

  func cancelGesture(reason: InteractionInputEndReason) {
    interpreter.end()
    keyboardContact = false
    latestSample = nil
    latestSampleTime = nil
    guard let token = currentToken, !endSubmitted, currentOrdinal < UInt64.max else { return }
    currentOrdinal += 1
    endSubmitted = true
    onEnd?(
      .end(
        stamp: .init(token: token, sourceOrdinal: currentOrdinal),
        reason: reason))
  }

  /// Owner/lifecycle ingress supplies the terminal fact. This only stops local sampling immediately.
  func abandonLocalInputForOwnerPreemption() {
    interpreter.end()
    keyboardContact = false
    latestSample = nil
    latestSampleTime = nil
    endSubmitted = true
  }

  func clear(token: InteractionToken) {
    guard currentToken == token else { return }
    interpreter.end()
    keyboardContact = false
    currentToken = nil
    currentOrdinal = 0
    latestSample = nil
    currentSource = nil
    latestSampleTime = nil
    endSubmitted = false
  }

  @objc private func accessiblePet() -> Bool {
    guard currentToken == nil else { return false }
    mode = .pet
    return acquire(
      mode: .pet, source: .accessibility, sample: .pet(region: .head, quality: 0.9))
  }

  @objc private func accessibleStop() -> Bool {
    cancelGesture(reason: .cancelled)
    return true
  }
}
