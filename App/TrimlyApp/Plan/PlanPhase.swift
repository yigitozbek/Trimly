import TrimlyCore

enum PlanPhase: Equatable {
    case idle
    case scanning(PlanProgress?)
    case reviewing(PlanProgress?)
    case applying
    case applied(runID: String)
    case failed(String)
}
