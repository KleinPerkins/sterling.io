import Foundation
import Testing

@testable import SterlingCore

struct SimulationTests {
  @Test func testPettingRisesThenEndsAndRetainsSatisfaction() {
    var sim = Simulation()
    let firstPet = token(1)
    sim.accept(begin(firstPet, mode: .pet))
    let initial = sim.character.receptiveness
    for ordinal in UInt64(1)...UInt64(100) { sim.accept(petStep(firstPet, ordinal)) }
    #expect(sim.character.receptiveness > initial)
    for ordinal in UInt64(101)...UInt64(1_500) { sim.accept(petStep(firstPet, ordinal)) }
    #expect(sim.activity != .petting)
    // Test restart immediately at the natural end, not after later recovery.
    var ending = Simulation()
    let endingPet = token(1)
    ending.accept(begin(endingPet, mode: .pet))
    for ordinal in UInt64(1)...UInt64(1_500) {
      ending.accept(petStep(endingPet, ordinal))
      if ending.activity != .petting { break }
    }
    let satisfaction = ending.character.contactSatisfaction
    #expect(satisfaction > 0.3)
    ending.accept(begin(token(2), mode: .pet))
    #expect(ending.character.contactSatisfaction == satisfaction)
    #expect(ending.activity != .petting)
  }
  @Test func testStillContactEndsWithoutAwardingSatisfaction() {
    var sim = Simulation()
    let pet = token(1)
    sim.accept(begin(pet, mode: .pet))
    sim.accept(petStep(pet, 1, seconds: 3, quality: nil))
    #expect(sim.activity != .petting)
    #expect(sim.character.contactSatisfaction == 0)
  }
  @Test func testSleepRecoveryPreservesControlsAndRecoversContact() {
    var sim = Simulation()
    let pet = token(1)
    sim.accept(begin(pet, mode: .pet))
    for ordinal in UInt64(1)...UInt64(100) { sim.accept(petStep(pet, ordinal)) }
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
    let pet = token(1)
    sim.accept(begin(pet, mode: .pet))
    sim.accept(petStep(pet, 1, seconds: 0.5, quality: 0.9))
    sim.accept(end(pet, 2))
    #expect(sim.activity == .settling)
    #expect(sim.character.contactSatisfaction < 0.01)
  }
  @Test func testToyReentryDoesNotResetBoredomOrEnergy() {
    var sim = Simulation()
    let firstPlay = token(1)
    sim.accept(begin(firstPlay, mode: .play))
    let before = sim.toy.interest(character: sim.character)
    for ordinal in UInt64(1)...UInt64(1_500) { sim.accept(playStep(firstPlay, ordinal)) }
    let boredom = sim.toy.boredom
    let energy = sim.character.energy
    sim.accept(end(firstPlay, 1_501))
    sim.accept(begin(token(2), mode: .play))
    #expect(sim.toy.boredom == boredom)
    #expect(sim.character.energy == energy)
    #expect(sim.toy.interest(character: sim.character) < before - 0.25)
  }
  @Test func testHiddenAndPausedFreezeAllState() {
    for command in [SimulationCommand.hide, .pause] {
      var sim = Simulation()
      sim.send(command)
      let before = sim
      for _ in 0..<100 { sim.advance(seconds: 5) }
      #expect(sim == before)
      let unavailable = sim.accept(begin(token(1), mode: .pet))
      #expect(unavailable.terminals.first?.reason == .policyUnavailable)
      #expect(sim.character == before.character)
      #expect(sim.toy == before.toy)
      #expect(sim.activeSeconds == before.activeSeconds)
      let afterUnavailable = sim
      #expect(sim.accept(petStep(token(1), 1)).disposition == .ignored(.postTerminal(.policyUnavailable)))
      #expect(sim == afterUnavailable)
      sim.send(.offerBasicFood)
      #expect(sim.character == before.character)
      #expect(sim.toy == before.toy)
      #expect(sim.activeSeconds == before.activeSeconds)
    }
  }
  @Test func testQuietAndFocusNeverMakeBudgetAvailable() {
    var budget = AttentionBudget()
    budget.advance(seconds: 10_000, available: false)
    #expect(!(budget.canStart))
  }
  @Test func testQuietAndFocusExitGrantGraceOnlyWhenAvailabilityResumes() {
    for quiet in [true, false] {
      var sim = Simulation()
      sim.send(.setQuiet(false))
      for _ in 0..<120 { sim.advance(seconds: 5) }
      #expect(sim.attention.canStart)
      sim.send(quiet ? .setQuiet(true) : .setFocus(true))
      let before = sim.attention.availableSeconds
      sim.advance(seconds: 5)
      #expect(sim.attention.availableSeconds == before)
      sim.send(quiet ? .setQuiet(false) : .setFocus(false))
      #expect(!sim.attention.canStart)
      #expect(sim.attention.blockedUntil == before + 60)
      for _ in 0..<6 { sim.advance(seconds: 5) }
      let deadline = sim.attention.blockedUntil
      sim.send(quiet ? .setQuiet(false) : .setFocus(false))
      #expect(sim.attention.blockedUntil == deadline)
      for _ in 0..<7 { sim.advance(seconds: 5) }
      #expect(sim.attention.canStart)
    }
  }
  @Test func testNestedAvailabilityRestrictionsDoNotPrematurelyRestartGrace() {
    var sim = Simulation()
    sim.send(.setQuiet(false))
    for _ in 0..<120 { sim.advance(seconds: 5) }
    sim.send(.setQuiet(true))
    sim.send(.setFocus(true))
    let previousDeadline = sim.attention.blockedUntil
    sim.send(.setQuiet(false))
    #expect(!sim.policy.allowsAttention)
    #expect(sim.attention.blockedUntil == previousDeadline)
    sim.send(.setFocus(false))
    #expect(sim.attention.blockedUntil == sim.attention.availableSeconds + 60)
    #expect(!sim.attention.canStart)
  }
  @Test func testRedundantResumeAndUnpauseDoNotExtendGrace() {
    for command in [SimulationCommand.resume, .unpause] {
      var sim = Simulation()
      sim.send(.setQuiet(false))
      for _ in 0..<6 { sim.advance(seconds: 5) }
      let deadline = sim.attention.blockedUntil
      sim.send(command)
      #expect(sim.attention.blockedUntil == deadline)
    }
  }
  @Test func testNestedHidePauseQuietAndFocusGrantOnlyFinalGrace() {
    var sim = Simulation()
    sim.send(.setQuiet(false))
    for _ in 0..<120 { sim.advance(seconds: 5) }
    sim.send(.hide)
    sim.send(.pause)
    sim.send(.setQuiet(true))
    sim.send(.setFocus(true))
    let deadline = sim.attention.blockedUntil
    for command in [SimulationCommand.resume, .unpause, .setQuiet(false)] {
      sim.send(command)
      #expect(!sim.policy.allowsAttention)
      #expect(sim.attention.blockedUntil == deadline)
    }
    sim.send(.setFocus(false))
    #expect(sim.policy.allowsAttention)
    #expect(!sim.attention.canStart)
    #expect(sim.attention.blockedUntil == sim.attention.availableSeconds + 60)
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
    let play = token(1)
    sim.accept(begin(play, mode: .play))
    for ordinal in UInt64(1)...UInt64(100) {
      sim.accept(playStep(play, ordinal, seconds: 1))
    }
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
        let play = token(UInt64(i / 1_000 + 1))
        a.accept(begin(play, mode: .play))
        b.accept(begin(play, mode: .play))
      }
      let play = token(UInt64(i / 1_000 + 1))
      let ordinal = UInt64(i % 1_000 + 1)
      a.accept(playStep(play, ordinal))
      b.accept(playStep(play, ordinal))
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
    let pet = token(1)
    sim.accept(begin(pet, mode: .pet))
    let beforeInvalidQuality = sim
    #expect(sim.accept(petStep(pet, 1, seconds: 1, quality: .nan)).disposition == .ignored(.invalidPayload))
    #expect(sim == beforeInvalidQuality)
  }
  @Test func testStateBoundsUnderAlternatingCommands() {
    var sim = Simulation(seed: 7)
    for i in 0..<40_000 {
      if i % 500 == 0 {
        sim.accept(
          begin(
            token(UInt64(i / 500 + 1)), mode: i % 1_000 == 0 ? .pet : .play))
      }
      if i % 3_000 == 0 { sim.send(.offerBasicFood) }
      if let session = sim.snapshot.interaction {
        let ordinal = session.lastAcceptedOrdinal + 1
        sim.accept(
          session.mode == .pet
            ? petStep(session.token, ordinal, quality: i % 2 == 0 ? 1 : 0.1)
            : playStep(session.token, ordinal))
      } else {
        sim.advance(seconds: 0.1)
      }
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
