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

struct ContentView: View {
    var body: some View {
        Home()
    }
}

struct Home: View {
    @State private var allProfiles: [Profile] = profile
    @State private var selectedProfile: Profile?
    @State private var showDetails: Bool = false
    @State private var heroProgress: CGFloat = 0
    @State private var showHeroView: Bool = true
    @State private var initialSourceRect: CGRect = .zero
    @State private var initialDestRect: CGRect = .zero
    @State private var hasInitialPositions: Bool = false
    @State private var isDraggingShared: Bool = false
    
    public var body: some View {
        NavigationStack {
            List(allProfiles) { profile in
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 50, height: 50)
                        .clipShape(.rect(cornerRadius: 50 / 2))
                        .opacity(selectedProfile?.id == profile.id ? 0 : 1)
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
                    selectedProfile = profile
                    showDetails = true
                    
                    withAnimation(.snappy(duration: 0.35, extraBounce: 0), completionCriteria: .logicallyComplete) {
                        heroProgress = 1.0
                    } completion: {
                        Task {
                            try? await Task.sleep(for: .seconds(0.1))
                            showHeroView = false
                        }
                    }
                    
                }
            }
            .navigationTitle("Progress Effect")
        }
        .overlay {
            DetailView(
                selectedProfile: $selectedProfile,
                heroProgress: $heroProgress,
                showDetails: $showDetails,
                showHeroView: $showHeroView,
                isDraggingShared: $isDraggingShared
            )
            .opacity(showDetails ? 1 : 0)
        }
        .overlayPreferenceValue(AnchorKey.self, alignment: .center) { value in
            GeometryReader { geo in
                if let selectedProfile,
                   let source = value[selectedProfile.id.uuidString],
                   let destination = value["DESTINATION"] {
                    
                    let sourceRect = geo[source]
                    let destinationRect = geo[destination]
                    
                    // Armazenar retângulos iniciais no primeiro frame do drag
                    Group {
                        Color.clear
                            .onAppear {
                                // Inicializar com valores atuais
                                if initialSourceRect == .zero {
                                    initialSourceRect = sourceRect
                                    initialDestRect = destinationRect
                                }
                            }
                            .onChange(of: isDraggingShared) { oldValue, newValue in
                                // Quando começa o drag
                                if newValue && !oldValue {
                                    initialSourceRect = sourceRect
                                    initialDestRect = destinationRect
                                    hasInitialPositions = true
                                }
                                
                                // Quando termina o drag
                                if !newValue && oldValue && heroProgress <= 0.01 {
                                    hasInitialPositions = false
                                }
                            }
                    }
                    
                    // Usar posições iniciais se disponíveis, caso contrário usar atuais
                    let effectiveSourceRect = hasInitialPositions ? initialSourceRect : sourceRect
                    let effectiveDestRect = hasInitialPositions ? initialDestRect : destinationRect
                    
                    let diffSize = CGSize(
                        width: effectiveDestRect.width - effectiveSourceRect.width,
                        height: effectiveDestRect.height - effectiveSourceRect.height
                    )
                    
                    let initialDiffOrigin = CGPoint(
                        x: effectiveDestRect.minX - effectiveSourceRect.minX,
                        y: effectiveDestRect.minY - effectiveSourceRect.minY
                    )
                    
                    let radius = (effectiveSourceRect.height + (diffSize.height * heroProgress)) / 2
                    
                    ZStack {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(
                                width: effectiveSourceRect.width + (diffSize.width * heroProgress),
                                height: effectiveSourceRect.height + (diffSize.height * heroProgress)
                            )
                            .clipShape(.rect(cornerRadius: radius))
                            .offset(
                                x: effectiveSourceRect.minX + (initialDiffOrigin.x * heroProgress),
                                y: effectiveSourceRect.minY + (initialDiffOrigin.y * heroProgress)
                            )
                            .opacity(showHeroView ? 1 : 0)
                    }
                }
            }
        }
    }
}

/// Detail View
struct DetailView: View {
    @Binding var selectedProfile: Profile?
    @Binding var heroProgress: CGFloat
    @Binding var showDetails: Bool
    @Binding var showHeroView: Bool
    @Binding var isDraggingShared: Bool
    
    @Environment(\.colorScheme) private var scheme
    
    @GestureState private var isDragging: Bool = false
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
                                    if !showHeroView {
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
                            showHeroView = true
                            
                            withAnimation(.snappy(duration: 0.35, extraBounce: 0), completionCriteria: .logicallyComplete) {
                                heroProgress = 0.0
                            } completion: {
                                Task {
                                    showDetails = false
                                    self.selectedProfile = nil
                                }
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                                .imageScale(.medium)
                                .contentShape(.rect)
                                .foregroundStyle(.white, .black)
                        }
                        .buttonStyle(.plain)
                        .opacity(showHeroView ? 0 : 1)
                        .animation(.snappy(duration: 0.2, extraBounce: 0), value: showHeroView)
                    }
                }
                .offset(x: (size.width * heroProgress) - size.width)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(.red)
                        .frame(width: 10)
                        .contentShape(.rect)
                        .gesture(
                            DragGesture()
                                .updating($isDragging) { _, out, _ in
                                    out = true
                                    isDraggingShared = true
                                }
                                .onChanged{ value in
                                    var translation = value.translation.width
                                    translation = isDragging ? translation : .zero
                                    translation = translation < 0 ? translation : 0
                                    
                                    /// Converting into progress
                                    /// Começando o movimento imediatamente com uma resposta mais rápida
                                    let dragProgress = 1.0 + ((translation * 1.2) / size.width)
                                    /// Limiting Progress btw 0 - 1
                                    let cappedProgress = min(max(0, dragProgress), 1)
                                    offset = translation
                                    heroProgress = cappedProgress
                                    if !showHeroView {
                                        showHeroView = true
                                    }
                                }
                                .onEnded { value in
                                    isDraggingShared = false
                                    /// Closing / Resettings based on end target
                                    let velocity = value.velocity.width
                                    
                                    if (offset + velocity) < -(size.width * 0.8) {
                                        withAnimation(.snappy(duration: 0.35, extraBounce: 0),
                                                      completionCriteria: .logicallyComplete) {
                                            heroProgress = .zero
                                        } completion: {
                                            offset = .zero
                                            showDetails = false
                                            showHeroView = true
                                            self.selectedProfile = nil
                                        }
                                    } else {
                                        withAnimation(.snappy(duration: 0.35, extraBounce: 0),
                                                      completionCriteria: .logicallyComplete) {
                                            heroProgress = 1
                                            offset = .zero
                                        } completion: {
                                            showHeroView = false
                                        }
                                    }
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
