import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_to_fog_flow_test.dart' as location_to_fog;
import 'red_dot_micro_event_flow_test.dart' as red_dot_micro_event;
import 'services_integration_test.dart' as services_integration;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AFTERSTEP Fog 整合測試套件', () {
    location_to_fog.main();
    red_dot_micro_event.main();
    services_integration.main();
  });
}
