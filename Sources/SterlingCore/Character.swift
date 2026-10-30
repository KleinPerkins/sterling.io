import Foundation

public func unit(_ value: Double) -> Double {
  value.isFinite ? min(1, max(0, value)) : 0
}

public struct CharacterState: Codable, Equatable, Sendable {
  public var hunger = 0.25
  public var satiety = 0.35
  public var energy = 0.75
  public var sleepPressure = 0.20
  public var socialAppetite = 0.55
  public var contactDesire = 0.45
  public var contactSatisfaction = 0.0
  public var playMotivation = 0.60
  public var arousal = 0.15
  public var comfort = 0.80
  public var safety = 0.95
  public var curiosity = 0.55
  public var overstimulation = 0.0
  public var familiarity = 0.15
  public init() {}

  public var receptiveness: Double {
    unit(
      0.15 + 0.65 * contactDesire + 0.20 * socialAppetite
        - 0.75 * contactSatisfaction - 0.65 * overstimulation
        - 0.25 * arousal - 0.30 * sleepPressure - 0.20 * hunger)
  }

  public mutating func normalize() {
    hunger = min(0.80, unit(hunger))
    satiety = unit(satiety)
    energy = unit(energy)
    sleepPressure = unit(sleepPressure)
    socialAppetite = min(0.80, unit(socialAppetite))
    contactDesire = unit(contactDesire)
    contactSatisfaction = unit(contactSatisfaction)
    playMotivation = unit(playMotivation)
    arousal = unit(arousal)
    comfort = unit(comfort)
    safety = unit(safety)
    curiosity = unit(curiosity)
    overstimulation = unit(overstimulation)
    familiarity = unit(familiarity)
  }
}

public struct ToyState: Codable, Equatable, Sendable {
  public var boredom = 0.0
  public var novelty = 0.80
  public var preference = 0.50
  public init() {}
  public func interest(character: CharacterState, patternQuality: Double = 1) -> Double {
    unit(
      0.35 * character.energy + 0.25 * character.playMotivation
        + 0.15 * preference + 0.15 * novelty + 0.10 * unit(patternQuality)
        - 0.40 * boredom - 0.20 * character.overstimulation - 0.15 * character.sleepPressure)
  }
}

public enum Activity: String, Codable, Sendable {
  case resting, watching, walking, petting, playing, eating, settling
}

public struct ControlPolicy: Codable, Equatable, Sendable {
  public var hidden = false
  public var paused = false
  public var quiet = true
  public var focused = false
  public var reducedMotion = false
  public init() {}
  public var advancesNeeds: Bool { !hidden && !paused }
  public var allowsAttention: Bool { advancesNeeds && !quiet && !focused }
}

public struct SeededRandom: Codable, Equatable, Sendable {
  public private(set) var state: UInt64
  public init(seed: UInt64) { state = seed }
  public mutating func nextUnit() -> Double {
    // SplitMix64, pinned as random algorithm version 1.
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    z ^= z >> 31
    return Double(z >> 11) / 9_007_199_254_740_992
  }
}

public struct AttentionBudget: Codable, Equatable, Sendable {
  public private(set) var availableSeconds = 0.0
  public private(set) var starts: [Double] = []
  public private(set) var blockedUntil = 60.0
  public init() {}
  public mutating func advance(seconds: Double, available: Bool) {
    guard available, seconds.isFinite, seconds > 0 else { return }
    availableSeconds += seconds
    starts.removeAll { availableSeconds - $0 >= 1_200 }
  }
  public var canStart: Bool { availableSeconds >= blockedUntil && starts.count < 2 }
  @discardableResult public mutating func start() -> Bool {
    guard canStart else { return false }
    starts.append(availableSeconds)
    return true
  }
  public mutating func unanswered() { blockedUntil = max(blockedUntil, availableSeconds + 900) }
  public mutating func resumeGrace() { blockedUntil = max(blockedUntil, availableSeconds + 60) }
}
