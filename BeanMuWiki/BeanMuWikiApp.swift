import SwiftUI
import SwiftData

@main
struct BeanMuWikiApp: App {
    private let container: ModelContainer
    private let engine: SyncEngine

    init() {
        let inMemory = CommandLine.arguments.contains("-inMemory")
        container = try! ModelContainer(for: Bean.self, Tombstone.self, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
        engine = SyncEngine(context: container.mainContext, enabled: !inMemory)
        engine.start()
    }

    // 주의: WindowGroup/Settings 클로저 안에서 container·engine을 참조하면 macOS 26에서 창이 뜨지 않는다. 주입은 씬 수정자로만.
    var body: some Scene {
        mainWindow
        #if os(macOS)
        Settings { SettingsView() }
            .modelContainer(container)
            .environment(\.syncEngine, engine)
        #endif
    }

    private var mainWindow: some Scene {
        WindowGroup {
            TabView {
                Tab("원두", systemImage: "cup.and.saucer") { BeanListView() }
                Tab("레시피", systemImage: "timer") { RecipesView() }
            }
            .rootTabStyle()
        }
        .modelContainer(container)
        .environment(\.syncEngine, engine)
        .commands { CommandGroup(replacing: .newItem) {} }
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        #endif
    }
}
