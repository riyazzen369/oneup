import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/features/home/welcome_dialog.dart';
import 'mem_store.dart';

void main() {
  testWidgets('welcome shows once, persists flag, resets after deleteAll', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final store = MemStore();
    Future<void> open() async {
      await t.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [secureStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            return Scaffold(body: TextButton(onPressed: () => maybeShowWelcome(context, ref), child: const Text('go')));
          }),
        ),
      ));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
    }

    await open();
    expect(find.text(welcomeTitle), findsOneWidget);
    expect(find.text(welcomeDisclaimer), findsOneWidget);
    expect(find.text('Financial'), findsOneWidget);
    await t.ensureVisible(find.text(welcomeCta));
    await t.pumpAndSettle();
    await t.tap(find.text(welcomeCta));
    await t.pumpAndSettle();
    expect(find.text(welcomeTitle), findsNothing);
    expect(store.m[kWelcomeShown], isNotNull);

    await open();
    expect(find.text(welcomeTitle), findsNothing); // never again

    await store.deleteAll(); // delete-my-data
    await open();
    expect(find.text(welcomeTitle), findsOneWidget);
  });

  test('copy has no numbers/statistics and keeps the disclaimer', () {
    expect(RegExp(r'\d').hasMatch(welcomeBody1 + welcomeBody2 + welcomeTitle), isFalse);
    expect(welcomeDisclaimer, 'OneUp is for wellness awareness, not medical diagnosis.');
  });
}
