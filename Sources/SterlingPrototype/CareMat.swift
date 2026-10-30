import AppKit
import MetalKit
import SterlingCore

@MainActor final class CareMat: MTKView {
  override var isOpaque: Bool { false }
  override var acceptsFirstResponder: Bool { true }
  var mode: InteractionMode = .pet
  var interpreter = GestureInterpreter()
  weak var catRenderer: CatRenderer?
  var onCommand: ((SimulationCommand) -> Void)?
  var onQuality: ((Double?) -> Void)?
  var onDismiss: (() -> Void)?
  var keyboardContact = false
  private(set) var inputGeneration: UInt64 = 0
  private var keyboardTarget = CGPoint(x: 260, y: 90)
  private var didBeginContact = false
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
  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    let p = convert(event.locationInWindow, from: nil)
    guard interpreter.begin(point: .init(x: p.x, y: p.y), at: event.timestamp, mat: mat) else {
      return
    }
    inputGeneration &+= 1
    keyboardContact = false
    if mode == .play {
      onCommand?(.startPlay)
      catRenderer?.scene.lureTarget = p
    } else if catRenderer?.scene.region(at: p) != .outside {
      didBeginContact = true
      onCommand?(.startPet)
    }
  }
  override func mouseDragged(with event: NSEvent) {
    guard interpreter.ownsGesture else { return }
    let p = convert(event.locationInWindow, from: nil)
    if mode == .play {
      let clamped = mat.clamped(.init(x: p.x, y: p.y))
      catRenderer?.scene.lureTarget = CGPoint(x: clamped.x, y: clamped.y)
    } else {
      let region = catRenderer?.scene.region(at: p) ?? .outside
      if region != .outside && !didBeginContact {
        didBeginContact = true
        onCommand?(.startPet)
      }
      onQuality?(
        interpreter.stroke(
          point: .init(x: p.x, y: p.y), at: event.timestamp, region: region, bodyLength: 160))
    }
  }
  override func mouseUp(with event: NSEvent) { cancelGesture() }
  override func keyDown(with event: NSEvent) {
    if event.isARepeat && event.keyCode == 49 { return }
    if !handleKey(code: event.keyCode) { super.keyDown(with: event) }
  }
  @discardableResult func handleKey(code: UInt16) -> Bool {
    switch code {
    case 53:
      cancelGesture()
      onDismiss?()
      return true
    case 49:
      inputGeneration &+= 1
      keyboardContact.toggle()
      if keyboardContact {
        onCommand?(mode == .pet ? .startPet : .startPlay)
        onQuality?(mode == .pet ? 0.9 : nil)
      } else {
        cancelGesture()
      }
      return true
    case 123, 124, 125, 126:
      guard mode == .play else { return false }
      keyboardTarget.x += code == 123 ? -12 : code == 124 ? 12 : 0
      keyboardTarget.y += code == 125 ? -12 : code == 126 ? 12 : 0
      let p = mat.clamped(.init(x: keyboardTarget.x, y: keyboardTarget.y))
      keyboardTarget = CGPoint(x: p.x, y: p.y)
      catRenderer?.scene.lureTarget = keyboardTarget
      return true
    default: return false
    }
  }
  func cancelGesture() {
    inputGeneration &+= 1
    interpreter.end()
    keyboardContact = false
    didBeginContact = false
    onQuality?(nil)
    onCommand?(.stopInteraction)
  }
  @objc private func accessiblePet() -> Bool {
    inputGeneration &+= 1
    mode = .pet
    keyboardContact = true
    onCommand?(.startPet)
    onQuality?(0.9)
    return true
  }
  @objc private func accessibleStop() -> Bool {
    cancelGesture()
    return true
  }
}
