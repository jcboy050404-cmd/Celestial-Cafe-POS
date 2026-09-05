import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/models/customer_feedback.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('CustomerFeedback Model Tests', () {
    test('CustomerFeedback serializes to and from JSON correctly', () {
      final now = DateTime.now();
      final feedback = CustomerFeedback(
        id: 'fb_123',
        orderId: 'ord_001',
        orderNumber: '#0042',
        tableNumber: 'Table 5',
        customerName: 'Astraea',
        rating: 5,
        tags: ['☕ Delicious Coffee', '⚡ Fast Service'],
        message: 'Loved the Spanish Latte!',
        createdAt: now,
      );

      final json = feedback.toJson();
      expect(json['id'], 'fb_123');
      expect(json['orderId'], 'ord_001');
      expect(json['orderNumber'], '#0042');
      expect(json['tableNumber'], 'Table 5');
      expect(json['customerName'], 'Astraea');
      expect(json['rating'], 5);
      expect(json['tags'], contains('☕ Delicious Coffee'));
      expect(json['message'], 'Loved the Spanish Latte!');

      final restored = CustomerFeedback.fromJson(json);
      expect(restored.id, feedback.id);
      expect(restored.orderId, feedback.orderId);
      expect(restored.orderNumber, feedback.orderNumber);
      expect(restored.tableNumber, feedback.tableNumber);
      expect(restored.customerName, feedback.customerName);
      expect(restored.rating, feedback.rating);
      expect(restored.tags, feedback.tags);
      expect(restored.message, feedback.message);
    });

    test('CustomerFeedback handles fallback values gracefully in fromJson', () {
      final json = <String, dynamic>{
        'id': 'fb_456',
        'rating': '4',
        'tags': ['Great Vibe'],
      };

      final fb = CustomerFeedback.fromJson(json);
      expect(fb.id, 'fb_456');
      expect(fb.rating, 4);
      expect(fb.orderId, '');
      expect(fb.orderNumber, '');
      expect(fb.tableNumber, isNull);
      expect(fb.customerName, '');
      expect(fb.tags, ['Great Vibe']);
      expect(fb.message, '');
    });

    test('Order serializes with customerFeedback', () {
      final feedback = CustomerFeedback(
        id: 'fb_999',
        orderId: 'ord_999',
        orderNumber: '#0007',
        customerName: 'Stella',
        rating: 5,
        tags: ['⭐ 5-Star'],
        message: 'Perfect!',
        createdAt: DateTime.now(),
      );

      final order = Order(
        id: 'ord_999',
        orderNumber: '#0007',
        customerName: 'Stella',
        items: const [],
        subtotal: 150,
        taxRate: 0,
        taxAmount: 0,
        totalAmount: 150,
        amountTendered: 200,
        changeDue: 50,
        paymentMethod: PaymentMethod.cash,
        orderType: OrderType.dineIn,
        status: OrderStatus.completed,
        cashierName: 'Admin',
        createdAt: DateTime.now(),
        customerFeedback: feedback,
      );

      final json = order.toJson();
      expect(json['customerFeedback'], isNotNull);
      expect(json['customerFeedback']['rating'], 5);
      expect(json['customerFeedback']['message'], 'Perfect!');

      final parsed = Order.fromJson(json);
      expect(parsed.customerFeedback, isNotNull);
      expect(parsed.customerFeedback!.rating, 5);
      expect(parsed.customerFeedback!.message, 'Perfect!');
    });
  });

  group('PosProvider Customer Feedback Integration Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('addCustomerFeedback saves feedback and attaches to matching order', () async {
      final provider = PosProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      final createdOrder = provider.submitCustomerSelfOrder(
        orderType: OrderType.dineIn,
        tableNumber: 'Table 3',
        customerName: 'Luna',
        items: const [],
        paymentMethod: PaymentMethod.cash,
        orderNotes: 'Hot latte please',
      );

      final fb = CustomerFeedback(
        id: 'fb_0015',
        orderId: createdOrder.id,
        orderNumber: createdOrder.orderNumber,
        tableNumber: '3',
        customerName: 'Luna',
        rating: 5,
        tags: ['☕ Delicious Coffee'],
        message: 'Best latte ever!',
        createdAt: DateTime.now(),
      );

      provider.addCustomerFeedback(fb);

      expect(provider.customerFeedbacks.length, 1);
      expect(provider.customerFeedbacks.first.id, 'fb_0015');
      final matched = provider.orders.firstWhere((o) => o.id == createdOrder.id);
      expect(matched.customerFeedback, isNotNull);
      expect(matched.customerFeedback!.message, 'Best latte ever!');
      expect(matched.customerFeedback!.rating, 5);
    });

    test('CustomerFeedback filtering and KPI calculations compute accurately', () {
      final feedbacks = [
        CustomerFeedback(
          id: 'fb_1',
          orderId: 'ord_1',
          orderNumber: '#0001',
          tableNumber: '1',
          customerName: 'Astraea',
          rating: 5,
          tags: ['☕ Delicious Coffee'],
          message: 'Loved the latte!',
          createdAt: DateTime.now(),
        ),
        CustomerFeedback(
          id: 'fb_2',
          orderId: 'ord_2',
          orderNumber: '#0002',
          tableNumber: '2',
          customerName: 'Bob',
          rating: 4,
          tags: ['⚡ Fast Service'],
          message: 'Quick and friendly',
          createdAt: DateTime.now(),
        ),
        CustomerFeedback(
          id: 'fb_3',
          orderId: 'ord_3',
          orderNumber: '#0003',
          tableNumber: '3',
          customerName: 'Charlie',
          rating: 3,
          tags: [],
          message: '',
          createdAt: DateTime.now(),
        ),
      ];

      // Avg rating
      final total = feedbacks.length;
      final avg = feedbacks.map((f) => f.rating).reduce((a, b) => a + b) / total;
      expect(avg, closeTo(4.0, 0.01));

      // Satisfaction rate (4 and 5 stars)
      final posCount = feedbacks.where((f) => f.rating >= 4).length;
      final satRate = ((posCount / total) * 100).round();
      expect(satRate, 67);

      // Search matching
      final searchMatches = feedbacks.where((fb) {
        final q = 'latte';
        return fb.message.toLowerCase().contains(q) || fb.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
      expect(searchMatches.length, 1);
      expect(searchMatches.first.customerName, 'Astraea');

      // With comments
      final withComments = feedbacks.where((fb) => fb.message.trim().isNotEmpty).toList();
      expect(withComments.length, 2);
    });
  });
}

