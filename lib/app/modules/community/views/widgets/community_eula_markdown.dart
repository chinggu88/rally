import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';

/// 이용규칙 원문(`assets/docs/community_eula.md`)의 가벼운 렌더링.
///
/// 마크다운 패키지를 의존성에 추가하지 않는다 — 두 화면(온보딩 시트의 동의
/// 박스, 내정보의 상시 열람 화면)을 위해 렌더러를 들이기에는 과하다.
/// `##` 제목 / `-` 목록 / `**강조**` 세 가지만 처리하고 나머지는 본문으로
/// 그린다.
///
/// 원래 `CommunityEulaSheet` 안에 있던 렌더링을 위젯으로 꺼낸 것이다.
/// Apple 요구사항상 이용규칙은 동의 시점 외에 **상시 열람**도 가능해야 해서
/// 같은 렌더링을 두 곳에서 쓰게 됐다.
class CommunityEulaMarkdown extends StatelessWidget {
  const CommunityEulaMarkdown({super.key, required this.raw});

  /// 마크다운 원문
  final String raw;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildLines(raw),
    );
  }

  List<Widget> _buildLines(String raw) {
    final widgets = <Widget>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(SizedBox(height: 8.h));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 6.h, bottom: 4.h),
            child: Text(
              trimmed.substring(3),
              style: AppTypography.labelLg.copyWith(
                fontSize: 13.sp,
                color: Colors.white,
              ),
            ),
          ),
        );
        continue;
      }
      if (trimmed.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: 6.w, bottom: 3.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '· ',
                  style: AppTypography.bodyMd.copyWith(
                    fontSize: 12.sp,
                    color: AppColors.subtleText,
                  ),
                ),
                Expanded(child: _body(trimmed.substring(2))),
              ],
            ),
          ),
        );
        continue;
      }
      widgets.add(
        Padding(padding: EdgeInsets.only(bottom: 3.h), child: _body(trimmed)),
      );
    }
    return widgets;
  }

  /// `**강조**` 구간만 흰색 볼드로 바꾼 본문 한 줄.
  Widget _body(String text) {
    final base = AppTypography.bodyMd.copyWith(
      fontSize: 12.sp,
      height: 1.6,
      color: AppColors.subtleText,
    );
    final segments = text.split('**');
    if (segments.length < 3) {
      return Text(text, style: base);
    }
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < segments.length; i++)
            TextSpan(
              text: segments[i],
              // 홀수 인덱스가 `**` 사이에 낀 강조 구간이다.
              style:
                  i.isOdd
                      ? base.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      )
                      : base,
            ),
        ],
      ),
    );
  }
}
