import 'package:flutter_test/flutter_test.dart';

import 'package:control_asistencia/main.dart';

void main() {
  testWidgets('App loads asistencia screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ControlAsistenciaApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Turno'), findsOneWidget);
    expect(find.text('Capacitacion'), findsOneWidget);
  });
}
