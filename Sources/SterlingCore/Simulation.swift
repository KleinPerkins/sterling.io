import Foundation

public struct SimulationSnapshot: Codable, Equatable, Sendable {
  public var character: CharacterState
  public var toy: ToyState
  public var activity: Activity
  public var policy: ControlPolicy
  public var activeSeconds: Double
  public var notice: String
  public var interaction: InteractionSessionSnapshot?
  public var acceptedRuntimeSequence: UInt64
}

public enum SimulationCommand: Codable, Equatable, Sendable {
  case offerBasicFood, settle
  case hide, resume, pause, unpause
  case setQuiet(Bool)
  case setFocus(Bool)
  case setReducedMotion(Bool)
}

public struct Simulation: Codable, Equatable, Sendable {
  public private(set) var character = CharacterState()
  public private(set) var toy = ToyState()
  public private(set) var policy = ControlPolicy()
  public private(set) var activity: Activity = .resting
  public private(set) var activeSeconds = 0.0
  public private(set) var attention = AttentionBudget()
  public private(set) var random: SeededRandom
  public private(set) var notice = "Quiet company."
  public private(set) var highestAcceptedInteractionGeneration: UInt64 = 0
  public private(set) var acceptedRuntimeSequence: UInt64 = 0
  public private(set) var lastInteractionTerminal: InteractionTerminal?
  private var activeInteraction: InteractionSession?
  private var phaseRemaining = 8.0
  private var contactElapsed = 0.0
  private var idleContactSeconds = 0.0
  private var lowReceptivenessSeconds = 0.0
  private var playElapsed = 0.0
  private var lowInterestSeconds = 0.0
  private var mealFraction = 0.0
  private var mealClock = 0.0

  public init(seed: UInt64 = 0x57E211) { random = SeededRandom(seed: seed) }

  public var snapshot: SimulationSnapshot {
    .init(
      character: character, toy: toy, activity: activity, policy: policy,
      activeSeconds: activeSeconds, notice: notice, interaction: activeInteraction?.snapshot,
      acceptedRuntimeSequence: acceptedRuntimeSequence)
  }

  private func result(
    _ disposition: RuntimeDisposition, sequence: UInt64? = nil,
    terminals: [InteractionTerminal] = []
  ) -> RuntimeResult {
    .init(
      snapshot: snapshot, disposition: disposition, runtimeSequence: sequence,
      terminals: terminals)
  }

  private func ignored(_ reason: InteractionIgnoreReason) -> RuntimeResult {
    result(.ignored(reason))
  }

  private var canAcceptRuntimeInput: Bool { acceptedRuntimeSequence < UInt64.max }

  @discardableResult private mutating func commitRuntimeSequence() -> UInt64 {
    precondition(canAcceptRuntimeInput)
    acceptedRuntimeSequence += 1
    return acceptedRuntimeSequence
  }

  private mutating func stopContact() {
    contactElapsed = 0
    idleContactSeconds = 0
    lowReceptivenessSeconds = 0
    activity = .settling
    phaseRemaining = 3
  }

  private mutating func terminalizeActive(
    reason: InteractionTerminalReason, finalOrdinal: UInt64? = nil
  ) -> InteractionTerminal? {
    guard let session = activeInteraction else { return nil }
    let terminal = InteractionTerminal(
      token: session.token, finalOrdinal: finalOrdinal ?? session.lastAcceptedOrdinal,
      reason: reason)
    activeInteraction = nil
    lastInteractionTerminal = terminal
    if activity == .petting || activity == .playing { stopContact() }
    return terminal
  }

  private mutating func recordTerminal(
    token: InteractionToken, finalOrdinal: UInt64, reason: InteractionTerminalReason
  ) -> InteractionTerminal {
    let terminal = InteractionTerminal(
      token: token, finalOrdinal: finalOrdinal, reason: reason)
    lastInteractionTerminal = terminal
    return terminal
  }

