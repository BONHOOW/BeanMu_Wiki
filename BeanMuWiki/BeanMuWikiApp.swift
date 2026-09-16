import SwiftUI
import SwiftData

@main
struct BeanMuWikiApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("원두", systemImage: "cup.and.saucer") { BeanListView() }
                Tab("레시피", systemImage: "timer") { RecipesView() }
            }
            #if os(iOS)
            .tabViewStyle(.sidebarAdaptable)
            #else
            .frame(minWidth: 900, minHeight: 600)   // macOS: 기본 탭 스타일. 탭 안 NavigationSplitView가 좌 목록 / 우 상세
            #endif
        }
        // Tombstone은 Bean과 관계가 없어 스키마에 명시해야 한다. UI 테스트는 -inMemory로 매번 빈 상태에서 시작.
        .modelContainer(for: [Bean.self, Tombstone.self], inMemory: CommandLine.arguments.contains("-inMemory"))
        .commands { CommandGroup(replacing: .newItem) {} }   // ⌘N을 목록의 '추가' 버튼에 양보
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        #endif
    }
}
