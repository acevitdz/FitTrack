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
  late final TextEditingController _email;
  var _sending = false;
  var _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.state.resetPassword(_email.text);
      if (mounted) setState(() => _sent = true);
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Không thể gửi liên kết lúc này. Hãy kiểm tra mạng và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FitTrackPage(
        maxWidth: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'FitTrack',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 170),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _sent ? _success(context) : _form(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.paleBlue,
          foregroundColor: AppColors.primary,
          child: Icon(Icons.lock_reset),
        ),
        const SizedBox(height: 24),
        Text(
          'Quên mật khẩu',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Nhập email của bạn để nhận liên kết đặt lại mật khẩu. Chúng tôi sẽ gửi hướng dẫn qua hòm thư của bạn.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        AppFormLabel(
          label: 'Email',
          child: TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final email = (value ?? '').trim();
              return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                  ? null
                  : 'Email không hợp lệ';
            },
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 22),
        AppPrimaryButton(
          label: 'Gửi liên kết',
          loading: _sending,
          onPressed: _submit,
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _sending ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Quay lại Đăng nhập'),
        ),
      ],
    ),
  );

  Widget _success(BuildContext context) => Column(
    key: const ValueKey('success'),
    children: [
      const Icon(
        Icons.mark_email_read_outlined,
        size: 64,
        color: AppColors.success,
      ),
      const SizedBox(height: 20),
      Text(
        'Kiểm tra email của bạn',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        'Nếu email hợp lệ, hướng dẫn đặt lại mật khẩu đã được gửi tới ${_email.text.trim()}.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      AppPrimaryButton(
        label: 'Quay lại Đăng nhập',
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );
}
