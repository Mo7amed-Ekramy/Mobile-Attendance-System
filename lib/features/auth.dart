import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/api.dart';
import '../widgets/common.dart';

class SignInPage extends StatefulWidget {
  const SignInPage(this.state, {super.key});
  final AppState state;
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final form = GlobalKey<FormState>();
  final identifier = TextEditingController();
  final password = TextEditingController();
  bool reveal = false;
  bool submitting = false;
  String? error;
  Future<void> submit() async {
    if (submitting || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.state.signIn(identifier.text, password.text);
    } on ApiException catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تسجيل الدخول. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Form(
                      key: form,
                      child: PageContent(children: [
                        Center(
                            child: Image.asset('assets/images/logo.png',
                                height: 120,
                                errorBuilder: (_, error, stack) =>
                                    const Icon(Icons.school, size: 80))),
                        Text('جامعة أسيوط الأهلية',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const Text('نظام الحضور والتقييم الأكاديمي',
                            textAlign: TextAlign.center),
                        const Text(
                            'استخدم حسابك الجامعي للوصول إلى مهامك ومقرراتك.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        TextFormField(
                            controller: identifier,
                            enabled: !submitting,
                            autocorrect: false,
                            key: const ValueKey('login-identifier'),
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'اسم المستخدم أو الرقم الجامعي',
                                prefixIcon: Icon(Icons.person_outline)),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'أدخل اسم المستخدم أو الرقم الجامعي.'
                                : null),
                        TextFormField(
                            controller: password,
                            enabled: !submitting,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => submit(),
                            key: const ValueKey('login-password'),
                            obscureText: !reveal,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                    tooltip: reveal
                                        ? 'إخفاء كلمة المرور'
                                        : 'إظهار كلمة المرور',
                                    onPressed: () =>
                                        setState(() => reveal = !reveal),
                                    icon: Icon(reveal
                                        ? Icons.visibility_off
                                        : Icons.visibility))),
                            validator: (value) => (value ?? '').isEmpty
                                ? 'أدخل كلمة المرور.'
                                : null),
                        if (error != null)
                          NoticeBanner(error!,
                              icon: Icons.error_outline, isError: true),
                        AsyncButton(
                            enabled: !submitting,
                            label: submitting
                                ? 'جار تسجيل الدخول...'
                                : 'تسجيل الدخول',
                            icon: Icons.login,
                            onPressed: submit),
                        if (widget.state.startupError != null)
                          EmptyPanel('تعذر استعادة الجلسة',
                              widget.state.startupError!),
                      ]))))));
}
