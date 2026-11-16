import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/games/domain/competition.dart';
import 'package:send_agift_mobile/features/games/presentation/screens/competition_screen.dart';

void main() {
  test('who can enter names the states a round is limited to', () {
    expect(whoCanEnter('Sri Lanka', const []), 'Players in Sri Lanka');
    expect(
      whoCanEnter('Sri Lanka', const ['Central Province']),
      'Players in Central Province (Sri Lanka)',
    );
    expect(
      whoCanEnter('Sri Lanka', const ['Central Province', 'Uva Province']),
      'Players in Central Province and Uva Province (Sri Lanka)',
    );
    expect(
      whoCanEnter('Sri Lanka', const ['A', 'B', 'C', 'D', 'E']),
      'Players in 5 states of Sri Lanka',
    );
  });

  test('a round\'s states are read from the server', () {
    final c = Competition.fromJson({
      'id': 'r1',
      'country_name': 'Sri Lanka',
      'states': [
        {'state_id': 's1', 'name': 'Central Province'},
      ],
    });
    expect(c.stateNames, ['Central Province']);
  });
}