  private func validate(_ input: InteractionInput) -> InteractionIgnoreReason? {
    guard input.isStructurallyValid else { return .invalidPayload }
    let stamp = input.stamp
    let token = stamp.token

    if token.generation > highestAcceptedInteractionGeneration {
      if case .begin = input { return nil }
      return .beginRequired(current: highestAcceptedInteractionGeneration)
    }
    if token.generation < highestAcceptedInteractionGeneration {
      return .staleGeneration(current: highestAcceptedInteractionGeneration)
    }

    let currentToken = activeInteraction?.token ?? lastInteractionTerminal?.token
    guard currentToken?.careSessionID == token.careSessionID else { return .foreignSession }
    if let terminal = lastInteractionTerminal, terminal.token == token,
      activeInteraction?.token != token
    {
      return .postTerminal(terminal.reason)
    }
    guard let session = activeInteraction, session.token == token else { return .foreignSession }
    guard stamp.sourceOrdinal > session.lastAcceptedOrdinal else {
      return .duplicateOrOutOfOrder(lastAccepted: session.lastAcceptedOrdinal)
    }
    if case .step(_, _, let sample) = input {
      switch (session.mode, sample) {
      case (.pet, .pet), (.play, .play): break
      case (.pet, .play): return .modeMismatch(expected: .pet)
      case (.play, .pet): return .modeMismatch(expected: .play)
      }
    }
    return nil
  }

  @discardableResult public mutating func accept(_ input: InteractionInput) -> RuntimeResult {
    if let reason = validate(input) { return ignored(reason) }
    guard canAcceptRuntimeInput else { return ignored(.invalidPayload) }

    var terminals: [InteractionTerminal] = []
    switch input {
    case .begin(let stamp, let mode, let source):
      if let previous = terminalizeActive(reason: .supersededGeneration) {
        terminals.append(previous)
      }
      highestAcceptedInteractionGeneration = stamp.token.generation

      guard policy.advancesNeeds else {
        terminals.append(
          recordTerminal(
            token: stamp.token, finalOrdinal: stamp.sourceOrdinal, reason: .policyUnavailable))
        let sequence = commitRuntimeSequence()
        return result(.accepted, sequence: sequence, terminals: terminals)
      }

      switch mode {
      case .pet:
        guard character.receptiveness >= 0.20 else {
          notice = "He turns gently away. A little space feels good."
          terminals.append(
            recordTerminal(
              token: stamp.token, finalOrdinal: stamp.sourceOrdinal, reason: .declined))
          let sequence = commitRuntimeSequence()
          return result(.accepted, sequence: sequence, terminals: terminals)
        }
        activity = .petting
        contactElapsed = 0
        idleContactSeconds = 0
        lowReceptivenessSeconds = 0
        notice = "He turns toward your touch."
      case .play:
        guard toy.interest(character: character) >= 0.35, character.energy >= 0.25 else {
          notice = "He watches the toy, then looks away."
          terminals.append(
            recordTerminal(
              token: stamp.token, finalOrdinal: stamp.sourceOrdinal, reason: .declined))
          let sequence = commitRuntimeSequence()
          return result(.accepted, sequence: sequence, terminals: terminals)
        }
        activity = .playing
        playElapsed = 0
        lowInterestSeconds = 0
        notice = "Something worth watching."
      }
      activeInteraction = InteractionSession(
        token: stamp.token, mode: mode, source: source,
        lastAcceptedOrdinal: stamp.sourceOrdinal)

    case .step(let stamp, let elapsedSeconds, let sample):
      guard var session = activeInteraction else { return ignored(.foreignSession) }
      session.lastAcceptedOrdinal = stamp.sourceOrdinal
      activeInteraction = session
      switch sample {
      case .pet(_, let quality): reduceAdvance(seconds: elapsedSeconds, contactQuality: quality)
      case .play: reduceAdvance(seconds: elapsedSeconds, contactQuality: nil)
      }
      let stillInMode =
        (session.mode == .pet && activity == .petting)
        || (session.mode == .play && activity == .playing)
      if !stillInMode,
        let terminal = terminalizeActive(
          reason: .naturalBoundary, finalOrdinal: stamp.sourceOrdinal)
      {
        terminals.append(terminal)
      }

    case .end(let stamp, let reason):
      guard var session = activeInteraction else { return ignored(.foreignSession) }
      session.lastAcceptedOrdinal = stamp.sourceOrdinal
      activeInteraction = session
      if let terminal = terminalizeActive(
        reason: .input(reason), finalOrdinal: stamp.sourceOrdinal)
      {
        terminals.append(terminal)
      }
      notice = "A little pause."
    }

    let sequence = commitRuntimeSequence()
    return result(.accepted, sequence: sequence, terminals: terminals)
  }

