import SwiftUI
import SwiftData

@main
struct CourtLogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Session.self)
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("首页", systemImage: "tennisball.fill") }
            SessionListView()
                .tabItem { Label("记录", systemImage: "list.bullet") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Session.self, inMemory: true)
}
