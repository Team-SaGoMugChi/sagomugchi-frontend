import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/storage/local_store.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/dummy/auth_dummy.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_background.dart';
import '../../../../widgets/oddo_text_field.dart';
import '../../../../widgets/oddo_wordmark.dart';
import '../../../../widgets/primary_button.dart';
import '../../application/auth_controller.dart';
import '../../data/models/social_login_result.dart';
import '../widgets/login_error_modal.dart';
import '../widgets/or_divider.dart';
import '../widgets/social_login_button.dart';

/// Screen 2 — 로그인. Email/password sign-in against Firebase Auth; social
/// login is deferred (buttons show a "준비 중" notice).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late bool _keepLoggedIn = ref
      .read(localStoreProvider)
      .getBool(LocalStore.kKeepLoggedIn);
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _emailError = Validators.email(email);
      _passwordError = password.isEmpty ? '비밀번호를 입력해주세요.' : null;
    });
    if (_emailError != null || _passwordError != null) return;

    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(email: email, password: password, keepLoggedIn: _keepLoggedIn);
      if (mounted) context.goNamed(AppRoute.home);
    } on AppException catch (e) {
      if (mounted) await showLoginErrorModal(context, message: e.message);
    }
  }

  Future<void> _socialLogin(
    Future<SocialLoginStatus> Function() attempt,
  ) async {
    try {
      final status = await attempt();
      if (!mounted) return;
      switch (status) {
        case SocialLoginStatus.success:
          context.goNamed(AppRoute.home);
        case SocialLoginStatus.needsProfile:
          unawaited(context.pushNamed(AppRoute.socialExtraInfo));
        case SocialLoginStatus.cancelled:
          break;
      }
    } on AppException catch (e) {
      if (mounted) await showLoginErrorModal(context, message: e.message);
    }
  }

  Future<void> _googleLogin() =>
      _socialLogin(ref.read(authControllerProvider.notifier).loginWithGoogle);

  Future<void> _kakaoLogin() =>
      _socialLogin(ref.read(authControllerProvider.notifier).loginWithKakao);

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      authControllerProvider.select((s) => s.isLoading),
    );

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                Gap.h32,
                const Text('이메일', style: AppTypography.bodySecondary),
                Gap.h8,
                OddoTextField(
                  controller: _emailController,
                  hint: AuthDummy.emailHint,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                ),
                Gap.h20,
                const Text('비밀번호', style: AppTypography.bodySecondary),
                Gap.h8,
                OddoTextField(
                  controller: _passwordController,
                  hint: AuthDummy.passwordHint,
                  obscure: true,
                  errorText: _passwordError,
                ),
                Gap.h12,
                _optionsRow(),
                Gap.h20,
                PrimaryButton(
                  label: '로그인',
                  loading: isLoading,
                  onPressed: _submit,
                ),
                Gap.h20,
                const OrDivider(),
                Gap.h16,
                SocialLoginButton(
                  label: '카카오로 계속하기',
                  backgroundColor: AppColors.kakao,
                  leading: const _KakaoBadge(),
                  onPressed: _kakaoLogin,
                ),
                Gap.h12,
                SocialLoginButton(
                  label: 'Google로 계속하기',
                  leading: const _GoogleBadge(),
                  onPressed: _googleLogin,
                ),
                Gap.h24,
                _signupRow(),
                Gap.h16,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return const Padding(
      padding: EdgeInsets.only(top: AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OddoWordmark(fontSize: 32),
          Gap.h16,
          Text('이메일로 로그인하거나 간편 로그인을 쓰세요.', style: AppTypography.bodySecondary),
        ],
      ),
    );
  }

  Widget _optionsRow() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        GestureDetector(
          onTap: () => setState(() => _keepLoggedIn = !_keepLoggedIn),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _keepLoggedIn
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: _keepLoggedIn ? AppColors.primary : AppColors.inactive,
              ),
              const SizedBox(width: 6),
              const Text('로그인 상태 유지', style: AppTypography.bodySecondary),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.pushNamed(AppRoute.findPassword),
          child: Text(
            '비밀번호 찾기',
            style: AppTypography.bodySecondary.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _signupRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: AppRadius.button,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('처음이신가요?', style: AppTypography.bodySecondary),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => context.pushNamed(AppRoute.signup),
            child: Text(
              '회원가입',
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kakao brand badge: yellow rounded square with a chat bubble.
class _KakaoBadge extends StatelessWidget {
  const _KakaoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.kakao,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.chat_bubble_rounded,
        size: 15,
        color: Color(0xFF3A1D1D),
      ),
    );
  }
}

/// Google brand badge: white circle with a colored "G".
class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
