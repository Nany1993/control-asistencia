import 'package:flutter_test/flutter_test.dart';

import 'package:control_asistencia/main.dart';

void main() {
  testWidgets('App loads asistencia screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ControlAsistenciaApp());
    expect(find.text('Marcar asistencia'), findsOneWidget);
  });
}
