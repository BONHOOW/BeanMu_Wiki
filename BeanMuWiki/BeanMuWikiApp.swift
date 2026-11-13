import SwiftUI
import SwiftData

@main
struct BeanMuWikiApp: App {
    private let container: ModelContainer
    private let engine: SyncEngine
    #if DEBUG
    @State private var tab = debugArg("-debugTab") ?? "beans"   // `-debugTab recipes`
    #else
    @State private var tab = "beans"
    #endif

    init() {
        let inMemory = CommandLine.arguments.contains("-inMemory")
        container = try! ModelContainer(for: Bean.self, Tombstone.self, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
        engine = SyncEngine(context: container.mainContext, enabled: !inMemory)
        #if DEBUG
        // `-inMemory` + 환경 변수 BEANMUWIKI_BACKUP(백업 JSON 본문): 실제 저장소·동기화를 건드리지 않고 화면을 채운다 (스크린샷용).
        // 파일 경로 대신 본문을 받는 이유: Mac 앱은 샌드박스라 임의 경로를 못 읽는다
        if inMemory, let json = ProcessInfo.processInfo.environment["BEANMUWIKI_BACKUP"] {
            _ = try? Snapshot.decode(Data(json.utf8)).merge(into: container.mainContext)
        }
        #endif
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
            #if os(macOS)
            MacRootView().rootStyle()
            #else
            TabView(selection: $tab) {
                Tab("원두", systemImage: "cup.and.saucer", value: "beans") { BeanListView() }
                Tab("레시피", systemImage: "timer", value: "recipes") { RecipesView() }
            }
            .rootStyle()
            #endif
        }
        .modelContainer(container)
        .environment(\.syncEngine, engine)
        .commands {
            CommandGroup(replacing: .newItem) {}   // ⌘N은 '추가' 버튼이 가진다
            SidebarCommands()
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 760)
        #endif
    }
}
