import SwiftUI
import WidgetKit

/// 관심 경기 위젯 루트 뷰.
///
/// small = 컴팩트("KOR 18 · 14 JPN"), medium = 확장 레이아웃.
/// 관심 경기가 없으면 안내 문구를 표시한다.
struct RallyWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RallyEntry

    var body: some View {
        content
            .widgetURL(URL(string: "rally://widget/favorite"))
            .rallyContainerBackground(RallyTheme.card)
    }

    @ViewBuilder
    private var content: some View {
        if let match = entry.match {
            if family == .systemSmall {
                CompactMatchView(match: match)
            } else {
                ExpandedMatchView(match: match, date: entry.date)
            }
        } else {
            EmptyStateView(isSmall: family == .systemSmall)
        }
    }
}

// MARK: - 확장 (medium)

private struct ExpandedMatchView: View {
    let match: MatchSnapshot
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // 대회명
            HStack(spacing: 5) {
                if match.isLive {
                    Circle()
                        .fill(RallyTheme.lime)
                        .frame(width: 6, height: 6)
                }
                Text(match.tournament)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(RallyTheme.lime)
                    .lineLimit(1)
            }

            if !match.meta.isEmpty {
                Text(match.meta)
                    .font(.system(size: 9))
                    .foregroundColor(RallyTheme.subtle)
                    .lineLimit(1)
            }

            // 스코어
            HStack(alignment: .center, spacing: 6) {
                TeamColumn(
                    country: match.team1Country,
                    name: match.team1,
                    nameColor: RallyTheme.lime,
                    alignment: .leading
                )

                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Text("\(match.leftScore)")
                        Text("·").foregroundColor(RallyTheme.subtle)
                        Text("\(match.rightScore)")
                    }
                    .font(.system(size: 32, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)

                    if !match.setLabel.isEmpty {
                        Text(match.setLabel)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(RallyTheme.subtle)
                    }
                }
                .fixedSize()

                TeamColumn(
                    country: match.team2Country,
                    name: match.team2,
                    nameColor: .white,
                    alignment: .trailing
                )
            }

            // 이전 세트 칩 + 갱신 시각
            HStack(spacing: 5) {
                ForEach(match.prevSets, id: \.self) { set in
                    Text(set.text)
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .foregroundColor(set.won ? RallyTheme.lime : RallyTheme.subtle)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    set.won ? RallyTheme.lime : Color.white.opacity(0.18),
                                    lineWidth: 1
                                )
                        )
                }

                Spacer(minLength: 4)

                // 고정 문구("방금 갱신")는 시간이 지나면 거짓이 되므로 상대 시간을 쓴다.
                Text(date, style: .relative)
                    .font(.system(size: 8))
                    .foregroundColor(RallyTheme.subtle)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct TeamColumn: View {
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

// MARK: - 컴팩트 (small)

private struct CompactMatchView: View {
    let match: MatchSnapshot

    var body: some View {
        VStack(spacing: 6) {
            if match.isLive {
                Circle()
                    .fill(RallyTheme.lime)
                    .frame(width: 5, height: 5)
            }

            HStack(spacing: 5) {
                Text(match.team1Country)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(RallyTheme.subtle)

                HStack(spacing: 4) {
                    Text("\(match.leftScore)")
                    Text("·").foregroundColor(RallyTheme.subtle)
                    Text("\(match.rightScore)")
                }
                .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundColor(.white)

                Text(match.team2Country)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(RallyTheme.subtle)
            }
            .minimumScaleFactor(0.7)
            .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 빈 상태

private struct EmptyStateView: View {
    let isSmall: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "star")
                .font(.system(size: isSmall ? 20 : 22, weight: .semibold))
                .foregroundColor(RallyTheme.lime)

            Text("관심 경기를 지정하세요")
                .font(.system(size: isSmall ? 10 : 12, weight: .semibold))
                .foregroundColor(RallyTheme.subtle)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 호환 헬퍼

private extension View {
    /// iOS 17+는 `containerBackground`를 요구하고, 그 이하는 무시해야 한다.
    @ViewBuilder
    func rallyContainerBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(color, for: .widget)
        } else {
            self.background(color)
        }
    }
}
