import 'menu_item.dart';

enum OrderType {
  dineIn('Dine-In', '🍽️'),
  takeaway('Takeaway', '🛍️'),
  delivery('Delivery', '🛵');

  final String label;
  final String icon;
  const OrderType(this.label, this.icon);
}

enum OrderStatus {
  pending('Pending', '⏳'),
  confirmed('In Queue', '📋'),
  preparing('Brewing / Kitchen', '🔥'),
  ready('Ready for Pickup', '✨'),
  completed('Completed', '✅'),
  cancelled('Cancelled', '❌');

  final String label;
  final String icon;
  const OrderStatus(this.label, this.icon);
}

enum PaymentMethod {
  cash('Cash', '💵'),
  mobilePay('GCash', '📱');

  final String label;
  final String icon;
  const PaymentMethod(this.label, this.icon);
}

class SelectedCustomization {
  final String groupTitle;
  final String optionName;
  final double extraPrice;

  SelectedCustomization({
    required this.groupTitle,
    required this.optionName,
    this.extraPrice = 0.0,
  });

  String get summary => extraPrice > 0
      ? '$optionName (+₱${extraPrice.toStringAsFixed(0)})'
      : optionName;

  Map<String, dynamic> toJson() => {
        'groupTitle': groupTitle,
        'optionName': optionName,
        'extraPrice': extraPrice,
      };

  factory SelectedCustomization.fromJson(Map<String, dynamic> json) {
    return SelectedCustomization(
      groupTitle: json['groupTitle'] as String? ?? '',
      optionName: json['optionName'] as String? ?? '',
      extraPrice: (json['extraPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderItem {
  final String id;
  final MenuItem menuItem;
  int quantity;
  final List<SelectedCustomization> customizations;
  final String? notes;
  bool isPrepared;

  OrderItem({
    required this.id,
    required this.menuItem,
    this.quantity = 1,
    this.customizations = const [],
    this.notes,
    this.isPrepared = false,
  });

  double get unitPrice {
    double price = menuItem.price;
    for (var custom in customizations) {
      price += custom.extraPrice;
    }
    return price;
  }

  double get totalPrice => unitPrice * quantity;

  bool get isKitchenDish => menuItem.isKitchenDish;

  Map<String, dynamic> toJson() => {
        'id': id,
        'menuItem': menuItem.toJson(),
        'quantity': quantity,
        'customizations': customizations.map((c) => c.toJson()).toList(),
        'notes': notes,
        'isPrepared': isPrepared,
      };

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String? ?? '',
      menuItem: MenuItem.fromJson(json['menuItem'] as Map<String, dynamic>),
      quantity: json['quantity'] as int? ?? 1,
      customizations: (json['customizations'] as List<dynamic>?)
              ?.map((c) => SelectedCustomization.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      isPrepared: json['isPrepared'] as bool? ?? false,
    );
  }

  OrderItem copyWith({
    int? quantity,
    String? notes,
    bool? isPrepared,
  }) {
    return OrderItem(
      id: id,
      menuItem: menuItem,
      quantity: quantity ?? this.quantity,
      customizations: customizations,
      notes: notes ?? this.notes,
      isPrepared: isPrepared ?? this.isPrepared,
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final OrderType orderType;
  final String? tableNumber;
  final String customerName;
  final List<OrderItem> items;
  final double subtotal;
  final double taxAmount;
  final double taxRate;
  final double discountAmount;
  final double discountPercentage;
  final double totalAmount;
  final PaymentMethod paymentMethod;
  final double amountTendered;
  final double changeDue;
  OrderStatus status;
  final DateTime createdAt;
  final String cashierName;
  final String? orderNotes;

  Order({
    required this.id,
    required this.orderNumber,
    required this.orderType,
    this.tableNumber,
    required this.customerName,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.taxRate,
    this.discountAmount = 0.0,
    this.discountPercentage = 0.0,
    required this.totalAmount,
    required this.paymentMethod,
    required this.amountTendered,
    this.changeDue = 0.0,
    this.status = OrderStatus.pending,
    required this.createdAt,
    required this.cashierName,
    this.orderNotes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'orderType': orderType.name,
        'tableNumber': tableNumber,
        'customerName': customerName,
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal,
        'taxAmount': taxAmount,
        'taxRate': taxRate,
        'discountAmount': discountAmount,
        'discountPercentage': discountPercentage,
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod.name,
        'amountTendered': amountTendered,
        'changeDue': changeDue,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'cashierName': cashierName,
        'orderNotes': orderNotes,
      };

  factory Order.fromJson(Map<String, dynamic> json) {
    final oTypeName = json['orderType'] as String? ?? 'dineIn';
    final oType = OrderType.values.firstWhere(
      (t) => t.name == oTypeName,
      orElse: () => OrderType.dineIn,
    );

    final pMethodName = json['paymentMethod'] as String? ?? 'cash';
    final pMethod = PaymentMethod.values.firstWhere(
      (m) => m.name == pMethodName,
      orElse: () => PaymentMethod.cash,
    );

    final statusName = json['status'] as String? ?? 'pending';
    final oStatus = OrderStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => OrderStatus.pending,
    );

    return Order(
      id: json['id'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '#1',
      orderType: oType,
      tableNumber: json['tableNumber'] as String?,
      customerName: json['customerName'] as String? ?? 'Guest Patron',
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.05,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: pMethod,
      amountTendered: (json['amountTendered'] as num?)?.toDouble() ?? 0.0,
      changeDue: (json['changeDue'] as num?)?.toDouble() ?? 0.0,
      status: oStatus,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      cashierName: json['cashierName'] as String? ?? 'Main POS',
      orderNotes: json['orderNotes'] as String?,
    );
  }

  int get totalItemCount =>
      items.fold(0, (sum, item) => sum + item.quantity);

  bool get hasKitchenDishes => items.any((i) => i.isKitchenDish);
  bool get hasBaristaDrinks => items.any((i) => !i.isKitchenDish);
  int get kitchenDishCount =>
      items.where((i) => i.isKitchenDish).fold(0, (sum, item) => sum + item.quantity);
  int get baristaDrinkCount =>
      items.where((i) => !i.isKitchenDish).fold(0, (sum, item) => sum + item.quantity);

  bool get isPaid =>
      status != OrderStatus.pending && status != OrderStatus.cancelled;

  String get durationString {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
  }

  Order copyWith({
    String? id,
    String? orderNumber,
    OrderType? orderType,
    String? tableNumber,
    String? customerName,
    List<OrderItem>? items,
    double? subtotal,
    double? taxAmount,
    double? taxRate,
    double? discountAmount,
    double? discountPercentage,
    double? totalAmount,
    PaymentMethod? paymentMethod,
    double? amountTendered,
    double? changeDue,
    OrderStatus? status,
    DateTime? createdAt,
    String? cashierName,
    String? orderNotes,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      orderType: orderType ?? this.orderType,
      tableNumber: tableNumber ?? this.tableNumber,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      taxRate: taxRate ?? this.taxRate,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountTendered: amountTendered ?? this.amountTendered,
      changeDue: changeDue ?? this.changeDue,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      cashierName: cashierName ?? this.cashierName,
      orderNotes: orderNotes ?? this.orderNotes,
    );
  }
}
