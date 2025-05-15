import SwiftUI
import SwiftUIIntrospect
import ComposableArchitecture

struct Profile: Identifiable, Equatable {
    let id: UUID = UUID()
    var username: String
    var profilePicture: String
    var lastMsg: String
}

var profile: [Profile] = [
    .init(username: "John Doe", profilePicture: "profile_pic_1", lastMsg: "Hey"),
    .init(username: "Jane Doe", profilePicture: "profile_pic_2", lastMsg: "Hi"),
    .init(username: "Michael Scott", profilePicture: "profile_pic_3", lastMsg: "How are you?"),
    .init(username: "Dwight Schrute", profilePicture: "profile_pic_4", lastMsg: "I'm fine")
]

struct ContentView: View {
    var body: some View {
        HomeView(store: Store(initialState: HomeFeature.State()) {
            HomeFeature()
        })
    }
}

/// Helpers
struct AnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String : Anchor<CGRect>], nextValue: () -> [String : Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}
