import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct StudioView: View {
    @EnvironmentObject var app: AppState
    @ObservedObject private var rec = AudioRecorder.shared
    @State private var showImporter = false
    @State private var photoItem: PhotosPickerItem?
    @EnvironmentObject private var loc: Localizer
    private var modes: [String] { [tr("mode_simple"), tr("mode_custom"), tr("mode_photo")] }

    var body: some View {
        ScrollView {
            BrandHeader()
            VStack(spacing: 16) {
                Picker("", selection: $app.mode) {
                    ForEach(0..<modes.count, id: \.self) { Text(modes[$0]).tag($0) }
                }
                .pickerStyle(.segmented)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Brand.panel)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Brand.stroke))
                    TextEditor(text: $app.prompt)
                        .frame(minHeight: 150)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    if app.prompt.isEmpty {
                        Text(promptPlaceholder)
                            .foregroundColor(Brand.muted)
                            .padding(18)
                            .allowsHitTesting(false)
                    }
                }

                if app.mode == 1 && !app.instrumental { lyricsEditor }

                if app.mode == 2 { photoCapture }

                audioCapture

                HStack(spacing: 12) {
                    optCard("mic", tr("lbl_voice"), app.voice) { app.activeSheet = .voice }
                    optCard("music.note", tr("lbl_genre"), app.genre) { app.activeSheet = .genre }
                    optCard("theatermasks", tr("lbl_mood"), app.mood) { app.activeSheet = .mood }
                    optCard("metronome", tr("lbl_tempo"), app.tempo) { cycleTempo() }
                }

                personalizeSliders

                HStack {
                    Text(tr("instrumental")).foregroundColor(Brand.muted).fontWeight(.semibold)
                    Spacer()
                    Toggle("", isOn: $app.instrumental).labelsHidden().tint(Brand.emerald)
                }
                .padding(.horizontal, 4)

                Button { app.mintSong() } label: {
                    Label(tr("mint_song"), systemImage: "diamond.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Brand.obsidian)
                        .frame(maxWidth: .infinity).padding(18)
                        .background(Brand.gradient).clipShape(Capsule())
                }
            }
            .padding()
        }
        .sheet(item: $app.activeSheet) { PickerSheet(sheet: $0).environmentObject(app) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                rec.useUploadedFile(url)
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let dest = FileManager.default.temporaryDirectory
                        .appendingPathComponent("photo-\(UUID().uuidString).jpg")
                    try? data.write(to: dest)
                    await MainActor.run { app.photoURL = dest }
                }
            }
        }
    }

    // Custom mode: see, edit, or auto-write the exact lyrics before generating.
    private var lyricsEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tr("lyrics_caps")).font(.system(size: 12, weight: .bold)).foregroundColor(Brand.muted)
                Spacer()
                Button { app.writeLyrics() } label: {
                    HStack(spacing: 6) {
                        if app.writingLyrics { ProgressView().scaleEffect(0.7).tint(Brand.emerald) }
                        else { Image(systemName: "sparkles") }
                        Text(app.writingLyrics ? tr("writing") : tr("write_for_me"))
                    }
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Brand.emerald)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(Brand.emerald.opacity(0.12)))
                }.disabled(app.writingLyrics)
            }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16).fill(Brand.panel)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.stroke))
                TextEditor(text: $app.lyrics)
                    .frame(minHeight: 160).padding(8)
                    .scrollContentBackground(.hidden).background(Color.clear)
                if app.lyrics.isEmpty {
                    Text(tr("lyrics_ph"))
                        .foregroundColor(Brand.muted).padding(14).allowsHitTesting(false)
                }
            }
        }
    }

    // Photo mode: pick an image that becomes the song's cover and inspiration.
    private var photoCapture: some View {
        VStack(spacing: 10) {
            if let url = app.photoURL {
                ZStack(alignment: .topTrailing) {
                    Artwork(url: url)
                        .frame(height: 170).frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    Button { app.photoURL = nil; photoItem = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24)).foregroundColor(.white)
                            .background(Circle().fill(.black.opacity(0.4)))
                            .padding(8)
                    }
                }
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 22)).foregroundColor(Brand.gold)
                    Text(app.photoURL == nil ? tr("choose_photo") : tr("change_photo"))
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.stroke)))
            }
        }
    }

    private var audioCapture: some View {
        VStack(spacing: 10) {
            if rec.hasClip {
                HStack(spacing: 12) {
                    Button { rec.previewToggle() } label: {
                        Image(systemName: rec.isPreviewing ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 36)).foregroundColor(Brand.emerald)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rec.clipName.isEmpty ? tr("your_audio") : rec.clipName)
                            .font(.system(size: 15, weight: .bold)).foregroundColor(.white).lineLimit(1)
                        Text(tr("cover_ready_mint")).font(.system(size: 12)).foregroundColor(Brand.emerald)
                    }
                    Spacer()
                    Image(systemName: "waveform").foregroundColor(Brand.emerald)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Brand.emerald.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.emerald)))
            } else {
                Button { rec.toggle() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: rec.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 26)).foregroundColor(rec.isRecording ? .red : Brand.gold)
                        Text(rec.isRecording ? tr("recording") : tr("audio_input"))
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        Spacer()
                        if rec.isRecording { Circle().fill(.red).frame(width: 10, height: 10) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.stroke)))
                }
            }

            HStack(spacing: 10) {
                Button { showImporter = true } label: {
                    Label(tr("upload_audio"), systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Brand.panel)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.stroke)))
                }
                if rec.hasClip {
                    Button { rec.reset() } label: {
                        Label(tr("clear"), systemImage: "xmark")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Brand.panel)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.stroke)))
                    }
                }
            }

            if !rec.status.isEmpty {
                Text(rec.status).font(.system(size: 12)).foregroundColor(Brand.gold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // Suno-style personalization knobs.
    private var personalizeSliders: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("personalize")).font(.system(size: 12, weight: .bold)).foregroundColor(Brand.muted)
            sliderRow(tr("faithful_audio"), "waveform", $app.audioWeight,
                      low: tr("loose"), high: tr("faithful"), tint: Brand.emerald)
            sliderRow(tr("faithful_style"), "guitars", $app.styleWeight,
                      low: tr("free"), high: tr("on_genre"), tint: Brand.teal)
            sliderRow(tr("weirdness"), "sparkles", $app.weirdness,
                      low: tr("safe"), high: tr("experimental"), tint: Brand.gold)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.stroke)))
    }

    private func sliderRow(_ title: String, _ icon: String, _ value: Binding<Double>,
                           low: String, high: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(tint)
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%").font(.system(size: 13, weight: .bold)).foregroundColor(tint)
            }
            Slider(value: value, in: 0...1).tint(tint)
            HStack {
                Text(low).font(.system(size: 10)).foregroundColor(Brand.muted)
                Spacer()
                Text(high).font(.system(size: 10)).foregroundColor(Brand.muted)
            }
        }
    }

    private func optCard(_ icon: String, _ label: String, _ value: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 22))
                Text(label).font(.system(size: 11, weight: .bold)).foregroundColor(Brand.muted)
                if !value.isEmpty {
                    Text(value).font(.system(size: 10, weight: .bold)).foregroundColor(Brand.emerald).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Brand.panel)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(value.isEmpty ? Brand.stroke : Brand.emerald, lineWidth: 1)))
        }
        .foregroundColor(.white)
    }

    private var promptPlaceholder: String {
        switch app.mode {
        case 1: return tr("prompt_ph_custom")
        case 2: return tr("prompt_ph_photo")
        default: return tr("prompt_ph_simple")
        }
    }

    private func cycleTempo() {
        let i = tempoOptions.firstIndex(of: app.tempo) ?? -1
        app.tempo = tempoOptions[(i + 1) % tempoOptions.count]
    }
}

