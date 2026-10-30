import Foundation
import Testing

@testable import SterlingCore

struct SimulationTests {
  @Test func testPettingRisesThenEndsAndRetainsSatisfaction() {
    var sim = Simulation()
    sim.send(.startPet)
    let initial = sim.character.receptiveness
    for _ in 0..<100 { sim.advance(seconds: 0.1, contactQuality: 1) }
    #expect(sim.character.receptiveness > initial)
    for _ in 0..<1_400 { sim.advance(seconds: 0.1, contactQuality: 1) }
    #expect(sim.activity != .petting)
    // Test restart immediately at the natural end, not after later recovery.
    var ending = Simulation()
    ending.send(.startPet)
    for _ in 0..<1_500 {
      ending.advance(seconds: 0.1, contactQuality: 1)
      if ending.activity != .petting { break }
    }
    let satisfaction = ending.character.contactSatisfaction
    #expect(satisfaction > 0.3)
    ending.send(.startPet)
    #expect(ending.character.contactSatisfaction == satisfaction)
    #expect(ending.activity != .petting)
  }
  @Test func testStillContactEndsWithoutAwardingSatisfaction() {
    var sim = Simulation()
    sim.send(.startPet)
    sim.advance(seconds: 3)
    #expect(sim.activity != .petting)
    #expect(sim.character.contactSatisfaction == 0)
  }
  @Test func testSleepRecoveryPreservesControlsAndRecoversContact() {
    var sim = Simulation()
    sim.send(.startPet)
    for _ in 0..<100 { sim.advance(seconds: 0.1, contactQuality: 1) }
    sim.send(.hide)
    sim.send(.pause)
    let availability = sim.attention.availableSeconds
    sim.reconcileReturn(absenceSeconds: 8 * 3_600)
    #expect(sim.policy.hidden && sim.policy.paused)
    #expect(sim.attention.availableSeconds == availability)
    #expect(sim.character.contactSatisfaction == 0)
  }
  @Test func testBriefTouchDoesNotForceLongSession() {
    var sim = Simulation()
    sim.send(.startPet)
    sim.advance(seconds: 0.5, contactQuality: 0.9)
    sim.send(.endContact)
    #expect(sim.activity == .settling)
    #expect(sim.character.contactSatisfaction < 0.01)
  }
  @Test func testToyReentryDoesNotResetBoredomOrEnergy() {
    var sim = Simulation()
    sim.send(.startPlay)
    let before = sim.toy.interest(character: sim.character)
    for _ in 0..<1_500 { sim.advance(seconds: 0.1) }
    let boredom = sim.toy.boredom
    let energy = sim.character.energy
    sim.send(.stopInteraction)
    sim.send(.startPlay)
    #expect(sim.toy.boredom == boredom)
    #expect(sim.character.energy == energy)
    #expect(sim.toy.interest(character: sim.character) < before - 0.25)
  }
  @Test func testHiddenAndPausedFreezeAllState() {
    for command in [SimulationCommand.hide, .pause] {
      var sim = Simulation()
      sim.send(command)
      let before = sim
      for _ in 0..<100 { sim.advance(seconds: 5, contactQuality: 1) }
      #expect(sim == before)
      sim.send(.startPet)
      sim.send(.startPlay)
      sim.send(.offerBasicFood)
      #expect(sim == before)
    }
  }
  @Test func testQuietAndFocusNeverMakeBudgetAvailable() {
    var budget = AttentionBudget()
    budget.advance(seconds: 10_000, available: false)
    #expect(!(budget.canStart))
  }
  @Test func testRollingBudgetAndUnansweredCooldownSurviveEncoding() throws {
    var budget = AttentionBudget()
    budget.advance(seconds: 60, available: true)
    let first = budget.start()
    #expect(first)
    budget.unanswered()
    budget = try JSONDecoder().decode(AttentionBudget.self, from: JSONEncoder().encode(budget))
    budget.advance(seconds: 899, available: true)
    let tooSoon = budget.start()
    #expect(!tooSoon)
    budget.advance(seconds: 1, available: true)
    let second = budget.start()
    #expect(second)
    let third = budget.start()
    #expect(!third)
    budget.advance(seconds: 300, available: true)
    let nextWindow = budget.start()
    #expect(nextWindow)
  }
  @Test func testLongAbsencePreservesFamiliarityAndComfort() {
    var sim = Simulation()
    sim.send(.startPlay)
    for _ in 0..<100 { sim.advance(seconds: 1) }
    let familiarity = sim.character.familiarity
    sim.reconcileReturn(absenceSeconds: 30 * 24 * 3_600)
    #expect(sim.character.familiarity == familiarity)
    #expect(sim.character.energy >= 0.65)
    #expect(sim.character.hunger <= 0.45)
    #expect(sim.character.overstimulation <= 0.05)
  }
  @Test func testMealRepeatedCommandDoesNotDuplicatePortion() {
    var normal = Simulation()
    var repeated = Simulation()
    normal.send(.offerBasicFood)
    repeated.send(.offerBasicFood)
    for _ in 0..<60 {
      normal.advance(seconds: 0.1)
      repeated.send(.offerBasicFood)
      repeated.advance(seconds: 0.1)
    }
    #expect(normal.character == repeated.character)
    #expect(normal.character.hunger < 0.10)
  }
  @Test func testSeededReplayAndRoundTripAreIdentical() throws {
    var a = Simulation(seed: 123)
    var b = Simulation(seed: 123)
    for i in 0..<10_000 {
      if i % 1_000 == 0 {
        a.send(.startPlay)
        b.send(.startPlay)
      }
      a.advance(seconds: 0.1)
      b.advance(seconds: 0.1)
    }
    #expect(a == b)
    let decoded = try JSONDecoder().decode(Simulation.self, from: JSONEncoder().encode(a))
    #expect(decoded == a)
  }
  @Test func testRejectsInvalidTimeAndQuality() {
    var sim = Simulation()
    let original = sim
    sim.advance(seconds: .nan)
    sim.advance(seconds: .infinity)
    sim.advance(seconds: -10)
    #expect(sim == original)
    sim.send(.startPet)
    sim.advance(seconds: 1, contactQuality: .nan)
    #expect(sim.character.receptiveness.isFinite)
  }
  @Test func testStateBoundsUnderAlternatingCommands() {
    var sim = Simulation(seed: 7)
    for i in 0..<40_000 {
      if i % 500 == 0 { sim.send(i % 1_000 == 0 ? .startPet : .startPlay) }
      if i % 3_000 == 0 { sim.send(.offerBasicFood) }
      sim.advance(seconds: 0.1, contactQuality: i % 2 == 0 ? 1 : 0.1)
      let c = sim.character
      for x in [
        c.hunger, c.satiety, c.energy, c.sleepPressure, c.socialAppetite, c.contactDesire,
        c.contactSatisfaction, c.playMotivation, c.arousal, c.comfort, c.safety, c.curiosity,
        c.overstimulation, c.familiarity,
      ] {
        #expect((0...1).contains(x))
      }
    }
  }
}

