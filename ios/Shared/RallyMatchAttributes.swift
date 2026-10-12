import ActivityKit
import Foundation

/// Live Activity 속성 — **Runner 타겟과 위젯 타겟이 공유한다.**
///
/// Runner는 Activity를 시작/갱신하고, 위젯 익스텐션은 이를 렌더링하므로
/// 양쪽 타겟 모두에 이 파일이 포함되어야 한다.
///
/// ContentState는 APNs 푸시로 갱신되므로 서버 payload의 `content-state` 키와
/// 1:1로 일치해야 한다. 스키마 변경 시 Edge Function(`send-live-activity`)도
/// 함께 고친다.

@available(iOS 16.1, *)
struct RallyMatchAttributes: ActivityAttributes {
    /// 경기 중 바뀌지 않는 값 (Activity 시작 시 고정).
    let matchCode: String
    let tournament: String
    let team1: String
    let team1Country: String
    let team2: String
    let team2Country: String

    /// 푸시로 갱신되는 값.
    struct ContentState: Codable, Hashable {
        /// 현재(또는 최종) 세트 점수 [team1, team2].
        var current: [Int]
        /// "3세트" 등. 비어있을 수 있다.
        var setLabel: String
        /// 이전 세트 칩.
        var prevSets: [PrevSet]
        /// 코트 · 라운드 · 종목.
        var meta: String
        /// 경기 종료 여부 — true면 잠금화면에 최종 스코어로 남는다.
        var isFinished: Bool

        struct PrevSet: Codable, Hashable {
            var text: String
            var won: Bool
        }

        var leftScore: Int { current.first ?? 0 }
        var rightScore: Int { current.count > 1 ? current[1] : 0 }
    }
}
