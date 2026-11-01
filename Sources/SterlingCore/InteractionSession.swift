import Foundation

public struct CareSessionID: RawRepresentable, Codable, Equatable, Hashable, Sendable {
  public let rawValue: UInt64

  public init(rawValue: UInt64) { self.rawValue = rawValue }
}

public struct InteractionToken: Codable, Equatable, Hashable, Sendable {
  public let careSessionID: CareSessionID
  public let generation: UInt64

  public init(careSessionID: CareSessionID, generation: UInt64) {
    self.careSessionID = careSessionID
    self.generation = generation
  }
}

public struct InteractionStamp: Codable, Equatable, Hashable, Sendable {
  public let token: InteractionToken
  public let sourceOrdinal: UInt64

  public init(token: InteractionToken, sourceOrdinal: UInt64) {
    self.token = token
    self.sourceOrdinal = sourceOrdinal
  }
}

public enum InteractionSource: String, Codable, Equatable, Sendable {
  case pointer, keyboard, accessibility
}

public enum InteractionSample: Codable, Equatable, Sendable {
  case pet(region: BodyRegion, quality: Double?)
  case play
}

/// Facts that an input adapter is allowed to report. Lifecycle and semantic outcomes stay core-owned.
public enum InteractionInputEndReason: String, Codable, Equatable, Sendable {
  case completed, cancelled, lostCapture, windowResignedKey, careClosed, modeChanged
}

public enum InteractionTerminalReason: Codable, Equatable, Sendable {
  case input(InteractionInputEndReason)
  case displayChanged, systemSuspended, hidden, paused, focusStarted
  case settledByOwner, supersededByFood, supersededGeneration
  case declined, policyUnavailable, naturalBoundary
}

public enum InteractionInput: Codable, Equatable, Sendable {
  case begin(stamp: InteractionStamp, mode: InteractionMode, source: InteractionSource)
  case step(stamp: InteractionStamp, elapsedSeconds: Double, sample: InteractionSample)
  case end(stamp: InteractionStamp, reason: InteractionInputEndReason)

  var stamp: InteractionStamp {
    switch self {
    case .begin(let stamp, _, _), .step(let stamp, _, _), .end(let stamp, _): stamp
    }
  }

  var isStructurallyValid: Bool {
    let stamp = stamp
    guard stamp.token.careSessionID.rawValue > 0, stamp.token.generation > 0,
      stamp.token.generation < UInt64.max
    else { return false }

    switch self {
    case .begin:
      return stamp.sourceOrdinal == 0
    case .step(_, let elapsedSeconds, let sample):
      // Reserve UInt64.max for an exactly-once terminal if a coalescing source jumps to max - 1.
      guard stamp.sourceOrdinal > 0, stamp.sourceOrdinal < UInt64.max,
        elapsedSeconds.isFinite, elapsedSeconds > 0,
        elapsedSeconds <= 5
      else { return false }
      switch sample {
      case .play: return true
      case .pet(let region, let quality):
        guard let quality else { return true }
        // Background samples are no-contact samples. A caller cannot bypass the adapter's body gate
        // by attaching positive quality to the outside region.
        return region != .outside && quality.isFinite && (0...1).contains(quality)
      }
    case .end:
      return stamp.sourceOrdinal > 0
    }
  }
}

public enum RuntimeLifecycleInput: String, Codable, Equatable, Sendable {
  case displayChanged, systemSuspended
}

public enum InteractionIgnoreReason: Codable, Equatable, Sendable {
  case invalidPayload
  case beginRequired(current: UInt64)
  case staleGeneration(current: UInt64)
  case foreignSession
  case duplicateOrOutOfOrder(lastAccepted: UInt64)
  case postTerminal(InteractionTerminalReason)
  case modeMismatch(expected: InteractionMode)
  case interactionTokenRequired
}

public enum RuntimeDisposition: Codable, Equatable, Sendable {
  case accepted
  case ignored(InteractionIgnoreReason)
}

public struct InteractionTerminal: Codable, Equatable, Sendable {
  public let token: InteractionToken
  public let finalOrdinal: UInt64
  public let reason: InteractionTerminalReason

  public init(token: InteractionToken, finalOrdinal: UInt64, reason: InteractionTerminalReason) {
    self.token = token
    self.finalOrdinal = finalOrdinal
    self.reason = reason
  }
}

public struct InteractionSessionSnapshot: Codable, Equatable, Sendable {
  public let token: InteractionToken
  public let mode: InteractionMode
  public let source: InteractionSource
  public let lastAcceptedOrdinal: UInt64

  public init(
    token: InteractionToken, mode: InteractionMode, source: InteractionSource,
    lastAcceptedOrdinal: UInt64
  ) {
    self.token = token
    self.mode = mode
    self.source = source
    self.lastAcceptedOrdinal = lastAcceptedOrdinal
  }
}

public struct RuntimeResult: Codable, Equatable, Sendable {
  public let snapshot: SimulationSnapshot
  public let disposition: RuntimeDisposition
  public let runtimeSequence: UInt64?
  public let terminals: [InteractionTerminal]

  public init(
    snapshot: SimulationSnapshot, disposition: RuntimeDisposition, runtimeSequence: UInt64?,
    terminals: [InteractionTerminal]
  ) {
    self.snapshot = snapshot
    self.disposition = disposition
    self.runtimeSequence = runtimeSequence
    self.terminals = terminals
  }
}

struct InteractionSession: Codable, Equatable, Sendable {
  let token: InteractionToken
  let mode: InteractionMode
  let source: InteractionSource
  var lastAcceptedOrdinal: UInt64

  var snapshot: InteractionSessionSnapshot {
    .init(
      token: token, mode: mode, source: source, lastAcceptedOrdinal: lastAcceptedOrdinal)
  }
}
