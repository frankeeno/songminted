import SwiftUI

@main
struct SongMintedAIApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(Localizer.shared)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var loc: Localizer

    var body: some View {
        ZStack {
            BrandBackground()

            switch app.screen {
            case .language:   LanguagePickerView()
            case .onboarding: OnboardingView()
            case .paywall:    PaywallView()
            case .main:       MainTabView()
            }
        }
        .fullScreenCover(isPresented: $app.showPlayer) { PlayerView() }
        .overlay {
            if app.isGenerating { GeneratingView() }
        }
        .overlay(alignment: .bottom) {
            if let t = app.toast {
                Text(t)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Capsule().fill(Brand.panel2).overlay(Capsule().stroke(Brand.stroke)))
                    .padding(.bottom, 44)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.toast)
        .sheet(isPresented: $app.showSettings) {
            SettingsView().environmentObject(app).environmentObject(loc)
        }
    }
}

// MARK: - Shared header

struct BrandHeader: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "diamond.fill")
                    .foregroundStyle(Brand.gradientGold)
                (Text("Song").font(.system(size: 20, weight: .bold))
                 + Text("Minted").font(.system(size: 20, weight: .bold)).foregroundColor(Brand.emerald))
            }
            Spacer()
            HStack(spacing: 8) {
                Label("\(app.coins)", systemImage: "circlebadge.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Brand.gold)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Brand.emerald.opacity(0.1))
                    .clipShape(Capsule())
                Button { app.screen = .paywall } label: {
                    Text("PRO")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Brand.obsidian)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Brand.gradientGold)
                        .clipShape(Capsule())
                }
                Button { app.showSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 18)).foregroundColor(Brand.muted)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
