import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../data/dummy/diary_flow_dummy.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/chat_bubble.dart';
import '../../../../widgets/help_sheet.dart';
import '../../../records/application/viewing_date_provider.dart';
import '../../application/counsel_controller.dart';
import '../../application/diary_draft_provider.dart';
import '../../data/models/counsel_session.dart';

/// Screen 44-B — Step 4. 채팅 상담.
///
/// 44번 영상통화와 같은 [counselControllerProvider]를 쓴다. 같은 대화를 두
/// 화면이 나눠 보는 구조라, 말로 시작했다가 채팅으로 넘어와도 이어진다.
/// 50번 상담 기록에서 "이어하기"로 들어오는 경로도 여기다.
///
/// 영상통화와 달리 지난 대화가 전부 남아 보인다 — 무슨 이야기를 했는지
/// 다시 읽으면서 답할 수 있는 게 채팅의 장점이라 그대로 살린다.
class DiaryStep4CounselChatScreen extends ConsumerStatefulWidget {
  const DiaryStep4CounselChatScreen({super.key});

  @override
  ConsumerState<DiaryStep4CounselChatScreen> createState() =>
      _DiaryStep4CounselChatScreenState();
}

class _DiaryStep4CounselChatScreenState
    extends ConsumerState<DiaryStep4CounselChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // 같은 날 저장된 상담이 있으면 불러와 이어서 대화한다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref
          .read(counselControllerProvider.notifier)
          .restoreIfEmpty(ref.read(viewingDateProvider));
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 새 말풍선이 붙으면 아래로 따라간다. 레이아웃이 끝난 뒤에 불러야
  /// 늘어난 높이까지 반영된다.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(counselControllerProvider.notifier).sendTurn(text);
  }

  /// 상담 종료 — 대화를 draft에 넘기고 리포트 생성으로 넘어간다.
  /// 실제 저장은 46번 화면의 "기록 완료하기"에서 한 번에 이뤄진다.
  void _endCounsel() {
    final counsel = ref.read(counselControllerProvider);
    ref
        .read(diaryDraftProvider.notifier)
        .setCounsel(messages: counsel.messages, startedAt: counsel.startedAt);
    context.pushReplacementNamed(AppRoute.reportGenerating);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CounselState>(counselControllerProvider, (previous, next) {
      if (next.messages.length != (previous?.messages.length ?? 0)) {
        _scrollToBottom();
      }
    });

    final counsel = ref.watch(counselControllerProvider);

    // 대화 전이면 인사말 하나를 띄워 빈 화면을 보여주지 않는다.
    final messages = counsel.messages.isEmpty
        ? const [
            CounselMessage(
              speaker: CounselSpeaker.oddo,
              text: DiaryFlowDummy.counselBubble,
            ),
          ]
        : counsel.messages;

    return Scaffold(
      // 흰 말풍선이 떠 보이도록 바탕은 한 톤 낮춘다.
      backgroundColor: AppColors.backgroundAlt,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('탄카츄와 이야기 중', style: AppTypography.subtitle),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, size: 20),
            onPressed: () => showHelpSheet(
              context,
              title: '채팅 상담 도움말',
              items: const [
                '탄카츄가 오늘의 감정을 함께 돌아봐줘요.',
                '떠오르는 대로 편하게 적으면 돼요. 정답은 없어요.',
                '상담 종료를 누르면 감정 리포트가 만들어져요.',
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.xs,
                ),
                children: [
                  for (final m in messages)
                    ChatBubble(
                      fromOddo: m.speaker == CounselSpeaker.oddo,
                      text: m.text,
                    ),
                  if (counsel.sending) const _TypingBubble(),
                  // 위기 발화가 감지되면 상담을 멈추고 전문 기관 안내를 띄운다.
                  if (counsel.crisis) const _CrisisCard(),
                ],
              ),
            ),
            _ChatInputBar(
              controller: _input,
              sending: counsel.sending,
              enabled: !counsel.crisis,
              onSend: _send,
              onEnd: _endCounsel,
            ),
          ],
        ),
      ),
    );
  }
}

/// 답을 기다리는 동안의 자리 표시 — 말풍선 자리를 미리 잡아둬서 응답이
/// 도착할 때 화면이 튀지 않는다.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const ChatBubble(fromOddo: true, text: '…');
  }
}

/// 위기 발화 감지 시 안내 — 상담 응답 대신 전문 기관 연결을 먼저 보여준다.
class _CrisisCard extends StatelessWidget {
  const _CrisisCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '지금은 전문가와 이야기하는 게 좋겠어요.\n'
              '자살예방 상담전화 109 · 24시간 연결돼요.',
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 입력줄 + 상담 종료. 통화 화면의 컨트롤 버튼에 해당하는 자리다.
class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.sending,
    required this.enabled,
    required this.onSend,
    required this.onEnd,
  });

  final TextEditingController controller;
  final bool sending;

  /// 위기 안내 중에는 입력을 막는다.
  final bool enabled;

  final VoidCallback onSend;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xs,
        AppSpacing.screenH,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.call_end_rounded, color: AppColors.error),
            tooltip: '상담 종료',
            onPressed: onEnd,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: TextField(
                controller: controller,
                enabled: enabled && !sending,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: AppTypography.body,
                decoration: InputDecoration(
                  hintText: enabled ? '하고 싶은 말을 적어보세요' : '상담을 잠시 멈췄어요',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          if (sending)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
              onPressed: enabled ? onSend : null,
            ),
        ],
      ),
    );
  }
}
