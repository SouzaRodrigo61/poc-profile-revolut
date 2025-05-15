import SwiftUI
import ComposableArchitecture
import SwiftUIIntrospect

@Reducer
struct DetailFeature {
    @ObservableState
    struct State: Equatable {
        var profile: Profile
        var scrollPosition: ScrollPosition
        var offset: CGFloat = 0
        var isDragging: Bool = false
        var isDraggingShared: Bool = false
        var hero: HeroFeature.State

        init(profile: Profile, hero: HeroFeature.State) {
            self.profile = profile
            self.scrollPosition = .init(edge: .top)
            self.hero = hero
        }
    }

    enum Action: BindableAction, Equatable {
        case close
        case dragChanged(CGFloat, CGSize)
        case dragEnded(CGFloat, CGFloat, CGSize)
        case setDragging(Bool)
        case setDraggingShared(Bool)
        case binding(BindingAction<State>)
        case hero(HeroFeature.Action)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .close:
                state.isDraggingShared = false
                state.isDragging = false
                state.hero.heroProgress = 0
                return .send(.hero(.resetTransition))

            case let .dragChanged(translation, size):
                state.isDragging = true
                state.isDraggingShared = true
                let currentTranslation = state.isDragging ? (translation < 0 ? translation : 0) : 0
                state.offset = currentTranslation
                let dragProgress = 1.0 + ((currentTranslation * 1.2) / size.width)
                let cappedProgress = min(max(0, dragProgress), 1)

                var effects: [Effect<Action>] = []

                if state.hero.heroProgress != cappedProgress {
                    state.hero.heroProgress = cappedProgress
                    effects.append(.send(.hero(.setProgress(cappedProgress))))
                }

                if !state.hero.showHeroView {
                    state.hero.showHeroView = true
                    effects.append(.send(.hero(.setShowHeroView(true))))
                }
                return .concatenate(effects)

            case let .dragEnded(offset, velocity, size):
                state.isDragging = false
                state.isDraggingShared = false
                let threshold = size.width * 0.8
                let totalOffset = offset + velocity
                if totalOffset < -threshold {
                    return .concatenate(
                        .send(.hero(.endDrag(offset: offset, velocity: velocity, viewSize: size, shouldClose: true))),
                        .send(.close)
                    )
                } else {
                    return .send(.hero(.endDrag(offset: offset, velocity: velocity, viewSize: size, shouldClose: false)))
                }

            case let .setDragging(isDragging):
                state.isDragging = isDragging
                return .send(.hero(.setDragging(isDragging)))

            case let .setDraggingShared(isDraggingShared):
                state.isDraggingShared = isDraggingShared
                return .none

            case .binding:
                return .none

            case let .hero(.setProgress(progress)):
                state.hero.heroProgress = progress
                return .none

            case let .hero(.setShowHeroView(show)):
                let oldShowHeroView = state.hero.showHeroView
                state.hero.showHeroView = show
                if oldShowHeroView && !show && !state.isDragging && state.hero.heroProgress == 1.0 {
                    state.scrollPosition.scrollTo(edge: .top)
                }
                return .none

            case .hero:
                return .none
            }
        }
        ._printChanges()
    }
}

struct DetailView: View {
    @Bindable var store: StoreOf<DetailFeature> // Fixed from @State to @Bindable
    @Environment(\.colorScheme) private var scheme
    @GestureState private var isDragging: Bool = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let size = geo.size
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(.clear)
                                .overlay {
                                    if !store.hero.showHeroView {
                                        Rectangle()
                                            .fill(.blue)
                                            .frame(width: 150, height: 150)
                                            .clipShape(.rect(cornerRadius: 75))
                                            .transition(.identity)
                                    }
                                }
                                .frame(width: 150, height: 150)
                                .anchorPreference(key: AnchorKey.self, value: .bounds) { anchor in
                                    ["DESTINATION": anchor]
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical)
                        }
                        VStack(spacing: 0) {
                            ForEach(0...10, id: \.self) { index in
                                VStack {
                                    Text("test: \(index)")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                    if index < 10 {
                                        Divider()
                                            .padding(.leading)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .background(scheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : Color(UIColor.systemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                        VStack(spacing: 0) {
                            ForEach(0...10, id: \.self) { index in
                                VStack {
                                    Text("test: \(index)")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                    if index < 10 {
                                        Divider()
                                            .padding(.leading)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .background(scheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : Color(UIColor.systemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .frame(width: size.width, height: size.height)
                .background {
                    Rectangle()
                        .fill(scheme == .dark ? .black : .white)
                        .ignoresSafeArea()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            store.send(.close)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                                .imageScale(.medium)
                                .contentShape(.rect)
                                .foregroundStyle(.white, .black)
                        }
                        .buttonStyle(.plain)
                        .opacity(store.hero.showHeroView ? 0 : 1)
                        .animation(.snappy(duration: 0.2, extraBounce: 0), value: store.hero.showHeroView)
                    }
                }
                .offset(x: (size.width * store.hero.heroProgress) - size.width)
                .overlay(alignment: .trailing) {
                    Capsule()
                        .fill(.red) // Keep red for debugging
                        .frame(width: 50)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            DragGesture()
                                .updating($isDragging) { _, out, _ in
                                    out = true
                                    store.send(.setDraggingShared(true))
                                }
                                .onChanged { value in
                                    store.send(.setDragging(true))
                                    store.send(.dragChanged(value.translation.width, size))
                                }
                                .onEnded { value in
                                    store.send(.dragEnded(value.translation.width, value.velocity.width, size))
                                    store.send(.setDragging(false))
                                    store.send(.setDraggingShared(false))
                                }
                        )
                }
                .overlay {
                    Text("heroProgress: \(store.hero.heroProgress)")
                        .foregroundColor(.white)
                        .padding()
                        .background(.black.opacity(0.7))
                        .position(x: size.width / 2, y: 50)
                }
            }
            .introspect(.viewController, on: .iOS(.v17, .v18)) { viewController in
                viewController.view.backgroundColor = .clear
                viewController.children.forEach { child in
                    if String(describing: type(of: child)).contains("NavigationStackHostingController") {
                        child.view.backgroundColor = .clear
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