  @discardableResult public mutating func send(_ command: SimulationCommand) -> RuntimeResult {
    guard canAcceptRuntimeInput else { return ignored(.invalidPayload) }
    let wasAvailable = policy.allowsAttention
    let focusEntered: Bool
    if case .setFocus(let focused) = command {
      focusEntered = focused && !policy.focused
    } else {
      focusEntered = false
    }
    let foodWillReplace = command == .offerBasicFood && policy.advancesNeeds
      && activity != .eating && character.hunger >= 0.20 && character.satiety < 0.80

    var terminals: [InteractionTerminal] = []
    let terminalReason: InteractionTerminalReason?
    switch command {
    case .hide: terminalReason = .hidden
    case .pause: terminalReason = .paused
    case .settle: terminalReason = .settledByOwner
    case .setFocus where focusEntered: terminalReason = .focusStarted
    case .offerBasicFood where foodWillReplace: terminalReason = .supersededByFood
    default: terminalReason = nil
    }
    if let terminalReason, let terminal = terminalizeActive(reason: terminalReason) {
      terminals.append(terminal)
    }

    switch command {
    case .hide:
      policy.hidden = true
      stopContact()
      notice = "Hidden. Resume whenever you like."
    case .pause:
      policy.paused = true
      stopContact()
      notice = "Paused."
    case .resume:
      policy.hidden = false
      notice = policy.paused ? "Paused." : "Back in his nook."
    case .unpause:
      policy.paused = false
      notice = "Quiet company."
    case .setQuiet(let quiet): policy.quiet = quiet
    case .setFocus(let focused):
      policy.focused = focused
      if focusEntered {
        stopContact()
        notice = "Settling nearby while you focus."
      }
    case .setReducedMotion(let enabled): policy.reducedMotion = enabled
    case .settle:
      stopContact()
      notice = "Settling in his nook."
    case .offerBasicFood:
      if foodWillReplace {
        activity = .eating
        mealFraction = 0
        mealClock = 0
        notice = "A sniff, then a small bite."
      } else if policy.advancesNeeds, activity != .eating {
        notice = "A sniff, then a contented look away."
      }
    }
    if !wasAvailable && policy.allowsAttention { attention.resumeGrace() }
    let sequence = commitRuntimeSequence()
    return result(.accepted, sequence: sequence, terminals: terminals)
  }

  /// Ordinary autonomous time. An owned interaction must use tokenized `InteractionInput.step`.
  @discardableResult public mutating func advance(seconds: Double) -> RuntimeResult {
    guard seconds.isFinite, seconds > 0, seconds <= 5 else { return ignored(.invalidPayload) }
    guard activeInteraction == nil else { return ignored(.interactionTokenRequired) }
    guard policy.advancesNeeds else { return ignored(.invalidPayload) }
    guard canAcceptRuntimeInput else { return ignored(.invalidPayload) }
    reduceAdvance(seconds: seconds, contactQuality: nil)
    let sequence = commitRuntimeSequence()
    return result(.accepted, sequence: sequence)
  }

