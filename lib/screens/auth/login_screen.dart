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
  final _emailController = TextEditingController(text: 'demo@fittrack.vn');
  final _passwordController = TextEditingController(text: 'FitTrack123!');
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
        body: Stack(
          children: [
            const Positioned(
              top: -150,
              right: -110,
              child: _BackgroundGlow(size: 360),
            ),
            const Positioned(
              bottom: -180,
              left: -100,
              child: _BackgroundGlow(size: 330),
            ),
            FitTrackPage(
              maxWidth: 440,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FitTrackLogo(showWordmark: true),
                    if (!_register) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Chào mừng trở lại',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tiếp tục hành trình thể lực của bạn cùng FitTrack.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 30),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_register) ...[
                              Text(
                                'Tạo tài khoản mới',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Điền thông tin dưới đây để đăng ký',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              AppFormLabel(
                                label: 'Họ và tên',
                                child: TextFormField(
                                  controller: _nameController,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  decoration: const InputDecoration(
                                    hintText: 'Nhập họ và tên của bạn',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Họ tên không được rỗng'
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                            AppFormLabel(
                              label: 'Email',
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: InputDecoration(
                                  hintText: _register
                                      ? 'ví dụ: ten@email.com'
                                      : 'nhap@email.com',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                ),
                                validator: _emailValidator,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Mật khẩu',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                if (!_register)
                                  TextButton(
                                    onPressed: widget.state.busy
                                        ? null
                                        : () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ForgotPasswordScreen(
                                                    state: widget.state,
                                                    initialEmail:
                                                        _emailController.text,
                                                  ),
                                            ),
                                          ),
                                    child: const Text('Quên mật khẩu?'),
                                  ),
                              ],
                            ),
                            TextFormField(
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
                                hintText: _register
                                    ? 'Tạo mật khẩu'
                                    : '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline),
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
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.length < 8
                                  ? 'Mật khẩu cần ít nhất 8 ký tự'
                                  : null,
                            ),
                            if (_register) ...[
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'Ít nhất 8 ký tự',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              AppFormLabel(
                                label: 'Xác nhận mật khẩu',
                                child: TextFormField(
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
                                        () =>
                                            _obscureConfirm = !_obscureConfirm,
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
                              const SizedBox(height: 12),
                              CheckboxListTile(
                                value: _acceptedTerms,
                                onChanged: widget.state.busy
                                    ? null
                                    : (value) => setState(
                                        () => _acceptedTerms = value ?? false,
                                      ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Tôi đồng ý với các Điều khoản dịch vụ và Chính sách bảo mật',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            AppPrimaryButton(
                              label: _register ? 'Đăng ký' : 'Đăng nhập',
                              loading: widget.state.busy,
                              onPressed: _submit,
                            ),
                            if (!_register) ...[
                              const SizedBox(height: 20),
                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text('HOẶC'),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _unsupportedSocial,
                                      icon: const Icon(Icons.g_mobiledata),
                                      label: const Text('Google'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _unsupportedSocial,
                                      icon: const Icon(Icons.facebook),
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
                    const SizedBox(height: 22),
                    TextButton(
                      onPressed: widget.state.busy ? null : _toggleMode,
                      child: Text(
                        _register
                            ? 'Đã có tài khoản? Đăng nhập'
                            : 'Chưa có tài khoản? Đăng ký',
                      ),
                    ),
                    OfflineBanner(visible: !widget.state.firebaseAvailable),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _unsupportedSocial() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bản hiện tại chỉ hỗ trợ đăng nhập bằng email/mật khẩu.'),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x2ED8E2FF),
      ),
    ),
  );
}
