import Foundation
import Testing

@testable import SterlingCore

struct ReplayTests {
  private let identity = SimulationReplayIdentity(
    codeVersion: "s1-session-v2", contentVersion: "synthetic-fixtures-v2",
    tuningVersion: "prototype-v1")

  private func replay(_ inputs: [SimulationReplayInput]) -> SimulationReplay {
    .init(identity: identity, seed: 123, records: inputs.enumerated().map {
      .init(sequence: $0.offset, input: $0.element)
    })
  }

  private func direct(_ inputs: [SimulationReplayInput]) -> SimulationReplayRunResult {
    var simulation = Simulation(seed: 123)
    var interactionResults: [SimulationReplayInteractionResult] = []
    for (sequence, input) in inputs.enumerated() {
      switch input {
      case .command(let command): _ = simulation.send(command)
      case .interaction(let interaction):
        interactionResults.append(
          .init(recordSequence: sequence, result: simulation.accept(interaction)))
      case .advance(let seconds): _ = simulation.advance(seconds: seconds)
      case .reconcileReturn(let seconds):
        _ = simulation.reconcileReturn(absenceSeconds: seconds)
      }
    }
    return .init(simulation: simulation, interactionResults: interactionResults)
  }

  @Test func testReplayV2OwnedSessionMatchesDirectReducer() throws {
    let pet = token(1)
    let play = token(2)
    let inputs: [SimulationReplayInput] = [
      .interaction(begin(pet, mode: .pet)),
      .interaction(petStep(pet, 1, seconds: 5)),
      .interaction(petStep(pet, 1, seconds: 5)),
      .interaction(end(pet, 2)),
      .interaction(begin(play, mode: .play)),
      .interaction(playStep(play, 1, seconds: 5)),
      .interaction(petStep(pet, 3)),
      .command(.hide), .command(.pause), .advance(seconds: 5),
      .reconcileReturn(absenceSeconds: 7 * 24 * 3_600),
      .command(.resume), .command(.unpause), .command(.offerBasicFood), .advance(seconds: 3),
    ]
    let original = replay(inputs)
    let data = try JSONEncoder().encode(original)
    let decoded = try SimulationReplay.decode(data, expectedIdentity: identity)
    #expect(decoded == original)

    let replayed = try decoded.runWithResults(expectedIdentity: identity)
    let reduced = direct(inputs)
    #expect(replayed == reduced)
    #expect(replayed.interactionResults.map(\.disposition) == [
      .accepted, .accepted, .ignored(.duplicateOrOutOfOrder(lastAccepted: 1)), .accepted,
      .accepted, .accepted, .ignored(.staleGeneration(current: 2)),
    ])
    #expect(replayed.simulation.policy.hidden == false)
    #expect(replayed.simulation.policy.paused == false)
  }

  @Test func testPettingCurveAndNaturalBoundaryReplay() throws {
    let pet = token(1)
    let contact = SimulationReplayInput.interaction(petStep(pet, 1, quality: 1))
    var risingInputs: [SimulationReplayInput] = [.interaction(begin(pet, mode: .pet))]
    risingInputs += (1...100).map {
      .interaction(petStep(pet, UInt64($0), quality: 1))
    }
    let early = try replay(risingInputs).run(expectedIdentity: identity)
    #expect(early.character.receptiveness > Simulation().character.receptiveness)
    #expect(contact != .advance(seconds: 0.1))

    var inputs: [SimulationReplayInput] = [.interaction(begin(pet, mode: .pet))]
    var directSimulation = Simulation(seed: 123)
    _ = directSimulation.accept(begin(pet, mode: .pet))
    for ordinal in UInt64(1)...UInt64(1_500) {
      inputs.append(.interaction(petStep(pet, ordinal)))
      let result = directSimulation.accept(petStep(pet, ordinal))
      if result.terminals.first?.reason == .naturalBoundary { break }
    }
    #expect(directSimulation.activity != .petting)
    let replayed = try replay(inputs).runWithResults(expectedIdentity: identity)
    #expect(replayed.simulation == directSimulation)
    #expect(replayed.interactionResults.last?.terminals.first?.reason == .naturalBoundary)
  }

  @Test func testPlayFatigueAndForgivingReturnReplay() throws {
    let play = token(1)
    let playInputs: [SimulationReplayInput] = [.interaction(begin(play, mode: .play))]
      + (1...150).map { .interaction(playStep(play, UInt64($0), seconds: 1)) }
    let tired = try replay(playInputs).run(expectedIdentity: identity)
    let reentered = try replay(
      playInputs + [.interaction(end(play, 151)), .interaction(begin(token(2), mode: .play))]
    ).run(expectedIdentity: identity)
    #expect(reentered.toy.boredom == tired.toy.boredom)
    #expect(reentered.character.energy == tired.character.energy)
    #expect(
      reentered.toy.interest(character: reentered.character)
        < Simulation().toy.interest(character: Simulation().character))

    let hidden = try replay(playInputs + [.command(.hide), .command(.pause)])
      .run(expectedIdentity: identity)
    let frozen = try replay(
      playInputs + [.command(.hide), .command(.pause), .advance(seconds: 5)]
    ).run(expectedIdentity: identity)
    #expect(hidden == frozen)
    let returned = try replay(
      playInputs + [
        .command(.hide), .command(.pause),
        .reconcileReturn(absenceSeconds: 30.0 * 24 * 3_600),
      ]
    ).run(expectedIdentity: identity)
    #expect(returned.policy.hidden && returned.policy.paused)
    #expect(returned.character.familiarity == tired.character.familiarity)
    #expect(returned.character.energy >= 0.65)
    #expect(returned.character.hunger <= 0.45)
    #expect(returned.attention.availableSeconds == hidden.attention.availableSeconds)
  }

  @Test func testReplayV2FutureGenerationRequiresBegin() throws {
    let first = token(1)
    let future = token(2)
    let inputs: [SimulationReplayInput] = [
      .interaction(petStep(first, 1)), .interaction(end(first, 1)),
      .interaction(begin(first, mode: .pet)),
      .interaction(playStep(future, 1)), .interaction(end(future, 1)),
      .interaction(begin(future, mode: .play)),
    ]

    let replayed = try replay(inputs).runWithResults(expectedIdentity: identity)

    #expect(replayed == direct(inputs))
    #expect(replayed.interactionResults.map(\.disposition) == [
      .ignored(.beginRequired(current: 0)), .ignored(.beginRequired(current: 0)), .accepted,
      .ignored(.beginRequired(current: 1)), .ignored(.beginRequired(current: 1)), .accepted,
    ])
    #expect(replayed.simulation.highestAcceptedInteractionGeneration == 2)
    #expect(replayed.simulation.snapshot.interaction?.token == future)
  }

  @Test func testReplayV2InteractionStepsCountTowardActiveWorkLimit() throws {
    let pet = token(1)
    var exact: [SimulationReplayInput] = [.interaction(begin(pet, mode: .pet))]
    exact += (1...5_759).map {
      .interaction(petStep(pet, UInt64($0), seconds: 5))
    }
    exact.append(.advance(seconds: 5))
    let exactFixture = replay(exact)
    try exactFixture.validate(expectedIdentity: identity)

    var over = exact
    over.append(.interaction(petStep(pet, 5_760, seconds: 0.1)))
    #expect(throws: SimulationReplayError.tooMuchActiveTime) {
      try replay(over).run(expectedIdentity: identity)
    }
  }

  @Test func testReplayRejectsUnsupportedIdentityAndSchema() throws {
    let fixture = replay([])
    let other = SimulationReplayIdentity(
      codeVersion: "future", contentVersion: identity.contentVersion,
      tuningVersion: identity.tuningVersion)
    #expect(throws: SimulationReplayError.incompatibleIdentity) {
      try fixture.run(expectedIdentity: other)
    }
    let future = SimulationReplay(schemaVersion: 3, identity: identity, seed: 1, records: [])
    #expect(throws: SimulationReplayError.unsupportedSchema) {
      try future.run(expectedIdentity: identity)
    }
    let invalid = SimulationReplayIdentity(codeVersion: "", contentVersion: "x", tuningVersion: "x")
    #expect(throws: SimulationReplayError.invalidIdentity) {
      try SimulationReplay(identity: invalid, seed: 1, records: []).run(expectedIdentity: invalid)
    }
  }

  @Test func testReplayRejectsDuplicateGapAndOutOfOrderSequence() {
    for sequences in [[1], [0, 0], [0, 2], [0, -1]] {
      let fixture = SimulationReplay(identity: identity, seed: 123, records: sequences.map {
        .init(sequence: $0, input: .command(.offerBasicFood))
      })
      #expect(throws: SimulationReplayError.self) { try fixture.run(expectedIdentity: identity) }
    }
  }

  @Test func testReplayRejectsInvalidTimeQualityAndInteractionBeforeExecution() {
    let pet = token(1)
    for time in [Double.nan, .infinity, -1, 0, 5.1] {
      #expect(throws: SimulationReplayError.invalidTime(index: 0)) {
        try replay([.advance(seconds: time)]).run(expectedIdentity: identity)
      }
      #expect(throws: SimulationReplayError.invalidTime(index: 0)) {
        try replay([.interaction(petStep(pet, 1, seconds: time))])
          .run(expectedIdentity: identity)
      }
    }
    for quality in [Double.nan, .infinity, -0.1, 1.1] {
      #expect(throws: SimulationReplayError.invalidQuality(index: 0)) {
        try replay([.interaction(petStep(pet, 1, seconds: 1, quality: quality))])
          .run(expectedIdentity: identity)
      }
    }
    for input in [
      petStep(pet, UInt64.max), petStep(pet, 1, region: .outside, quality: 1),
      begin(token(0), mode: .pet),
    ] {
      #expect(throws: SimulationReplayError.invalidInteraction(index: 0)) {
        try replay([.interaction(input)]).run(expectedIdentity: identity)
      }
    }
    for time in [Double.nan, .infinity, -1] {
      #expect(throws: SimulationReplayError.invalidTime(index: 0)) {
        try replay([.reconcileReturn(absenceSeconds: time)]).run(expectedIdentity: identity)
      }
    }
  }

  @Test func testReplayRejectsExcessiveRecordsAndImportSize() {
    #expect(throws: SimulationReplayError.tooManyRecords) {
      try replay(Array(repeating: .command(.settle), count: SimulationReplay.maximumRecords + 1))
        .run(expectedIdentity: identity)
    }
    #expect(throws: SimulationReplayError.tooManyBytes) {
      try SimulationReplay.decode(
        Data(repeating: 0, count: SimulationReplay.maximumBytes + 1), expectedIdentity: identity)
    }
  }

  @Test func testDecodedFixtureStillRequiresValidation() throws {
    let invalid = replay([.command(.hide), .advance(seconds: 6)])
    let bytes = try JSONEncoder().encode(invalid)
    #expect(throws: SimulationReplayError.invalidTime(index: 1)) {
      try SimulationReplay.decode(bytes, expectedIdentity: identity)
    }
    let decoded = try JSONDecoder().decode(SimulationReplay.self, from: bytes)
    #expect(throws: SimulationReplayError.invalidTime(index: 1)) {
      try decoded.run(expectedIdentity: identity)
    }
  }
}
