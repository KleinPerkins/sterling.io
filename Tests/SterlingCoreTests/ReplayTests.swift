import Foundation
import Testing

@testable import SterlingCore

struct ReplayTests {
  private let identity = SimulationReplayIdentity(
    codeVersion: "s0-reducer-v1", contentVersion: "synthetic-fixtures-v1", tuningVersion: "prototype-v1")

  private func replay(_ inputs: [SimulationReplayInput]) -> SimulationReplay {
    .init(identity: identity, seed: 123, records: inputs.enumerated().map {
      .init(sequence: $0.offset, input: $0.element)
    })
  }

  @Test func testPortableCareReplayMatchesDirectReducer() throws {
    let inputs: [SimulationReplayInput] = [
      .command(.startPet), .advance(seconds: 5, contactQuality: 1),
      .command(.endContact), .command(.startPlay), .advance(seconds: 5, contactQuality: nil),
      .command(.hide), .command(.pause), .advance(seconds: 5, contactQuality: 1),
      .reconcileReturn(absenceSeconds: 7 * 24 * 3_600), .command(.resume), .command(.unpause),
      .command(.offerBasicFood), .advance(seconds: 3, contactQuality: nil),
    ]
    let original = replay(inputs)
    let data = try JSONEncoder().encode(original)
    let decoded = try SimulationReplay.decode(data, expectedIdentity: identity)
    #expect(decoded == original)
    let first = try original.run(expectedIdentity: identity)
    #expect(try decoded.run(expectedIdentity: identity) == first)
    var direct = Simulation(seed: 123)
    direct.send(.startPet)
    direct.advance(seconds: 5, contactQuality: 1)
    direct.send(.endContact)
    direct.send(.startPlay)
    direct.advance(seconds: 5)
    direct.send(.hide)
    direct.send(.pause)
    direct.advance(seconds: 5, contactQuality: 1)
    direct.reconcileReturn(absenceSeconds: 7 * 24 * 3_600)
    direct.send(.resume)
    direct.send(.unpause)
    direct.send(.offerBasicFood)
    direct.advance(seconds: 3)
    #expect(first == direct)
  }

  @Test func testPettingCurveAndNaturalBoundaryReplay() throws {
    let contact = SimulationReplayInput.advance(seconds: 0.1, contactQuality: 1)
    let rising = replay([.command(.startPet)] + Array(repeating: contact, count: 100))
    let early = try rising.run(expectedIdentity: identity)
    #expect(early.character.receptiveness > Simulation().character.receptiveness)
    // Find the actual natural boundary without assuming a tuned duration is an accepted requirement.
    var inputs: [SimulationReplayInput] = [.command(.startPet)]
    var boundary = Simulation(seed: 123)
    boundary.send(.startPet)
    for _ in 0..<1_500 {
      inputs.append(contact)
      boundary.advance(seconds: 0.1, contactQuality: 1)
      if boundary.activity != .petting { break }
    }
    #expect(boundary.activity != .petting)
    let satisfaction = boundary.character.contactSatisfaction
    inputs.append(.command(.startPet))
    let reentered = try replay(inputs).run(expectedIdentity: identity)
    #expect(reentered.character.contactSatisfaction == satisfaction)
    #expect(reentered.activity != .petting)
  }

  @Test func testPlayFatigueAndForgivingReturnReplay() throws {
    let play: [SimulationReplayInput] = [.command(.startPlay)] + Array(
      repeating: .advance(seconds: 1, contactQuality: nil), count: 150)
    let tired = try replay(play).run(expectedIdentity: identity)
    let reentered = try replay(play + [.command(.stopInteraction), .command(.startPlay)])
      .run(expectedIdentity: identity)
    #expect(reentered.toy.boredom == tired.toy.boredom)
    #expect(reentered.character.energy == tired.character.energy)
    #expect(reentered.toy.interest(character: reentered.character)
      < Simulation().toy.interest(character: Simulation().character))
    let hidden = try replay(play + [.command(.hide), .command(.pause)])
      .run(expectedIdentity: identity)
    let frozen = try replay(play + [
      .command(.hide), .command(.pause), .advance(seconds: 5, contactQuality: 1),
      .command(.startPet), .command(.startPlay), .command(.offerBasicFood),
    ]).run(expectedIdentity: identity)
    #expect(hidden == frozen)
    let returned = try replay(play + [
      .command(.hide), .command(.pause), .reconcileReturn(absenceSeconds: 30.0 * 24 * 3_600),
    ]).run(expectedIdentity: identity)
    #expect(returned.policy.hidden && returned.policy.paused)
    #expect(returned.character.familiarity == tired.character.familiarity)
    #expect(returned.character.energy >= 0.65)
    #expect(returned.character.hunger <= 0.45)
    #expect(returned.attention.availableSeconds == hidden.attention.availableSeconds)
  }

  @Test func testReplayRejectsUnsupportedIdentityAndSchema() throws {
    let fixture = replay([])
    let other = SimulationReplayIdentity(
      codeVersion: "future", contentVersion: identity.contentVersion, tuningVersion: identity.tuningVersion)
    #expect(throws: SimulationReplayError.incompatibleIdentity) {
      try fixture.run(expectedIdentity: other)
    }
    let future = SimulationReplay(schemaVersion: 2, identity: identity, seed: 1, records: [])
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

  @Test func testReplayRejectsInvalidTimeAndQualityBeforeExecution() {
    for time in [Double.nan, .infinity, -1, 0, 5.1] {
      let fixture = replay([.command(.startPlay), .advance(seconds: time, contactQuality: nil)])
      #expect(throws: SimulationReplayError.invalidTime(index: 1)) {
        try fixture.run(expectedIdentity: identity)
      }
    }
    for quality in [Double.nan, .infinity, -0.1, 1.1] {
      #expect(throws: SimulationReplayError.invalidQuality(index: 0)) {
        try replay([.advance(seconds: 1, contactQuality: quality)]).run(expectedIdentity: identity)
      }
    }
    for time in [Double.nan, .infinity, -1] {
      #expect(throws: SimulationReplayError.invalidTime(index: 0)) {
        try replay([.reconcileReturn(absenceSeconds: time)]).run(expectedIdentity: identity)
      }
    }
  }

  @Test func testReplayRejectsExcessiveRecordsTimeAndImportSize() {
    #expect(throws: SimulationReplayError.tooManyRecords) {
      try replay(Array(repeating: .command(.settle), count: SimulationReplay.maximumRecords + 1))
        .run(expectedIdentity: identity)
    }
    #expect(throws: SimulationReplayError.tooMuchActiveTime) {
      try replay(Array(repeating: .advance(seconds: 5, contactQuality: nil), count: 5_761))
        .run(expectedIdentity: identity)
    }
    #expect(throws: SimulationReplayError.tooManyBytes) {
      try SimulationReplay.decode(Data(repeating: 0, count: SimulationReplay.maximumBytes + 1),
        expectedIdentity: identity)
    }
  }

  @Test func testDecodedFixtureStillRequiresValidation() throws {
    let invalid = replay([.command(.hide), .advance(seconds: 6, contactQuality: nil)])
    let bytes = try JSONEncoder().encode(invalid)
    #expect(throws: SimulationReplayError.invalidTime(index: 1)) {
      try SimulationReplay.decode(bytes, expectedIdentity: identity)
    }
    // Even clients using Codable directly cannot bypass run's whole-envelope validation.
    let decoded = try JSONDecoder().decode(SimulationReplay.self, from: bytes)
    #expect(throws: SimulationReplayError.invalidTime(index: 1)) {
      try decoded.run(expectedIdentity: identity)
    }
  }
}
