// Admin console data. These mirror the server's allowlisted fields: counts
// and timestamps only, never amounts, notes or chat text.

class AdminDayPoint {
  final DateTime day;
  final int activeTesters;
  final int hamiTokens;

  const AdminDayPoint({required this.day, required this.activeTesters, required this.hamiTokens});

  factory AdminDayPoint.fromJson(Map<String, dynamic> json) => AdminDayPoint(
        day: DateTime.parse(json['day'] as String),
        activeTesters: json['active_testers'] as int,
        hamiTokens: json['hami_tokens'] as int,
      );
}

class AdminOverview {
  final int testersTotal;
  final int activeToday;
  final int active7d;
  final int active30d;
  final int new7d;
  final int hamiMessages7d;
  final int hamiTokens7d;
  final List<AdminDayPoint> daily;
  final DateTime? trackingSince;

  const AdminOverview({
    required this.testersTotal,
    required this.activeToday,
    required this.active7d,
    required this.active30d,
    required this.new7d,
    required this.hamiMessages7d,
    required this.hamiTokens7d,
    required this.daily,
    required this.trackingSince,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> json) => AdminOverview(
        testersTotal: json['testers_total'] as int,
        activeToday: json['active_today'] as int,
        active7d: json['active_7d'] as int,
        active30d: json['active_30d'] as int,
        new7d: json['new_7d'] as int,
        hamiMessages7d: json['hami_messages_7d'] as int,
        hamiTokens7d: json['hami_tokens_7d'] as int,
        daily: (json['daily'] as List).map((d) => AdminDayPoint.fromJson((d as Map).cast<String, dynamic>())).toList(),
        trackingSince: json['tracking_since'] == null ? null : DateTime.parse(json['tracking_since'] as String),
      );
}

class AdminTester {
  final int id;
  final String name;
  final String email;
  final DateTime joinedAt;
  final DateTime? lastActiveAt;
  final int daysActive30d;
  final int transactionsCount;
  final int budgetsCount;
  final int goalsCount;
  final int hamiMessagesTotal;
  final int hamiTokensTotal;
  final int hamiTokens7d;
  final int hamiTokensChat;
  final int hamiTokensInsight;

  const AdminTester({
    required this.id,
    required this.name,
    required this.email,
    required this.joinedAt,
    required this.lastActiveAt,
    required this.daysActive30d,
    required this.transactionsCount,
    required this.budgetsCount,
    required this.goalsCount,
    required this.hamiMessagesTotal,
    required this.hamiTokensTotal,
    required this.hamiTokens7d,
    required this.hamiTokensChat,
    required this.hamiTokensInsight,
  });

  factory AdminTester.fromJson(Map<String, dynamic> json) => AdminTester(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        joinedAt: DateTime.parse(json['joined_at'] as String),
        lastActiveAt: json['last_active_at'] == null ? null : DateTime.parse(json['last_active_at'] as String),
        daysActive30d: json['days_active_30d'] as int,
        transactionsCount: json['transactions_count'] as int,
        budgetsCount: json['budgets_count'] as int,
        goalsCount: json['goals_count'] as int,
        hamiMessagesTotal: json['hami_messages_total'] as int,
        hamiTokensTotal: json['hami_tokens_total'] as int,
        hamiTokens7d: json['hami_tokens_7d'] as int,
        hamiTokensChat: json['hami_tokens_chat'] as int,
        hamiTokensInsight: json['hami_tokens_insight'] as int,
      );

  String lastActiveLabel(DateTime now) {
    final last = lastActiveAt;
    if (last == null) return 'Never active';
    final gap = now.difference(last);
    if (gap.inMinutes < 1) return 'Active just now';
    if (gap.inHours < 1) return 'Active ${gap.inMinutes}m ago';
    if (gap.inDays < 1) return 'Active ${gap.inHours}h ago';
    return 'Active ${gap.inDays}d ago';
  }
}

class AdminTesterPage {
  final List<AdminTester> items;
  final int total;

  const AdminTesterPage({required this.items, required this.total});

  factory AdminTesterPage.fromJson(Map<String, dynamic> json) => AdminTesterPage(
        items: (json['items'] as List).map((t) => AdminTester.fromJson((t as Map).cast<String, dynamic>())).toList(),
        total: json['total'] as int,
      );
}

class AdminAccessEntry {
  final String path;
  final DateTime createdAt;

  const AdminAccessEntry({required this.path, required this.createdAt});

  factory AdminAccessEntry.fromJson(Map<String, dynamic> json) => AdminAccessEntry(
        path: json['path'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
