import 'dart:convert';

class RecentPdf {
  final String path;
  final String name;
  final int lastOpenedTimestamp;
  final int totalPages;
  final int lastPage;

  RecentPdf({
    required this.path,
    required this.name,
    required this.lastOpenedTimestamp,
    this.totalPages = 0,
    this.lastPage = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'lastOpenedTimestamp': lastOpenedTimestamp,
      'totalPages': totalPages,
      'lastPage': lastPage,
    };
  }

  factory RecentPdf.fromMap(Map<String, dynamic> map) {
    return RecentPdf(
      path: map['path'] ?? '',
      name: map['name'] ?? '',
      lastOpenedTimestamp: map['lastOpenedTimestamp'] ?? 0,
      totalPages: map['totalPages'] ?? 0,
      lastPage: map['lastPage'] ?? 1,
    );
  }

  String toJson() => json.encode(toMap());

  factory RecentPdf.fromJson(String source) =>
      RecentPdf.fromMap(json.decode(source));
}
