import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/community_post_response.dart';
import '../controllers/community_controller.dart';
import 'widgets/community_category_chips.dart';
import 'widgets/community_post_card.dart';

/// 커뮤니티 목록 화면 — 카테고리 칩 + 최신순 게시글 무한 스크롤.
///
/// Stitch에 대응 화면이 없어 `PlayerView`(선수 리스트 매거진)의 카드 리스트
/// 레이아웃을 기준으로 구성했다.
class CommunityView extends StatefulWidget {
  const CommunityView({super.key});

  @override
  State<CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends State<CommunityView> {
  CommunityController get controller => CommunityController.to;

  final ScrollController _scroll = ScrollController();

  /// 무한 스크롤 트리거 임계값 — 바닥에서 이만큼 떨어진 지점부터 loadMore 시작
  static const double _loadMoreThreshold = 300.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - _loadMoreThreshold) {
      controller.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _buildAppBar(scheme),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.openCompose,
        tooltip: '글쓰기',
        child: const Icon(Icons.edit_outlined),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 12.h),
            Obx(
              () => CommunityCategoryChips(
                selected: controller.selectedCategory,
                onSelected: controller.changeCategory,
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refreshPosts,
                color: AppColors.accent,
                backgroundColor: scheme.surfaceContainer,
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme scheme) {
    return AppBar(
      backgroundColor: scheme.surface,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'Rally',
        style: TextStyle(
          color: AppColors.accent,
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 18.sp,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // 상태 분기: 로딩/에러/빈 상태일 땐 단일 sliver, 정상이면 SliverList.
        // Obx를 sliver 단위로 쪼개 스크롤 중 전체 리빌드를 막는다.
        Obx(() {
          if (controller.isLoading) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 80.h),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
            );
          }
          final error = controller.errorMessage;
          if (error != null && controller.posts.isEmpty) {
            return SliverToBoxAdapter(child: _buildErrorState(error));
          }
          if (controller.posts.isEmpty) {
            return SliverToBoxAdapter(
              child: _buildEmptyState(controller.emptyStateMessage),
            );
          }
          return _buildPostSliverList(controller.posts);
        }),
        // 추가 페이지 로딩 인디케이터 — isLoadingMore일 때만 표시
        SliverToBoxAdapter(
          child: Obx(() {
            if (!controller.isLoadingMore) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2,
                  ),
                ),
              ),
            );
          }),
        ),
        // FAB에 마지막 카드가 가리지 않도록 하단 여백을 넉넉히 둔다.
        SliverToBoxAdapter(child: SizedBox(height: 88.h)),
      ],
    );
  }

  Widget _buildPostSliverList(List<CommunityPostResponse> list) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
      sliver: SliverList.separated(
        itemCount: list.length,
        itemBuilder: (_, i) {
          final post = list[i];
          return CommunityPostCard(
            post: post,
            onTap: () => controller.openPostDetail(post),
          );
        },
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 60.h, 20.w, 60.h),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48.sp,
            color: AppColors.subtleText,
          ),
          SizedBox(height: 12.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(color: Colors.white),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            height: 44.h,
            child: ElevatedButton(
              onPressed: controller.refreshPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.accentDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24.w),
              ),
              child: Text(
                '다시 시도',
                style: TextStyle(
                  fontFamily: AppTypography.chivo,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.sp,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 60.h, 20.w, 60.h),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 48.sp, color: AppColors.subtleText),
          SizedBox(height: 12.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
