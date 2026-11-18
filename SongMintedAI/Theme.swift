import SwiftUI

// MARK: - Brand color system (matches the Liquid Glass brand kit)

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum Brand {
    static let emerald  = Color(hex: "34D399")
    static let teal     = Color(hex: "12B3A6")
    static let gold     = Color(hex: "F5C451")
    static let obsidian = Color(hex: "05070A")
    static let panel    = Color(hex: "0D1117")
    static let panel2   = Color(hex: "131A22")
    static let stroke   = Color(hex: "212C38")
    static let muted    = Color(hex: "7D8C99")
    static let text     = Color(hex: "F2F6F8")

    static let gradient = LinearGradient(
        colors: [Color(hex: "3EE0A6"), Color(hex: "0EA5A4")],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let gradientGold = LinearGradient(
        colors: [Color(hex: "F9DD8A"), Color(hex: "E0A83A")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

// Ambient app background — obsidian with soft emerald/gold glows.
struct BrandBackground: View {
    var body: some View {
        ZStack {
            Brand.obsidian
            RadialGradient(colors: [Brand.emerald.opacity(0.18), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [Brand.gold.opacity(0.12), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [Brand.teal.opacity(0.10), .clear],
                           center: .center, startRadius: 0, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

// Cover art: shows a local file image, a remote image, else a brand gradient.
struct Artwork: View {
    let url: URL?
    var gradient: LinearGradient = Brand.gradient
    var body: some View {
        if let url = url, url.isFileURL, let ui = UIImage(contentsOfFile: url.path) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else if let url = url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: placeholder
                }
            }
        } else {
            placeholder
        }
    }

    // Branded "logo cover" shown until the generated art loads.
    private var placeholder: some View {
        ZStack {
            Rectangle().fill(gradient)
            GeometryReader { geo in
                Image(systemName: "diamond.fill")
                    .resizable().scaledToFit()
                    .frame(width: geo.size.width * 0.38, height: geo.size.height * 0.38)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
