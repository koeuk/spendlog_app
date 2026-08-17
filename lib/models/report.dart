/// The periods `GET /reports` will chart, in the order the toggle shows them.
/// Values match App\Enums\TrendGranularity on the server; anything else falls
/// back to `month` there rather than erroring.
///
/// Lives with the model rather than in one screen because the Reports tab and
/// the dashboard's spending card both offer the same four.
const trendGranularities = [
  (value: 'week', label: 'Week'),
  (value: 'month', label: 'Month'),
  (value: 'year', label: 'Year'),
  (value: 'all', label: 'All'),
];

/// GET /api/v1/reports — the trend chart, breakdown and headline stats.
///
/// Money fields arrive as strings per the API convention; only the chart
/// parses them into numbers, because bar heights are geometry, not money.
class ReportBucket {
  const ReportBucket({
    required this.key,
    required this.label,
    required this.caption,
    required this.value,
    required this.isCurrent,
    required this.isFuture,
  });

  final String key;
  final String label;
  final String caption;
  final String value;

  /// Highlighted as "now" by the chart.
  final bool isCurrent;

  /// Drawn empty, not as zero — "nothing spent" and "not yet" are different
  /// claims, and the API marks the difference.
  final bool isFuture;

  double get amount => double.tryParse(value) ?? 0;

  factory ReportBucket.fromJson(Map<String, dynamic> json) => ReportBucket(
        key: json['key']?.toString() ?? '',
        label: json['label'] as String? ?? '',
        caption: json['caption'] as String? ?? '',
        value: json['value']?.toString() ?? '0.00',
        isCurrent: json['is_current'] as bool? ?? false,
        isFuture: json['is_future'] as bool? ?? false,
      );
}

class ReportSeries {
  const ReportSeries({
    required this.label,
    required this.total,
    required this.buckets,
  });

  final String label;
  final String total;
  final List<ReportBucket> buckets;

  factory ReportSeries.fromJson(Map<String, dynamic> json) => ReportSeries(
        label: json['label'] as String? ?? '',
        total: json['total']?.toString() ?? '0.00',
        buckets: (json['buckets'] as List<dynamic>? ?? [])
            .map((e) => ReportBucket.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One category's slice of the period, largest first.
class ReportSlice {
  const ReportSlice({
    required this.uuid,
    required this.name,
    required this.color,
    required this.total,
    required this.count,
    required this.average,
    required this.share,
    this.icon,
  });

  final String uuid;
  final String name;
  final String color;
  final String? icon;
  final String total;
  final int count;
  final String average;
  final num share;

  factory ReportSlice.fromJson(Map<String, dynamic> json) => ReportSlice(
        uuid: json['uuid']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? 'slate',
        icon: json['icon'] as String?,
        total: json['total']?.toString() ?? '0.00',
        count: json['count'] as int? ?? 0,
        average: json['average']?.toString() ?? '0.00',
        share: json['share'] as num? ?? 0,
      );
}

class ReportStats {
  const ReportStats({
    required this.total,
    required this.count,
    required this.dailyAverage,
    required this.previous,
    required this.previousIsPartial,
    this.changePercent,
    this.previousLabel,
  });

  final String total;
  final int count;
  final String dailyAverage;
  final String previous;

  /// Null when there is nothing to compare against — not zero, so the UI can
  /// say nothing instead of claiming "+100%".
  final num? changePercent;

  final String? previousLabel;

  /// True while the current period is still running: `previous` then holds
  /// only the same elapsed stretch of the period before.
  final bool previousIsPartial;

  factory ReportStats.fromJson(Map<String, dynamic> json) => ReportStats(
        total: json['total']?.toString() ?? '0.00',
        count: json['count'] as int? ?? 0,
        dailyAverage: json['daily_average']?.toString() ?? '0.00',
        previous: json['previous']?.toString() ?? '0.00',
        changePercent: json['change_percent'] as num?,
        previousLabel: json['previous_label'] as String?,
        previousIsPartial: json['previous_is_partial'] as bool? ?? false,
      );
}

class PeriodOption {
  const PeriodOption({required this.value, required this.label});

  final String value;
  final String label;

  factory PeriodOption.fromJson(Map<String, dynamic> json) => PeriodOption(
        value: json['value']?.toString() ?? '',
        label: json['label'] as String? ?? '',
      );
}

/// The breakdown row under its other name — both are in circulation.
typedef ReportBreakdownRow = ReportSlice;

class Report {
  const Report({
    required this.granularity,
    required this.anchor,
    required this.periodLabel,
    required this.options,
    required this.series,
    required this.breakdown,
    required this.stats,
  });

  final String granularity;
  final String anchor;
  final String periodLabel;
  final List<PeriodOption> options;
  final ReportSeries series;
  final List<ReportSlice> breakdown;
  final ReportStats stats;

  // Flat aliases — some call sites read the series' fields off the report.
  String get seriesLabel => series.label;
  String get seriesTotal => series.total;
  List<ReportBucket> get buckets => series.buckets;

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        granularity: json['granularity'] as String? ?? 'month',
        anchor: json['anchor']?.toString() ?? '',
        periodLabel: json['period_label'] as String? ?? '',
        options: (json['options'] as List<dynamic>? ?? [])
            .map((e) => PeriodOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        series: ReportSeries.fromJson(json['series'] as Map<String, dynamic>? ?? {}),
        breakdown: (json['breakdown'] as List<dynamic>? ?? [])
            .map((e) => ReportSlice.fromJson(e as Map<String, dynamic>))
            .toList(),
        stats: ReportStats.fromJson(json['stats'] as Map<String, dynamic>? ?? {}),
      );
}
