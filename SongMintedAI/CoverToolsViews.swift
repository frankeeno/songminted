import SwiftUI

// MARK: - Cover

struct CoverView: View {
    @EnvironmentObject var app: AppState
    @State private var picker: StudioSheet?

    var body: some View {
        ScrollView {
            BrandHeader()
            VStack(alignment: .leading, spacing: 18) {
                Text("Cover Studio").font(.system(size: 24, weight: .bold))
                Text("Reimagine any song in a new voice and style.")
                    .font(.system(size: 14)).foregroundColor(Brand.muted)

                TextField("Search or paste a song link, or describe it…", text: $app.prompt)
                    .foregroundColor(.white).padding()
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.stroke)))

                header("Voice")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(voiceOptions, id: \.1) { opt in voiceTile(opt.0, opt.1) }
                    myVoiceTile()
                }

                header("Style")
                HStack(spacing: 10) {
                    Button { picker = .genre } label: { pillLabel(app.genre.isEmpty ? "Genre" : app.genre, "guitars") }
                    Button { picker = .mood } label: { pillLabel(app.mood.isEmpty ? "Mood" : app.mood, "sparkles") }
                }
                Toggle(isOn: $app.instrumental) {
                    Text("Instrumental (no vocals)").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                }.tint(Brand.emerald)

                header("Fine-tune")
                slider("Follow the original", $app.audioWeight)
                slider("Stick to the style", $app.styleWeight)
                slider("Experimental", $app.weirdness)

                Button { app.mintSong() } label: {
                    Label("MINT COVER", systemImage: "diamond.fill")
                        .font(.system(size: 18, weight: .bold)).foregroundColor(Brand.obsidian)
                        .frame(maxWidth: .infinity).padding(18)
                        .background(Brand.gradientGold).clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .padding()
        }
        .sheet(item: $picker) { PickerSheet(sheet: $0).environmentObject(app) }
    }

    private func header(_ t: String) -> some View {
        Text(t.uppercased()).font(.system(size: 12, weight: .bold))
            .foregroundColor(Brand.muted).tracking(1)
    }

    private func voiceTile(_ emoji: String, _ name: String) -> some View {
        let on = app.voice == name
        return Button { app.voice = name } label: {
            VStack(spacing: 6) {
                Text(emoji).font(.system(size: 24))
                Text(name).font(.system(size: 12, weight: .semibold)).foregroundColor(.white).lineLimit(1)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(on ? Brand.emerald.opacity(0.18) : Brand.panel)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? Brand.emerald : Brand.stroke)))
        }
    }

    private func myVoiceTile() -> some View {
        let on = app.voice == "My Voice"
        return Button {
            if app.hasClonedVoice { app.voice = "My Voice" }
            else { app.showToast("Record your voice first to use it here") }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "mic.circle.fill").font(.system(size: 24)).foregroundColor(Brand.gold)
                Text("My Voice").font(.system(size: 12, weight: .semibold)).foregroundColor(.white).lineLimit(1)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(on ? Brand.gold.opacity(0.18) : Brand.panel)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? Brand.gold : Brand.stroke)))
        }
    }

    private func pillLabel(_ t: String, _ icon: String) -> some View {
        HStack(spacing: 6) { Image(systemName: icon); Text(t).lineLimit(1) }
            .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Brand.panel)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.stroke)))
    }

    private func slider(_ label: String, _ value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 13)).foregroundColor(Brand.muted)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundColor(Brand.emerald)
            }
            Slider(value: value, in: 0...1).tint(Brand.emerald)
        }
    }
}

// MARK: - Tools

struct ToolsView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        ScrollView {
            BrandHeader()
            VStack(alignment: .leading, spacing: 14) {
                Text("Templates").font(.system(size: 24, weight: .bold))
                HStack(spacing: 14) {
                    tool("pianokeys", "Instrumental") { app.applyTemplate(genre: "Lo-Fi", mood: "Chill", prompt: "A smooth instrumental beat", instrumental: true) }
                    tool("person.2.fill", "Duet Styles") { app.applyTemplate(genre: "Pop", mood: "Romantic", prompt: "A male and female duet love song") }
                }
                Text("Studio Packs").font(.system(size: 24, weight: .bold))
                HStack(spacing: 14) {
                    tool("gift.fill", "Birthday Anthem") { app.applyTemplate(genre: "Pop", mood: "Fun", prompt: "An upbeat, joyful happy-birthday anthem") }
                    tool("heart.fill", "Wedding Ballad") { app.applyTemplate(genre: "Pop", mood: "Romantic", prompt: "A heartfelt wedding ballad") }
                }
                Text("AI Remix").font(.system(size: 24, weight: .bold))
                HStack(spacing: 14) {
                    tool("arrow.triangle.2.circlepath", "Genre Swap") { app.applyTemplate(genre: "EDM", mood: "Energetic", prompt: "Reimagine my idea in a brand-new genre") }
                    tool("timer", "Tempo Shift") { app.applyTemplate(genre: "Hip-Hop", mood: "Chill", prompt: "Same vibe, different tempo") }
                }
            }
            .padding()
        }
    }

    private func tool(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 28))
                Text(label).font(.system(size: 17, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(RoundedRectangle(cornerRadius: 20).fill(Brand.panel)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Brand.stroke)))
        }
        .foregroundColor(.white)
    }
}
