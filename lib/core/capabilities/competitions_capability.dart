import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/providers.dart';

/// The competitions policy this build understands. Any other version is
/// treated as "off": a newer server may have rules this app cannot show.
const knownCompetitionsPolicyVersion = 1;

/// True only for an explicit, recognised "enabled" from GET /capabilities.
bool competitionsAllowed(Object? body) {
  if (body is! Map) return false;
  final competitions = body['competitions'];
  if (competitions is! Map) return false;
  return competitions['enabled'] == true &&
      competitions['policyVersion'] == knownCompetitionsPolicyVersion;
}

/// Whether competitions may be shown and opened. Asked of the server, never
/// assumed: a failed, slow or unreadable answer keeps them hidden, while
/// shopping carries on as normal.
final competitionsEnabledProvider = FutureProvider<bool>((ref) async {
  try {
    final response = await ref
        .watch(apiClientProvider)
        .dio
        .get<Object?>('/capabilities');
    return competitionsAllowed(response.data);
  } catch (_) {
    return false;
  }
});

/// The settled answer, or false while it is still on its way.
final competitionsOnProvider = Provider<bool>((ref) {
  return ref.watch(competitionsEnabledProvider).valueOrNull ?? false;
});
