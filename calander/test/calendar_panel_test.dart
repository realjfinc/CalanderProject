import 'package:calander/ui/calendar/calendar_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('panel tiles render and respond without background warnings', (tester) async {
    var tapped = false;
    var allDay = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          CalendarPanel(
            padding: 0,
            child: ListTile(
              title: const Text('Starts'),
              onTap: () => tapped = true,
            ),
          ),
          CalendarPanel(
            padding: 0,
            child: SwitchListTile.adaptive(
              title: const Text('All day'),
              value: allDay,
              onChanged: (value) => allDay = value,
            ),
          ),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Starts'));
    await tester.tap(find.text('All day'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
    expect(allDay, isTrue);
    expect(tester.takeException(), isNull);
  });
}
