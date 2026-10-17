import Observation

@MainActor
@Observable
final class AccountMenuState {
    var showsSettings = false
    var showsPhotoPicker = false
    var confirmsSignOut = false
}
