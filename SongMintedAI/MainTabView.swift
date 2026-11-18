import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView(selection: $app.selectedTab) {
            StudioView().tabItem { Label(tr("tab_studio"), systemImage: "plus.circle.fill") }.tag(0)
            CoverView().tabItem  { Label(tr("tab_cover"), systemImage: "mic.fill") }.tag(1)
            ToolsView().tabItem  { Label(tr("tab_tools"), systemImage: "wand.and.stars") }.tag(2)
            ExploreView().tabItem { Label(tr("tab_explore"), systemImage: "safari.fill") }.tag(3)
            VaultView().tabItem  { Label(tr("tab_vault"), systemImage: "square.stack.fill") }.tag(4)
        }
        .tint(Brand.emerald)
    }
}