// Bottom-sheet picker for genre / mood / voice.
struct PickerSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let sheet: StudioSheet
    private let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    private var options: [(String, String)] {
        switch sheet { case .genre: return genreOptions; case .mood: return moodOptions; case .voice: return voiceOptions }
    }
    private var title: String {
        switch sheet { case .genre: return tr("pick_genre"); case .mood: return tr("pick_mood"); case .voice: return tr("pick_voice") }
    }
    private func current() -> String {
        switch sheet { case .genre: return app.genre; case .mood: return app.mood; case .voice: return app.voice }
    }

    var body: some View {
        ZStack {
            BrandBackground()
            VStack(spacing: 14) {
                Capsule().fill(Brand.stroke).frame(width: 44, height: 5).padding(.top, 10)
                Text(title).font(.system(size: 22, weight: .bold))
                ScrollView {
                    LazyVGrid(columns: cols, spacing: 18) {
                        ForEach(options, id: \.1) { opt in
                            Button {
                                switch sheet {
                                case .genre: app.genre = opt.1
                                case .mood: app.mood = opt.1
                                case .voice: app.voice = opt.1
                                }
                                dismiss()
                            } label: {
                                VStack(spacing: 8) {
                                    Text(opt.0).font(.system(size: 34))
                                        .frame(width: 84, height: 84)
                                        .background(RoundedRectangle(cornerRadius: 22).fill(Brand.panel)
                                            .overlay(RoundedRectangle(cornerRadius: 22)
                                                .stroke(current() == opt.1 ? Brand.emerald : Brand.stroke, lineWidth: current() == opt.1 ? 2 : 1)))
                                    Text(opt.1).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
