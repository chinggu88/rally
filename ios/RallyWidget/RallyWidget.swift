import SwiftUI
import WidgetKit

// MARK: - 디자인 토큰

enum RallyTheme {
    /// 액센트 라임 #C3F400 — Flutter `AppColors.accent`와 동일.
    static let lime = Color(red: 0.765, green: 0.957, blue: 0.0)
    static let card = Color(red: 0.055, green: 0.055, blue: 0.055) // #0E0E0E
    static let subtle = Color(red: 0.612, green: 0.639, blue: 0.631) // #9CA3A1
}

// MARK: - Timeline

struct RallyEntry: TimelineEntry {
    let date: Date
    let match: MatchSnapshot?
}

struct RallyProvider: TimelineProvider {
    func placeholder(in context: Context) -> RallyEntry {
        RallyEntry(date: Date(), match: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (RallyEntry) -> Void) {
        completion(RallyEntry(date: Date(), match: MatchSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RallyEntry>) -> Void) {
        let match = MatchSnapshot.load()
        let entry = RallyEntry(date: Date(), match: match)

        // 실질 갱신은 앱이 HomeWidget.updateWidget()으로 푸시한다.
        // 여기서는 앱이 죽어 있을 때를 위한 폴백 주기만 잡는다.
        let interval: TimeInterval = (match?.isLive == true) ? 60 : 1800
        let next = Date().addingTimeInterval(interval)

        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget

struct RallyWidget: Widget {
    /// Dart의 `FavoriteMatchService._iOSWidgetName`과 동일해야 한다.
    let kind = "RallyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RallyProvider()) { entry in
            RallyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Rally 관심 경기")
        .description("지정한 관심 경기의 스코어를 홈 화면에서 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct RallyWidgetBundle: WidgetBundle {
    var body: some Widget {
        RallyWidget()
        // Live Activity(잠금화면 + 다이나믹 아일랜드)는 iOS 16.1+에서만 등록한다.
        if #available(iOS 16.1, *) {
            RallyLiveActivity()
        }
    }
}
