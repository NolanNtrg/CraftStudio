import SwiftUI

@main
struct CraftStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1020, minHeight: 690)
        }
        .defaultSize(width: 1020, height: 690)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}
