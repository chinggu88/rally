import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_typography.dart';
import '../../../../data/models/community_comment_response.dart';

/// 댓글 한 줄 (최상위 댓글 / 1depth 대댓글 / 삭제 툼스톤).
///
/// 상태를 갖지 않고 콜백만 받는다 — 어떤 댓글에 답글을 달 수 있는지,
/// 더보기 시트에 무엇을 그릴지는 컨트롤러가 판정한다.
///
/// 더보기(⋯)는 롱프레스가 아니라 **눈에 보이는 버튼**이다. 신고 창구를
/// 숨은 제스처에 두면 Apple 리뷰어도, 실제 사용자도 찾지 못한다
/// (기획서 §6-1 / Guideline 1.2). 롱프레스도 같은 시트를 열어 준다.
///
/// Stitch 에 대응 화면이 없어(`list_screens` 인증 실패) `CommunityPostCard` 의
/// 아바타 + 닉네임 + 상대시간 배치를 그대로 준용했다.
class CommunityCommentTile extends StatelessWidget {
  const CommunityCommentTile({
    super.key,
    required this.comment,
    required this.canReply,
    this.onReply,
    this.onMore,
    this.onAuthorTap,
  });

  final CommunityCommentResponse comment;

  /// 답글 버튼 노출 조건. 대댓글과 삭제된 댓글에는 답글을 달 수 없다.
  final bool canReply;

  final VoidCallback? onReply;

  /// 더보기(⋯) — 수정/삭제 · 신고/차단 · 운영자 조치를 담은 시트를 연다.
  final VoidCallback? onMore;

  /// 아바타 탭 — 작성자 프로필 시트를 연다. [onMore] 와 같은 패턴으로
  /// nullable 이며, null 이면 탭을 걸지 않는다(툼스톤에는 아바타가 없다).
  final VoidCallback? onAuthorTap;

  /// 최상위 댓글 좌측 여백
  static const double _rootIndent = 20;

  /// 대댓글 좌측 여백 — `↳` 표기와 함께 부모와의 관계를 보여준다
  static const double _replyIndent = 48;

  @override
  Widget build(BuildContext context) {
    final isReply = comment.isReply;
    final padding = EdgeInsets.fromLTRB(
      (isReply ? _replyIndent : _rootIndent).w,
      10.h,
      20.w,
      10.h,
    );

    if (comment.isRemoved) {
      // 툼스톤에도 더보기를 남긴다 — 운영자가 숨김 댓글을 복구하려면
      // 진입점이 필요하다. 일반 사용자에게는 호출부가 onMore 를 주지 않는다.
      return Padding(padding: padding, child: _buildTombstone(isReply));
    }

    return GestureDetector(
      onLongPress: onMore,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isReply) ...[
              Padding(
                padding: EdgeInsets.only(top: 4.h, right: 6.w),
                child: Icon(
                  Icons.subdirectory_arrow_right,
                  size: 14.sp,
                  color: AppColors.inactive,
                ),
              ),
            ],
            _buildAvatar(),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  SizedBox(height: 4.h),
                  Text(
                    (comment.content ?? '').trim(),
                    style: AppTypography.bodyMd.copyWith(
                      fontSize: 14.sp,
                      height: 1.5,
                      color: Colors.white,
                    ),
                  ),
                  if (canReply) ...[SizedBox(height: 2.h), _buildReplyButton()],
                ],
              ),
            ),
            if (onMore != null) ...[SizedBox(width: 4.w), _buildMoreButton()],
          ],
        ),
      ),
    );
  }

  /// 삭제·숨김 댓글. 본문 자리에 안내 문구만 남기고 작성자는 노출하지 않는다
  /// (뷰가 닉네임/아바타까지 NULL 로 마스킹해서 내려준다).
  Widget _buildTombstone(bool isReply) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isReply) ...[
          Padding(
            padding: EdgeInsets.only(right: 6.w),
            child: Icon(
              Icons.subdirectory_arrow_right,
              size: 14.sp,
              color: AppColors.inactive,
            ),
          ),
        ],
        Expanded(
          child: Text(
            '삭제된 댓글입니다.',
            style: AppTypography.bodyMd.copyWith(
              fontSize: 13.sp,
              fontStyle: FontStyle.italic,
              color: AppColors.subtleText,
            ),
          ),
        ),
        if (onMore != null) _buildMoreButton(),
      ],
    );
  }

  /// 아바타. [onAuthorTap] 이 있으면 프로필 시트 진입점이 된다.
  ///
  /// 상위에 `onLongPress: onMore` 가 걸려 있지만 여기서는 탭만 처리하므로
  /// 롱프레스는 그대로 상위로 간다. 시각적 표시는 추가하지 않는다.
  Widget _buildAvatar() {
    final avatar = _buildAvatarImage();
    if (onAuthorTap == null) return avatar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAuthorTap,
      child: avatar,
    );
  }

  Widget _buildAvatarImage() {
    final avatarUrl = comment.authorAvatarUrl;
    return ClipOval(
      child: SizedBox(
        width: 28.w,
        height: 28.w,
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
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 16.sp, color: AppColors.subtleText),
    );
  }

  Widget _buildHeader() {
    final edited = comment.editedAt != null;
    final time = _formatRelativeTime(comment.createdAt);

    return Row(
      children: [
        Flexible(
          child: Text(
            comment.authorDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelLg.copyWith(
              fontSize: 13.sp,
              letterSpacing: 0.2,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          edited ? '$time · 수정됨' : time,
          style: AppTypography.labelLg.copyWith(
            fontSize: 11.sp,
            letterSpacing: 0.2,
            color: AppColors.subtleText,
          ),
        ),
      ],
    );
  }

  Widget _buildMoreButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onMore,
        borderRadius: BorderRadius.circular(999.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          child: Icon(
            Icons.more_horiz,
            size: 18.sp,
            color: AppColors.subtleText,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReply,
        borderRadius: BorderRadius.circular(999.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          child: Text(
            '답글',
            style: AppTypography.labelLg.copyWith(
              fontSize: 12.sp,
              letterSpacing: 0.2,
              color: AppColors.subtleText,
            ),
          ),
        ),
      ),
    );
  }

  /// 상대 시간 표기 (`CommunityPostCard` / 상세 화면과 동일한 규칙)
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
