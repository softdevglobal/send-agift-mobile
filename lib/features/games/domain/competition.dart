import 'game.dart';

DateTime? _date(dynamic raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

int? _int(dynamic raw) => raw is num ? raw.toInt() : null;

const _currencySymbols = {
  'USD': r'$',
  'NZD': r'NZ$',
  'AUD': r'A$',
  'CAD': r'CA$',
  'SGD': r'S$',
  'GBP': '£',
  'EUR': '€',
  'INR': '₹',
  'LKR': 'Rs ',
  'JPY': '¥',
};

/// Minor units as money, e.g. 34800 USD → "\$348", 34850 → "\$348.50".
/// Whole amounts drop the cents so a prize reads as a headline.
String formatMoneyCents(int cents, String? currency) {
  final code = (currency ?? '').toUpperCase();
  final symbol = _currencySymbols[code] ?? (code.isEmpty ? '' : '$code ');
  final negative = cents < 0;
  final abs = cents.abs();
  final whole = abs ~/ 100;
  final grouped = whole.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final fraction = abs % 100 == 0
      ? ''
      : '.${(abs % 100).toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}$symbol$grouped$fraction';
}

/// A skill competition: one game, one country, fixed rules and a pre-funded
/// prize. Every entrant plays the identical board, and the highest verified
/// score wins — ties go to the fastest verified time.
///
/// The prize is either fixed or growing: a growing prize starts at
/// [startPrizeCents] and every eligible play adds [incrementPerPlayCents], up
/// to [maxPrizeCents]. The server's prize ledger is the only source of the
/// figure; [currentPrizeCents] is its latest value.
class Competition {
  const Competition({
    required this.id,
    required this.title,
    required this.status,
    required this.gameSlug,
    required this.gameName,
    required this.countryName,
    required this.startsAt,
    required this.endsAt,
    required this.pointsPerAttempt,
    required this.pointsDeductionEnabled,
    required this.maxAttempts,
    required this.minAge,
    required this.requiresIdentityVerification,
    required this.numberOfWinners,
    required this.prizeDescription,
    this.prizeValueAmount,
    this.prizeCurrency,
    this.officialRules,
    this.cancelReason,
    this.cancelNote,
    this.me,
    this.winners = const [],
    this.prizeGrowthEnabled = false,
    this.prizeType = 'cash',
    this.startPrizeCents = 0,
    this.currentPrizeCents = 0,
    this.incrementPerPlayCents = 0,
    this.maxPrizeCents,
    this.prizeCapReached = false,
    this.continueAtCap = true,
    this.finalPrizeCents,
    this.eligiblePlayCount = 0,
    this.uniquePlayerCount = 0,
    this.dailyPlayLimit,
    this.prizeVersion = 0,
    this.roundNo = 1,
    this.gameType = '',
    this.winnerMethod = 'score',
    this.winOdds,
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    final rawMe = json['me'];
    final rawWinners = json['winners'];
    return Competition(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'scheduled',
      gameSlug: json['game_slug'] as String? ?? '',
      gameName: json['game_name'] as String? ?? '',
      countryName: json['country_name'] as String? ?? '',
      startsAt: _date(json['starts_at']) ?? DateTime.now(),
      endsAt: _date(json['ends_at']) ?? DateTime.now(),
      pointsPerAttempt: _int(json['points_per_attempt']) ?? 0,
      pointsDeductionEnabled:
          json['points_deduction_enabled'] as bool? ?? false,
      maxAttempts: _int(json['max_attempts_per_customer']) ?? 0,
      minAge: _int(json['min_age']) ?? 18,
      requiresIdentityVerification:
          json['requires_identity_verification'] as bool? ?? true,
      numberOfWinners: _int(json['number_of_winners']) ?? 1,
      prizeDescription: json['prize_description'] as String? ?? '',
      prizeValueAmount: _int(json['prize_value_amount']),
      prizeCurrency: json['prize_currency'] as String?,
      officialRules: json['official_rules'] as String?,
      cancelReason: json['cancel_reason'] as String?,
      cancelNote: json['cancel_note'] as String?,
      me: rawMe is Map<String, dynamic> ? CompetitionMe.fromJson(rawMe) : null,
      winners: rawWinners is List
          ? rawWinners
                .whereType<Map<String, dynamic>>()
                .map(PublicWinner.fromJson)
                .toList(growable: false)
          : const [],
      prizeGrowthEnabled: json['prize_growth_enabled'] as bool? ?? false,
      prizeType: json['prize_type'] as String? ?? 'cash',
      startPrizeCents:
          _int(json['start_prize_cents']) ??
          _int(json['prize_value_amount']) ??
          0,
      currentPrizeCents:
          _int(json['current_prize_cents']) ??
          _int(json['prize_value_amount']) ??
          0,
      incrementPerPlayCents: _int(json['increment_per_play_cents']) ?? 0,
      maxPrizeCents: _int(json['max_prize_cents']),
      prizeCapReached: json['prize_cap_reached'] as bool? ?? false,
      continueAtCap: json['continue_at_cap'] as bool? ?? true,
      finalPrizeCents: _int(json['final_prize_cents']),
      eligiblePlayCount: _int(json['eligible_play_count']) ?? 0,
      uniquePlayerCount: _int(json['unique_player_count']) ?? 0,
      dailyPlayLimit: _int(json['daily_play_limit']),
      prizeVersion: _int(json['prize_version']) ?? 0,
      roundNo: _int(json['round_no']) ?? 1,
      gameType: json['game_type'] as String? ?? '',
      winnerMethod: json['winner_method'] as String? ?? 'score',
      winOdds: _int(json['win_odds']),
    );
  }

  /// The same round with a newer live prize from the event stream. An event
  /// older than what is shown is ignored.
  Competition withLive(LivePrize live) {
    if (live.version < prizeVersion) return this;
    return Competition(
      id: id,
      title: title,
      status: live.status ?? status,
      gameSlug: gameSlug,
      gameName: gameName,
      countryName: countryName,
      startsAt: startsAt,
      endsAt: endsAt,
      pointsPerAttempt: pointsPerAttempt,
      pointsDeductionEnabled: pointsDeductionEnabled,
      maxAttempts: maxAttempts,
      minAge: minAge,
      requiresIdentityVerification: requiresIdentityVerification,
      numberOfWinners: numberOfWinners,
      prizeDescription: prizeDescription,
      prizeValueAmount: prizeValueAmount,
      prizeCurrency: prizeCurrency,
      officialRules: officialRules,
      cancelReason: cancelReason,
      cancelNote: cancelNote,
      me: me,
      winners: winners,
      prizeGrowthEnabled: prizeGrowthEnabled,
      prizeType: prizeType,
      startPrizeCents: startPrizeCents,
      currentPrizeCents: live.currentPrizeCents,
      incrementPerPlayCents: incrementPerPlayCents,
      maxPrizeCents: maxPrizeCents,
      prizeCapReached:
          prizeGrowthEnabled &&
          maxPrizeCents != null &&
          live.currentPrizeCents >= maxPrizeCents!,
      continueAtCap: continueAtCap,
      finalPrizeCents: finalPrizeCents,
      eligiblePlayCount: live.eligiblePlayCount ?? eligiblePlayCount,
      uniquePlayerCount: uniquePlayerCount,
      dailyPlayLimit: dailyPlayLimit,
      prizeVersion: live.version,
      roundNo: roundNo,
      gameType: gameType,
      winnerMethod: winnerMethod,
      winOdds: winOdds,
    );
  }

  static List<Competition> listFromJson(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Competition.fromJson)
        .toList(growable: false);
  }

  final String id;
  final String title;

  /// scheduled, live, closed, frozen, finalised or cancelled — as decided by
  /// the server clock.
  final String status;
  final String gameSlug;
  final String gameName;
  final String countryName;
  final DateTime startsAt;
  final DateTime endsAt;
  final int pointsPerAttempt;

  /// False until SendAgift Points go live; attempts are free until then.
  final bool pointsDeductionEnabled;

  /// 0 means no limit: players play as long as their points last.
  final int maxAttempts;

  bool get unlimitedPlays => maxAttempts == 0;
  final int minAge;
  final bool requiresIdentityVerification;
  final int numberOfWinners;
  final String prizeDescription;

  /// In minor units (cents).
  final int? prizeValueAmount;
  final String? prizeCurrency;
  final String? officialRules;
  final String? cancelReason;
  final String? cancelNote;

  /// This customer's attempts, eligibility and rank; null for guests.
  final CompetitionMe? me;

  /// Validated winners, published once the result is final.
  final List<PublicWinner> winners;

  final bool prizeGrowthEnabled;

  /// cash, product, voucher, gift or other.
  final String prizeType;

  /// Money fields are minor units of [prizeCurrency].
  final int startPrizeCents;
  final int currentPrizeCents;
  final int incrementPerPlayCents;
  final int? maxPrizeCents;

  /// The prize has hit its cap: plays add nothing more to it.
  final bool prizeCapReached;

  /// Whether plays are still taken once the cap is reached.
  final bool continueAtCap;

  /// The prize the round closed on, before any payout.
  final int? finalPrizeCents;

  /// `chance` for spin, scratch, treasure, instant win and prize draw.
  final String gameType;

  /// score (skill games), instant (the first winning play takes the prize) or
  /// draw (winners drawn from every entry at close).
  final String winnerMethod;

  /// Instant-win rounds: each play wins with probability 1 in [winOdds].
  final int? winOdds;

  bool get isChance => gameType == 'chance';
  bool get isDraw => winnerMethod == 'draw';
  final int eligiblePlayCount;
  final int uniquePlayerCount;
  final int? dailyPlayLimit;

  /// Bumped on every prize change; live events carry it.
  final int prizeVersion;
  final int roundNo;

  bool get isLive => status == 'live';
  bool get isPaused => status == 'paused';

  /// The prize to headline: the final one once closed, else the live one.
  int get headlinePrizeCents => finalPrizeCents ?? currentPrizeCents;

  String get headlinePrize =>
      formatMoneyCents(headlinePrizeCents, prizeCurrency);

  String get incrementLabel =>
      formatMoneyCents(incrementPerPlayCents, prizeCurrency);

  String? get maxPrizeLabel => maxPrizeCents == null
      ? null
      : formatMoneyCents(maxPrizeCents!, prizeCurrency);

  /// Playing is refused because the prize is capped and the round stops
  /// there.
  bool get stoppedAtCap => prizeCapReached && !continueAtCap;
  bool get isUpcoming => status == 'scheduled';
  bool get isCancelled => status == 'cancelled';
  bool get isFinal => status == 'finalised';

  /// Closed for play but the result is still being checked.
  bool get isVerifying => status == 'closed' || status == 'frozen';

  String? get prizeValueLabel {
    final currency = prizeCurrency;
    if (currency == null) return null;
    return formatMoneyCents(headlinePrizeCents, currency);
  }
}

/// One live prize update from the round's event stream.
class LivePrize {
  const LivePrize({
    required this.currentPrizeCents,
    required this.version,
    this.eligiblePlayCount,
    this.status,
  });

  factory LivePrize.fromJson(Map<String, dynamic> json) => LivePrize(
    currentPrizeCents: _int(json['current_prize_cents']) ?? 0,
    version: _int(json['version']) ?? 0,
    eligiblePlayCount: _int(json['eligible_play_count']),
    status: json['status'] as String?,
  );

  final int currentPrizeCents;
  final int version;
  final int? eligiblePlayCount;
  final String? status;
}

/// The signed-in customer's position in one competition.
class CompetitionMe {
  const CompetitionMe({
    required this.attemptsUsed,
    required this.attemptsRemaining,
    required this.eligible,
    this.bestScore,
    this.rank,
    this.ineligibleReason,
    this.win,
    this.pointsBalance = 0,
    this.playsLeftToday,
    this.dailyResetAt,
  });

  factory CompetitionMe.fromJson(Map<String, dynamic> json) {
    final rawWin = json['win'];
    return CompetitionMe(
      attemptsUsed: _int(json['attempts_used']) ?? 0,
      attemptsRemaining: _int(json['attempts_remaining']) ?? 0,
      eligible: json['eligible'] as bool? ?? false,
      bestScore: _int(json['best_score']),
      rank: _int(json['rank']),
      ineligibleReason: json['ineligible_reason'] as String?,
      win: rawWin is Map<String, dynamic> ? MyWin.fromJson(rawWin) : null,
      pointsBalance: _int(json['points_balance']) ?? 0,
      playsLeftToday: _int(json['plays_left_today']),
      dailyResetAt: _date(json['daily_reset_at']),
    );
  }

  final int attemptsUsed;
  final int attemptsRemaining;
  final bool eligible;
  final int? bestScore;
  final int? rank;

  /// Why this customer cannot enter, written for them.
  final String? ineligibleReason;
  final MyWin? win;

  /// SendAgift Points available to spend on plays.
  final int pointsBalance;

  /// Plays left today when the round has a daily limit, and when they reset.
  final int? playsLeftToday;
  final DateTime? dailyResetAt;
}

/// Shown only to a winner: their prize and claim.
class MyWin {
  const MyWin({
    required this.winnerId,
    required this.prizePosition,
    required this.status,
    this.claimId,
    this.claimStatus,
    this.claimDeadlineAt,
  });

  factory MyWin.fromJson(Map<String, dynamic> json) {
    return MyWin(
      winnerId: json['winner_id'] as String? ?? '',
      prizePosition: _int(json['prize_position']) ?? 1,
      status: json['status'] as String? ?? '',
      claimId: json['claim_id'] as String?,
      claimStatus: json['claim_status'] as String?,
      claimDeadlineAt: _date(json['claim_deadline_at']),
    );
  }

  final String winnerId;
  final int prizePosition;

  /// pending_validation, validated, disqualified, unclaimed or replaced.
  final String status;
  final String? claimId;

  /// pending, claimed, verified, fulfilled, expired or rejected.
  final String? claimStatus;
  final DateTime? claimDeadlineAt;

  bool get canClaim =>
      status == 'validated' &&
      claimStatus == 'pending' &&
      (claimDeadlineAt?.isAfter(DateTime.now()) ?? false);
}

/// What may be published about a winner: first name, surname initial,
/// country and score.
class PublicWinner {
  const PublicWinner({
    required this.prizePosition,
    required this.displayName,
    required this.countryName,
    required this.score,
  });

  factory PublicWinner.fromJson(Map<String, dynamic> json) {
    return PublicWinner(
      prizePosition: _int(json['prize_position']) ?? 1,
      displayName: json['display_name'] as String? ?? 'Player',
      countryName: json['country_name'] as String? ?? '',
      score: _int(json['score']) ?? 0,
    );
  }

  final int prizePosition;
  final String displayName;
  final String countryName;
  final int score;
}

/// One competition's live board, plus this player's own row.
class CompetitionLeaderboard {
  const CompetitionLeaderboard({
    required this.status,
    required this.isFinal,
    required this.entries,
    required this.totalPlayers,
    this.me,
  });

  factory CompetitionLeaderboard.fromJson(Map<String, dynamic> json) {
    final rawMe = json['me'];
    return CompetitionLeaderboard(
      status: json['status'] as String? ?? '',
      isFinal: json['final'] as bool? ?? false,
      entries: LeaderboardEntry.listFromJson(json['entries']),
      totalPlayers: _int(json['total_players']) ?? 0,
      me: rawMe is Map<String, dynamic>
          ? LeaderboardEntry.fromJson(rawMe)
          : null,
    );
  }

  final String status;
  final bool isFinal;
  final List<LeaderboardEntry> entries;
  final int totalPlayers;
  final LeaderboardEntry? me;
}

/// One of the customer's saved addresses, offered as a prize delivery address.
class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.line1,
    required this.city,
    this.label,
    this.line2,
    this.region,
    this.postalCode,
    this.isDefault = false,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: json['id'] as String? ?? '',
      line1: json['line1'] as String? ?? '',
      city: json['city'] as String? ?? '',
      label: json['label'] as String?,
      line2: json['line2'] as String?,
      region: json['region'] as String?,
      postalCode: json['postal_code'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  static List<DeliveryAddress> listFromJson(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(DeliveryAddress.fromJson)
        .toList(growable: false);
  }

  final String id;
  final String line1;
  final String city;
  final String? label;
  final String? line2;
  final String? region;
  final String? postalCode;
  final bool isDefault;

  /// Everything after the first line, e.g. "Flat 2, Auckland, 1010".
  String get summary => [
    line2,
    city,
    region,
    postalCode,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
}

/// An official attempt the server has opened. Its session carries the
/// competition's shared seed — the same board every entrant gets.
///
/// It is also the play's receipt: what it cost, what is left, and what it
/// added to the prize.
class AttemptStart {
  const AttemptStart({
    required this.attemptNumber,
    required this.attemptsRemaining,
    required this.session,
    this.playId = '',
    this.pointsSpent = 0,
    this.walletPointsRemaining = 0,
    this.prizeBeforeCents = 0,
    this.prizeIncrementCents = 0,
    this.prizeAfterCents = 0,
    this.prizeCapReached = false,
    this.replayed = false,
    this.result,
  });

  factory AttemptStart.fromJson(Map<String, dynamic> json) {
    final rawSession = json['session'];
    return AttemptStart(
      attemptNumber: _int(json['attempt_number']) ?? 1,
      attemptsRemaining: _int(json['attempts_remaining']) ?? 0,
      session: GameSession.fromJson(
        rawSession is Map<String, dynamic> ? rawSession : const {},
      ),
      playId: json['play_id'] as String? ?? '',
      pointsSpent: _int(json['points_spent']) ?? 0,
      walletPointsRemaining: _int(json['wallet_points_remaining']) ?? 0,
      prizeBeforeCents: _int(json['prize_before_cents']) ?? 0,
      prizeIncrementCents: _int(json['prize_increment_cents']) ?? 0,
      prizeAfterCents: _int(json['prize_after_cents']) ?? 0,
      prizeCapReached: json['prize_cap_reached'] as bool? ?? false,
      replayed: json['replayed'] as bool? ?? false,
      result: json['result'] is Map<String, dynamic>
          ? ChanceResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
    );
  }

  final int attemptNumber;
  final int attemptsRemaining;
  final GameSession session;
  final String playId;
  final int pointsSpent;
  final int walletPointsRemaining;
  final int prizeBeforeCents;
  final int prizeIncrementCents;
  final int prizeAfterCents;
  final bool prizeCapReached;

  /// True when this was a retry of a play already made: nothing new was
  /// charged.
  final bool replayed;

  /// A chance play's outcome, decided by the server when it was made.
  final ChanceResult? result;
}

/// What a chance play came to. The server decided it with a secure random
/// draw at the moment of play; everything here is for revealing it.
class ChanceResult {
  const ChanceResult({
    required this.mechanic,
    required this.won,
    this.odds,
    this.draw,
    this.segment,
    this.segments,
    this.cells = const [],
    this.contents,
    this.entryNumber,
  });

  factory ChanceResult.fromJson(Map<String, dynamic> json) {
    final cells = json['cells'];
    return ChanceResult(
      mechanic: json['mechanic'] as String? ?? 'instant',
      won: json['won'] as bool? ?? false,
      odds: _int(json['odds']),
      draw: _int(json['draw']),
      segment: _int(json['segment']),
      segments: _int(json['segments']),
      cells: cells is List ? cells.whereType<String>().toList() : const [],
      contents: json['contents'] as String?,
      entryNumber: _int(json['entry_number']),
    );
  }

  /// spin, scratch, treasure, instant or draw.
  final String mechanic;
  final bool won;
  final int? odds;

  /// The random value the play was decided by; 0 wins.
  final int? draw;

  /// Spin: where the wheel stops (0 is the jackpot) and how many segments.
  final int? segment;
  final int? segments;

  /// Scratch: the symbols under the nine panels.
  final List<String> cells;

  /// Treasure: what the chest holds.
  final String? contents;

  /// Prize draw: this play's entry number.
  final int? entryNumber;

  bool get isDrawEntry => mechanic == 'draw';
}

/// One change to the customer's points.
class PointsEntry {
  const PointsEntry({
    required this.id,
    required this.entryType,
    required this.amountDelta,
    required this.balanceAfter,
    required this.createdAt,
    this.category = '',
    this.description,
    this.reason,
    this.competitionTitle,
  });

  factory PointsEntry.fromJson(Map<String, dynamic> json) => PointsEntry(
    id: json['id'] as String? ?? '',
    entryType: json['entry_type'] as String? ?? '',
    amountDelta: _int(json['amount_delta']) ?? 0,
    balanceAfter: _int(json['balance_after']) ?? 0,
    createdAt: _date(json['created_at']) ?? DateTime.now(),
    category: json['category'] as String? ?? '',
    description: json['description'] as String?,
    reason: json['reason'] as String?,
    competitionTitle: json['competition_title'] as String?,
  );

  final String id;

  /// The ledger type, e.g. play_debit, product_reward, gift_points_received.
  final String entryType;
  final int amountDelta;
  final int balanceAfter;
  final DateTime createdAt;

  /// The kind of change: PRODUCT_PURCHASE, GIFT_REWARD, GIFT_SENT,
  /// GAME_ENTRY, REFUND or ADMIN_ADJUSTMENT.
  final String category;

  /// The server's own wording, e.g. "Purchased Wireless Headphones".
  final String? description;
  final String? reason;
  final String? competitionTitle;

  bool get isCredit => amountDelta > 0;

  /// The line to show: the server's description, or one built here for an
  /// older server that does not send it.
  String get label {
    final d = description;
    if (d != null && d.isNotEmpty) return d;
    return _fallbackLabel;
  }

  String get _fallbackLabel => switch (entryType) {
    'play_debit' => 'Played ${competitionTitle ?? 'a competition'}',
    'play_refund' => 'Refund · ${competitionTitle ?? 'competition play'}',
    'admin_grant' => 'Points added',
    'admin_deduction' => 'Points removed',
    'order_reward' => 'Earned from an order',
    'order_reversal' => 'Order refunded',
    'signup_bonus' => 'Welcome bonus',
    'product_reward' => 'Purchase reward',
    'gift_points_received' => 'Gift received',
    'gift_points_sent' => 'Sent with a gift',
    'gift_points_returned' => 'Gift points returned',
    'prize_points' => 'Prize won',
    _ => 'Adjustment',
  };
}

/// Where a customer's points came from and went.
class PointsTotals {
  const PointsTotals({
    this.fromPurchases = 0,
    this.fromGifts = 0,
    this.fromPrizes = 0,
    this.spentOnGames = 0,
    this.sentAsGifts = 0,
  });

  factory PointsTotals.fromJson(Map<String, dynamic> json) => PointsTotals(
    fromPurchases: _int(json['from_purchases']) ?? 0,
    fromGifts: _int(json['from_gifts']) ?? 0,
    fromPrizes: _int(json['from_prizes']) ?? 0,
    spentOnGames: _int(json['spent_on_games']) ?? 0,
    sentAsGifts: _int(json['sent_as_gifts']) ?? 0,
  );

  final int fromPurchases;
  final int fromGifts;
  final int fromPrizes;
  final int spentOnGames;
  final int sentAsGifts;
}

/// How the customer earns points in their country.
class PointsEarningRule {
  const PointsEarningRule({
    required this.enabled,
    required this.pointsPerUnit,
    required this.signupBonus,
    required this.currency,
    required this.earningAllowed,
  });

  factory PointsEarningRule.fromJson(Map<String, dynamic> json) =>
      PointsEarningRule(
        enabled: json['enabled'] as bool? ?? false,
        pointsPerUnit: _int(json['points_per_unit']) ?? 0,
        signupBonus: _int(json['signup_bonus']) ?? 0,
        currency: json['currency'] as String? ?? '',
        earningAllowed: json['earning_allowed'] as bool? ?? false,
      );

  final bool enabled;
  final int pointsPerUnit;
  final int signupBonus;
  final String currency;
  final bool earningAllowed;

  /// Whether orders earn anything at all.
  bool get earnsOnOrders => enabled && earningAllowed && pointsPerUnit > 0;
}

/// The customer's points balance and history.
class PointsWallet {
  const PointsWallet({
    required this.balance,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    required this.entries,
    this.totals = const PointsTotals(),
  });

  factory PointsWallet.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'];
    final totals = json['totals'];
    return PointsWallet(
      balance: _int(json['balance']) ?? 0,
      lifetimeEarned: _int(json['lifetime_earned']) ?? 0,
      lifetimeSpent: _int(json['lifetime_spent']) ?? 0,
      totals: totals is Map<String, dynamic>
          ? PointsTotals.fromJson(totals)
          : const PointsTotals(),
      entries: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(PointsEntry.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  final int balance;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final PointsTotals totals;
  final List<PointsEntry> entries;
}
