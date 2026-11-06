import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserPreferences {
  const UserPreferences({this.courseId, this.sectionId, this.darkMode = false});
  final int? courseId, sectionId;
  final bool darkMode;
  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
          courseId: json['course_id'] as int?,
          sectionId: json['section_id'] as int?,
          darkMode: json['dark_mode'] == true);
  Map<String, dynamic> toJson() => {
        'course_id': courseId,
        'section_id': sectionId,
        'dark_mode': darkMode,
      };
}

abstract interface class PreferencesStore {
  Future<UserPreferences?> read(int userId);
  Future<void> write(int userId, UserPreferences value);
}

class SecurePreferencesStore implements PreferencesStore {
  const SecurePreferencesStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<UserPreferences?> read(int userId) async {
    final text = await _storage.read(key: 'attendance_preferences_$userId');
    if (text == null) return null;
    return UserPreferences.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }

  @override
  Future<void> write(int userId, UserPreferences value) => _storage.write(
      key: 'attendance_preferences_$userId', value: jsonEncode(value.toJson()));
}
