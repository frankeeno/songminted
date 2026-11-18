import SwiftUI

struct OnboardingSlide: Identifiable {
    let id = UUID()
    let title: String
    let highlight: String
    let subtitle: String
    let symbol: String
}

struct OnboardingView: View {
    @EnvironmentObject var app: AppState
    @State private var page = 0

    private var slides: [OnboardingSlide] {[
        OnboardingSlide(title: tr("ob1_pre"), highlight: tr("ob1_hl"), subtitle: tr("ob1_sub"), symbol: "diamond.fill"),
        OnboardingSlide(title: tr("ob2_pre"), highlight: tr("ob2_hl"), subtitle: tr("ob2_sub"), symbol: "waveform"),
        OnboardingSlide(title: tr("ob3_pre"), highlight: tr("ob3_hl"), subtitle: tr("ob3_sub"), symbol: "mic.fill"),
        OnboardingSlide(title: tr("ob4_pre"), highlight: tr("ob4_hl"), subtitle: tr("ob4_sub"), symbol: "chart.line.uptrend.xyaxis")
    ]}

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.offset) { idx, s in
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: s.symbol)
                            .font(.system(size: 88, weight: .bold))
                            .foregroundStyle(Brand.gradient)
                        VStack(spacing: 6) {
                            Text(s.title).font(.system(size: 32, weight: .bold))
                            Text(s.highlight).font(.system(size: 40, weight: .bold))
                                .foregroundStyle(Brand.gradientGold)
                        }
                        Text(s.subtitle)
                            .font(.system(size: 18))
                            .foregroundColor(Brand.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 34)
                        Spacer()
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(action: next) {
                Text(page < slides.count - 1 ? tr("continue") : tr("get_started"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Brand.obsidian)
                    .frame(maxWidth: .infinity).padding(18)
                    .background(Brand.gradient)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    private func next() {
        if page < slides.count - 1 {
            withAnimation { page += 1 }
        } else {
            app.screen = .paywall
        }
    }
}
