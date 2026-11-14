import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/api.dart';
import '../widgets/common.dart';
import '../theme.dart';

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

  Widget loginForm(BuildContext context, bool wide) => Card(
        child: Padding(
            padding: EdgeInsets.all(wide ? 40 : 24),
            child: AutofillGroup(
                child: Form(
                    key: form,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!wide) ...[
                            Image.asset('assets/images/logo.png', height: 82),
                            const SizedBox(height: 12),
                            Text('جامعة أسيوط الأهلية',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 24),
                          ],
                          Text('مرحباً بعودتك',
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 6),
                          Text('سجّل الدخول لمتابعة مقرراتك ومهامك الأكاديمية.',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          const SizedBox(height: 30),
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
                          const SizedBox(height: 18),
                          TextFormField(
                              controller: password,
                              enabled: !submitting,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => submit(),
                              key: const ValueKey('login-password'),
                              obscureText: !reveal,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                  labelText: 'كلمة المرور',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                      tooltip: reveal
                                          ? 'إخفاء كلمة المرور'
                                          : 'إظهار كلمة المرور',
                                      onPressed: submitting
                                          ? null
                                          : () =>
                                              setState(() => reveal = !reveal),
                                      icon: Icon(reveal
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined))),
                              validator: (value) => (value ?? '').isEmpty
                                  ? 'أدخل كلمة المرور.'
                                  : null),
                          const SizedBox(height: 24),
                          if (error != null) ...[
                            NoticeBanner(error!,
                                icon: Icons.error_outline, isError: true),
                            const SizedBox(height: 16),
                          ],
                          AsyncButton(
                              enabled: !submitting,
                              label: submitting
                                  ? 'جار تسجيل الدخول...'
                                  : 'تسجيل الدخول',
                              icon: Icons.arrow_back,
                              onPressed: submit),
                          const SizedBox(height: 24),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.verified_user_outlined,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        'استخدم بيانات حسابك الجامعي. إذا تعذر الدخول، تواصل مع مسؤول النظام.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant))),
                              ]),
                          if (widget.state.startupError != null) ...[
                            const SizedBox(height: 16),
                            EmptyPanel('تعذر استعادة الجلسة',
                                widget.state.startupError!),
                          ],
                        ])))),
      );

  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Center(
              child: SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 32 : 16),
            child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 1060 : 460),
                child: wide
                    ? IntrinsicHeight(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            const Expanded(child: _UniversityPanel()),
                            const SizedBox(width: 24),
                            Expanded(child: loginForm(context, true)),
                          ]))
                    : loginForm(context, false)),
          ));
        }),
      ));
}

class _UniversityPanel extends StatelessWidget {
  const _UniversityPanel();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Brand.brownDark, borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.all(36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Image.asset('assets/images/logo.png',
                    height: 56, width: 56)),
            const SizedBox(width: 16),
            const Expanded(
                child: Text('جامعة أسيوط الأهلية\nASSIUT NATIONAL UNIVERSITY',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12, height: 1.9))),
          ]),
          const SizedBox(height: 40),
          const Text('حضورك يصنع الفرق.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text('تجربة أكاديمية أوضح، من أول محاضرة إلى آخر تقييم.',
              style: TextStyle(
                  color: Color(0xFFE9DCCC), fontSize: 15, height: 1.9)),
          const SizedBox(height: 26),
          const _UniversityFeature(
              Icons.event_available_outlined, 'الحضور والمحاضرات'),
          const _UniversityFeature(
              Icons.auto_stories_outlined, 'المقررات والكويزات'),
          const _UniversityFeature(
              Icons.insights_outlined, 'الدرجات والمتابعة'),
          const SizedBox(height: 24),
          const Spacer(),
          const SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(painter: _CampusPainter())),
          const SizedBox(height: 20),
          const Text('نظام الحضور والتقييم الأكاديمي',
              style: TextStyle(color: Brand.gold, fontSize: 12)),
        ]),
      );
}

class _UniversityFeature extends StatelessWidget {
  const _UniversityFeature(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Icon(icon, color: Brand.gold, size: 20),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(color: Color(0xFFF0E6DA), fontSize: 13)),
      ]));
}

class _CampusPainter extends CustomPainter {
  const _CampusPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Brand.gold.withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()..color = Brand.gold.withValues(alpha: .07);
    final w = size.width, h = size.height;
    final roof = Path()
      ..moveTo(w * .16, h * .40)
      ..lineTo(w * .50, h * .10)
      ..lineTo(w * .84, h * .40)
      ..close();
    canvas.drawPath(roof, fill);
    canvas.drawPath(roof, line);
    canvas.drawRect(Rect.fromLTRB(w * .19, h * .44, w * .81, h * .91), line);
    for (var i = 0; i < 5; i++) {
      final x = w * (.25 + i * .115);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, h * .53, w * .055, h * .38),
              const Radius.circular(3)),
          line);
    }
    canvas.drawLine(Offset(w * .11, h * .94), Offset(w * .89, h * .94), line);
    canvas.drawLine(Offset(w * .06, h * .99), Offset(w * .94, h * .99), line);
  }

  @override
  bool shouldRepaint(_CampusPainter oldDelegate) => false;
}
