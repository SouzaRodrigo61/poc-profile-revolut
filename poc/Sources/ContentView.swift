import SwiftUI
import SwiftUIIntrospect

struct Profile: Identifiable {
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

@Observable
class ProfileViewModel {
    var allProfiles: [Profile] = profile
    var selectedProfile: Profile? = nil
    var showDetails: Bool = false
    var heroProgress: CGFloat = 0
    var showHeroView: Bool = true
    var initialSourceRect: CGRect = .zero
    var initialDestRect: CGRect = .zero
    var hasInitialPositions: Bool = false
    var isDraggingShared: Bool = false

    func selectProfile(_ profile: Profile) {
        selectedProfile = profile
        showDetails = true
        
        Task { @MainActor in
            withAnimation(.snappy(duration: 0.35, extraBounce: 0), completionCriteria: .logicallyComplete) {
                self.heroProgress = 1.0
            } completion: {
                Task {
                    try? await Task.sleep(for: .seconds(0.1))
                    self.showHeroView = false
                }
            }
        }
    }

    func closeDetails(currentScrollPosition: Binding<ScrollPosition>? = nil) {
        showHeroView = true
        
        withAnimation(.snappy(duration: 0.35, extraBounce: 0), completionCriteria: .logicallyComplete) {
            heroProgress = 0.0
        } completion: {
            Task {
                self.showDetails = false
                self.selectedProfile = nil
                currentScrollPosition?.wrappedValue.scrollTo(edge: .top)
            }
        }
    }
    
    func handleDragChanged(translation: CGFloat, viewSize: CGSize) {
        var currentTranslation = translation
        currentTranslation = currentTranslation < 0 ? currentTranslation : 0
        
        let dragProgress = 1.0 + ((currentTranslation * 1.2) / viewSize.width)
        let cappedProgress = min(max(0, dragProgress), 1)
        
        heroProgress = cappedProgress
        if !showHeroView {
            showHeroView = true
        }
    }
    
    func handleDragEnded(offset: CGFloat, velocity: CGFloat, viewSize: CGSize, currentScrollPosition: Binding<ScrollPosition>) {
        isDraggingShared = false
        if (offset + velocity) < -(viewSize.width * 0.8) {
            withAnimation(.snappy(duration: 0.35, extraBounce: 0),
                          completionCriteria: .logicallyComplete) {
                heroProgress = .zero
            } completion: {
                self.showDetails = false
                self.showHeroView = true
                self.selectedProfile = nil
                // offset = .zero // Offset é local para a DetailView, não precisa estar no ViewModel
            }
        } else {
            withAnimation(.snappy(duration: 0.35, extraBounce: 0),
                          completionCriteria: .logicallyComplete) {
                heroProgress = 1
                // offset = .zero // Offset é local para a DetailView
            } completion: {
                self.showHeroView = false
                currentScrollPosition.wrappedValue.scrollTo(edge: .top)
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        Home()
    }
}

struct Home: View {
    @State private var viewModel = ProfileViewModel()
    
    public var body: some View {
        NavigationStack {
            List(viewModel.allProfiles) { profile in
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 50, height: 50)
                        .clipShape(.rect(cornerRadius: 50 / 2))
                        .opacity(viewModel.selectedProfile?.id == profile.id ? 0 : 1)
                        .anchorPreference(key: AnchorKey.self, value: .bounds) { anchor in
                            return [profile.id.uuidString: anchor]
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
                    viewModel.selectProfile(profile)
                }
            }
            .navigationTitle("Progress Effect")
        }
        .overlay {
            DetailView(viewModel: viewModel)
            .opacity(viewModel.showDetails ? 1 : 0)
        }
        .overlayPreferenceValue(AnchorKey.self, alignment: .center) { value in
            GeometryReader { geo in
                if let selectedProfile = viewModel.selectedProfile,
                   let source = value[selectedProfile.id.uuidString],
                   let destination = value["DESTINATION"] {
                    
                    let sourceRect = geo[source]
                    let destinationRect = geo[destination]
                    
                    // Armazenar retângulos iniciais no primeiro frame do drag
                    Group {
                        Color.clear
                            .onAppear {
                                // Inicializar com valores atuais
                                if viewModel.initialSourceRect == .zero {
                                    viewModel.initialSourceRect = sourceRect
                                    viewModel.initialDestRect = destinationRect
                                }
                            }
                            .onChange(of: viewModel.isDraggingShared) { oldValue, newValue in
                                // Quando começa o drag
                                if newValue && !oldValue {
                                    viewModel.initialSourceRect = sourceRect
                                    viewModel.initialDestRect = destinationRect
                                    viewModel.hasInitialPositions = true
                                }
                                
                                // Quando termina o drag
                                if !newValue && oldValue && viewModel.heroProgress <= 0.01 {
                                    viewModel.hasInitialPositions = false
                                }
                            }
                    }
                    
                    // Usar posições iniciais se disponíveis, caso contrário usar atuais
                    let effectiveSourceRect = viewModel.hasInitialPositions ? viewModel.initialSourceRect : sourceRect
                    let effectiveDestRect = viewModel.hasInitialPositions ? viewModel.initialDestRect : destinationRect
                    
                    let diffSize = CGSize(
                        width: effectiveDestRect.width - effectiveSourceRect.width,
                        height: effectiveDestRect.height - effectiveSourceRect.height
                    )
                    
                    let initialDiffOrigin = CGPoint(
                        x: effectiveDestRect.minX - effectiveSourceRect.minX,
                        y: effectiveDestRect.minY - effectiveSourceRect.minY
                    )
                    
                    let radius = (effectiveSourceRect.height + (diffSize.height * viewModel.heroProgress)) / 2
                    
                    ZStack {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(
                                width: effectiveSourceRect.width + (diffSize.width * viewModel.heroProgress),
                                height: effectiveSourceRect.height + (diffSize.height * viewModel.heroProgress)
                            )
                            .clipShape(.rect(cornerRadius: radius))
                            .offset(
                                x: effectiveSourceRect.minX + (initialDiffOrigin.x * viewModel.heroProgress),
                                y: effectiveSourceRect.minY + (initialDiffOrigin.y * viewModel.heroProgress)
                            )
                            .opacity(viewModel.showHeroView ? 1 : 0)
                    }
                }
            }
        }
    }
}

/// Detail View
struct DetailView: View {
    @Bindable var viewModel: ProfileViewModel
    
