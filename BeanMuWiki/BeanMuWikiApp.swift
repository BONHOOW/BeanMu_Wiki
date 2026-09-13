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
        }
        // UI 테스트는 -inMemory로 매번 빈 상태에서 시작한다.
        .modelContainer(for: Bean.self, inMemory: CommandLine.arguments.contains("-inMemory"))
    }
}
