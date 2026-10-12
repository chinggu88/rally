import ActivityKit
import SwiftUI
import WidgetKit

/// 관심 경기 Live Activity — 잠금화면 카드 + 다이나믹 아일랜드.
///
/// 속성/상태 정의는 `Shared/RallyMatchAttributes.swift`에 있다(Runner와 공유).
/// 다이나믹 아일랜드는 iPhone 14 Pro 이상에서만 표시되고, 그 외 기기는
/// 잠금화면 카드만 보인다. iOS 16.1+ 필요.
@available(iOS 16.1, *)
struct RallyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RallyMatchAttributes.self) { context in
            // 잠금화면 / 배너
            LockScreenLiveView(context: context)
                .padding(14)
                .activityBackgroundTint(RallyTheme.card)
                .activitySystemActionForegroundColor(RallyTheme.lime)
        } dynamicIsland: { context in
            DynamicIsland {
                // 확장 — 길게 눌렀을 때
                DynamicIslandExpandedRegion(.leading) {
                    TeamBlock(
                        country: context.attributes.team1Country,
                        name: context.attributes.team1,
                        nameColor: RallyTheme.lime,
                        alignment: .leading
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TeamBlock(
                        country: context.attributes.team2Country,
                        name: context.attributes.team2,
                        nameColor: .white,
                        alignment: .trailing
                    )
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        ScoreLine(
                            left: context.state.leftScore,
                            right: context.state.rightScore,
                            size: 30
                        )
                        if !context.state.setLabel.isEmpty {
                            Text(context.state.setLabel)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(RallyTheme.subtle)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 5) {
                        ForEach(context.state.prevSets, id: \.self) { set in
                            SetChip(text: set.text, won: set.won)
                        }
                        Spacer(minLength: 4)
                        Text(context.attributes.tournament)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(RallyTheme.lime)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Text(context.attributes.team1Country)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(RallyTheme.lime)
            } compactTrailing: {
                Text("\(context.state.leftScore)·\(context.state.rightScore)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
            } minimal: {
                Text("\(context.state.leftScore)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundColor(RallyTheme.lime)
            }
            .widgetURL(URL(string: "rally://widget/favorite"))
            .keylineTint(RallyTheme.lime)
        }
    }
}

// MARK: - 잠금화면

@available(iOS 16.1, *)
private struct LockScreenLiveView: View {
    let context: ActivityViewContext<RallyMatchAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if !context.state.isFinished {
                    Circle().fill(RallyTheme.lime).frame(width: 6, height: 6)
                }
                Text(context.attributes.tournament)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(RallyTheme.lime)
                    .lineLimit(1)
            }

            if !context.state.meta.isEmpty {
                Text(context.state.meta)
                    .font(.system(size: 9))
                    .foregroundColor(RallyTheme.subtle)
                    .lineLimit(1)
            }

            HStack(alignment: .center, spacing: 6) {
                TeamBlock(
                    country: context.attributes.team1Country,
                    name: context.attributes.team1,
                    nameColor: RallyTheme.lime,
                    alignment: .leading
                )

                VStack(spacing: 0) {
                    ScoreLine(
                        left: context.state.leftScore,
                        right: context.state.rightScore,
                        size: 32
                    )
                    if !context.state.setLabel.isEmpty {
                        Text(context.state.setLabel)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(RallyTheme.subtle)
                    }
                }
                .fixedSize()

                TeamBlock(
                    country: context.attributes.team2Country,
                    name: context.attributes.team2,
                    nameColor: .white,
                    alignment: .trailing
                )
            }

            if !context.state.prevSets.isEmpty {
                HStack(spacing: 5) {
                    ForEach(context.state.prevSets, id: \.self) { set in
                        SetChip(text: set.text, won: set.won)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - 공용 조각

@available(iOS 16.1, *)
private struct ScoreLine: View {
    let left: Int
    let right: Int
    let size: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Text("\(left)")
            Text("·").foregroundColor(RallyTheme.subtle)
            Text("\(right)")
        }
        .font(.system(size: size, weight: .heavy, design: .rounded).monospacedDigit())
        .foregroundColor(.white)
    }
}

@available(iOS 16.1, *)
private struct TeamBlock: View {
    let country: String
    let name: String
    let nameColor: Color
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(country)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(nameColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(
            maxWidth: .infinity,
            alignment: alignment == .leading ? .leading : .trailing
        )
    }
}

@available(iOS 16.1, *)
private struct SetChip: View {
    let text: String
    let won: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold).monospacedDigit())
            .foregroundColor(won ? RallyTheme.lime : RallyTheme.subtle)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        won ? RallyTheme.lime : Color.white.opacity(0.18),
                        lineWidth: 1
                    )
            )
    }
}
