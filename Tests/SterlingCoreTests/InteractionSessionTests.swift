import Foundation
import Testing

@testable import SterlingCore

func token(_ generation: UInt64, careSession: UInt64 = 1) -> InteractionToken {
  .init(careSessionID: .init(rawValue: careSession), generation: generation)
}

func stamp(_ token: InteractionToken, _ ordinal: UInt64) -> InteractionStamp {
  .init(token: token, sourceOrdinal: ordinal)
}

func begin(
  _ token: InteractionToken, mode: InteractionMode, source: InteractionSource = .pointer
) -> InteractionInput {
  .begin(stamp: stamp(token, 0), mode: mode, source: source)
}

func petStep(
  _ token: InteractionToken, _ ordinal: UInt64, seconds: Double = 0.1,
  region: BodyRegion = .head, quality: Double? = 1
) -> InteractionInput {
  .step(
    stamp: stamp(token, ordinal), elapsedSeconds: seconds,
    sample: .pet(region: region, quality: quality))
}

func playStep(
  _ token: InteractionToken, _ ordinal: UInt64, seconds: Double = 0.1
) -> InteractionInput {
  .step(stamp: stamp(token, ordinal), elapsedSeconds: seconds, sample: .play)
}

func end(
  _ token: InteractionToken, _ ordinal: UInt64,
  reason: InteractionInputEndReason = .completed
) -> InteractionInput {
  .end(stamp: stamp(token, ordinal), reason: reason)
}

struct InteractionSessionTests {
  @Test func testLateOldTerminalCannotStopNewPlayGeneration() {
    let pet = token(1)
    let play = token(2)
    var simulation = Simulation()
    _ = simulation.accept(begin(pet, mode: .pet))
    _ = simulation.accept(end(pet, 1))
    _ = simulation.accept(begin(play, mode: .play))
    let before = simulation

    let result = simulation.accept(end(pet, 2, reason: .cancelled))

    #expect(result.disposition == .ignored(.staleGeneration(current: 2)))
    #expect(simulation == before)
    #expect(simulation.activity == .playing)
    #expect(simulation.snapshot.interaction?.token == play)
  }

  @Test func testDuplicatePetStepAppliesEffectsAtMostOnce() {
    let pet = token(1)
    var simulation = Simulation()
    _ = simulation.accept(begin(pet, mode: .pet))
    _ = simulation.accept(petStep(pet, 1, seconds: 1))
    let afterFirst = simulation

    let duplicate = simulation.accept(petStep(pet, 1, seconds: 1))

    #expect(duplicate.disposition == .ignored(.duplicateOrOutOfOrder(lastAccepted: 1)))
    #expect(simulation == afterFirst)
    let next = simulation.accept(petStep(pet, 2, seconds: 1))
    #expect(next.disposition == .accepted)
    #expect(simulation != afterFirst)
  }

  @Test func testDuplicatePlayStepDoesNotDoubleDrainOrBore() {
    let play = token(1)
    var simulation = Simulation()
    _ = simulation.accept(begin(play, mode: .play))
    _ = simulation.accept(playStep(play, 1, seconds: 1))
    let afterFirst = simulation

    let duplicate = simulation.accept(playStep(play, 1, seconds: 1))

    #expect(duplicate.disposition == .ignored(.duplicateOrOutOfOrder(lastAccepted: 1)))
    #expect(simulation == afterFirst)
    _ = simulation.accept(playStep(play, 2, seconds: 1))
    #expect(simulation.character.energy < afterFirst.character.energy)
    #expect(simulation.toy.boredom > afterFirst.toy.boredom)
  }

  @Test func testOutOfOrderGapAndPostTerminalDisposition() {
    let pet = token(1)
    var simulation = Simulation()
    _ = simulation.accept(begin(pet, mode: .pet))
    let gap = simulation.accept(petStep(pet, 3))
    #expect(gap.disposition == .accepted)
    let afterGap = simulation

    let lower = simulation.accept(petStep(pet, 2))
    #expect(lower.disposition == .ignored(.duplicateOrOutOfOrder(lastAccepted: 3)))
    #expect(simulation == afterGap)

    let terminal = simulation.accept(end(pet, 5))
    #expect(terminal.terminals.count == 1)
    let afterTerminal = simulation
    let late = simulation.accept(petStep(pet, 6))
    #expect(late.disposition == .ignored(.postTerminal(.input(.completed))))
    #expect(simulation == afterTerminal)
  }

