import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_pdf.dart';

class RecentService {
  static const String _key = 'recent_pdfs';

  static Future<List<RecentPdf>> getRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null || data.isEmpty) return [];

    try {
      final List<dynamic> jsonList = json.decode(data);
      final recents = jsonList.map((e) => RecentPdf.fromMap(e)).toList();
      recents.sort((a, b) => b.lastOpenedTimestamp.compareTo(a.lastOpenedTimestamp));
      return recents;
    } catch (_) {
      return [];
    }
  }

  static Future<void> addOrUpdateRecent({
    required String path,
    required String name,
    int totalPages = 0,
    int lastPage = 1,
  }) async {
    final recents = await getRecents();
    final now = DateTime.now().millisecondsSinceEpoch;

    final index = recents.indexWhere((element) => element.path == path);
    if (index >= 0) {
      final old = recents[index];
      recents[index] = RecentPdf(
        path: path,
        name: name,
        lastOpenedTimestamp: now,
        totalPages: totalPages > 0 ? totalPages : old.totalPages,
        lastPage: lastPage > 0 ? lastPage : old.lastPage,
      );
    } else {
      recents.insert(
        0,
        RecentPdf(
          path: path,
          name: name,
          lastOpenedTimestamp: now,
          totalPages: totalPages,
          lastPage: lastPage,
        ),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(recents.map((e) => e.toMap()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<void> removeRecent(String path) async {
    final recents = await getRecents();
    recents.removeWhere((element) => element.path == path);
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(recents.map((e) => e.toMap()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
