import SwiftUI
import ComposableArchitecture

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var profiles: IdentifiedArrayOf<Profile> = .init(uniqueElements: profile)
        var detail: DetailFeature.State?
        var hero: HeroFeature.State
        
        init() {
            self.hero = HeroFeature.State()
        }
    }
    
    enum Action {
        case selectProfile(UUID)
        case detail(DetailFeature.Action)
        case hero(HeroFeature.Action)
        case clearDetail
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.hero, action: \.hero) {
            HeroFeature()
        }
        
        Reduce { state, action in
            switch action {
            case let .selectProfile(id):
                if let profile = state.profiles[id: id] {
                    state.hero = HeroFeature.State()
                    state.detail = DetailFeature.State(profile: profile, hero: state.hero)
                    return .run { send in
                        await send(.hero(.startTransition(to: id)))
                    }
                }
                return .none
                
            case .detail(.close):
                return .none
                
            case .hero(.transitionDidEnd):
                return .send(.clearDetail)
                
            case .clearDetail:
                state.detail = nil
                return .none
                
            case let .detail(.hero(heroAction)):
                return .send(.hero(heroAction))
                
            case .hero:
                if var detail = state.detail {
                    if detail.hero != state.hero {
                        detail.hero = state.hero
                        state.detail = detail
                    }
                }
                return .none
                
            case .detail:
                return .none
            }
        }
        .ifLet(\.detail, action: \.detail) {
            DetailFeature()
        }
        ._printChanges()
    }
}

struct HomeView: View {
    let store: StoreOf<HomeFeature>
    
    var body: some View {
        NavigationStack {
            List(store.profiles) { profile in
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 50, height: 50)
                        .clipShape(.rect(cornerRadius: 25))
                        .opacity(store.detail?.profile.id == profile.id ? 0 : 1)
                        .anchorPreference(key: AnchorKey.self, value: .bounds) { anchor in
                            [profile.id.uuidString: anchor]
                        }
                        .transition(.identity)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.username)
                            .font(.headline)
                        Text(profile.lastMsg)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(.rect)
                .onTapGesture {
                    store.send(.selectProfile(profile.id))
                }
            }
            .navigationTitle("Progress Effect")
        }
        .overlay {
            IfLetStore(
                store.scope(
                    state: \.detail,
                    action: \.detail
                )
            ) { detailStore in
                DetailView(store: detailStore)
                    .opacity(store.detail != nil ? 1 : 0)
            }
        }
        .overlayPreferenceValue(AnchorKey.self, alignment: .center) { value in
            GeometryReader { geo in
                if let detail = store.detail,
                   let source = value[detail.profile.id.uuidString],
                   let destination = value["DESTINATION"] {
                    HeroView(
                        store: store.scope(
                            state: \.hero,
                            action: \.hero
                        ),
                        sourceRect: geo[source],
                        destinationRect: geo[destination],
                        profileID: detail.profile.id
                    )
                }
            }
        }
    }
}