  @Test func testEveryAcquiredSessionHasOneTerminal() {
    let pet = token(1)
    var simulation = Simulation()
    let acquired = simulation.accept(begin(pet, mode: .pet))
    #expect(acquired.disposition == .accepted)
    #expect(acquired.terminals.isEmpty)

    let first = simulation.accept(end(pet, 1, reason: .careClosed))
    #expect(first.terminals == [
      .init(token: pet, finalOrdinal: 1, reason: .input(.careClosed))
    ])
    let afterFirst = simulation
    let repeated = simulation.accept(end(pet, 2, reason: .careClosed))
    #expect(repeated.disposition == .ignored(.postTerminal(.input(.careClosed))))
    #expect(repeated.terminals.isEmpty)
    #expect(simulation == afterFirst)
  }

  @Test func testNewGenerationAtomicallySupersedesOld() {
    let old = token(1)
    let new = token(2)
    var simulation = Simulation()
    _ = simulation.accept(begin(old, mode: .pet))

    let replacement = simulation.accept(begin(new, mode: .play))

    #expect(replacement.disposition == .accepted)
    #expect(replacement.terminals == [
      .init(token: old, finalOrdinal: 0, reason: .supersededGeneration)
    ])
    #expect(simulation.snapshot.interaction?.token == new)
    #expect(simulation.activity == .playing)
    let afterReplacement = simulation
    let late = simulation.accept(petStep(old, 1))
    #expect(late.disposition == .ignored(.staleGeneration(current: 2)))
    #expect(simulation == afterReplacement)

    var declinedReplacement = Simulation()
    let saturatedPet = token(1)
    _ = declinedReplacement.accept(begin(saturatedPet, mode: .pet))
    for ordinal in UInt64(1)...UInt64(1_500) {
      let result = declinedReplacement.accept(petStep(saturatedPet, ordinal))
      if result.terminals.first?.reason == .naturalBoundary { break }
    }
    let activePlay = token(2)
    _ = declinedReplacement.accept(begin(activePlay, mode: .play))
    let declinedPet = token(3)
    let twoTerminals = declinedReplacement.accept(begin(declinedPet, mode: .pet))
    #expect(twoTerminals.terminals == [
      .init(token: activePlay, finalOrdinal: 0, reason: .supersededGeneration),
      .init(token: declinedPet, finalOrdinal: 0, reason: .declined),
    ])
    let afterDecline = declinedReplacement
    #expect(
      declinedReplacement.accept(petStep(declinedPet, 1)).disposition
        == .ignored(.postTerminal(.declined)))
    #expect(declinedReplacement == afterDecline)
  }

  @Test func testNaturalPetBoundaryTerminalizesBeforeLateContact() {
    let pet = token(1)
    var simulation = Simulation()
    _ = simulation.accept(begin(pet, mode: .pet))
    var natural: InteractionTerminal?
    var finalOrdinal: UInt64 = 0
    for ordinal in UInt64(1)...UInt64(1_600) {
      let result = simulation.accept(petStep(pet, ordinal))
      if let terminal = result.terminals.first {
        natural = terminal
        finalOrdinal = ordinal
        break
      }
    }

    #expect(natural?.reason == .naturalBoundary)
    #expect(natural?.token == pet)
    #expect(simulation.snapshot.interaction == nil)
    let afterBoundary = simulation
    let late = simulation.accept(petStep(pet, finalOrdinal + 1))
    #expect(late.disposition == .ignored(.postTerminal(.naturalBoundary)))
    #expect(simulation == afterBoundary)
  }

  @Test func testAdapterEndCannotClaimCoreTerminalReason() throws {
    let valid = end(token(1), 1)
    let encoded = try JSONEncoder().encode(valid)
    let json = try #require(String(data: encoded, encoding: .utf8))
    let forged = json.replacingOccurrences(of: "completed", with: "hidden")
    #expect(forged != json)
    let forgedData = try #require(forged.data(using: .utf8))

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(InteractionInput.self, from: forgedData)
    }

    var simulation = Simulation()
    let pet = token(1)
    _ = simulation.accept(begin(pet, mode: .pet))
    #expect(simulation.send(.hide).terminals.first?.reason == .hidden)
  }

  @Test func testOwnerControlsPreemptAndInvalidateInteraction() {
    let commandCases: [(SimulationCommand, InteractionTerminalReason)] = [
      (.hide, .hidden), (.pause, .paused), (.settle, .settledByOwner),
      (.setFocus(true), .focusStarted), (.offerBasicFood, .supersededByFood),
    ]
    for (command, reason) in commandCases {
      let pet = token(1)
      var simulation = Simulation()
      _ = simulation.accept(begin(pet, mode: .pet))
      let result = simulation.send(command)
      #expect(result.terminals.first?.token == pet)
      #expect(result.terminals.first?.reason == reason)
      let afterControl = simulation
      #expect(simulation.accept(petStep(pet, 1)).disposition == .ignored(.postTerminal(reason)))
      #expect(simulation == afterControl)
      if command == .hide { #expect(simulation.policy.hidden) }
      if command == .pause { #expect(simulation.policy.paused) }
    }

    for (lifecycle, reason) in [
      (RuntimeLifecycleInput.displayChanged, InteractionTerminalReason.displayChanged),
      (.systemSuspended, .systemSuspended),
    ] {
      let pet = token(1)
      var simulation = Simulation()
      _ = simulation.accept(begin(pet, mode: .pet))
      let result = simulation.lifecycle(lifecycle)
      #expect(result.terminals.first?.token == pet)
      #expect(result.terminals.first?.reason == reason)
      let afterLifecycle = simulation
      #expect(simulation.accept(petStep(pet, 1)).disposition == .ignored(.postTerminal(reason)))
      #expect(simulation == afterLifecycle)
    }
  }

  @Test func testDeclinedFoodOfferDoesNotTerminateCare() {
    var simulation = Simulation()
    _ = simulation.send(.offerBasicFood)
    _ = simulation.advance(seconds: 5)
    _ = simulation.advance(seconds: 5)
    let pet = token(1)
    _ = simulation.accept(begin(pet, mode: .pet))
    let beforeCharacter = simulation.character
    let beforeToy = simulation.toy
    let beforeSeconds = simulation.activeSeconds

    let result = simulation.send(.offerBasicFood)

    #expect(result.disposition == .accepted)
    #expect(result.terminals.isEmpty)
    #expect(simulation.snapshot.interaction?.token == pet)
    #expect(simulation.activity == .petting)
    #expect(simulation.character == beforeCharacter)
    #expect(simulation.toy == beforeToy)
    #expect(simulation.activeSeconds == beforeSeconds)
  }

  @Test func testQuietAndReducedMotionPreserveDeliberateCareOwnership() {
    let pet = token(1)
    var simulation = Simulation()
    _ = simulation.accept(begin(pet, mode: .pet))

    for command in [SimulationCommand.setQuiet(true), .setReducedMotion(true)] {
      let result = simulation.send(command)
      #expect(result.terminals.isEmpty)
      #expect(simulation.snapshot.interaction?.token == pet)
      #expect(simulation.activity == .petting)
    }
  }

  @Test func testWrongModeAndInvalidPayloadRejectBeforeMutation() {
    let play = token(1)
    var simulation = Simulation()
    _ = simulation.accept(begin(play, mode: .play))
    var before = simulation
    let wrongMode = simulation.accept(petStep(play, 1))
    #expect(wrongMode.disposition == .ignored(.modeMismatch(expected: .play)))
    #expect(simulation == before)

    let invalid: [InteractionInput] = [
      petStep(token(1, careSession: 0), 1), petStep(token(0), 1),
      begin(token(UInt64.max), mode: .pet),
      .begin(stamp: stamp(token(2), 1), mode: .pet, source: .pointer),
      playStep(play, 0), playStep(play, 2, seconds: 0), playStep(play, 2, seconds: -1),
      playStep(play, 2, seconds: 5.1),
      petStep(play, 2, quality: .nan), petStep(play, 2, quality: .infinity),
      petStep(play, 2, quality: -0.1), petStep(play, 2, quality: 1.1),
      petStep(play, 2, region: .outside, quality: 0.8),
      playStep(play, UInt64.max),
    ]
    for input in invalid {
      before = simulation
      let result = simulation.accept(input)
      #expect(result.disposition == .ignored(.invalidPayload))
      #expect(simulation == before)
    }

    let pet = token(2)
    _ = simulation.accept(begin(pet, mode: .pet))
    let nearExhaustion = simulation.accept(petStep(pet, UInt64.max - 1))
    #expect(nearExhaustion.disposition == .accepted)
    before = simulation
    #expect(simulation.accept(petStep(pet, UInt64.max)).disposition == .ignored(.invalidPayload))
    #expect(simulation == before)
    let terminal = simulation.accept(end(pet, UInt64.max))
    #expect(terminal.disposition == .accepted)
    #expect(terminal.terminals.first?.finalOrdinal == UInt64.max)
  }

  @Test func testFutureStepAndEndRequireBeginWithoutConsumingGeneration() {
    let first = token(1)
    var simulation = Simulation()
    var before = simulation
    #expect(
      simulation.accept(petStep(first, 1)).disposition == .ignored(.beginRequired(current: 0)))
    #expect(simulation == before)
    #expect(
      simulation.accept(end(first, 1)).disposition == .ignored(.beginRequired(current: 0)))
    #expect(simulation == before)

    _ = simulation.accept(begin(first, mode: .pet))
    let future = token(2)
    before = simulation
    #expect(
      simulation.accept(playStep(future, 1)).disposition
        == .ignored(.beginRequired(current: 1)))
    #expect(simulation == before)
    #expect(
      simulation.accept(end(future, 1)).disposition == .ignored(.beginRequired(current: 1)))
    #expect(simulation == before)

    let begun = simulation.accept(begin(future, mode: .play))
    #expect(begun.disposition == .accepted)
    #expect(simulation.highestAcceptedInteractionGeneration == 2)
    #expect(simulation.snapshot.interaction?.token == future)
  }

  @Test func testInteractionValidationPrecedenceIsStable() {
    let live = token(2)
    var simulation = Simulation()
    _ = simulation.accept(begin(live, mode: .pet))
    _ = simulation.accept(petStep(live, 2))

    var before = simulation
    #expect(simulation.accept(playStep(token(3), 0)).disposition == .ignored(.invalidPayload))
    #expect(simulation == before)
    #expect(
      simulation.accept(playStep(token(3), 1)).disposition
        == .ignored(.beginRequired(current: 2)))
    #expect(simulation == before)
    #expect(
      simulation.accept(playStep(token(1, careSession: 99), 1)).disposition
        == .ignored(.staleGeneration(current: 2)))
    #expect(simulation == before)
    #expect(
      simulation.accept(playStep(token(2, careSession: 99), 1)).disposition
        == .ignored(.foreignSession))
    #expect(simulation == before)
    #expect(
      simulation.accept(playStep(live, 2)).disposition
        == .ignored(.duplicateOrOutOfOrder(lastAccepted: 2)))
    #expect(simulation == before)
    #expect(
      simulation.accept(playStep(live, 3)).disposition == .ignored(.modeMismatch(expected: .pet)))
    #expect(simulation == before)

    _ = simulation.accept(end(live, 4))
    before = simulation
    #expect(
      simulation.accept(playStep(live, 4)).disposition
        == .ignored(.postTerminal(.input(.completed))))
    #expect(simulation == before)
  }

  @Test func testAnonymousAdvanceCannotBypassOwnedSession() {
    let pet = token(1)
    var simulation = Simulation()
    _ = simulation.accept(begin(pet, mode: .pet))
    let before = simulation

    let anonymous = simulation.advance(seconds: 1)

    #expect(anonymous.disposition == .ignored(.interactionTokenRequired))
    #expect(simulation == before)
    #expect(simulation.accept(petStep(pet, 1, seconds: 1)).disposition == .accepted)
    #expect(simulation != before)
  }

  @Test func testRuntimeResultCannotClearNewerHostToken() {
    let old = token(1)
    let new = token(2)
    var simulation = Simulation()
    _ = simulation.accept(begin(old, mode: .pet))
    let oldResult = simulation.accept(end(old, 1))
    _ = simulation.accept(begin(new, mode: .play))
    var heldToken: InteractionToken? = new

    for terminal in oldResult.terminals where terminal.token == heldToken { heldToken = nil }

    #expect(heldToken == new)
    #expect(oldResult.snapshot.interaction == nil)
    #expect(simulation.snapshot.interaction?.token == new)

    var other = Simulation()
    #expect(other.send(.setQuiet(true)).runtimeSequence != nil)
    #expect(other.advance(seconds: 0.1).runtimeSequence != nil)
    #expect(other.lifecycle(.displayChanged).runtimeSequence != nil)
    #expect(other.reconcileReturn(absenceSeconds: 1).runtimeSequence != nil)
  }

  @Test func testPetBackgroundOwnershipDoesNotBeginCoreSession() {
    let mat = WorldRect(x: 0, y: 0, width: 400, height: 250)
    var interpreter = GestureInterpreter()
    var simulation = Simulation()
    let untouched = simulation
    let acquired = interpreter.begin(point: .init(x: 20, y: 20), at: 0, mat: mat)
    #expect(acquired)
    #expect(
      interpreter.stroke(
        point: .init(x: 30, y: 20), at: 0.1, region: .outside, bodyLength: 160) == nil)
    #expect(simulation == untouched)
    #expect(simulation.snapshot.interaction == nil)

    let quality = interpreter.stroke(
      point: .init(x: 46, y: 20), at: 0.2, region: .head, bodyLength: 160)
    #expect(quality != nil)
    let pet = token(1)
    _ = simulation.accept(begin(pet, mode: .pet))
    #expect(simulation.snapshot.interaction?.token == pet)
  }

  @Test func testExactlyOneEffectStepPerTimerTick() {
    let pet = token(1)
    var simulation = Simulation()
    _ = simulation.accept(begin(pet, mode: .pet))
    let before = simulation

    _ = simulation.accept(petStep(pet, 1, seconds: 0.1))
    let afterStep = simulation
    let accidentalAnonymousAdvance = simulation.advance(seconds: 0.1)

    #expect(afterStep != before)
    #expect(accidentalAnonymousAdvance.disposition == .ignored(.interactionTokenRequired))
    #expect(simulation == afterStep)
  }
}