  private mutating func reduceAdvance(seconds: Double, contactQuality: Double?) {
    var remaining = seconds
    while remaining > 0.000_001 {
      let dt = min(0.1, remaining)
      step(dt, contactQuality: contactQuality)
      remaining -= dt
    }
  }

  private mutating func step(_ dt: Double, contactQuality: Double?) {
    activeSeconds += dt
    attention.advance(seconds: dt, available: policy.allowsAttention)
    character.hunger += 0.003 * dt / 60
    character.satiety -= 0.004 * dt / 60
    if activity == .resting {
      character.energy += 0.015 * dt / 60
      character.sleepPressure -= 0.020 * dt / 60
    } else {
      character.energy -= 0.0012 * dt / 60
      character.sleepPressure += 0.0015 * dt / 60
    }

    if activity == .petting { contactElapsed += dt }
    if activity == .petting, let quality = contactQuality {
      let q = quality
      let d = character.contactDesire
      let z = character.contactSatisfaction
      let o = character.overstimulation
      character.contactDesire += dt * (0.09 * q * (1 - d) - 0.07 * z * d - 0.06 * o * d)
      character.contactSatisfaction += dt * 0.009 * q
      character.overstimulation += dt * (0.002 * q + 0.025 * (1 - q))
      character.socialAppetite -= dt * 0.003
      idleContactSeconds = q > 0 ? 0 : idleContactSeconds + dt
      lowReceptivenessSeconds = character.receptiveness < 0.12 ? lowReceptivenessSeconds + dt : 0
      if character.contactSatisfaction >= 0.80 || character.overstimulation >= 0.65
        || lowReceptivenessSeconds >= 2 || contactElapsed >= 150
      {
        stopContact()
        notice = "A tail flick, then he settles. That was enough for now."
      } else if character.receptiveness < 0.24 {
        notice = "His tail flicks. He is beginning to want a little space."
      } else if contactElapsed > 5 {
        notice = "He leans into the next stroke."
      }
    } else {
      if activity == .petting { idleContactSeconds += dt }
      character.contactDesire -=
        dt * 0.035 * (character.contactDesire - 0.2 * character.socialAppetite)
      character.contactSatisfaction -= dt * 0.004
      character.overstimulation -= dt * 0.008
      character.socialAppetite += dt * 0.002 / 60
    }
    if activity == .petting && (idleContactSeconds >= 2 || contactElapsed >= 150) {
      stopContact()
      notice = "A little pause."
    }
    if activity == .playing {
      playElapsed += dt
      character.energy -= dt * 0.0015
      character.sleepPressure += dt * 0.0004
      character.playMotivation -= dt * 0.002
      character.arousal += dt * 0.006
      character.overstimulation += dt * 0.009
      toy.boredom = unit(toy.boredom + dt * 0.004)
      toy.novelty = max(0.05, toy.novelty - dt * 0.002)
      let interest = toy.interest(character: character)
      lowInterestSeconds = interest < 0.20 ? lowInterestSeconds + dt : 0
      if lowInterestSeconds >= 5 || character.energy < 0.20 || character.overstimulation >= 0.65
        || playElapsed >= 180
      {
        stopContact()
        notice = "He lets the toy go and settles down."
      } else if interest < 0.35 {
        notice = "A slower chase. He is losing interest."
      }
    } else {
      character.arousal += (0.12 - character.arousal) * (1 - exp(-dt / 20))
      character.playMotivation += dt * 0.003 / 60
      toy.boredom = max(0, toy.boredom - dt * 0.002 / 60)
    }
    if activity == .eating {
      mealClock += dt
      if mealClock >= 0.8 {
        mealClock -= 0.8
        let consumed = min(0.10, 1 - mealFraction)
        character.hunger -= 0.50 * consumed
        character.satiety += 0.70 * consumed
        mealFraction += consumed
        if mealFraction >= 0.999 || character.satiety >= 0.90 {
          activity = .settling
          phaseRemaining = 4
          notice = "A little lip lick. Time to rest."
        }
      }
    }
    character.normalize()
    if activity == .resting || activity == .watching || activity == .walking
      || activity == .settling
    {
      phaseRemaining -= dt
      if phaseRemaining <= 0 {
        if activity == .settling || policy.focused || character.sleepPressure > 0.50 {
          activity = .resting
          phaseRemaining = 30 + random.nextUnit() * 60
        } else {
          let choice = random.nextUnit()
          activity =
            choice < 0.45 ? .resting : choice < 0.8 || policy.reducedMotion ? .watching : .walking
          phaseRemaining = 10 + random.nextUnit() * 30
        }
        notice =
          activity == .walking
          ? "A small wander."
          : activity == .watching ? "Watching the world go by." : "Quiet company."
      }
    }
  }

