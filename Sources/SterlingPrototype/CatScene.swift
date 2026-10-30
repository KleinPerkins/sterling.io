import AppKit
import SpriteKit
import SterlingCore

/// Temporary shape study for feasibility. Not an approved likeness or production asset.
@MainActor final class CatScene: SKScene {
  let cat = SKNode()
  let body = SKNode()
  let head = SKNode()
  let eyeLeft = SKShapeNode(ellipseOf: CGSize(width: 11, height: 13))
  let eyeRight = SKShapeNode(ellipseOf: CGSize(width: 11, height: 13))
  let tail = SKShapeNode()
  let lure = SKShapeNode(ellipseOf: CGSize(width: 20, height: 12))
  let string = SKShapeNode()
  let shadow = SKShapeNode(ellipseOf: CGSize(width: 164, height: 16))
  let nook = SKShapeNode(ellipseOf: CGSize(width: 196, height: 38))
  var snapshot = Simulation().snapshot
  var interactive = false
  var lureTarget: CGPoint?
  private var walkX: CGFloat = 0
  private var lastFrameTime: Double?
  private let fur = NSColor(calibratedRed: 0.43, green: 0.47, blue: 0.51, alpha: 1)
  private let lightFur = NSColor(calibratedRed: 0.66, green: 0.69, blue: 0.71, alpha: 1)
  private let darkFur = NSColor(calibratedRed: 0.26, green: 0.30, blue: 0.34, alpha: 1)

