import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/widgets/receipt_dialog.dart';

void main() {
  test('SerratedReceiptClipper creates valid path with scalloped teeth', () {
    const clipper = SerratedReceiptClipper(toothRadius: 7.0);
    final path = clipper.getClip(const Size(320, 500));
    expect(path, isNotNull);
    final bounds = path.getBounds();
    expect(bounds.width, equals(320));
    expect(bounds.height, greaterThan(400));
  });

  testWidgets('ReceiptDialog displays dispenser slot, receipt items, total and controls', (tester) async {
    final order = Order(
      id: 'ord_test_001',
      orderNumber: '#0108',
      items: [
        OrderItem(
          id: 'oi_1',
          menuItem: MenuItem(
            id: 'item_1',
            name: 'Chicken Soup',
            price: 45.0,
            category: ItemCategory.dinner,
            description: 'Delicious soup',
            icon: '🍲',
          ),
          quantity: 1,
        ),
        OrderItem(
          id: 'oi_2',
          menuItem: MenuItem(
            id: 'item_2',
            name: 'Tomato Soup',
            price: 15.0,
            category: ItemCategory.dinner,
            description: 'Delicious soup',
            icon: '🍲',
          ),
          quantity: 2,
        ),
      ],
      totalAmount: 75.0,
      subtotal: 75.0,
      taxAmount: 0.0,
      taxRate: 0.0,
      amountTendered: 100.0,
      changeDue: 25.0,
      paymentMethod: PaymentMethod.cash,
      orderType: OrderType.dineIn,
      tableNumber: '4',
      customerName: 'Alice',
      cashierName: 'POS Cashier',
      status: OrderStatus.completed,
      createdAt: DateTime(2026, 9, 4, 18, 30),
    );

    await tester.binding.setSurfaceSize(const Size(800, 1000));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PosProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ReceiptDialog(order: order),
          ),
        ),
      ),
    );

    // Let animation run
    await tester.pumpAndSettle();

    // Verify Title & Mockup elements
    expect(find.text('RECEIPT'), findsOneWidget);
    expect(find.text('TOTAL AMOUNT'), findsOneWidget);
    expect(find.text('THANK YOU'), findsOneWidget);
    expect(find.text('1x Chicken Soup'), findsOneWidget);
    expect(find.text('2x Tomato Soup'), findsOneWidget);
    expect(find.text('Print Receipt'), findsOneWidget);
    expect(find.text('Track QR'), findsOneWidget);
  });
}
