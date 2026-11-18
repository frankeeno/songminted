import SwiftUI

// First screen a new user sees: pick a language → the whole app switches to it.
struct LanguagePickerView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var loc: Localizer

    private let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "globe")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(Brand.gradient)
            Text(tr("choose_language"))
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
            Text(tr("lang_sub"))
                .font(.system(size: 15))
                .foregroundColor(Brand.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(appLanguages, id: \.code) { l in
                    Button { loc.set(l.code) } label: {
                        HStack(spacing: 10) {
                            Text(l.flag).font(.system(size: 24))
                            Text(l.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                            Spacer()
                            if loc.lang == l.code {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(Brand.emerald)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel)
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(loc.lang == l.code ? Brand.emerald : Brand.stroke, lineWidth: 1.5)))
                    }
                }
            }
            .padding(.horizontal, 22).padding(.top, 6)

            Spacer()
            Button { app.screen = .onboarding } label: {
                Text(tr("continue"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Brand.obsidian)
                    .frame(maxWidth: .infinity).padding(18)
                    .background(Brand.gradient).clipShape(Capsule())
            }
            .padding(.horizontal, 24).padding(.bottom, 20)
        }
    }
}
