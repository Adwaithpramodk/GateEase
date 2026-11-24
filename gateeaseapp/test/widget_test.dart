import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gateeaseapp/Mentor/mentor_management.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/privacy_policy_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

String tokenExpiringAt(DateTime date) {
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'exp': date.millisecondsSinceEpoch ~/ 1000})),
  );
  return 'header.$payload.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'lid': 12, 'usertype': 'Student'});
  });

  test('retains a session whose access token needs renewal', () async {
    final now = DateTime.now();
    await saveSession(
      tokenExpiringAt(now.subtract(const Duration(minutes: 1))),
      tokenExpiringAt(now.add(const Duration(days: 7))),
    );
    expect(await restoreSession(), isTrue);
  });

  test(
    'clears saved identity when the seven-day refresh token expires',
    () async {
      final expired = tokenExpiringAt(
        DateTime.now().subtract(const Duration(seconds: 30)),
      );
      await saveSession(expired, expired);
      expect(await restoreSession(), isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('lid'), isNull);
      expect(preferences.getString('usertype'), isNull);
    },
  );

  test('rejects another origin for authenticated media', () {
    expect(isGateEaseOrigin(Uri.parse('$baseurl/media/private.png')), isTrue);
    expect(
      isGateEaseOrigin(Uri.parse('https://other.example/media/private.png')),
      isFalse,
    );
  });

  testWidgets('login fits a compact screen with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const LoginPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('account deletion link is reachable at large text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: const PrivacyPolicyScreen(),
      ),
    );
    final deletion = find.widgetWithText(
      OutlinedButton,
      'Request account deletion',
    );
    await tester.ensureVisible(deletion);
    await tester.pumpAndSettle();
    expect(deletion.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'approved pass revocation requires a reason and refreshes the list',
    (tester) async {
      const listPath = '/api/mentor/approved-passes/';
      const revokePath = '${listPath}42/revoke/';
      String? submittedReason;
      final fakeMentorApi = InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.method == 'POST' && request.path == revokePath) {
            submittedReason = (request.data as Map)['reason'] as String;
            handler.resolve(
              Response<void>(requestOptions: request, statusCode: 204),
            );
            return;
          }
          expect(request.path, listPath);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: request,
              statusCode: 200,
              data: {
                'page': 1,
                'pages': 1,
                'passes': [
                  if (submittedReason == null)
                    {'id': 42, 'name': 'Sample student', 'time': '02:00 PM'},
                ],
              },
            ),
          );
        },
      );
      dio.interceptors.insert(0, fakeMentorApi);
      addTearDown(() => dio.interceptors.remove(fakeMentorApi));

      await tester.pumpWidget(
        const MaterialApp(home: MentorApprovedPassesPage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sample student'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Revoke pass'));
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(FilledButton, 'Revoke pass');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Enter a reason.'), findsOneWidget);
      expect(submittedReason, isNull);

      await tester.enterText(find.byType(TextFormField), 'Schedule changed');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(submittedReason, 'Schedule changed');
      expect(find.text('Sample student'), findsNothing);
    },
  );
}
