import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/repositories/community_moderation_repository.dart';
import 'widgets/community_eula_markdown.dart';

/// 커뮤니티 이용규칙 상시 열람 화면 (내정보 → 커뮤니티 이용규칙).
///
/// **Apple App Review Guideline 1.2 요건이다.** 이용규칙은 첫 글을 쓸 때의
/// 동의 시점뿐 아니라 언제든 다시 볼 수 있어야 한다. 동의 시트
/// (`CommunityEulaSheet`)와 같은 애셋·같은 렌더러를 쓴다.
///
/// 컨트롤러도 바인딩도 두지 않는다 — 애셋 한 개를 읽어 그리는 것이 전부라
/// 상태가 화면 밖으로 나갈 일이 없다.
///
/// Stitch 에 대응 화면이 없어(`list_screens` 인증 실패) `FavoritePlayersView`
/// 의 앱바 + 다크 배경 톤을 준용했다.
class CommunityTermsView extends StatefulWidget {
  const CommunityTermsView({super.key});

  @override
  State<CommunityTermsView> createState() => _CommunityTermsViewState();
}

class _CommunityTermsViewState extends State<CommunityTermsView> {
  late final Future<String> _eula;

  @override
  void initState() {
    super.initState();
    _eula = rootBundle.loadString(CommunityModerationRepository.eulaAssetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back<void>(),
        ),
        title: Text(
          '커뮤니티 이용규칙',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17.sp,
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _eula,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }
            // 애셋 누락은 배포 실수다. 빈 화면 대신 원인을 알 수 있는 문구를
            // 남긴다(동의 시트와 같은 정책).
            final raw = snapshot.data;
            if (snapshot.hasError || raw == null || raw.trim().isEmpty) {
              return _buildMessage('이용규칙을 불러오지 못했습니다.\n잠시 후 다시 시도해주세요.');
            }
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '적용 버전 ${CommunityModerationRepository.eulaVersion}',
                    style: AppTypography.labelLg.copyWith(
                      fontSize: 11.sp,
                      letterSpacing: 0.2,
                      color: AppColors.accent,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  CommunityEulaMarkdown(raw: raw),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessage(String text) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd.copyWith(
            fontSize: 14.sp,
            height: 1.5,
            color: AppColors.subtleText,
          ),
        ),
      ),
    );
  }
}
