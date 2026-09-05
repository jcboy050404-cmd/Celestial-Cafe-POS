import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/main.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/widgets/customization_dialog.dart';
import 'package:celestial_pos/widgets/header_bar.dart';
import 'package:celestial_pos/theme/celestial_theme.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Celestial Cafe POS app launches properly and renders official catalog on Desktop', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const CelestialCafePosApp());
    await tester.pumpAndSettle();

    // Verify Brand & Navigation
    expect(find.text('CELESTIAL'), findsOneWidget);
    expect(find.text('Cozy&Classic'), findsOneWidget);
    expect(find.text('POS Station'), findsOneWidget);
    expect(find.text('Barista / KDS'), findsOneWidget);
    expect(find.text('Order History'), findsOneWidget);
    expect(find.text('Menu & Stock'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);

    // Verify Official Menu Items & Empty Initial Order Tray
    expect(find.text('Current Order'), findsOneWidget);
    expect(find.text('Your Tray is Empty'), findsOneWidget);
    expect(find.text('Spanish Latte'), findsOneWidget);
    expect(find.text('Americano'), findsOneWidget);
  });

  testWidgets('Celestial Cafe POS app renders on Mobile screen with Bottom Navigation', (WidgetTester tester) async {
    // Phone viewport: 390 x 844
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const CelestialCafePosApp());
    await tester.pumpAndSettle();

    // Verify Mobile Header & Mobile Bottom Nav Destinations
    expect(find.text('CELESTIAL'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('KDS'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);

    // Verify Mobile Menu Grid
    expect(find.text('Spanish Latte'), findsOneWidget);
    expect(find.text('Americano'), findsOneWidget);
  });

  test('PosProvider starts with 0 dummy orders and cleanly processes new orders', () {
    final provider = PosProvider();

    // Starts 100% clean
    expect(provider.orders.isEmpty, true);
    expect(provider.activeKdsOrders.isEmpty, true);
    expect(provider.todayOrdersCount, 0);
    expect(provider.todayTotalSales, 0.0);
    expect(provider.cart.isEmpty, true);
    expect(provider.cartItemCount, 0);

    final item = provider.menuItems.first; // Americano ₱90
    final initialStock = item.stockCount;

    // Add item to cart with Extra Espresso Shot (₱25)
    provider.addToCart(
      item,
      quantity: 2,
      customizations: [
        SelectedCustomization(groupTitle: 'Add-ons & Extras', optionName: 'Extra Espresso Shot', extraPrice: 25.00),
      ],
      notes: 'Extra hot',
    );

    expect(provider.cart.length, 1);
    expect(provider.cartItemCount, 2);
    expect(provider.cartSubtotal, (item.price + 25.00) * 2);

    // Apply 10% discount
    provider.applyDiscount(percentage: 10);
    expect(provider.discountPercentage, 10.0);
    expect(provider.cartDiscountAmount, provider.cartSubtotal * 0.10);

    // Checkout order with cash ₱500 bill
    final createdOrder = provider.completeCheckout(
      paymentMethod: PaymentMethod.cash,
      amountTendered: 500.0,
      specialOrderNotes: 'VIP patron',
    );

    // Verify order is created and cart is cleared
    expect(provider.orders.length, 1);
    expect(createdOrder.items.length, 1);
    expect(createdOrder.paymentMethod, PaymentMethod.cash);
    expect(provider.cart.isEmpty, true);
    expect(provider.menuItems.first.stockCount, initialStock - 2);

    // Verify order exists in order history & KDS
    expect(provider.orders.first.id, createdOrder.id);
    expect(provider.activeKdsOrders.any((o) => o.id == createdOrder.id), true);
    expect(provider.todayOrdersCount, 1);
    expect(provider.todayTotalSales, createdOrder.totalAmount);

    // Advance status to preparing -> ready -> completed
    provider.updateOrderStatus(createdOrder.id, OrderStatus.preparing);
    expect(provider.preparingOrders.any((o) => o.id == createdOrder.id), true);

    provider.updateOrderStatus(createdOrder.id, OrderStatus.ready);
    expect(provider.readyOrders.any((o) => o.id == createdOrder.id), true);

    provider.updateOrderStatus(createdOrder.id, OrderStatus.completed);
    expect(provider.completedOrders.any((o) => o.id == createdOrder.id), true);
  });

  test('PosProvider local persistence preserves data across sessions', () async {
    final provider1 = PosProvider();
    final firstItem = provider1.menuItems.first;

    // Modify stock
    provider1.updateStockCount(firstItem.id, 77);

    // Create an order
    provider1.addToCart(firstItem, quantity: 1);
    final order = provider1.completeCheckout(
      paymentMethod: PaymentMethod.mobilePay,
      amountTendered: 90.0,
    );

    // Simulate reopening the app with a fresh provider instance
    final provider2 = PosProvider();
    // Wait for async initialization
    await Future.delayed(const Duration(milliseconds: 50));

    expect(provider2.orders.length, 1);
    expect(provider2.orders.first.id, order.id);
    expect(provider2.menuItems.firstWhere((m) => m.id == firstItem.id).stockCount, 76);
  });

  test('PosProvider item price settings and price updates', () async {
    final provider = PosProvider();
    final item = provider.menuItems.first; // Americano initial ₱90
    expect(item.price, 90.00);

    // Update Americano price to ₱99
    provider.updateItemPrice(item.id, 99.00);
    expect(provider.menuItems.first.price, 99.00);

    // Bulk adjust coffee prices (+₱10)
    provider.bulkAdjustPrices(flatAmount: 10.0, category: ItemCategory.coffee);
    expect(provider.menuItems.first.price, 109.00);
  });

  test('PosProvider inventory management and stock toggles', () {
    final provider = PosProvider();
    final firstItem = provider.menuItems.first;

    provider.updateStockCount(firstItem.id, 100);
    expect(provider.menuItems.first.stockCount, 100);
    expect(provider.menuItems.first.inStock, true);

    provider.toggleItemStock(firstItem.id);
    expect(provider.menuItems.first.inStock, false);

    provider.toggleItemStock(firstItem.id);
    expect(provider.menuItems.first.inStock, true);
  });

  test('PosProvider customer table QR self-ordering creates order and syncs status', () {
    final provider = PosProvider();
    final firstItem = provider.menuItems.first;

    final customerOrder = provider.submitCustomerSelfOrder(
      tableNumber: 'Table 3',
      customerName: 'Alice',
      items: [
        OrderItem(
          id: 'item_test_1',
          menuItem: firstItem,
          quantity: 2,
          customizations: [
            SelectedCustomization(groupTitle: 'Cup Size', optionName: '22 oz', extraPrice: 30.0),
          ],
        ),
      ],
      paymentMethod: PaymentMethod.mobilePay,
      orderNotes: 'Please bring to Table 3',
    );

    expect(customerOrder.tableNumber, 'Table 3');
    expect(customerOrder.customerName, 'Alice');
    expect(customerOrder.totalAmount, (firstItem.price + 30.0) * 2);
    expect(customerOrder.status, OrderStatus.pending);
    expect(provider.pendingCustomerOrders.any((o) => o.id == customerOrder.id), true);

    // Transition status to ready
    provider.updateOrderStatus(customerOrder.id, OrderStatus.ready);
    expect(provider.orders.firstWhere((o) => o.id == customerOrder.id).status, OrderStatus.ready);
  });

  test('PosProvider menu item photo upload and image byte retrieval', () {
    final provider = PosProvider();
    final dummyBase64 = base64Encode(utf8.encode('PNG_IMAGE_BYTES_MOCK'));

    final photoItem = MenuItem(
      id: 'item_with_photo_1',
      name: 'Matcha Cloud Frappe',
      category: ItemCategory.frappe,
      price: 185.0,
      description: 'Matcha frappe with foam cloud',
      icon: '🥤',
      imageBase64: dummyBase64,
    );

    provider.addNewMenuItem(photoItem);

    final retrievedBytes = provider.getItemImageBytes('item_with_photo_1');
    expect(retrievedBytes, isNotNull);
    expect(utf8.decode(retrievedBytes!), 'PNG_IMAGE_BYTES_MOCK');

    final customerMenu = provider.getMenuJsonForCustomer();
    final menuItemJson = customerMenu.firstWhere((m) => m['id'] == 'item_with_photo_1');
    expect(menuItemJson['imageBase64'], dummyBase64);
    expect(menuItemJson['imageUrl'], '/api/item-image?id=item_with_photo_1');
  });

  testWidgets('CustomizationDialog renders rich UI and handles temperature, add-ons, quick notes and add to cart', (WidgetTester tester) async {
    final item = initialCelestialMenu.first; // Americano (₱90)
    int addedQuantity = 0;
    List<SelectedCustomization> addedCustomizations = [];
    String? addedNotes;

    await tester.pumpWidget(
      MaterialApp(
        theme: CelestialTheme.themeData,
        home: Scaffold(
          body: CustomizationDialog(
            item: item,
            onAddToCart: (qty, customs, notes) {
              addedQuantity = qty;
              addedCustomizations = customs;
              addedNotes = notes;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title, Price Badge and Required Badges
    expect(find.text('Americano'), findsOneWidget);
    expect(find.text('₱90'), findsWidgets);
    expect(find.text('REQUIRED'), findsNWidgets(2)); // Temperature & Sweetness

    // Verify Temperature Section has Hot and Iced
    expect(find.text('Hot'), findsOneWidget);
    expect(find.text('Iced'), findsOneWidget);

    // Verify Sweetness Level options: 75% added, 125% removed
    expect(find.text('Less Sweet (75%)'), findsOneWidget);
    expect(find.text('Extra Sweet (125%)'), findsNothing);

    // Tap "Hot"
    await tester.tap(find.text('Hot'));
    await tester.pumpAndSettle();

    // Toggle an Add-on: "Extra Espresso Shot"
    expect(find.text('Extra Espresso Shot'), findsOneWidget);
    expect(find.text('Oat Milk Sub'), findsNothing);
    await tester.tap(find.text('Extra Espresso Shot'));
    await tester.pumpAndSettle();

    // Stepper +
    await tester.tap(find.byKey(const Key('customization_qty_plus')));
    await tester.pumpAndSettle();

    // Now quantity is 2, total price is ₱230 (115 * 2)
    expect(find.textContaining('₱230'), findsWidgets);

    // Tap Add to Cart
    await tester.tap(find.textContaining('Add 2'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(addedQuantity, 2);
    expect(addedNotes, isNull);
    expect(addedCustomizations.any((c) => c.optionName == 'Hot'), true);
    expect(addedCustomizations.any((c) => c.optionName == 'Extra Espresso Shot'), true);
  });

  testWidgets('HeaderBar renders liquid glass with smooth animated states when scrolled', (WidgetTester tester) async {
    final pos = PosProvider();

    // Unscrolled state
    await tester.pumpWidget(
      ChangeNotifierProvider<PosProvider>.value(
        value: pos,
        child: MaterialApp(
          theme: CelestialTheme.themeData,
          home: const Scaffold(
            body: HeaderBar(
              isScrolled: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CELESTIAL'), findsOneWidget);
    expect(find.text('POS Station'), findsOneWidget);

    // Scrolled state
    await tester.pumpWidget(
      ChangeNotifierProvider<PosProvider>.value(
        value: pos,
        child: MaterialApp(
          theme: CelestialTheme.themeData,
          home: const Scaffold(
            body: HeaderBar(
              isScrolled: true,
            ),
          ),
        ),
      ),
    );
    // Let animation run
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('CELESTIAL'), findsOneWidget);
    expect(find.text('POS Station'), findsOneWidget);
  });
}

