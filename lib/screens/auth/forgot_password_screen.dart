import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/design_system.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.state,
    this.initialEmail = '',
  });

  final AppState state;
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  var _sending = false;
  var _sent = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_sending || !_formKey.currentState!.validate()) return;

    setState(() {
      _sending = true;
      _errorMessage = null;
    });

    try {
      await widget.state.resetPassword(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } on Object {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Không thể gửi liên kết lúc này. Hãy kiểm tra mạng và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return valid ? null : 'Email không hợp lệ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('ui-04-forgot-password'),
      body: FitTrackPage(
        maxWidth: 390,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Quay lại',
                onPressed: _sending ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.center,
              child: FitTrackLogo(size: 48),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _sent ? _successContent(context) : _formContent(context),
            ),
            const SizedBox(height: 16),
            OfflineBanner(visible: !widget.state.firebaseAvailable),
          ],
        ),
      ),
    );
  }

  Widget _formContent(BuildContext context) {
    return Column(
      key: const ValueKey('forgot-password-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quên mật khẩu?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Nhập email đã đăng ký. FitTrack sẽ gửi hướng dẫn đặt lại mật khẩu cho bạn.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppFormLabel(
                    label: 'Email',
                    child: TextFormField(
                      key: const Key('forgot_email'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        hintText: 'Nhập địa chỉ email',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      validator: _validateEmail,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: 22),
                  AppPrimaryButton(
                    key: const Key('forgot_submit'),
                    label: 'Gửi liên kết',
                    loading: _sending,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _sending ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Quay lại đăng nhập'),
        ),
      ],
    );
  }

  Widget _successContent(BuildContext context) {
    return Column(
      key: const ValueKey('forgot-password-success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.center,
          child: CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.paleBlue,
            foregroundColor: AppColors.success,
            child: Icon(Icons.mark_email_read_outlined, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Kiểm tra email của bạn',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Nếu email hợp lệ, hướng dẫn đặt lại mật khẩu đã được gửi tới ${_emailController.text.trim()}.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AppPrimaryButton(
              label: 'Quay lại đăng nhập',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ],
    );
  }
}
