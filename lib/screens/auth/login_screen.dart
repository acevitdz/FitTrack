import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/design_system.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});

  final AppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  var _register = false;
  var _obscurePassword = true;
  var _obscureConfirm = true;
  var _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (widget.state.busy || !_formKey.currentState!.validate()) return;
    if (_register && !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đồng ý với điều khoản dịch vụ.')),
      );
      return;
    }

    final success = _register
        ? await widget.state.register(
            _nameController.text,
            _emailController.text,
            _passwordController.text,
          )
        : await widget.state.signIn(
            _emailController.text,
            _passwordController.text,
          );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.state.errorMessage ?? 'Có lỗi xảy ra.')),
      );
    }
  }

  void _toggleMode() {
    _formKey.currentState?.reset();
    setState(() {
      _register = !_register;
      _acceptedTerms = false;
      _confirmController.clear();
    });
  }

  String? _emailValidator(String? value) {
    final email = (value ?? '').trim();
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return valid ? null : 'Email không hợp lệ';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => Scaffold(
        key: ValueKey(_register ? 'ui-03-register' : 'ui-02-login'),
        body: FitTrackPage(
          maxWidth: 390,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.center,
                  child: FitTrackLogo(size: 48),
                ),
                const SizedBox(height: 20),
                Text(
                  _register ? 'Tạo tài khoản mới' : 'Chào mừng trở lại',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _register
                      ? 'Điền thông tin bên dưới để bắt đầu với FitTrack.'
                      : 'Theo dõi sức khỏe, tập luyện và tiến bộ mỗi ngày.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_register) ...[
                          AppFormLabel(
                            label: 'Họ và tên',
                            child: TextFormField(
                              key: const Key('auth_name'),
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                hintText: 'Nhập họ và tên',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Họ tên không được để trống'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        AppFormLabel(
                          label: 'Email',
                          child: TextFormField(
                            key: const Key('auth_email'),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              hintText: 'Nhập địa chỉ email',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                            validator: _emailValidator,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppFormLabel(
                          label: 'Mật khẩu',
                          child: TextFormField(
                            key: const Key('auth_password'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: _register
                                ? TextInputAction.next
                                : TextInputAction.done,
                            autofillHints: [
                              _register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            onFieldSubmitted: (_) =>
                                _register ? null : _submit(),
                            decoration: InputDecoration(
                              hintText: 'Nhập mật khẩu',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                value == null || value.length < 8
                                ? 'Mật khẩu cần ít nhất 8 ký tự'
                                : null,
                          ),
                        ),
                        if (_register) ...[
                          const SizedBox(height: 8),
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Sử dụng ít nhất 8 ký tự để bảo vệ tài khoản.',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (!_register)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: widget.state.busy
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ForgotPasswordScreen(
                                          state: widget.state,
                                          initialEmail: _emailController.text,
                                        ),
                                      ),
                                    ),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                              child: const Text('Quên mật khẩu?'),
                            ),
                          ),
                        if (_register) ...[
                          const SizedBox(height: 14),
                          AppFormLabel(
                            label: 'Xác nhận mật khẩu',
                            child: TextFormField(
                              key: const Key('auth_confirm_password'),
                              controller: _confirmController,
                              obscureText: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                hintText: 'Nhập lại mật khẩu',
                                prefixIcon: const Icon(Icons.lock_reset),
                                suffixIcon: IconButton(
                                  tooltip: _obscureConfirm
                                      ? 'Hiện mật khẩu'
                                      : 'Ẩn mật khẩu',
                                  onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value != _passwordController.text
                                  ? 'Mật khẩu xác nhận chưa trùng khớp'
                                  : null,
                            ),
                          ),
                          CheckboxListTile(
                            key: const Key('auth_terms'),
                            value: _acceptedTerms,
                            onChanged: widget.state.busy
                                ? null
                                : (value) => setState(
                                    () => _acceptedTerms = value ?? false,
                                  ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Tôi đồng ý với Điều khoản dịch vụ và Chính sách bảo mật',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        AppPrimaryButton(
                          key: const Key('auth_submit'),
                          label: _register ? 'Đăng ký' : 'Đăng nhập',
                          loading: widget.state.busy,
                          onPressed: _submit,
                        ),
                        if (!_register) ...[
                          const SizedBox(height: 18),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'Hoặc',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _unsupportedSocial,
                                  icon: const Text(
                                    'G',
                                    style: TextStyle(
                                      color: Color(0xFF4285F4),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  label: const Text('Google'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _unsupportedSocial,
                                  icon: const Icon(
                                    Icons.facebook,
                                    color: Color(0xFF1877F2),
                                    size: 20,
                                  ),
                                  label: const Text('Facebook'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _register ? 'Đã có tài khoản?' : 'Bạn chưa có tài khoản?',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    TextButton(
                      onPressed: widget.state.busy ? null : _toggleMode,
                      child: Text(_register ? 'Đăng nhập' : 'Đăng ký ngay'),
                    ),
                  ],
                ),
                OfflineBanner(visible: !widget.state.firebaseAvailable),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _unsupportedSocial() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bản hiện tại chỉ hỗ trợ email và mật khẩu.'),
      ),
    );
  }
}
