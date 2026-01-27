import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = DashboardViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.scenePhase) var scenePhase
    
    @State private var isListExpanded = false
    @State private var showCalendar = false
    
    var body: some View {
        NavigationStack {
            if viewModel.isLoading {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text(viewModel.loadingStatus)
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(.body, design: .rounded))
                        Text(viewModel.locationName) // Show "Locating..." or "Location found"
                             .foregroundColor(.gray)
                             .font(.caption)
                    }
                }
            } else {
                ZStack {
                    BackgroundView(sunPos: viewModel.sunPosition, moonPos: viewModel.moonPosition)
                    
                    // Unified ScrollView
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                permissionBanner
                                
                                verseHeader
                                
                                heroSection
                                    .padding(.bottom, 10)
                                
                                // Prayer List
                                VStack(spacing: 12) {
                                    ForEach(viewModel.dashboardItems) { item in
                                        PrayerCard(
                                            name: item.title,
                                            time: item.time,
                                            isNext: item.isNext,
                                            type: item.type
                                        )
                                        .id(item.id)
                                        .padding(.horizontal, 24)
                                        .scrollTransition { content, phase in
                                            content
                                                .scaleEffect(phase.isIdentity ? 1.0 : 0.95)
                                                .opacity(phase.isIdentity ? 1.0 : 0.8)
                                        }
                                    }
                                }
                                
                                Spacer().frame(height: 250) // Increased space for bottom dock + Astro Panel
                            }
                        }
                        .scrollIndicators(.hidden)
                        .onAppear {
                            // Scroll to next prayer on appear
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if let nextItem = viewModel.dashboardItems.first(where: { $0.isNext }) {
                                    withAnimation(.spring) {
                                        proxy.scrollTo(nextItem.id, anchor: .center)
                                    }
                                }
                            }
                        }
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
                    .ignoresSafeArea(.keyboard)
                    
                    bottomDock
                    
                    audioOverlay
                    
                    if viewModel.isCalculating {
                        ZStack {
                            Color.black.opacity(0.5).ignoresSafeArea()
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                Text("Calculating...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
            // ZStack End
            // .navigationBarHidden(true) applied to ZStack content previously, wait.
            // Original code: NavigationStack { ZStack { ... } .navigationBarHidden(true) }
            // Now: NavigationStack { if loading { ... } else { ZStack { ... } } }
            // So we should apply modifiers to the group or handle navigation title.
        }
        .navigationBarHidden(true) // Apply to the NavigationStack content container
        .environmentObject(viewModel)
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
                    .padding(.top, 50) // Safe Area
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
            
            Text(LocalizedStringKey(viewModel.currentVerseEnglish))
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
        // Add top padding only if banner is hidden to respect safe area
        .padding(.top, (viewModel.isLocationAuthorized && viewModel.isNotificationsAuthorized) ? 50 : 0)
    }
    
    private var heroSection: some View {
        VStack(spacing: 8) {
            DateControlView(
                dateString: viewModel.currentDateString,
                hijriString: viewModel.hijriDateString,
                showCalendar: $showCalendar,
                selectedDate: $viewModel.selectedDate,
                onNext: { viewModel.goToNextDay() },
                onPrev: { viewModel.goToPreviousDay() },
                onJump: { date in viewModel.jumpToDate(date) },
                isToday: viewModel.isToday,
                onReturnToToday: { viewModel.jumpToDate(Date()) }
            )
            
            Text(viewModel.locationName)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            
            // Hero Countdown
            if viewModel.isToday {
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
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 20)
            }
        }
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
}


