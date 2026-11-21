import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/mtush_management_screen.dart';
import 'package:frontend/screens/product_sales_screen.dart';
import 'package:frontend/screens/repair_jobs_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/account_creation_screen.dart';
import 'package:frontend/screens/inventory_screen.dart';
import 'package:frontend/screens/reports_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/gestures.dart';

Future<void> _pumpAppWithoutNetwork(WidgetTester tester) {
  return http.runWithClient(
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

  testWidgets('form fields use the shared blue-and-white styling', (
    tester,
  ) async {
    await _pumpAppWithoutNetwork(tester);

    final field = tester.widget<InputDecorator>(
      find
          .descendant(
            of: find.byType(TextFormField).first,
            matching: find.byType(InputDecorator),
          )
          .first,
    );

    expect(field.decoration.filled, isTrue);
    expect(field.decoration.fillColor, Colors.white);
    expect(field.decoration.enabledBorder, isA<OutlineInputBorder>());

    expect(
      (field.decoration.enabledBorder as OutlineInputBorder).borderSide.color,
      const Color(0xFFD5E3F0),
    );

    expect(field.decoration.focusedBorder, isA<OutlineInputBorder>());

    expect(
      (field.decoration.focusedBorder as OutlineInputBorder).borderSide.color,
      const Color(0xFF1565C0),
    );
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
    await http.runWithClient(
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
    await http.runWithClient(
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

  testWidgets('Lipa Mdogo order dialog opens on a phone-sized screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'test-token',
      'business_id': 'test-business',
    });

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MtushManagementScreen(initialTab: 1, showAppBar: false),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('New Lipa Mdogo Order'));
        await tester.pumpAndSettle();

        expect(find.text('New Lipa Mdogo order'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        final path = request.url.path;

        final response = path.endsWith('/settings')
            ? {
                'data': {'role': 'owner'},
              }
            : path.endsWith('/mtush/installment-orders')
            ? {'orders': <dynamic>[]}
            : path.endsWith('/inventory')
            ? {'items': <dynamic>[]}
            : path.endsWith('/dashboard/displays')
            ? {
                'data': {
                  'displays': ['mtushDailySales'],
                },
              }
            : path.endsWith('/mtush/dashboard')
            ? {
                'metrics': {
                  'profitByDay': [0, 0, 0, 0, 0, 0, 0],
                },
              }
            : {'metrics': <String, dynamic>{}};

        return http.Response(jsonEncode(response), 200);
      }),
    );
  });

  testWidgets('Mtush dashboard has customizable metric display cards', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'test-token',
      'business_id': 'test-business',
    });

    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selectedDisplays = [
      'mtushDailySales',
      'mtushInventoryValue',
      'mtushReservedStock',
      'mtushWeeklyOperatingProfit',
    ];

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: MtushManagementScreen()),
        );

        await tester.pumpAndSettle();

        expect(find.text('Mtush Boutique'), findsOneWidget);
        expect(find.text('Dashboard Displays'), findsOneWidget);
        expect(find.text("Today's Total Sales"), findsOneWidget);
        expect(find.text('Current Stock Value'), findsOneWidget);
        expect(find.text('LIPA MDOGO ASSETS'), findsOneWidget);
        expect(find.text('Operating Profit'), findsOneWidget);
        expect(find.text('Make a Sale'), findsOneWidget);
        expect(find.text('Add Stock'), findsOneWidget);
        expect(find.text('LIPA MDOGO'), findsOneWidget);

        final graphCard = find
            .ancestor(
              of: find.text('Operating Profit'),
              matching: find.byType(Card),
            )
            .first;

        final inventoryCard = find
            .ancestor(
              of: find.text('Current Stock Value'),
              matching: find.byType(Card),
            )
            .first;

        expect(
          tester.getTopLeft(graphCard).dy,
          greaterThan(tester.getTopLeft(inventoryCard).dy),
        );

        await tester.tap(find.text('Add Display'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Weekly Tithe (10%)'));
        await tester.pumpAndSettle();

        expect(selectedDisplays, contains('mtushWeeklyTithe'));
        expect(find.text('Weekly Tithe (10%)'), findsOneWidget);
        expect(find.text('Cost of Goods Sold'), findsNothing);
        expect(find.text('Available Stock'), findsNothing);
        expect(find.text('Pending Installment Orders'), findsNothing);
        expect(find.text('Awaiting Collection'), findsNothing);
        expect(find.text('Completed Collections'), findsNothing);
      },
      () => MockClient((request) async {
        final path = request.url.path;

        if (request.method == 'PATCH' && path.endsWith('/dashboard/displays')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;

          selectedDisplays = List<String>.from(body['displays'] as List);

          return http.Response(
            jsonEncode({
              'data': {'displays': selectedDisplays},
            }),
            200,
          );
        }

        final response = path.endsWith('/settings')
            ? {
                'data': {
                  'role': 'owner',
                  'business': {
                    'name': 'Mtush Boutique',
                    'businessType': 'mtush',
                    'location': 'Nairobi',
                  },
                },
              }
            : path.endsWith('/mtush/installment-orders')
            ? {'orders': <dynamic>[]}
            : path.endsWith('/inventory')
            ? {'items': <dynamic>[]}
            : path.endsWith('/dashboard/displays')
            ? {
                'data': {'displays': selectedDisplays},
              }
            : path.endsWith('/mtush/dashboard')
            ? {
                'metrics': {
                  'collected': {'cash': 1500},
                  'revenue': {'total': 4000},
                  'inventory': {'value': 25000, 'availableUnits': 8},
                  'cogs': {'total': 2000},
                  'profit': {'total': 2000},
                  'profitByDay': [0, 100, 200, 300, 400, 500, 500],
                  'reserved': {'units': 2, 'value': 5000},
                  'lowStock': {'count': 1},
                  'outstanding': {'amount': 700},
                  'pending': {'count': 2},
                  'awaitingCollection': {'count': 1},
                  'collectedOrders': {'count': 3},
                },
              }
            : {'metrics': <String, dynamic>{}};

        return http.Response(jsonEncode(response), 200);
      }),
    );
  });

  testWidgets('Mtush dashboard sale form loads after inventory requests', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'test-token',
      'business_id': 'test-business',
    });

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: MtushManagementScreen()),
        );

        await tester.pumpAndSettle();

        final saleButton = find.text('Make a Sale');

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);

        final buttonPosition = tester.getCenter(saleButton);

        await mouse.addPointer(location: buttonPosition);
        await mouse.moveTo(buttonPosition);
        await tester.pump();

        await mouse.down(buttonPosition);
        await mouse.up();

        await tester.pumpAndSettle();

        expect(find.text('New product sale'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        final path = request.url.path;

        final response = path.endsWith('/settings')
            ? {
                'data': {
                  'role': 'owner',
                  'business': {
                    'name': 'Mtush Boutique',
                    'businessType': 'mtush',
                  },
                },
              }
            : path.endsWith('/mtush/installment-orders')
            ? {'orders': <dynamic>[]}
            : path.endsWith('/inventory')
            ? {
                'items': [
                  {
                    '_id': 'test-item',
                    'name': 'Test item',
                    'quantityInStock': 2,
                    'reservedQuantity': 0,
                    'costPrice': 200,
                    'sellingPrice': 500,
                  },
                ],
              }
            : path.endsWith('/product-sales')
            ? {'sales': <dynamic>[]}
            : path.endsWith('/dashboard/displays')
            ? {
                'data': {
                  'displays': ['mtushDailySales'],
                },
              }
            : path.endsWith('/mtush/dashboard')
            ? {
                'metrics': {
                  'profitByDay': [0, 0, 0, 0, 0, 0, 0],
                },
              }
            : {'metrics': <String, dynamic>{}};

        return http.Response(jsonEncode(response), 200);
      }),
    );
  });

  testWidgets('Dashboard graph stays below all selected metric cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'test-token',
      'business_id': 'test-business',
    });

    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

        await tester.pumpAndSettle();

        final graphCard = find
            .ancestor(
              of: find.text('Operating Profit'),
              matching: find.byType(Card),
            )
            .first;

        final expensesCard = find
            .ancestor(
              of: find.text("Today's Expenses"),
              matching: find.byType(Card),
            )
            .first;

        expect(
          tester.getTopLeft(graphCard).dy,
          greaterThan(tester.getTopLeft(expensesCard).dy),
        );
      },
      () => MockClient((request) async {
        final path = request.url.path;

        final response = path.endsWith('/settings')
            ? {
                'data': {
                  'business': {
                    'name': 'General Store',
                    'businessType': 'retail_shop',
                  },
                },
              }
            : path.endsWith('/dashboard/displays')
            ? {
                'data': {
                  'displays': [
                    'weeklyOperatingProfit',
                    'dailyExpenses',
                    'dailyTotalMoney',
                  ],
                },
              }
            : {
                'dashboard': {
                  'dailyTotalMoney': 1000,
                  'weeklyTithe': 700,
                  'weeklyTotalMoney': 7000,
                  'lowStockItems': 2,
                  'dailyExpenses': 300,
                  'weeklyMoneyByDay': [500, 1000, 1500, 1000, 1000, 1000, 1000],
                },
              };

        return http.Response(jsonEncode(response), 200);
      }),
    );
  });

  testWidgets('Lipa Mdogo order can be created with an initial deposit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'test-token',
      'business_id': 'test-business',
    });

    http.Request? createOrderRequest;

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MtushManagementScreen(initialTab: 1, showAppBar: false),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('New Lipa Mdogo Order'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).first,
          'Test Customer',
        );

        await tester.enterText(find.byType(TextField).last, '100');

        await tester.tap(find.text('Create order'));
        await tester.pumpAndSettle();

        expect(createOrderRequest, isNotNull);

        final body =
            jsonDecode(createOrderRequest!.body) as Map<String, dynamic>;

        final initialPayment = body['initialPayment'] as Map<String, dynamic>;

        expect(
          initialPayment['idempotencyKey'],
          matches(RegExp(r'^\d+-[0-9a-f]{32}$')),
        );

        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        if (request.method == 'POST') {
          createOrderRequest = request;
          return http.Response('{"success":true}', 201);
        }

        final path = request.url.path;

        final response = path.endsWith('/settings')
            ? {
                'data': {'role': 'owner'},
              }
            : path.endsWith('/mtush/installment-orders')
            ? {'orders': <dynamic>[]}
            : path.endsWith('/inventory')
            ? {
                'items': [
                  {
                    '_id': 'test-item',
                    'name': 'Test item',
                    'quantityInStock': 2,
                    'reservedQuantity': 0,
                    'sellingPrice': 500,
                  },
                ],
              }
            : path.endsWith('/dashboard/displays')
            ? {
                'data': {
                  'displays': ['mtushDailySales'],
                },
              }
            : path.endsWith('/mtush/dashboard')
            ? {
                'metrics': {
                  'profitByDay': [0, 0, 0, 0, 0, 0, 0],
                },
              }
            : {'metrics': <String, dynamic>{}};

        return http.Response(jsonEncode(response), 200);
      }),
    );
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
