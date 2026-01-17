import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = DashboardViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.scenePhase) var scenePhase
    
    @State private var isListExpanded = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView(sunPos: viewModel.sunPosition, moonPos: viewModel.moonPosition)
                
                VStack(spacing: 16) {
                    if !isListExpanded {
                        permissionBanner
                        
                        verseHeader
                        
                        heroSection
                    }
                    
                    if isListExpanded {
                        expandedPrayerList
                            .transition(.opacity) // Smooth fade transition
                    } else {
                        compactPrayerList
                            .transition(.opacity)
                    }
                    
                    Spacer()
                }
                
                VStack {
                    Spacer()
                    AstroSummaryPanel(
                        sunRise: viewModel.sunRise,
                        solarNoon: viewModel.solarNoon,
                        sunSet: viewModel.sunSet,
                        moonRise: viewModel.moonrise,
                        moonSet: viewModel.moonset
                    )
                    .padding(.bottom, 90) // Tighter above bottom dock
                }
                
                bottomDock
                
                audioOverlay
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.calculatePrayerTimes(location: locationManager)
        }
        .onChange(of: locationManager.location) {
            viewModel.calculatePrayerTimes(location: locationManager)
            viewModel.scheduleNotifications() 
        }
        .onChange(of: viewModel.prayerTimes) {
            viewModel.scheduleNotifications()
        }
    }
    
    // MARK: - Subviews
    
    private var permissionBanner: some View {
        Group {
            if !viewModel.isLocationAuthorized || !viewModel.isNotificationsAuthorized {
                NavigationLink(destination: PermissionView(viewModel: viewModel)) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Permissions check required")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Fix")
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .foregroundColor(.red)
                            .cornerRadius(5)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var verseHeader: some View {
        VStack(spacing: 8) {
            Text(viewModel.currentVerseArabic)
                .font(.system(.title3, design: .serif))
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(viewModel.currentVerseEnglish)
                .font(.system(.subheadline, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
        }
        .lineSpacing(4)
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var heroSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.currentDateString)
                .font(.system(.title3, design: .serif))
                .foregroundColor(.white.opacity(0.8))
            
            Text(viewModel.hijriDateString)
                .font(.system(.caption, design: .serif))
                .foregroundColor(.cyan.opacity(0.8))
            
            Text(viewModel.locationName)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            
            // Hero Countdown
            ZStack {
                Circle()
                    .stroke(lineWidth: 4)
                    .foregroundColor(.white.opacity(0.1))
                    .frame(width: 220, height: 220)
                
                Circle()
                    .trim(from: 0, to: viewModel.progressToNextPrayer)
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .foregroundColor(.cyan)
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .cyan.opacity(0.5), radius: 10)
                
                VStack {
                    Text(viewModel.nextPrayerName)
                        .font(.title2)
                        .fontWeight(.light)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(viewModel.timeRemaining)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - List Views
    
    private var compactPrayerList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.dashboardItems) { item in
                        PrayerCard(
                            name: item.title,
                            time: item.time,
                            isNext: item.isNext,
                            type: item.type
                        )
                        .id(item.id)
                        .containerRelativeFrame(.vertical, count: 5, span: 2, spacing: 0)
                        .padding(.horizontal, 32)
                        .scrollTransition(topLeading: .interactive, bottomTrailing: .interactive) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.15 : 0.95)
                                .opacity(phase.isIdentity ? 1.0 : 0.6)
                                .blur(radius: phase.isIdentity ? 0 : 1)
                                .rotation3DEffect(
                                    .degrees(Double(phase.value) * -70),
                                    axis: (x: 1, y: 0, z: 0),
                                    perspective: 0.5
                                )
                                .offset(y: phase.isIdentity ? 0 : (phase.value < 0 ? 10 : -10))
                        }
                        .padding(.vertical, 10)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isListExpanded = true
                            }
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .safeAreaPadding(.vertical, 80)
            .frame(height: 320)
            .onChange(of: viewModel.dashboardItems) { _, items in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let nextItem = items.first(where: { $0.isNext }) {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                            proxy.scrollTo(nextItem.id, anchor: .center)
                        }
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let nextItem = viewModel.dashboardItems.first(where: { $0.isNext }) {
                        withAnimation(.easeOut(duration: 1.0)) {
                            proxy.scrollTo(nextItem.id, anchor: .center)
                        }
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let nextItem = viewModel.dashboardItems.first(where: { $0.isNext }) {
                            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                                proxy.scrollTo(nextItem.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var expandedPrayerList: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(viewModel.dashboardItems) { item in
                        PrayerCard(
                            name: item.title,
                            time: item.time,
                            isNext: item.isNext,
                            type: item.type
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 60) // Space for close button
                .padding(.bottom, 100)
            }
            .background(.thinMaterial) // Full backdrop
            
            // Close Button
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isListExpanded = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
            .padding(.top, 40) // Adjust for status bar overlap if needed, though safeArea handles most
        }
        .edgesIgnoringSafeArea(.all) // Take over screen
    }
    
    private var bottomDock: some View {
        VStack {
            Spacer()
            HStack(spacing: 20) {
                NavigationLink(destination: QiblaView()) {
                    DockIcon(icon: "location.north.circle.fill", label: "Qibla")
                }
                NavigationLink(destination: LocationMapView()) {
                    DockIcon(icon: "map.fill", label: "Map")
                }
                NavigationLink(destination: VisualizerView()) {
                    DockIcon(icon: "sun.max.circle.fill", label: "Sky")
                }
                NavigationLink(destination: SettingsView()) {
                    DockIcon(icon: "gearshape.fill", label: "Settings")
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(.ultraThinMaterial)
            .cornerRadius(30)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            .padding(.bottom, 20)
        }
    }
    
    private var audioOverlay: some View {
        Group {
            if audioManager.isPlaying {
                VStack {
                    Spacer()
                    Button(action: {
                        audioManager.stop()
                    }) {
                        Text("Stop Adhan")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
        }
    }
    
    // scheduleNotifications removed, moved to ViewModel
}


