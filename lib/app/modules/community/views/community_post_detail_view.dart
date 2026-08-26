import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_typography.dart';
import '../../../data/models/community_post_response.dart';
import '../controllers/community_controller.dart';
import '../controllers/community_post_detail_controller.dart';
import 'widgets/community_comment_input_bar.dart';
import 'widgets/community_comment_tile.dart';
import 'widgets/community_image_grid.dart';

/// 커뮤니티 게시글 상세 화면.
///
/// Stitch에 대응 화면이 없어(`list_screens` 인증 실패) `CommunityView` /
/// `PlayerDetailView` 의 다크 매거진 톤을 그대로 준용했다.
///
/// `Obx` 는 AppBar 액션 / 본문 sliver / 하단 액션바로 쪼개 두었다.
/// 화면 전체를 하나의 `Obx` 로 감싸면 스크롤 중 전면 리빌드가 발생하고
/// `improper use of a GetX` 경고가 뜬다.
class CommunityPostDetailView extends GetView<CommunityPostDetailController> {
  const CommunityPostDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = AppColors.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _buildAppBar(scheme),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: Obx(() {
                  if (controller.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    );
                  }
                  final error = controller.errorMessage;
                  if (error != null) return _buildErrorState(error);
                  final post = controller.post;
                  if (post == null) {
                    return _buildErrorState('게시글을 찾을 수 없습니다.');
                  }
                  return _buildBody(context, post);
                }),
              ),
              Obx(() {
                final post = controller.post;
                if (post == null) return const SizedBox.shrink();
                return _buildActionBar(scheme, post);
              }),
              // 입력바는 글을 못 읽는 상태(삭제·차단·조회 실패)에서는 숨긴다.
              // 어차피 서버가 `cc_insert` 정책으로 막는다.
              Obx(() {
                if (controller.post == null) return const SizedBox.shrink();
                return const CommunityCommentInputBar();
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(ColorScheme scheme) {
    return AppBar(
      backgroundColor: scheme.surface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Get.back<void>(),
      ),
      title: Text(
        '게시글',
        style: TextStyle(
          color: Colors.white,
          fontFamily: AppTypography.chivo,
          fontWeight: FontWeight.w800,
          fontSize: 16.sp,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        // 더보기는 글이 떠 있으면 항상 노출한다. 본인 글이면 수정/삭제,
        // 타인 글이면 신고/차단, 운영자면 조치 항목까지 시트가 분기한다.
        // 비로그인 상태에서도 감춰서는 안 된다 — 신고 창구를 찾을 수 없으면
        // Apple 1.2 요건을 충족하지 못한다(누르면 로그인으로 유도한다).
        Obx(() {
          if (controller.post == null) return SizedBox(width: 8.w);
          return IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            tooltip: '더보기',
            onPressed: controller.showPostMoreSheet,
          );
        }),
      ],
    );
  }

  // ── 본문 ──────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, CommunityPostResponse post) {
    final imageUrls = post.imageUrls;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildAuthorRow(post),
              SizedBox(height: 16.h),
              _buildCategoryChip(post.category),
              SizedBox(height: 10.h),
              Text(
                (post.title ?? '').trim().isEmpty
                    ? '제목 없음'
                    : post.title!.trim(),
                style: TextStyle(
                  fontFamily: AppTypography.chivo,
                  fontWeight: FontWeight.w800,
                  fontSize: 20.sp,
                  height: 1.3,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 14.h),
              // 본문은 `SelectableText` 라 자체 탭 인식기가 탭을 소비한다.
              // 화면에서 가장 넓은 영역이므로 body 래핑만으로는 여기를 눌러도
              // 키보드가 내려가지 않는다 — onTap 으로 직접 unfocus 한다.
              // 텍스트 선택(롱프레스 드래그) 동작은 그대로 유지된다.
              SelectableText(
                (post.content ?? '').trim(),
                onTap: () => FocusScope.of(context).unfocus(),
                style: AppTypography.bodyMd.copyWith(
                  fontSize: 15.sp,
                  height: 1.6,
                  color: Colors.white,
                ),
              ),
              if (imageUrls.isNotEmpty) ...[
                SizedBox(height: 18.h),
                CommunityImageGrid(imageUrls: imageUrls),
              ],
              SizedBox(height: 24.h),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: Divider(height: 1, color: AppColors.divider)),
        SliverToBoxAdapter(
          child: Obx(() => _buildCommentHeader(controller.visibleCommentCount)),
        ),
        // Obx 가 sliver 를 그대로 돌려준다 — 댓글이 바뀔 때 본문까지 다시
        // 그리지 않도록 본문 sliver 와 분리해 둔 것이다.
        Obx(() => _buildCommentSliver()),
        SliverToBoxAdapter(child: SizedBox(height: 16.h)),
      ],
    );
  }

  // ── 댓글 ──────────────────────────────────────────────────────────────

  /// "댓글 N" 헤더.
  ///
  /// 여기 N 은 **화면에 실제로 그려지는 개수**다. 하단 액션바의 숫자
  /// (`comment_count`)와 다를 수 있는데, 카운터는 서버 트리거가 전체 기준으로
  /// 세고 목록은 차단 필터를 통과한 것만 담기 때문이다. 의도된 차이다.
  Widget _buildCommentHeader(int count) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 6.h),
      child: Text(
        '댓글 $count',
        style: AppTypography.labelLg.copyWith(
          fontSize: 14.sp,
          letterSpacing: 0.2,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCommentSliver() {
    final comments = controller.comments;

    if (controller.isCommentsLoading && comments.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28.h),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
      );
    }

    final error = controller.commentsError;
    if (error != null && comments.isEmpty) {
      return SliverToBoxAdapter(child: _buildCommentsError(error));
    }

    final items = controller.threadedComments;
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28.h),
          child: Center(
            child: Text(
              '첫 댓글을 남겨보세요.',
              style: AppTypography.bodyMd.copyWith(
                fontSize: 14.sp,
                color: AppColors.subtleText,
              ),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final comment = items[index];
        return CommunityCommentTile(
          comment: comment,
          canReply: controller.canReplyTo(comment),
          onReply: () => controller.startReply(comment),
          // 툼스톤에는 조치할 것이 없다 — 숨김 댓글을 복구할 수 있는
          // 운영자에게만 진입점을 준다.
          onMore:
              controller.canOpenCommentMoreSheet(comment)
                  ? () => controller.showCommentMoreSheet(comment)
                  : null,
          // 툼스톤에는 아바타 자체가 없다 — 마스킹된 작성자는 넘기지 않는다.
          onAuthorTap:
              comment.isRemoved
                  ? null
                  : () => controller.openProfile(
                    comment.authorId,
                    nickname: comment.authorNickname,
                    avatarUrl: comment.authorAvatarUrl,
                  ),
        );
      }, childCount: items.length),
    );
  }

  Widget _buildCommentsError(String message) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              fontSize: 14.sp,
              color: AppColors.subtleText,
            ),
          ),
          SizedBox(height: 12.h),
          TextButton(
            onPressed: controller.loadComments,
            child: Text(
              '댓글 다시 불러오기',
              style: AppTypography.labelLg.copyWith(
                fontSize: 13.sp,
                letterSpacing: 0.2,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 아바타 + 닉네임 + 작성 시각(수정됨 표기 포함)
  ///
  /// 행 전체가 프로필 시트 진입점이다. 더보기(⋯)는 이 행이 아니라 AppBar에
  /// 있으므로 겹치지 않는다. 탭 가능하다는 시각적 표시는 넣지 않는다.
  /// `behavior: opaque` 로 이벤트를 확실히 소비해, 나중에 body 를 감쌀
  /// 상위 제스처가 이 탭을 가로채지 않게 한다.
  Widget _buildAuthorRow(CommunityPostResponse post) {
    final avatarUrl = post.authorAvatarUrl;
    final edited = post.editedAt != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          () => controller.openProfile(
            post.authorId,
            nickname: post.authorNickname,
            avatarUrl: avatarUrl,
          ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 36.w,
              height: 36.w,
              child:
                  (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                      ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _avatarPlaceholder(),
                        errorWidget: (_, __, ___) => _avatarPlaceholder(),
                      )
                      : _avatarPlaceholder(),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  post.authorDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLg.copyWith(
                    fontSize: 14.sp,
                    letterSpacing: 0.2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  edited
                      ? '${_formatRelativeTime(post.createdAt)} · 수정됨'
                      : _formatRelativeTime(post.createdAt),
                  style: AppTypography.labelLg.copyWith(
                    fontSize: 12.sp,
                    letterSpacing: 0.2,
                    color: AppColors.subtleText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 20.sp, color: AppColors.subtleText),
    );
  }

  Widget _buildCategoryChip(String? category) {
    if (category == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          CommunityController.labelKoOf(category),
          style: AppTypography.labelLg.copyWith(
            fontSize: 11.sp,
            letterSpacing: 0.2,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }

  // ── 하단 액션바 ────────────────────────────────────────────────────────

  /// 좋아요 토글 · 댓글 수 · 조회 수.
  ///
  /// 여기 댓글 수는 서버 카운터(`comment_count`)다. 댓글 섹션 헤더의 숫자와
  /// 어긋날 수 있는데, 그쪽은 차단 필터를 통과해 실제로 그려진 개수라서다.
  Widget _buildActionBar(ColorScheme scheme, CommunityPostResponse post) {
    final liked = post.isLiked == true;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Row(
        children: [
          _likeButton(liked, post.likeCount ?? 0),
          SizedBox(width: 18.w),
          _metric(Icons.mode_comment_outlined, post.commentCount ?? 0),
          SizedBox(width: 18.w),
          _metric(Icons.visibility_outlined, post.viewCount ?? 0),
        ],
      ),
    );
  }

  Widget _likeButton(bool liked, int count) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: controller.toggleLike,
        borderRadius: BorderRadius.circular(999.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                size: 20.sp,
                color: liked ? AppColors.accent : Colors.white,
              ),
              SizedBox(width: 6.w),
              Text(
                '$count',
                style: AppTypography.labelLg.copyWith(
                  fontSize: 14.sp,
                  letterSpacing: 0.2,
                  color: liked ? AppColors.accent : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18.sp, color: AppColors.subtleText),
        SizedBox(width: 6.w),
        Text(
          '$count',
          style: AppTypography.labelLg.copyWith(
            fontSize: 14.sp,
            letterSpacing: 0.2,
            color: AppColors.subtleText,
          ),
        ),
      ],
    );
  }

  // ── 에러 ──────────────────────────────────────────────────────────────

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                onPressed: controller.refreshPost,
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
      ),
    );
  }

  /// 상대 시간 표기 (`CommunityPostCard` 와 동일한 규칙)
  static String _formatRelativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }
}
