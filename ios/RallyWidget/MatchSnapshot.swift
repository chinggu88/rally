import Foundation

/// 관심 경기 스냅샷 — Flutter가 App Group UserDefaults에 기록한 JSON을 디코딩한다.
///
/// 스키마의 유일한 원본은 Dart의 `FavoriteMatchResponse.toWidgetJson()`이다.
/// **스키마를 바꾸면 Dart / Swift / Kotlin 세 곳을 함께 고쳐야 한다.**
struct MatchSnapshot: Decodable {
    let tournament: String
    let meta: String
    let team1: String
    let team1Country: String
    let team2: String
    let team2Country: String
    let current: [Int]
    let setLabel: String
    let prevSets: [PrevSet]
    let isLive: Bool
    let timeKst: String

    struct PrevSet: Decodable, Hashable {
        let text: String
        let won: Bool
    }

    /// 현재(또는 최종) 세트의 좌/우 점수.
    var leftScore: Int { current.first ?? 0 }
    var rightScore: Int { current.count > 1 ? current[1] : 0 }

    /// App Group ID — Runner/Extension entitlements 및 Dart의
    /// `FavoriteMatchService.appGroupId`와 **반드시 동일**해야 한다.
    /// (오타 시 에러 없이 조용히 빈 위젯이 된다.)
    static let appGroupId = "group.com.iksun.rallys"

    /// Dart의 `FavoriteMatchService._widgetDataKey`와 동일해야 한다.
    static let dataKey = "rally_match"

    /// 관심 경기가 없으면 nil을 돌려준다.
    static func load() -> MatchSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let raw = defaults.string(forKey: dataKey),
            !raw.isEmpty,
            raw != "null",
            let data = raw.data(using: .utf8)
        else { return nil }

        return try? JSONDecoder().decode(MatchSnapshot.self, from: data)
    }
}