  @discardableResult public mutating func lifecycle(_ input: RuntimeLifecycleInput) -> RuntimeResult {
    guard canAcceptRuntimeInput else { return ignored(.invalidPayload) }
    var terminals: [InteractionTerminal] = []
    let reason: InteractionTerminalReason =
      input == .displayChanged ? .displayChanged : .systemSuspended
    if let terminal = terminalizeActive(reason: reason) { terminals.append(terminal) }
    let sequence = commitRuntimeSequence()
    return result(.accepted, sequence: sequence, terminals: terminals)
  }

  @discardableResult public mutating func reconcileReturn(absenceSeconds: Double) -> RuntimeResult {
    guard canAcceptRuntimeInput else { return ignored(.invalidPayload) }
    var terminals: [InteractionTerminal] = []
    if let terminal = terminalizeActive(reason: .systemSuspended) { terminals.append(terminal) }
    let elapsed = absenceSeconds.isFinite ? max(0, absenceSeconds) : 0
    if elapsed >= 1_800 {
      character.hunger = min(0.45, max(0.20, character.hunger))
      character.satiety = min(0.60, max(0.30, character.satiety))
      character.energy = max(0.65, character.energy)
      character.sleepPressure = min(0.30, character.sleepPressure)
      character.arousal = min(0.15, character.arousal)
      character.overstimulation = min(0.05, character.overstimulation)
    } else {
      let quiet = min(elapsed, 600)
      character.arousal += (0.12 - character.arousal) * (1 - exp(-quiet / 20))
      character.overstimulation = max(0, character.overstimulation - quiet * 0.008)
      character.energy += min(0.10, quiet * 0.015 / 60)
      character.sleepPressure -= min(0.15, quiet * 0.020 / 60)
    }
    character.contactSatisfaction = max(
      0, character.contactSatisfaction - min(elapsed, 600) * 0.004)
    toy.boredom = max(0, toy.boredom - min(elapsed, 7_200) * 0.002 / 60)
    character.normalize()
    stopContact()
    attention.resumeGrace()
    notice = "Back in his nook."
    let sequence = commitRuntimeSequence()
    return result(.accepted, sequence: sequence, terminals: terminals)
  }
}

public actor SimulationRuntime {
  private var simulation: Simulation

  public init(simulation: Simulation = Simulation()) { self.simulation = simulation }

  public func accept(_ input: InteractionInput) -> RuntimeResult { simulation.accept(input) }

  public func send(_ command: SimulationCommand) -> RuntimeResult { simulation.send(command) }

  public func lifecycle(_ input: RuntimeLifecycleInput) -> RuntimeResult {
    simulation.lifecycle(input)
  }

  public func advance(seconds: Double) -> RuntimeResult { simulation.advance(seconds: seconds) }

  public func reconcileReturn(absenceSeconds: Double) -> RuntimeResult {
    simulation.reconcileReturn(absenceSeconds: absenceSeconds)
  }

  public func snapshot() -> SimulationSnapshot { simulation.snapshot }
}
