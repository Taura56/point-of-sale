import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/product_sales_screen.dart';
import 'package:frontend/screens/repair_jobs_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/account_creation_screen.dart';
import 'package:frontend/screens/inventory_screen.dart';
import 'package:frontend/screens/reports_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:http/http.dart' show runWithClient;
import 'package:http/testing.dart';

Future<void> _pumpAppWithoutNetwork(WidgetTester tester) {
  return runWithClient(
    () async {
      await tester.pumpWidget(const BusinessManagerApp());
      await tester.pumpAndSettle();
    },
    () => MockClient((_) async {
      throw StateError('The login screen should not make HTTP requests.');
    }),
  );
}

void main() {
  testWidgets('Business Manager launches on the login screen', (tester) async {
    await _pumpAppWithoutNetwork(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sign in to manage your business'), findsOneWidget);
  });

  testWidgets('login screen has email, password, and login controls', (
    tester,
  ) async {
    await _pumpAppWithoutNetwork(tester);

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'LOGIN'), findsOneWidget);
  });

  testWidgets('login screen opens account creation form', (tester) async {
    await _pumpAppWithoutNetwork(tester);

    await tester.ensureVisible(find.text("Don't have an account? Create one"));
    await tester.tap(find.text("Don't have an account? Create one"));
    await tester.pumpAndSettle();

    expect(find.byType(AccountCreationScreen), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Business name'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });

  testWidgets('quick sale opens a dialog instead of the sales page', (
    tester,
  ) async {
    await runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: ProductSalesScreen(openSaleOnOpen: true)),
        );
        await tester.pump();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Product Sales'), findsNothing);
      },
      () => MockClient((_) async {
        throw StateError('The quick-sale dialog should not make this request.');
      }),
    );
  });

  testWidgets('new repair dialog captures a repair name and price', (
    tester,
  ) async {
    await runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: RepairJobsScreen()));
        await tester.pump();
        await tester.tap(find.text('New Repair'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('Repair name (e.g. mouth pic repair)'),
          findsOneWidget,
        );
        expect(find.text('Price (KSh)'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(2));
      },
      () => MockClient((_) async {
        throw StateError('The repair form should not make this request.');
      }),
    );
  });

  testWidgets('Inventory shows its branded layout while loading', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: InventoryScreen()));

    expect(find.text('INVENTORY'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      const Color(0xFF1565C0),
    );
  });

  testWidgets('Inventory can open the add-item form', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: InventoryScreen()));
    await tester.tap(find.text('Add Item'));
    await tester.pump();

    expect(find.text('Add Inventory Item'), findsOneWidget);
    expect(find.text('Product Name'), findsOneWidget);
    expect(find.text('Cost Price (KSh)'), findsOneWidget);
    expect(find.text('Selling Price (KSh)'), findsOneWidget);
    expect(find.text('Quantity in Stock'), findsOneWidget);
    expect(find.text('Low Stock Alert Level'), findsOneWidget);
  });

  testWidgets('Reports opens with the branded page header', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));

    expect(find.text('REPORTS'), findsOneWidget);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      const Color(0xFF1565C0),
    );
  });

  testWidgets('Settings opens with the branded page header', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      const Color(0xFF1565C0),
    );
  });
}
