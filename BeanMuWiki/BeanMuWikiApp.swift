import SwiftUI
import SwiftData

@main
struct BeanMuWikiApp: App {
    var body: some Scene {
        WindowGroup {
            BeanListView()
        }
        // UI 테스트는 -inMemory로 매번 빈 상태에서 시작한다.
        .modelContainer(for: Bean.self, inMemory: CommandLine.arguments.contains("-inMemory"))
    }
}