    @State private var position = ScrollPosition(edge: .top)
    
    @Environment(\.colorScheme) private var scheme
    
    @GestureState private var isDraggingGesture: Bool = false // Renomeado para evitar conflito com viewModel.isDraggingShared
    @State private var offset: CGFloat = 0
    
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
                                    if !viewModel.showHeroView {
                                        Rectangle()
                                            .fill(.blue)
                                            .frame(width: 150, height: 150)
                                            .clipShape(.rect(cornerRadius: 150 / 2))
                                            .transition(.identity)
                                    }
                                }
                                .frame(width: 150, height: 150)
                                .anchorPreference(key: AnchorKey.self, value: .bounds) { anchor in
                                    return ["DESTINATION": anchor]
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical)
                        }
                        
                        VStack(spacing: 0) {
                            ForEach(0...10, id: \.self) { index in
                                VStack {
                                    Text("test: \\(index)")
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
                                    Text("test: \\(index)")
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
                .scrollPosition($position)
                .scrollIndicators(.hidden)
                .frame(width: size.width, height: size.height)
                .background {
                    Rectangle()
                        .fill(scheme == .dark ? .black : .white)
                        .ignoresSafeArea()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.closeDetails(currentScrollPosition: $position)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                                .imageScale(.medium)
                                .contentShape(.rect)
                                .foregroundStyle(.white, .black)
                        }
                        .buttonStyle(.plain)
                        .opacity(viewModel.showHeroView ? 0 : 1)
                        .animation(.snappy(duration: 0.2, extraBounce: 0), value: viewModel.showHeroView)
                    }
                }
                .offset(x: (size.width * viewModel.heroProgress) - size.width)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(.clear)
                        .frame(width: 10)
                        .contentShape(.rect)
                        .gesture(
                            DragGesture()
                                .updating($isDraggingGesture) { _, out, _ in
                                    out = true
                                    viewModel.isDraggingShared = true
                                }
                                .onChanged{ value in
                                    var translation = value.translation.width
                                    translation = isDraggingGesture ? translation : .zero
                                    offset = translation // Atualiza o offset local
                                    viewModel.handleDragChanged(translation: translation, viewSize: size)
                                }
                                .onEnded { value in
                                    // viewModel.isDraggingShared = false // Movido para dentro de handleDragEnded
                                    let velocity = value.velocity.width
                                    viewModel.handleDragEnded(offset: offset, velocity: velocity, viewSize: size, currentScrollPosition: $position)
                                    offset = .zero // Reset offset local após o término do drag
                                }
                        )
                }
            }
            .introspect(.viewController, on: .iOS(.v17, .v18)) { viewController in
                viewController.view.backgroundColor = .clear
                
                // Também tenta limpar o background do filho, se houver:
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

/// Helpers
struct AnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String : Anchor<CGRect>], nextValue: () -> [String : Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}
