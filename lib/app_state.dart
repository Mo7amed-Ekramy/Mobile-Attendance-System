import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data/api.dart';
import 'data/models.dart';
import 'data/preferences.dart';

class AppState extends ChangeNotifier {
  AppState(this.api, {PreferencesStore? preferences})
      : preferences = preferences ?? const SecurePreferencesStore() {
    api.onSessionExpired = expire;
  }
  final AttendanceApi api;
  final PreferencesStore preferences;
  int? _rememberedCourse, _rememberedSection;
  Future<void> _preferenceWrites = Future.value();
  UserProfile? user;
  List<CourseOffering> courses = [];
  CourseOffering? course;
  CourseSection? section;
  bool restoring = true;
  bool darkMode = false;
  int refreshRevision = 0;
  String? startupError;

  Future<void> restore() async {
    try {
      api.token = await api.tokens.read();
      if (api.token != null) {
        user = await api.me();
        await _restorePreferences();
        await refreshCourses();
      }
    } catch (error) {
      if (error is! ApiException || error.status != 401) {
        startupError = '$error';
      }
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String identifier, String password) async {
    user = await api.login(identifier, password);
    await _restorePreferences();
    startupError = null;
    try {
      await refreshCourses();
    } finally {
      notifyListeners();
    }
  }

  Future<void> refreshCourses() async {
    try {
      final loaded = await api.courses();
      if (user == null) return;
      courses = loaded;
      startupError = null;
    } catch (error) {
      startupError = '$error';
      notifyListeners();
      rethrow;
    }
    final previous = course?.id ?? _rememberedCourse;
    course = courses.where((item) => item.id == previous).firstOrNull ??
        courses.firstOrNull;
    final selected = section?.id ?? _rememberedSection;
    section = course?.sections.where((item) => item.id == selected).firstOrNull;
    if (user?.role != Role.doctor) section ??= course?.sections.firstOrNull;
    _rememberedCourse = null;
    _rememberedSection = null;
    _savePreferences();
    refreshRevision++;
    notifyListeners();
  }

  void selectCourse(CourseOffering selected) {
    course = selected;
    section = user?.role == Role.doctor ? null : selected.sections.firstOrNull;
    _savePreferences();
    refreshRevision++;
    notifyListeners();
  }

  void selectSection(CourseSection? selected) {
    section = selected;
    _savePreferences();
    refreshRevision++;
    notifyListeners();
  }

  void toggleTheme(bool value) {
    darkMode = value;
    _savePreferences();
    notifyListeners();
  }

  void expire() {
    user = null;
    courses = [];
    course = null;
    section = null;
    darkMode = false;
    _rememberedCourse = null;
    _rememberedSection = null;
    api.token = null;
    unawaited(api.tokens.write(null).catchError((Object error) {}));
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await api.logout();
    } finally {
      expire();
    }
  }

  String get scopeKey =>
      '${user?.id}:${course?.id}:${section?.id}:$refreshRevision';

  Future<void> _restorePreferences() async {
    final id = user!.id;
    // Preferences never carry a previous account's navigation or theme.
    courses = [];
    course = null;
    section = null;
    darkMode = false;
    _rememberedCourse = null;
    _rememberedSection = null;
    try {
      final saved = await preferences.read(id);
      if (user?.id != id || saved == null) return;
      darkMode = saved.darkMode;
      _rememberedCourse = saved.courseId;
      _rememberedSection = saved.sectionId;
    } catch (_) {
      // A missing/unreadable preference must not prevent university login.
    }
  }

  void _savePreferences() {
    final id = user?.id;
    if (id == null) return;
    final saved = UserPreferences(
        courseId: course?.id, sectionId: section?.id, darkMode: darkMode);
    _preferenceWrites = _preferenceWrites
        .then((_) => preferences.write(id, saved))
        .catchError((Object _) {});
  }

  Future<void> flushPreferences() => _preferenceWrites;
}
