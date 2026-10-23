# 📱 نظام الحضور الذكي — جامعة أسيوط الأهلية
### Mobile Attendance System — Assiut National University

> تطبيق فلاتر متكامل لإدارة الحضور والتقييم الأكاديمي، يدعم أدوار متعددة (دكتور، معيد، طالب) مع بيانات حقيقية من قاعدة بيانات الجامعة.

---

## 🗂️ هيكل المشروع

```
mobile/
├── lib/
│   ├── app.dart              # الشاشات وكل منطق الواجهة
│   ├── theme.dart            # نظام الألوان والخطوط (Brand)
│   ├── mock_data.dart        # DemoState + بيانات الجلسة
│   └── college_database.dart # قاعدة بيانات الجامعة (415 طالب، 36 موظف)
├── assets/
│   └── images/
│       └── logo.png          # شعار الجامعة
├── android/                  # إعدادات Android
├── web/                      # إعدادات Flutter Web
└── pubspec.yaml
```

---

## ⚡ متطلبات التشغيل

| أداة | الإصدار المطلوب |
|------|----------------|
| Flutter SDK | ≥ 3.22.0 |
| Dart SDK | ≥ 3.4.0 |
| Android Studio | Hedgehog أو أحدث |
| Chrome | أي إصدار حديث |

تحقق من البيئة:
```bash
flutter doctor
```

---

## 🚀 تشغيل المشروع

### 1️⃣ تثبيت الاعتماديات

```bash
flutter pub get
```

---

### 2️⃣ تشغيل على الويب (Dev Mode)

```bash
flutter run -d chrome
```

أو على بورت معين:
```bash
flutter run -d web-server --web-port=8080 --web-hostname=localhost
```

ثم افتح المتصفح على: `http://localhost:8080`

---

### 3️⃣ تشغيل على الموبايل (Dev Mode)

تأكد أن جهازك متصل أو المحاكي شغّال:
```bash
flutter devices
```

ثم شغّل:
```bash
flutter run
```

لتحديد جهاز معين:
```bash
flutter run -d <device-id>
```

---

### 4️⃣ تشغيل عبر Android Studio

1. افتح **Android Studio**
2. اختر **Open** → حدد مجلد `mobile/`
3. من شريط الأدوات اختر الجهاز (محاكي أو جهاز حقيقي)
4. اضغط **▶ Run** أو `Shift+F10`

> لتفعيل Hot Reload أثناء التشغيل اضغط **⚡ (Lightning bolt)** أو `Ctrl+\`

---

## 🔑 حسابات تجريبية

| الدور | معرف المستخدم | كلمة المرور |
|-------|--------------|-------------|
| 👨‍🏫 دكتور | `doc_rasha01` | `pass123` |
| 🎓 معيد | `ta_nehad00` | `pass123` |
| 👨‍🎓 طالب | `20720236007` | `pass123` |

---

## 🏗️ بناء ملف الإنتاج

**Web:**
```bash
flutter build web --release
```
الملفات ستكون في `build/web/`

**Android APK:**
```bash
flutter build apk --release
```
الملف في `build/app/outputs/flutter-apk/app-release.apk`

**Android App Bundle (للـ Play Store):**
```bash
flutter build appbundle --release
```

---

## 🗄️ قاعدة البيانات

التطبيق يستخدم `college_database.dart` كـ static mirror لقاعدة بيانات الجامعة الأصلية (.NET / EF Core):

- **415 طالب** مسجل بأسمائهم الحقيقية ورقم القيد
- **36 مستخدم** (دكاترة ومعيدين) بأرقامهم الوظيفية
- **14 مقرر دراسي** مع أقسامها وسكاشنها
- **19 قسم (section)** منتشرة على الأقسام العلمية

---

## 📄 الترخيص

هذا المشروع تعليمي خاص بجامعة أسيوط الأهلية.
