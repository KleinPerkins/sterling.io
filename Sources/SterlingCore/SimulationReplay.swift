import Foundation

/// Identities supplied by a fixture's author and checked by its runner. This is not a save format.
public struct SimulationReplayIdentity: Codable, Equatable, Sendable {
  public let codeVersion: String
  public let contentVersion: String
  public let tuningVersion: String

  public init(codeVersion: String, contentVersion: String, tuningVersion: String) {
    self.codeVersion = codeVersion
    self.contentVersion = contentVersion
    self.tuningVersion = tuningVersion
  }
}

/// Synthetic, simulation-local input. No platform event, wall clock, or renderer is consulted.
public enum SimulationReplayInput: Codable, Equatable, Sendable {
  case command(SimulationCommand)
  case interaction(InteractionInput)
  case advance(seconds: Double)
  case reconcileReturn(absenceSeconds: Double)
}

public struct SimulationReplayRecord: Codable, Equatable, Sendable {
  public let sequence: Int
  public let input: SimulationReplayInput

  public init(sequence: Int, input: SimulationReplayInput) {
    self.sequence = sequence
    self.input = input
  }
}

public enum SimulationReplayError: Error, Equatable, Sendable {
  case unsupportedSchema
  case incompatibleIdentity
  case invalidIdentity
  case tooManyRecords
  case tooMuchActiveTime
  case tooManyBytes
  case invalidSequence(index: Int)
  case invalidTime(index: Int)
  case invalidQuality(index: Int)
  case invalidInteraction(index: Int)
}

public struct SimulationReplayInteractionResult: Codable, Equatable, Sendable {
  public let recordSequence: Int
  public let disposition: RuntimeDisposition
  public let runtimeSequence: UInt64?
  public let terminals: [InteractionTerminal]

  public init(recordSequence: Int, result: RuntimeResult) {
    self.recordSequence = recordSequence
    disposition = result.disposition
    runtimeSequence = result.runtimeSequence
    terminals = result.terminals
  }
}

public struct SimulationReplayRunResult: Codable, Equatable, Sendable {
  public let simulation: Simulation
  public let interactionResults: [SimulationReplayInteractionResult]

  public init(
    simulation: Simulation, interactionResults: [SimulationReplayInteractionResult]
  ) {
    self.simulation = simulation
    self.interactionResults = interactionResults
  }
}

/// Bounded developer fixtures for the existing prototype reducer, not a production event bus.
/// The exact step schedule is part of the fixture; cross-version/platform float identity is not promised.
public struct SimulationReplay: Codable, Equatable, Sendable {
  public static let currentSchemaVersion = 2
  public static let maximumRecords = 10_000
  public static let maximumActiveSeconds = 8.0 * 3_600
  public static let maximumBytes = 4 * 1_024 * 1_024

  public let schemaVersion: Int
  public let identity: SimulationReplayIdentity
  public let seed: UInt64
  public let records: [SimulationReplayRecord]

  public init(
    schemaVersion: Int = Self.currentSchemaVersion,
    identity: SimulationReplayIdentity, seed: UInt64, records: [SimulationReplayRecord]
  ) {
    self.schemaVersion = schemaVersion
    self.identity = identity
    self.seed = seed
    self.records = records
  }

  /// Validate the whole envelope before executing any input. Never silently truncate a fixture.
  public func validate(expectedIdentity: SimulationReplayIdentity) throws {
    guard schemaVersion == Self.currentSchemaVersion else {
      throw SimulationReplayError.unsupportedSchema
    }
    guard identity == expectedIdentity else { throw SimulationReplayError.incompatibleIdentity }
    for value in [identity.codeVersion, identity.contentVersion, identity.tuningVersion] {
      guard !value.isEmpty, value.utf8.count <= 128,
        value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
      else { throw SimulationReplayError.invalidIdentity }
    }
    guard records.count <= Self.maximumRecords else { throw SimulationReplayError.tooManyRecords }
    var activeSeconds = 0.0
    for (index, record) in records.enumerated() {
      guard record.sequence == index else { throw SimulationReplayError.invalidSequence(index: index) }
      switch record.input {
      case .command: break
      case .advance(let seconds):
        guard seconds.isFinite, seconds > 0, seconds <= 5 else {
          throw SimulationReplayError.invalidTime(index: index)
        }
        activeSeconds += seconds
      case .interaction(let input):
        if case .step(_, let seconds, let sample) = input {
          guard seconds.isFinite, seconds > 0, seconds <= 5 else {
            throw SimulationReplayError.invalidTime(index: index)
          }
          if case .pet(_, let quality) = sample, let quality,
            !quality.isFinite || !(0...1).contains(quality)
          {
            throw SimulationReplayError.invalidQuality(index: index)
          }
          activeSeconds += seconds
        }
        guard input.isStructurallyValid else {
          throw SimulationReplayError.invalidInteraction(index: index)
        }
      case .reconcileReturn(let seconds):
        guard seconds.isFinite, seconds >= 0 else {
          throw SimulationReplayError.invalidTime(index: index)
        }
      }
      guard activeSeconds <= Self.maximumActiveSeconds else {
        throw SimulationReplayError.tooMuchActiveTime
      }
    }
  }

  /// Import only explicitly supplied developer data. This API never records live input or writes files.
  public static func decode(_ data: Data, expectedIdentity: SimulationReplayIdentity) throws -> Self {
    guard data.count <= Self.maximumBytes else { throw SimulationReplayError.tooManyBytes }
    let replay = try JSONDecoder().decode(Self.self, from: data)
    try replay.validate(expectedIdentity: expectedIdentity)
    return replay
  }

  public func runWithResults(
    expectedIdentity: SimulationReplayIdentity
  ) throws -> SimulationReplayRunResult {
    try validate(expectedIdentity: expectedIdentity)
    var simulation = Simulation(seed: seed)
    var interactionResults: [SimulationReplayInteractionResult] = []
    interactionResults.reserveCapacity(records.count)
    for record in records {
      switch record.input {
      case .command(let command): _ = simulation.send(command)
      case .interaction(let input):
        interactionResults.append(
          .init(recordSequence: record.sequence, result: simulation.accept(input)))
      case .advance(let seconds): _ = simulation.advance(seconds: seconds)
      case .reconcileReturn(let seconds):
        _ = simulation.reconcileReturn(absenceSeconds: seconds)
      }
    }
    return .init(simulation: simulation, interactionResults: interactionResults)
  }

  public func run(expectedIdentity: SimulationReplayIdentity) throws -> Simulation {
    try runWithResults(expectedIdentity: expectedIdentity).simulation
  }
}
