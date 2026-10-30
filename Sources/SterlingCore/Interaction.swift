import Foundation

public struct WorldPoint: Codable, Equatable, Sendable {
  public var x: Double
  public var y: Double
  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
  public func distance(to other: Self) -> Double { hypot(x - other.x, y - other.y) }
}
public struct WorldRect: Codable, Equatable, Sendable {
  public var x: Double, y: Double, width: Double, height: Double
  public init(x: Double, y: Double, width: Double, height: Double) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }
  public func contains(_ p: WorldPoint) -> Bool {
    [x, y, width, height, p.x, p.y].allSatisfy(\.isFinite) && width > 0 && height > 0
      && p.x >= x && p.y >= y && p.x < x + width && p.y < y + height
  }
  public func clamped(_ point: WorldPoint) -> WorldPoint {
    .init(x: min(x + width, max(x, point.x)), y: min(y + height, max(y, point.y)))
  }
}
public struct DisplayGeometry: Codable, Equatable, Sendable {
  public var token: UInt32
  public var globalFrame: WorldRect
  public var usableFrame: WorldRect
  public var scale: Double
  public init(token: UInt32, globalFrame: WorldRect, usableFrame: WorldRect, scale: Double) {
    self.token = token
    self.globalFrame = globalFrame
    self.usableFrame = usableFrame
    self.scale = scale
  }
  public func localPoint(fromGlobal point: WorldPoint) -> WorldPoint {
    .init(x: point.x - globalFrame.x, y: point.y - globalFrame.y)
  }
  public func backingPoint(fromLocal point: WorldPoint) -> WorldPoint {
    .init(x: point.x * scale, y: point.y * scale)
  }
}
public enum InteractionMode: String, Sendable { case pet, play }
public enum BodyRegion: Sendable { case head, back, sensitive, outside }

/// Ownership begins only with a down inside the visible, explicitly opened care mat.
/// Passive visuals never call this interpreter. Cancelled or foreign drags cannot begin ownership.
public struct GestureInterpreter: Sendable {
  public private(set) var ownsGesture = false
  public private(set) var lastPoint: WorldPoint?
  private var lastTime: Double?
  public init() {}
  @discardableResult public mutating func begin(point: WorldPoint, at time: Double, mat: WorldRect)
    -> Bool
  {
    guard !ownsGesture, time.isFinite, mat.contains(point) else { return false }
    ownsGesture = true
    lastPoint = point
    lastTime = time
    return true
  }
  public mutating func stroke(
    point: WorldPoint, at time: Double, region: BodyRegion, bodyLength: Double
  ) -> Double? {
    guard ownsGesture, let previous = lastPoint, let previousTime = lastTime,
      time.isFinite, point.x.isFinite, point.y.isFinite, bodyLength.isFinite, bodyLength > 0
    else { return nil }
    defer {
      lastPoint = point
      lastTime = time
    }
    let dt = time - previousTime
    guard dt > 0, dt <= 0.25, region != .outside else { return nil }
    let distance = point.distance(to: previous)
    guard distance >= 0.5 else { return nil }  // Still contact is acknowledgment, not repeated strokes.
    let speed = distance / bodyLength / dt
    guard speed < 20 else { return nil }  // Ignore impossible discontinuities.
    let weight: Double = region == .head ? 1 : region == .back ? 0.85 : 0.35
    let speedWeight =
      speed >= 0.3 && speed <= 2.5 ? 1 : max(0.25, speed < 0.3 ? speed / 0.3 : 2.5 / speed)
    return weight * speedWeight
  }
  public mutating func end() {
    ownsGesture = false
    lastPoint = nil
    lastTime = nil
  }
}
