import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_repository.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.repository,
    required this.demoMode,
  });

  final AppRepository repository;
  final bool demoMode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _schoolId = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  UserRole _role = UserRole.student;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _schoolId.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('invalid-credential')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    }
    if (text.contains('email-already-in-use')) return 'อีเมลนี้มีบัญชีแล้ว';
    if (text.contains('weak-password')) {
      return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    }
    return text;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_register) {
        await widget.repository.signUp(
          email: _email.text,
          password: _password.text,
          name: _name.text,
          schoolId: _schoolId.text,
          role: _role,
        );
      } else {
        await widget.repository.signIn(_email.text, _password.text);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(error)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Image.asset(
                    'assets/icon/hatyaiwit_borrow_sports_logo.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Hatyaiwit Borrow Sports',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ระบบยืม–คืนอุปกรณ์กีฬาในโรงเรียน',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                  if (widget.demoMode) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E8),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'โหมดทดลอง • เชื่อม Firebase ได้ภายหลัง',
                        style: TextStyle(
                          color: Color(0xFF9A531C),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('เข้าสู่ระบบ'),
                                  icon: Icon(Icons.login_rounded),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('สมัครสมาชิก'),
                                  icon: Icon(Icons.person_add_alt_1_rounded),
                                ),
                              ],
                              selected: {_register},
                              onSelectionChanged: _busy
                                  ? null
                                  : (value) =>
                                        setState(() => _register = value.first),
                              showSelectedIcon: false,
                            ),
                            const SizedBox(height: 22),
                            if (_register) ...[
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: 'ชื่อ–นามสกุล',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                                validator: (value) =>
                                    (value?.trim().length ?? 0) < 3
                                    ? 'กรุณากรอกชื่อ–นามสกุล'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _schoolId,
                                decoration: const InputDecoration(
                                  labelText: 'รหัสนักเรียน / รหัสบุคลากร',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                validator: (value) =>
                                    (value?.trim().isEmpty ?? true)
                                    ? 'กรุณากรอกรหัส'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<UserRole>(
                                initialValue: _role,
                                decoration: const InputDecoration(
                                  labelText: 'ประเภทผู้ใช้งาน',
                                  prefixIcon: Icon(Icons.school_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: UserRole.student,
                                    child: Text('นักเรียน'),
                                  ),
                                  DropdownMenuItem(
                                    value: UserRole.teacher,
                                    child: Text('ครู / บุคลากร'),
                                  ),
                                ],
                                onChanged: (value) => setState(
                                  () => _role = value ?? UserRole.student,
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: '52972@hatyaiwit.ac.th',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                              ),
                              validator: validateSchoolEmail,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                hintText: 'รหัสผ่าน',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (value) => (value?.length ?? 0) < 6
                                  ? 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร'
                                  : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _busy ? null : _submit,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      _register
                                          ? Icons.person_add_alt_1_rounded
                                          : Icons.arrow_forward_rounded,
                                    ),
                              label: Text(
                                _register ? 'สร้างบัญชี' : 'เข้าสู่ระบบ',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
