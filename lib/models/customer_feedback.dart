class CustomerFeedback {
  final String id;
  final String orderId;
  final String orderNumber;
  final String? tableNumber;
  final String customerName;
  final int rating; // 1 to 5
  final List<String> tags;
  final String message;
  final DateTime createdAt;

  CustomerFeedback({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    this.tableNumber,
    this.customerName = '',
    required this.rating,
    this.tags = const [],
    this.message = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'orderNumber': orderNumber,
        'tableNumber': tableNumber,
        'customerName': customerName,
        'rating': rating,
        'tags': tags,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomerFeedback.fromJson(Map<String, dynamic> json) {
    final ratingVal = json['rating'];
    final ratingNum = (ratingVal is num)
        ? ratingVal.toInt()
        : (int.tryParse(ratingVal?.toString() ?? '') ?? 5);

    return CustomerFeedback(
      id: json['id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      tableNumber: json['tableNumber'] as String?,
      customerName: json['customerName'] as String? ?? '',
      rating: ratingNum.clamp(1, 5),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          const [],
      message: json['message'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  CustomerFeedback copyWith({
    String? id,
    String? orderId,
    String? orderNumber,
    String? tableNumber,
    String? customerName,
    int? rating,
    List<String>? tags,
    String? message,
    DateTime? createdAt,
  }) {
    return CustomerFeedback(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      tableNumber: tableNumber ?? this.tableNumber,
      customerName: customerName ?? this.customerName,
      rating: rating ?? this.rating,
      tags: tags ?? this.tags,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