struct InteractionTests {
  let mat = WorldRect(x: 0, y: 0, width: 400, height: 250)
  @Test func testForeignDragCannotAcquireOwnership() {
    var g = GestureInterpreter()
    let acquired = g.begin(point: .init(x: -1, y: 20), at: 0, mat: mat)
    #expect(!acquired)
    #expect(g.stroke(point: .init(x: 80, y: 80), at: 0.1, region: .head, bodyLength: 160) == nil)
    #expect(!(g.ownsGesture))
  }
  @Test func testOwnedStrokeAndCancellation() {
    var g = GestureInterpreter()
    let acquired = g.begin(point: .init(x: 80, y: 100), at: 0, mat: mat)
    #expect(acquired)
    let q = g.stroke(point: .init(x: 96, y: 100), at: 0.1, region: .head, bodyLength: 160)
    #expect(q == 1)
    g.end()
    #expect(g.stroke(point: .init(x: 112, y: 100), at: 0.2, region: .head, bodyLength: 160) == nil)
  }
  @Test func testStillTouchAndTeleportDoNotEarnCredit() {
    var g = GestureInterpreter()
    _ = g.begin(point: .init(x: 10, y: 10), at: 0, mat: mat)
    #expect(g.stroke(point: .init(x: 10, y: 10), at: 0.1, region: .head, bodyLength: 160) == nil)
    #expect(
      g.stroke(point: .init(x: 3_000, y: 100), at: 0.2, region: .head, bodyLength: 160) == nil)
  }
  @Test func testNegativeOriginAndMixedScale() {
    let d = DisplayGeometry(
      token: 2, globalFrame: .init(x: -1_920, y: -100, width: 1_920, height: 1_080),
      usableFrame: mat, scale: 2)
    let local = d.localPoint(fromGlobal: .init(x: -1_900, y: 0))
    #expect(local == .init(x: 20, y: 100))
    #expect(d.backingPoint(fromLocal: local) == .init(x: 40, y: 200))
  }
}
