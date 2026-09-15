/// Money borrowed from someone — a friend, family, a bank — with a ledger of
/// repayments against it. What is still owed is `amount − repaid`, derived
/// server-side on every read and never stored, so the figures here are
/// already consistent with the ledger beneath them.
class Borrowing {
  const Borrowing({
    required this.uuid,
    required this.lender,
    required this.lenderType,
    required this.amount,
    required this.repaid,
    required this.remaining,
    required this.percentRepaid,
    required this.settled,
    required this.overdue,
    required this.borrowedOn,
    this.dueOn,
    this.note,
    this.repaymentsCount = 0,
    this.repayments = const [],
  });

  final String uuid;

  /// Who lent it — free text ("Mom", "ABA Bank").
  final String lender;

  /// One of [lenderTypes].
  final String lenderType;

  /// Money is a string ("200.00") end to end — see the API doc's money note.
  final String amount;
  final String repaid;
  final String remaining;

  /// 0..100, already capped, so it can drive a bar directly.
  final num percentRepaid;

  /// Paid back in full.
  final bool settled;

  /// Not settled, and the due date has passed.
  final bool overdue;

  final String borrowedOn;

  /// Optional: a loan from a friend rarely has one.
  final String? dueOn;

  final String? note;

  /// On a listing; the ledger itself comes with a single borrowing.
  final int repaymentsCount;

  /// Newest first. Only filled by GET /borrowings/{uuid}.
  final List<BorrowingRepayment> repayments;

  factory Borrowing.fromJson(Map<String, dynamic> json) => Borrowing(
    uuid: json['uuid'] as String,
    lender: json['lender'] as String? ?? '',
    lenderType: json['lender_type'] as String? ?? 'other',
    amount: json['amount'] as String? ?? '0.00',
    repaid: json['repaid'] as String? ?? '0.00',
    remaining: json['remaining'] as String? ?? '0.00',
    percentRepaid: json['percent_repaid'] as num? ?? 0,
    settled: json['settled'] as bool? ?? false,
    overdue: json['overdue'] as bool? ?? false,
    borrowedOn: json['borrowed_on'] as String? ?? '',
    dueOn: json['due_on'] as String?,
    note: json['note'] as String?,
    repaymentsCount: (json['repayments_count'] as num?)?.toInt() ?? 0,
    repayments: (json['repayments'] as List<dynamic>? ?? [])
        .map((e) => BorrowingRepayment.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// One line in a borrowing's ledger: money paid back on a day. Always
/// positive — money going the other way is a new borrowing.
class BorrowingRepayment {
  const BorrowingRepayment({
    required this.uuid,
    required this.amount,
    required this.paidOn,
    this.note,
  });

  final String uuid;
  final String amount;
  final String paidOn;
  final String? note;

  factory BorrowingRepayment.fromJson(Map<String, dynamic> json) =>
      BorrowingRepayment(
        uuid: json['uuid'] as String,
        amount: json['amount'] as String? ?? '0.00',
        paidOn: json['paid_on'] as String? ?? '',
        note: json['note'] as String?,
      );
}

/// One line of GET /borrowings/summary's `by_lender_type`: what is still owed
/// to one kind of lender. Only kinds with something outstanding appear,
/// largest first.
class LenderTypeOutstanding {
  const LenderTypeOutstanding({
    required this.lenderType,
    required this.label,
    required this.outstanding,
    required this.count,
  });

  final String lenderType;

  /// Already in the app locale, resolved server-side.
  final String label;

  final String outstanding;
  final int count;

  factory LenderTypeOutstanding.fromJson(Map<String, dynamic> json) =>
      LenderTypeOutstanding(
        lenderType: json['lender_type'] as String? ?? 'other',
        label: json['label'] as String? ?? '',
        outstanding: json['outstanding'] as String? ?? '0.00',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

/// The headline figures over everything ever borrowed. All time, not a
/// month: a debt is not a monthly thing.
class BorrowingSummary {
  const BorrowingSummary({
    required this.outstanding,
    required this.borrowed,
    required this.repaid,
    required this.openCount,
    required this.settledCount,
    required this.overdueCount,
    required this.byLenderType,
  });

  final String outstanding;
  final String borrowed;
  final String repaid;
  final int openCount;
  final int settledCount;
  final int overdueCount;
  final List<LenderTypeOutstanding> byLenderType;

  factory BorrowingSummary.fromJson(Map<String, dynamic> json) =>
      BorrowingSummary(
        outstanding: json['outstanding'] as String? ?? '0.00',
        borrowed: json['borrowed'] as String? ?? '0.00',
        repaid: json['repaid'] as String? ?? '0.00',
        openCount: (json['open_count'] as num?)?.toInt() ?? 0,
        settledCount: (json['settled_count'] as num?)?.toInt() ?? 0,
        overdueCount: (json['overdue_count'] as num?)?.toInt() ?? 0,
        byLenderType: (json['by_lender_type'] as List<dynamic>? ?? [])
            .map(
              (e) => LenderTypeOutstanding.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
}

/// One of the fixed lender kinds, labelled server-side for the app locale.
class LenderType {
  const LenderType({required this.value, required this.label});

  final String value;
  final String label;

  factory LenderType.fromJson(Map<String, dynamic> json) => LenderType(
    value: json['value'] as String? ?? 'other',
    label: json['label'] as String? ?? '',
  );
}

/// GET /borrowings/lenders: everything the form's pickers need in one call.
class LenderOptions {
  const LenderOptions({required this.lenders, required this.types});

  /// The names this account has used, most frequent first.
  final List<String> lenders;

  final List<LenderType> types;

  factory LenderOptions.fromJson(Map<String, dynamic> json) => LenderOptions(
    lenders: (json['lenders'] as List<dynamic>? ?? []).cast<String>(),
    types: (json['types'] as List<dynamic>? ?? [])
        .map((e) => LenderType.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// The five kinds, in the order the web's picker shows them. A fallback for
/// when the lenders call has not landed: a row still needs a label, and the
/// form still needs pills to pick from.
const lenderTypes = ['friend', 'family', 'bank', 'employer', 'other'];

/// The English label for a type, for [tr] to translate.
String lenderTypeLabel(String type) => switch (type) {
  'friend' => 'Friend',
  'family' => 'Family',
  'bank' => 'Bank',
  'employer' => 'Employer',
  _ => 'Other',
};
