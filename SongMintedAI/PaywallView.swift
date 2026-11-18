import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var app: AppState
    @State private var plan = 1

    private let plans = [("Weekly", "€5.99", ""),
                         ("Yearly", "€49.99", "84% OFF"),
                         ("Lifetime", "€79.99", "")]

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { app.screen = .main } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white).padding(10)
                        .background(.white.opacity(0.08)).clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal)

            Image(systemName: "diamond.fill")
                .font(.system(size: 54))
                .foregroundStyle(Brand.gradientGold)

            Text(tr("pro_title")).font(.system(size: 28, weight: .bold))
            Text(tr("pro_sub"))
                .font(.system(size: 15)).foregroundColor(Brand.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 30)

            VStack(alignment: .leading, spacing: 12) {
                featRow("Unlimited song minting")
                featRow("30+ premium AI voices")
                featRow("HD downloads & commercial license")
            }
            .padding(.vertical, 8)

            HStack(spacing: 12) {
                ForEach(Array(plans.enumerated()), id: \.offset) { i, p in
                    Button { plan = i } label: {
                        VStack(spacing: 6) {
                            Text(p.0).font(.system(size: 15, weight: .bold))
                            Text(p.1).font(.system(size: 16, weight: .bold))
                            if !p.2.isEmpty {
                                Text(p.2).font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Brand.obsidian)
                                    .padding(4).background(Brand.gold).clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16)
                            .stroke(plan == i ? Brand.emerald : Brand.stroke, lineWidth: 1.5))
                    }
                    .foregroundColor(.white)
                }
            }
            .padding(.horizontal)

            Button { app.screen = .main } label: {
                Text(tr("continue"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Brand.obsidian)
                    .frame(maxWidth: .infinity).padding(18)
                    .background(Brand.gradientGold).clipShape(Capsule())
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 20)
    }

    private func featRow(_ t: String) -> some View {
        HStack {
            Image(systemName: "checkmark").foregroundColor(Brand.emerald).fontWeight(.bold)
            Text(t).foregroundColor(.white)
        }
    }
}
