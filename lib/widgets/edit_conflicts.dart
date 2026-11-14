import 'package:flutter/material.dart';

enum ConflictChoice { server, local }

Future<ConflictChoice?> reviewEditConflict(BuildContext context,
    {required List<String> differences, required bool canReapply}) {
  return showDialog<ConflictChoice>(
      context: context,
      builder: (dialog) => AlertDialog(
            title: const Text('تعارض في الحفظ · تعديلاتك محفوظة هنا'),
            content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      const Text(
                          'لم تُرسل تعديلاتك فوق نسخة أحدث. راجع القيم قبل اختيار ما تحتفظ به.'),
                      for (final difference in differences) ...[
                        const Divider(),
                        SelectableText(difference),
                      ],
                      if (!canReapply)
                        const Text(
                            'أصبحت الجلسة معتمدة. يمكنك نسخ تعديلاتك للمراجعة، ولا يمكن تعديل السجل المعتمد.'),
                    ]))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('الرجوع دون تغيير')),
              TextButton(
                  onPressed: () => Navigator.pop(dialog, ConflictChoice.server),
                  child: const Text('تجاهل تعديلاتي وتحميل نسخة الخادم')),
              if (canReapply)
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(dialog, ConflictChoice.local),
                    child: const Text('الاحتفاظ بتعديلاتي للمراجعة ثم الحفظ')),
            ],
          ));
}
