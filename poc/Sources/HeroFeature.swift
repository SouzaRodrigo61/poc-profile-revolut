import SwiftUI
import ComposableArchitecture

@Reducer
struct HeroFeature {
    @ObservableState
    struct State: Equatable {
        var heroProgress: CGFloat = 0
        var showHeroView: Bool = true
        var initialSourceRect: CGRect = .zero
        var initialDestRect: CGRect = .zero
        var hasInitialPositions: Bool = false
        var isDragging: Bool = false
        var selectedProfileID: UUID?
    }
    
    enum Action: Equatable {
        case startTransition(to: UUID)
        case resetTransition
        case endDrag(offset: CGFloat, velocity: CGFloat, viewSize: CGSize, shouldClose: Bool)
        case setDragging(Bool)
        case updateRect(source: CGRect, destination: CGRect)
        case setProgress(CGFloat)
        case setShowHeroView(Bool)
        case transitionDidEnd
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .startTransition(to: id):
                state.selectedProfileID = id
                state.showHeroView = true
                state.hasInitialPositions = true
                state.initialSourceRect = .zero
                state.initialDestRect = .zero
                return .run { send in
                    await send(.setProgress(1.0), animation: .snappy(duration: 0.35, extraBounce: 0))
                    try? await Task.sleep(for: .seconds(0.35))
                    await send(.setShowHeroView(false))
                }
                
            case .resetTransition:
                state.showHeroView = true
                return .run { send in
                    await send(.setProgress(0.0), animation: .snappy(duration: 0.35, extraBounce: 0))
                    try? await Task.sleep(for: .seconds(0.35))
                    await send(.transitionDidEnd)
                }
                
            case .transitionDidEnd:
                state.selectedProfileID = nil
                state.hasInitialPositions = false
                state.initialSourceRect = .zero
                state.initialDestRect = .zero
                state.heroProgress = 0
                state.showHeroView = true
                return .none
                
            case let .endDrag(_, _, _, shouldClose):
                state.isDragging = false
                if shouldClose {
                    return .send(.resetTransition)
                } else {
                    return .run { send in
                        await send(.setProgress(1.0), animation: .snappy(duration: 0.35, extraBounce: 0))
                        try? await Task.sleep(for: .seconds(0.35))
                        await send(.setShowHeroView(false))
                    }
                }
                
            case let .setDragging(isDragging):
                state.isDragging = isDragging
                if isDragging {
                    if !state.hasInitialPositions {
                        state.hasInitialPositions = true
                        state.initialSourceRect = .zero
                        state.initialDestRect = .zero
                    }
                } else if state.heroProgress < 0.01 && !state.isDragging {
                    // Se não fechou via endDrag, e o progresso é mínimo, considere limpar.
                    // No entanto, endDrag ou resetTransition devem ser os caminhos principais para limpar.
                }
                return .none
                
            case let .updateRect(source, destination):
                if state.hasInitialPositions && state.initialSourceRect == .zero {
                    state.initialSourceRect = source
                    state.initialDestRect = destination
                }
                return .none
                
            case let .setProgress(progress):
                state.heroProgress = progress
                return .none
                
            case let .setShowHeroView(show):
                state.showHeroView = show
                return .none
            }
        }
    }
}

struct HeroView: View {
    let store: StoreOf<HeroFeature>
    let sourceRect: CGRect
    let destinationRect: CGRect
    let profileID: UUID
    
    var body: some View {
        Group {
            Color.clear
                .onAppear {
                    store.send(.updateRect(source: sourceRect, destination: destinationRect))
                }
                .onChange(of: store.isDragging) { oldValue, newValue in
                    if newValue && !oldValue {
                        store.send(.updateRect(source: sourceRect, destination: destinationRect))
                    }
                }
        }
        
        let actualInitialSourceRect = (store.hasInitialPositions && store.initialSourceRect != .zero) ? store.initialSourceRect : sourceRect
        let actualInitialDestRect = (store.hasInitialPositions && store.initialDestRect != .zero) ? store.initialDestRect : destinationRect
        
        let diffSize = CGSize(
            width: actualInitialDestRect.width - actualInitialSourceRect.width,
            height: actualInitialDestRect.height - actualInitialSourceRect.height
        )
        
        let initialDiffOrigin = CGPoint(
            x: actualInitialDestRect.minX - actualInitialSourceRect.minX,
            y: actualInitialDestRect.minY - actualInitialSourceRect.minY
        )
        
        let currentAnimatedHeight = actualInitialSourceRect.height + (diffSize.height * store.heroProgress)
        let radius = currentAnimatedHeight / 2
        
        ZStack {
            Rectangle()
                .fill(Color.blue)
                .frame(
                    width: actualInitialSourceRect.width + (diffSize.width * store.heroProgress),
                    height: currentAnimatedHeight
                )
                .clipShape(.rect(cornerRadius: radius))
                .offset(
                    x: actualInitialSourceRect.minX + (initialDiffOrigin.x * store.heroProgress),
                    y: actualInitialSourceRect.minY + (initialDiffOrigin.y * store.heroProgress)
                )
                .opacity(store.showHeroView ? 1 : 0)
        }
    }
}