  override init(size: CGSize) {
    super.init(size: size)
    backgroundColor = .clear
    scaleMode = .resizeFill
    shadow.fillColor = .black.withAlphaComponent(0.13)
    shadow.strokeColor = .clear
    shadow.zPosition = -2
    nook.fillColor = NSColor(calibratedRed: 0.73, green: 0.62, blue: 0.49, alpha: 0.35)
    nook.strokeColor = NSColor(calibratedRed: 0.72, green: 0.60, blue: 0.47, alpha: 0.55)
    nook.lineWidth = 1
    nook.zPosition = -3
    addChild(nook)
    addChild(shadow)
    addChild(cat)
    cat.addChild(body)
    cat.addChild(head)
    tail.strokeColor = darkFur
    tail.lineWidth = 18
    tail.lineCap = .round
    tail.zPosition = -1
    cat.addChild(tail)
    addEllipse(
      to: body, size: CGSize(width: 132, height: 91), point: CGPoint(x: -13, y: 57), color: fur)
    addEllipse(
      to: body, size: CGSize(width: 72, height: 83), point: CGPoint(x: -52, y: 55), color: fur)
    addEllipse(
      to: body, size: CGSize(width: 50, height: 58), point: CGPoint(x: 35, y: 47), color: lightFur)
    for x: CGFloat in [-58, -26, 24, 49] {
      addEllipse(
        to: body, size: CGSize(width: 27, height: 23), point: CGPoint(x: x, y: 13),
        color: x > 0 ? lightFur : fur)
    }
    head.position = CGPoint(x: 41, y: 107)
    addEllipse(to: head, size: CGSize(width: 76, height: 65), point: .zero, color: fur)
    let earL = CGMutablePath()
    earL.move(to: CGPoint(x: -32, y: 17))
    earL.addLine(to: CGPoint(x: -35, y: 53))
    earL.addLine(to: CGPoint(x: -9, y: 30))
    earL.closeSubpath()
    let earR = CGMutablePath()
    earR.move(to: CGPoint(x: 10, y: 30))
    earR.addLine(to: CGPoint(x: 35, y: 52))
    earR.addLine(to: CGPoint(x: 33, y: 13))
    earR.closeSubpath()
    for p in [earL, earR] {
      let e = SKShapeNode(path: p)
      e.fillColor = darkFur
      e.strokeColor = .clear
      e.zPosition = -1
      head.addChild(e)
    }
    let innerL = CGMutablePath()
    innerL.move(to: CGPoint(x: -28, y: 26))
    innerL.addLine(to: CGPoint(x: -29, y: 43))
    innerL.addLine(to: CGPoint(x: -16, y: 29))
    innerL.closeSubpath()
    let innerR = CGMutablePath()
    innerR.move(to: CGPoint(x: 18, y: 30))
    innerR.addLine(to: CGPoint(x: 29, y: 43))
    innerR.addLine(to: CGPoint(x: 28, y: 24))
    innerR.closeSubpath()
    for p in [innerL, innerR] {
      let e = SKShapeNode(path: p)
      e.fillColor = NSColor(calibratedRed: 0.70, green: 0.56, blue: 0.57, alpha: 1)
      e.strokeColor = .clear
      head.addChild(e)
    }
    for (node, x) in [(eyeLeft, CGFloat(-16)), (eyeRight, CGFloat(16))] {
      node.position = CGPoint(x: x, y: 7)
      node.fillColor = NSColor(calibratedRed: 0.73, green: 0.81, blue: 0.59, alpha: 1)
      node.strokeColor = darkFur
      node.lineWidth = 1
      head.addChild(node)
      addEllipse(to: node, size: CGSize(width: 3, height: 10), point: .zero, color: darkFur)
    }
    for x: CGFloat in [-10, 10] {
      addEllipse(
        to: head, size: CGSize(width: 27, height: 19), point: CGPoint(x: x, y: -14),
        color: NSColor(calibratedWhite: 0.85, alpha: 1))
    }
    let nose = CGMutablePath()
    nose.move(to: CGPoint(x: -5, y: -7))
    nose.addLine(to: CGPoint(x: 5, y: -7))
    nose.addLine(to: CGPoint(x: 0, y: -12))
    nose.closeSubpath()
    let n = SKShapeNode(path: nose)
    n.fillColor = NSColor(calibratedRed: 0.60, green: 0.44, blue: 0.46, alpha: 1)
    n.strokeColor = .clear
    head.addChild(n)
    for sign: CGFloat in [-1, 1] {
      for offset: CGFloat in [-5, 1, 7] {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: sign * 19, y: -13 + offset))
        p.addLine(to: CGPoint(x: sign * 47, y: -13 + offset * 1.5))
        let w = SKShapeNode(path: p)
        w.strokeColor = NSColor(calibratedWhite: 0.84, alpha: 0.85)
        w.lineWidth = 0.8
        head.addChild(w)
      }
    }
    string.strokeColor = NSColor(calibratedWhite: 0.46, alpha: 1)
    string.lineWidth = 1.5
    addChild(string)
    lure.fillColor = NSColor(calibratedRed: 0.65, green: 0.36, blue: 0.25, alpha: 1)
    lure.strokeColor = .clear
    addChild(lure)
    lure.isHidden = true
    string.isHidden = true
  }
  required init?(coder: NSCoder) { fatalError("Programmatic scene only") }
  private func addEllipse(to node: SKNode, size: CGSize, point: CGPoint, color: NSColor) {
    let shape = SKShapeNode(ellipseOf: size)
    shape.position = point
    shape.fillColor = color
    shape.strokeColor = .clear
    node.addChild(shape)
  }
  var catCenter: CGPoint { cat.position }
  func region(at point: CGPoint) -> BodyRegion {
    let local = cat.convert(point, from: self)
    if CGRect(x: 1, y: 76, width: 82, height: 79).contains(local) { return .head }
    if CGRect(x: -82, y: 20, width: 135, height: 84).contains(local) { return .back }
    return .outside
  }
  func pose(at time: Double) {
    let dt = min(0.1, max(0, time - (lastFrameTime ?? time)))
    lastFrameTime = time
    let c = snapshot.character
    let reduced = snapshot.policy.reducedMotion
    let playing = snapshot.activity == .playing
    let resting = snapshot.activity == .resting || snapshot.activity == .settling
    let targetX: CGFloat
    if playing, let target = lureTarget {
      targetX = min(size.width - 105, max(105, target.x - 45))
    } else if snapshot.activity == .walking && !reduced {
      targetX = size.width / 2 + sin(time * 0.20) * min(100, size.width * 0.18)
    } else {
      targetX = size.width / 2
    }
    if walkX == 0 { walkX = targetX }
    walkX += (targetX - walkX) * min(1, dt * 3)
    cat.position = CGPoint(x: walkX, y: interactive ? 48 : 27)
    let breath = 1 + sin(time * 1.7) * (reduced ? 0.006 : 0.012)
    body.yScale = (resting ? 0.85 : 1) * breath
    head.position.y = resting ? 91 : 107
    head.zRotation =
      snapshot.activity == .petting
      ? CGFloat(0.06 + 0.06 * c.contactDesire) : CGFloat(reduced ? 0 : sin(time * 0.35) * 0.025)
    let blink = sin(time * 0.7) > 0.995
    let eyeScale: CGFloat = resting ? 0.17 : blink ? 0.1 : snapshot.activity == .petting ? 0.55 : 1
    eyeLeft.yScale = eyeScale
    eyeRight.yScale = eyeScale
    let tailPath = CGMutablePath()
    tailPath.move(to: CGPoint(x: -68, y: 35))
    let tailMotion =
      reduced
      ? 0
      : sin(time * (c.overstimulation > 0.08 ? 5 : 1)) * CGFloat(c.overstimulation > 0.08 ? 15 : 4)
    tailPath.addCurve(
      to: CGPoint(x: -115, y: 65 + tailMotion), control1: CGPoint(x: -111, y: 6),
      control2: CGPoint(x: -132, y: 28))
    tail.path = tailPath
    shadow.position = CGPoint(x: walkX - 9, y: cat.position.y + 4)
    nook.position = CGPoint(x: size.width / 2 - 12, y: cat.position.y + 5)
    nook.isHidden = playing
    lure.isHidden = !playing
    string.isHidden = !playing
    if playing {
      let target =
        lureTarget
        ?? CGPoint(
          x: size.width / 2 + (reduced ? 70 : sin(time * 1.3) * 100),
          y: 62 + (reduced ? 20 : abs(sin(time * 0.9)) * 50))
      lure.position = target
      let p = CGMutablePath()
      p.move(to: CGPoint(x: target.x + 25, y: min(size.height - 12, target.y + 110)))
      p.addQuadCurve(to: target, control: CGPoint(x: target.x - 10, y: target.y + 50))
      string.path = p
    }
  }
}
