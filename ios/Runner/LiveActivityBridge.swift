import ActivityKit
import Flutter
import Foundation

/// Flutter ↔ ActivityKit 브리지.
///
/// Dart(`LiveActivityService`)가 관심 경기를 지정/해제할 때 Live Activity를
/// 시작·종료하고, ActivityKit이 발급한 **per-activity push token**을 Dart로
/// 돌려준다. 이 토큰이 있어야 서버가 APNs로 스코어를 갱신할 수 있다.
///
/// 토큰은 활동마다 다르고 수명 중에도 회전하므로 `pushTokenUpdates`를 계속
/// 구독해 바뀔 때마다 Dart로 올려보낸다.
@available(iOS 16.1, *)
final class LiveActivityBridge {
    static let channelName = "rally/live_activity"

    private let channel: FlutterMethodChannel
    private var tokenTasks: [String: Task<Void, Never>] = [:]

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(ActivityAuthorizationInfo().areActivitiesEnabled)

        case "start":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "bad_args", message: "arguments missing", details: nil))
                return
            }
            start(args, result)

        case "update":
            guard let args = call.arguments as? [String: Any],
                  let matchCode = args["matchCode"] as? String else {
                result(FlutterError(code: "bad_args", message: "matchCode missing", details: nil))
                return
            }
            update(matchCode: matchCode, args: args, result: result)

        case "end":
            let matchCode = (call.arguments as? [String: Any])?["matchCode"] as? String
            end(matchCode: matchCode, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - 시작

    private func start(_ args: [String: Any], _ result: @escaping FlutterResult) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            result(FlutterError(code: "disabled",
                                message: "Live Activities are disabled in Settings",
                                details: nil))
            return
        }
        guard let matchCode = args["matchCode"] as? String else {
            result(FlutterError(code: "bad_args", message: "matchCode missing", details: nil))
            return
        }

        // 같은 경기의 기존 활동이 있으면 중복 생성하지 않는다.
        if Activity<RallyMatchAttributes>.activities
            .contains(where: { $0.attributes.matchCode == matchCode }) {
            result(nil)
            return
        }

        let attributes = RallyMatchAttributes(
            matchCode: matchCode,
            tournament: args["tournament"] as? String ?? "",
            team1: args["team1"] as? String ?? "TBD",
            team1Country: args["team1Country"] as? String ?? "",
            team2: args["team2"] as? String ?? "TBD",
            team2Country: args["team2Country"] as? String ?? ""
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: Self.contentState(from: args),
                pushType: .token
            )
            observeToken(activity)
            result(nil)
        } catch {
            result(FlutterError(code: "start_failed",
                                message: error.localizedDescription,
                                details: nil))
        }
    }

    /// 활동의 push token을 구독해 Dart로 올려보낸다(회전 포함).
    private func observeToken(_ activity: Activity<RallyMatchAttributes>) {
        let matchCode = activity.attributes.matchCode
        tokenTasks[matchCode]?.cancel()
        tokenTasks[matchCode] = Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                let hex = tokenData.map { String(format: "%02x", $0) }.joined()
                await MainActor.run {
                    self?.channel.invokeMethod("onPushToken", arguments: [
                        "matchCode": matchCode,
                        "token": hex,
                    ])
                }
            }
        }
    }

    // MARK: - 갱신 / 종료

    /// 포그라운드에서 Realtime으로 받은 스코어를 즉시 반영한다(푸시 없이).
    private func update(matchCode: String, args: [String: Any], result: @escaping FlutterResult) {
        guard let activity = Activity<RallyMatchAttributes>.activities
            .first(where: { $0.attributes.matchCode == matchCode }) else {
            result(nil)
            return
        }
        let state = Self.contentState(from: args)
        Task {
            await activity.update(using: state)
            await MainActor.run { result(nil) }
        }
    }

    /// matchCode가 nil이면 모든 활동을 종료한다(로그아웃 등).
    private func end(matchCode: String?, result: @escaping FlutterResult) {
        let targets = Activity<RallyMatchAttributes>.activities.filter {
            matchCode == nil || $0.attributes.matchCode == matchCode
        }
        for code in targets.map({ $0.attributes.matchCode }) {
            tokenTasks[code]?.cancel()
            tokenTasks[code] = nil
        }
        Task {
            for activity in targets {
                await activity.end(dismissalPolicy: .immediate)
            }
            await MainActor.run { result(nil) }
        }
    }

    // MARK: - 매핑

    /// Dart가 보낸 맵을 ContentState로 변환한다.
    /// 키는 `FavoriteMatchResponse.toWidgetJson()`과 같은 이름을 쓴다.
    private static func contentState(from args: [String: Any]) -> RallyMatchAttributes.ContentState {
        let prev = (args["prevSets"] as? [[String: Any]] ?? []).map {
            RallyMatchAttributes.ContentState.PrevSet(
                text: $0["text"] as? String ?? "",
                won: $0["won"] as? Bool ?? false
            )
        }
        return RallyMatchAttributes.ContentState(
            current: args["current"] as? [Int] ?? [0, 0],
            setLabel: args["setLabel"] as? String ?? "",
            prevSets: prev,
            meta: args["meta"] as? String ?? "",
            isFinished: args["isFinished"] as? Bool ?? false
        )
    }
}
