import SwiftState

typealias PKStateMachine = StateMachine<PKStateMachineStates, PKStateMachineEvents>

enum PKStateMachineEvents: EventType {
    case startStop, timerFired, skipRest
}

enum PKStateMachineStates: String, StateType {
    case idle, work, shortRest, longRest
}
