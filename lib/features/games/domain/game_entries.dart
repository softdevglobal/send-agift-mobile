/// Game entries: earned by buying products a seller promotes, and spent to
/// play skill games in this app. They cannot be bought or sent to anyone.
library;

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// Whether the customer may earn entries, or play, where they live, and the
/// rules of that place.
class EntryGate {
  const EntryGate({
    required this.allowed,
    this.code,
    this.message,
    this.minAge = 0,
    this.officialRules,
    this.freeEntriesPerDay = 0,
  });

  factory EntryGate.fromJson(Map<String, dynamic> json) => EntryGate(
    allowed: json['allowed'] as bool? ?? false,
    code: json['code'] as String?,
    message: json['message'] as String?,
    minAge: _int(json['min_age']) ?? 0,
    officialRules: json['official_rules'] as String?,
    freeEntriesPerDay: _int(json['free_entries_per_day']) ?? 0,
  );

  final bool allowed;

  /// Why not, e.g. STATE_REQUIRED or REGION_NOT_AVAILABLE.
  final String? code;
  final String? message;
  final int minAge;
  final String? officialRules;
  final int freeEntriesPerDay;

  bool get needsState => code == 'STATE_REQUIRED';
}

/// One change to the customer's entries.
class GameEntryRow {
  const GameEntryRow({
    required this.id,
    required this.entryType,
    required this.delta,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
    this.orderNumber,
    this.reason,
  });

  factory GameEntryRow.fromJson(Map<String, dynamic> json) => GameEntryRow(
    id: json['id'] as String? ?? '',
    entryType: json['entry_type'] as String? ?? '',
    delta: _int(json['delta']) ?? 0,
    balanceAfter: _int(json['balance_after']) ?? 0,
    description: json['description'] as String? ?? 'Game entries',
    createdAt: _date(json['created_at']) ?? DateTime.now(),
    orderNumber: json['order_number'] as String?,
    reason: json['reason'] as String?,
  );

  final String id;

  /// purchase_grant, purchase_reversal, play_debit, play_refund,
  /// free_entry, admin_grant or admin_deduction.
  final String entryType;
  final int delta;
  final int balanceAfter;
  final String description;
  final DateTime createdAt;
  final String? orderNumber;
  final String? reason;

  bool get isCredit => delta > 0;
}

/// Sums of the customer's history. Pending is promised on orders whose
/// payment is not confirmed yet; it cannot be spent.
class GameEntriesTotals {
  const GameEntriesTotals({
    this.earned = 0,
    this.spent = 0,
    this.reversed = 0,
    this.pending = 0,
  });

  factory GameEntriesTotals.fromJson(Map<String, dynamic> json) =>
      GameEntriesTotals(
        earned: _int(json['earned']) ?? 0,
        spent: _int(json['spent']) ?? 0,
        reversed: _int(json['reversed']) ?? 0,
        pending: _int(json['pending']) ?? 0,
      );

  final int earned;
  final int spent;
  final int reversed;
  final int pending;
}

/// The customer's entries: balance, totals, history, and whether they can
/// earn and play where they live.
class GameEntriesWallet {
  const GameEntriesWallet({
    required this.balance,
    this.totals = const GameEntriesTotals(),
    this.history = const [],
    this.earn,
    this.play,
  });

  factory GameEntriesWallet.fromJson(Map<String, dynamic> json) {
    final history = json['history'];
    final totals = json['totals'];
    final earn = json['earn'];
    final play = json['play'];
    return GameEntriesWallet(
      balance: _int(json['balance']) ?? 0,
      totals: totals is Map<String, dynamic>
          ? GameEntriesTotals.fromJson(totals)
          : const GameEntriesTotals(),
      history: history is List
          ? history
                .whereType<Map<String, dynamic>>()
                .map(GameEntryRow.fromJson)
                .toList(growable: false)
          : const [],
      earn: earn is Map<String, dynamic> ? EntryGate.fromJson(earn) : null,
      play: play is Map<String, dynamic> ? EntryGate.fromJson(play) : null,
    );
  }

  final int balance;
  final GameEntriesTotals totals;
  final List<GameEntryRow> history;
  final EntryGate? earn;
  final EntryGate? play;
}

/// A state or region of a country.
class StateOption {
  const StateOption({required this.id, required this.code, required this.name});

  factory StateOption.fromJson(Map<String, dynamic> json) => StateOption(
    id: json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );

  final String id;
  final String code;
  final String name;
}

/// The state on the customer's account.
class CustomerState {
  const CustomerState({
    required this.countryId,
    required this.stateRequired,
    this.state,
    this.canChangeAt,
    this.phoneVerified = false,
  });

  factory CustomerState.fromJson(Map<String, dynamic> json) {
    final state = json['state'];
    return CustomerState(
      countryId: json['country_id'] as String? ?? '',
      stateRequired: json['state_required'] as bool? ?? false,
      state: state is Map<String, dynamic> ? StateOption.fromJson(state) : null,
      canChangeAt: _date(json['can_change_at']),
      phoneVerified: json['phone_verified'] as bool? ?? false,
    );
  }

  final String countryId;

  /// True when the country has states and the customer has not given one.
  final bool stateRequired;
  final StateOption? state;
  final DateTime? canChangeAt;
  final bool phoneVerified;

  bool get locked =>
      state != null &&
      canChangeAt != null &&
      canChangeAt!.isAfter(DateTime.now());
}

/// What a cart would earn, worked out on the server for this customer.
class EntryOffers {
  const EntryOffers({
    required this.total,
    this.message,
    this.byProduct = const {},
  });

  factory EntryOffers.fromJson(Map<String, dynamic> json) {
    final offers = json['offers'];
    final map = <String, int>{};
    String? note;
    if (offers is List) {
      for (final o in offers.whereType<Map<String, dynamic>>()) {
        final n = _int(o['game_entries']) ?? 0;
        map[o['product_id'] as String? ?? ''] = n;
        final reason = o['reason'] as String?;
        if (n == 0 && reason != null && reason.isNotEmpty) note ??= reason;
      }
    }
    return EntryOffers(
      total: _int(json['total_game_entries']) ?? 0,
      message: note,
      byProduct: map,
    );
  }

  final int total;

  /// Why something will not earn, when the server says so.
  final String? message;
  final Map<String, int> byProduct;
}

String entriesLabel(int n) => '$n game ${n == 1 ? 'entry' : 'entries'}';
