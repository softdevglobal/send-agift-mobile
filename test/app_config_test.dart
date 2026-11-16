import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/core/config/app_config.dart';

void main() {
  const live = AppConfig.productionBaseUrl;

  test('a store build never ships a development address', () {
    for (final dev in [
      'http://192.168.1.2:8081/api/v1',
      'http://localhost:8081/api/v1',
      '',
      null,
      'not a url',
    ]) {
      expect(
        AppConfig.chooseApiBaseUrl(dev, release: true),
        live,
        reason: '$dev',
      );
    }
  });

  test('a store build keeps an HTTPS address from .env', () {
    expect(
      AppConfig.chooseApiBaseUrl(
        ' https://staging.sendagift.win/api/v1 ',
        release: true,
      ),
      'https://staging.sendagift.win/api/v1',
    );
  });

  test('a development build uses .env as written', () {
    expect(
      AppConfig.chooseApiBaseUrl(
        'http://192.168.1.2:8081/api/v1',
        release: false,
      ),
      'http://192.168.1.2:8081/api/v1',
    );
    expect(
      AppConfig.chooseApiBaseUrl(null, release: false),
      'http://localhost:8081/api/v1',
    );
  });
}
