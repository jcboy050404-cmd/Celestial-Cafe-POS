import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/order.dart';

typedef OrderStatusUpdateCallback = void Function(String orderId, String newStatus);
typedef OrderItemPreparedCallback = void Function(String orderId, int itemIndex, bool isPrepared);
typedef CustomerOrderCallback = Map<String, dynamic> Function(Map<String, dynamic> rawOrder);
typedef CustomerChangeOrderCallback = Map<String, dynamic> Function(String orderId);
typedef CustomerCancelOrderCallback = Map<String, dynamic> Function(String orderId);
typedef ItemImageCallback = Uint8List? Function(String itemId);

class KdsServerService {
  HttpServer? _server;
  final Set<WebSocket> _clients = {};
  final Set<WebSocket> _baristaClients = {};
  String _localIp = '192.168.43.1';
  int _port = 8080;
  bool _isRunning = false;
  String _baristaPin = '1234';

  OrderStatusUpdateCallback? onOrderStatusUpdate;
  OrderItemPreparedCallback? onOrderItemPrepared;
  List<Map<String, dynamic>> Function()? getActiveOrdersJson;
  List<Map<String, dynamic>> Function()? getMenuCallback;
  CustomerOrderCallback? onCustomerOrderSubmitted;
  CustomerChangeOrderCallback? onCustomerChangeOrder;
  CustomerCancelOrderCallback? onCustomerCancelOrder;
  dynamic Function(String orderId)? getOrderByIdCallback;
  ItemImageCallback? getItemImageCallback;

  bool get isRunning => _isRunning;
  String get serverUrl => 'http://$_localIp:$_port';
  String get kdsUrl => 'http://$_localIp:$_port/kds';
  String get localIp => _localIp;
  int get port => _port;
  int get clientCount => _clients.length;
  String get baristaPin => _baristaPin;

  void setBaristaPin(String pin) {
    if (pin.trim().isNotEmpty) {
      _baristaPin = pin.trim();
    }
  }

  String getTableOrderUrl(String tableNumber) {
    final cleanTable = tableNumber.replaceAll('Table', '').trim();
    return 'http://$_localIp:$_port/order?table=$cleanTable';
  }

  String getOrderTrackingUrl(String orderId, {String? orderNumber}) {
    final cleanId = orderId.trim();
    final cleanNum = (orderNumber ?? '').replaceAll('#', '').trim();
    return 'http://$_localIp:$_port/track?id=$cleanId&order=$cleanNum';
  }

  Future<void> start({
    required List<Map<String, dynamic>> Function() getOrdersCallback,
    required OrderStatusUpdateCallback onStatusUpdate,
    OrderItemPreparedCallback? onOrderItemPrepared,
    List<Map<String, dynamic>> Function()? getMenuCallback,
    CustomerOrderCallback? onCustomerOrderSubmitted,
    CustomerChangeOrderCallback? onCustomerChangeOrder,
    CustomerCancelOrderCallback? onCustomerCancelOrder,
    dynamic Function(String orderId)? getOrderByIdCallback,
    ItemImageCallback? getItemImageCallback,
    int port = 8080,
  }) async {
    getActiveOrdersJson = getOrdersCallback;
    onOrderStatusUpdate = onStatusUpdate;
    this.onOrderItemPrepared = onOrderItemPrepared;
    this.getMenuCallback = getMenuCallback;
    this.onCustomerOrderSubmitted = onCustomerOrderSubmitted;
    this.onCustomerChangeOrder = onCustomerChangeOrder;
    this.onCustomerCancelOrder = onCustomerCancelOrder;
    this.getOrderByIdCallback = getOrderByIdCallback;
    this.getItemImageCallback = getItemImageCallback;
    _port = port;

    await _detectLocalIp();

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);
      _isRunning = true;
      if (kDebugMode) {
        print('Celestial POS & KDS Server started on $serverUrl');
      }

      _server!.listen((HttpRequest request) {
        _handleRequest(request);
      }, onError: (e) {
        if (kDebugMode) print('KDS Server Error: $e');
      });
    } catch (e) {
      try {
        _port = 8081;
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);
        _isRunning = true;
        if (kDebugMode) {
          print('Celestial KDS Server started on fallback $serverUrl');
        }
        _server!.listen((HttpRequest request) {
          _handleRequest(request);
        }, onError: (err) {
          if (kDebugMode) print('KDS Server Error: $err');
        });
      } catch (e2) {
        if (kDebugMode) print('Failed to start KDS Server: $e2');
        _isRunning = false;
      }
    }
  }

  Future<void> _detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Android cellular interface name patterns — never use these as server IP
      const cellularPrefixes = [
        'rmnet', 'ccmni', 'pdp_ip', 'v4-rmnet', 'clat', 'wwan', 'ppp',
      ];

      bool isCellular(String name) {
        final lower = name.toLowerCase();
        return cellularPrefixes.any((p) => lower.startsWith(p));
      }

      String? bestIp;    // Best LAN / Wi-Fi IP
      String? cellularIp; // Last-resort: cellular IP (avoid if possible)

      for (var interface in interfaces) {
        final name = interface.name;
        final isCell = isCellular(name);

        for (var addr in interface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;

          if (kDebugMode) print('Interface: $name  IP: $ip  cellular: $isCell');

          // Skip cellular interfaces for priority matching
          if (isCell) {
            cellularIp ??= ip;
            continue;
          }

          // Priority 1: Current router subnet (192.168.8.x — gateway 192.168.8.1)
          if (ip.startsWith('192.168.8.')) {
            _localIp = ip;
            if (kDebugMode) print('Using router Wi-Fi IP (192.168.8.x): $ip');
            return;
          }
          // Priority 2: TP-Link AP subnet (10.0.0.x)
          else if (ip.startsWith('10.0.0.')) {
            bestIp ??= ip;
          }
          // Priority 3: Common router range (192.168.0.x)
          else if (ip.startsWith('192.168.0.')) {
            bestIp ??= ip;
          }
          // Priority 4: Android hotspot (192.168.43.x)
          else if (ip.startsWith('192.168.43.')) {
            bestIp ??= ip;
          }
          // Priority 5: iPhone hotspot (172.20.10.x)
          else if (ip.startsWith('172.20.10.')) {
            bestIp ??= ip;
          }
          // Priority 6: Any other 192.168.x.x
          else if (ip.startsWith('192.168.')) {
            bestIp ??= ip;
          }
          // Priority 7: Any non-cellular 10.x.x.x
          else if (ip.startsWith('10.')) {
            bestIp ??= ip;
          }
          // Priority 8: Anything else non-loopback non-cellular
          else {
            bestIp ??= ip;
          }
        }
      }

      if (bestIp != null) {
        _localIp = bestIp;
        if (kDebugMode) print('Using LAN IP: $_localIp');
      } else if (cellularIp != null) {
        // Only fall back to cellular IP if there is truly no other option
        _localIp = cellularIp;
        if (kDebugMode) print('No Wi-Fi IP found, using cellular IP: $_localIp');
      } else {
        if (kDebugMode) print('No IP found, keeping default: $_localIp');
      }
    } catch (e) {
      if (kDebugMode) print('Error detecting local IP: $e');
      _localIp = '192.168.8.1';
    }
  }

  void setManualIp(String ip) {
    _localIp = ip.trim();
  }

  Future<void> stop() async {
    for (var client in _clients) {
      try {
        client.close();
      } catch (_) {}
    }
    _baristaClients.clear();
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
  }

  Timer? _broadcastDebounceTimer;

  void broadcastOrders({bool immediate = false}) {
    if (immediate) {
      _broadcastDebounceTimer?.cancel();
      _doBroadcastOrders();
    } else {
      _broadcastDebounceTimer?.cancel();
      _broadcastDebounceTimer = Timer(const Duration(milliseconds: 350), () {
        _doBroadcastOrders();
      });
    }
  }

  void _doBroadcastOrders() {
    if (getActiveOrdersJson == null) return;
    try {
      final ordersList = getActiveOrdersJson!();
      final payload = jsonEncode({
        'type': 'SYNC_ORDERS',
        'orders': ordersList,
      });

      final deadClients = <WebSocket>[];
      for (var client in List<WebSocket>.from(_baristaClients)) {
        if (client.readyState == WebSocket.open) {
          try {
            client.add(payload);
          } catch (_) {
            deadClients.add(client);
          }
        } else {
          deadClients.add(client);
        }
      }
      for (var dead in deadClients) {
        _baristaClients.remove(dead);
        _clients.remove(dead);
        try { dead.close(); } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) print('Error broadcasting KDS orders: $e');
    }
  }

  void broadcastItemPrepared(String orderId, int itemIndex, bool isPrepared) {
    try {
      final payload = jsonEncode({
        'type': 'ITEM_PREPARED',
        'orderId': orderId,
        'itemIndex': itemIndex,
        'isPrepared': isPrepared,
      });

      final deadClients = <WebSocket>[];
      for (var client in List<WebSocket>.from(_baristaClients)) {
        if (client.readyState == WebSocket.open) {
          try {
            client.add(payload);
          } catch (_) {
            deadClients.add(client);
          }
        } else {
          deadClients.add(client);
        }
      }
      for (var dead in deadClients) {
        _baristaClients.remove(dead);
        _clients.remove(dead);
        try { dead.close(); } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) print('Error broadcasting item prepared event: $e');
    }
  }

  void broadcastOrderStatus(String orderId, String orderNumber, String status) {
    try {
      final payload = jsonEncode({
        'type': 'ORDER_STATUS_UPDATE',
        'orderId': orderId,
        'orderNumber': orderNumber,
        'status': status,
      });

      final deadClients = <WebSocket>[];
      for (var client in List<WebSocket>.from(_clients)) {
        if (client.readyState == WebSocket.open) {
          try {
            client.add(payload);
          } catch (_) {
            deadClients.add(client);
          }
        } else {
          deadClients.add(client);
        }
      }
      for (var dead in deadClients) {
        _clients.remove(dead);
        try { dead.close(); } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) print('Error broadcasting order status update: $e');
    }
  }

  void _handleRequest(HttpRequest request) {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      request.response.close();
      return;
    }

    final path = request.uri.path.toLowerCase();

    // ── Captive Portal Detection ─────────────────────────────────────────────
    // iOS checks captive.apple.com/hotspot-detect.html when joining Wi-Fi.
    // If this server is pointed to by the router's DNS for that domain,
    // iOS gets a "Success" response and Safari opens local IPs normally.
    // Android checks /generate_204, Windows checks /connecttest.txt & /ncsi.txt
    if (path == '/hotspot-detect.html' || path == '/library/test/success.html') {
      // Apple iOS / macOS captive portal response
      request.response
        ..headers.contentType = ContentType.html
        ..statusCode = HttpStatus.ok
        ..write('<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>')
        ..close();
      return;
    } else if (path == '/generate_204' || path == '/gen_204') {
      // Android / Chrome captive portal response (204 No Content = online)
      request.response
        ..statusCode = 204
        ..close();
      return;
    } else if (path == '/connecttest.txt' || path == '/ncsi.txt') {
      // Windows Network Connectivity Status Indicator
      request.response
        ..headers.contentType = ContentType.text
        ..statusCode = HttpStatus.ok
        ..write('Microsoft Connect Test')
        ..close();
      return;
    }
    // ─────────────────────────────────────────────────────────────────────────

    if (path == '/ws') {
      _handleWebSocket(request);
    } else if (path == '/logo.png' || path == '/assets/images/logo.png') {
      _serveLogo(request);
    } else if (path.startsWith('/api/item-image') || path.startsWith('/item-image')) {
      _serveItemImage(request);
    } else if (path.startsWith('/order') || path.startsWith('/menu') || path.startsWith('/table') || path.startsWith('/track') || path.startsWith('/claim') || path.startsWith('/status')) {
      _serveCustomerOrderWebPage(request);
    } else if (path.startsWith('/api/barista/verify-pin') || path.startsWith('/api/verify-pin')) {
      _handleBaristaVerifyPinApi(request);
    } else if (path.startsWith('/api/menu')) {
      _handleMenuApi(request);
    } else if (path.startsWith('/api/customer/order')) {
      _handleCustomerOrderApi(request);
    } else if (path.startsWith('/api/customer/change-order')) {
      _handleCustomerChangeOrderApi(request);
    } else if (path.startsWith('/api/customer/cancel-order') || path.startsWith('/api/cancel-order')) {
      _handleCustomerCancelOrderApi(request);
    } else if (path.startsWith('/api/order-status')) {
      _handleOrderStatusApi(request);
    } else if (path.startsWith('/api/orders/update-status') || path.startsWith('/api/update-status')) {
      _handleUpdateStatusApi(request);
    } else if (path.startsWith('/api/orders/item-prep') || path.startsWith('/api/item-prep')) {
      _handleItemPrepApi(request);
    } else if (path.startsWith('/api/table-order')) {
      _handleTableOrderApi(request);
    } else if (path.startsWith('/api/orders')) {
      _handleOrdersApi(request);
    } else {
      _serveKdsWebPage(request);
    }
  }

  static Uint8List? _cachedLogoBytes;

  void _serveItemImage(HttpRequest request) {
    final itemId = request.uri.queryParameters['id'] ?? request.uri.queryParameters['itemId'] ?? '';
    if (getItemImageCallback != null && itemId.isNotEmpty) {
      final bytes = getItemImageCallback!(itemId);
      if (bytes != null) {
        request.response
          ..headers.contentType = ContentType.parse('image/png')
          ..headers.add('Cache-Control', 'public, max-age=86400, immutable')
          ..statusCode = HttpStatus.ok
          ..add(bytes)
          ..close();
        return;
      }
    }
    request.response.statusCode = HttpStatus.notFound;
    request.response.close();
  }

  void _serveLogo(HttpRequest request) async {
    try {
      if (_cachedLogoBytes == null) {
        final byteData = await rootBundle.load('assets/images/Logo.png');
        _cachedLogoBytes = byteData.buffer.asUint8List();
      }
      request.response
        ..headers.contentType = ContentType.parse('image/png')
        ..headers.add('Cache-Control', 'public, max-age=86400, immutable')
        ..statusCode = HttpStatus.ok
        ..add(_cachedLogoBytes!)
        ..close();
      return;
    } catch (_) {}
    request.response.statusCode = HttpStatus.notFound;
    request.response.close();
  }

  void _handleMenuApi(HttpRequest request) {
    final menuList = getMenuCallback != null ? getMenuCallback!() : [];
    request.response
      ..headers.contentType = ContentType.json
      ..statusCode = HttpStatus.ok
      ..write(jsonEncode({'success': true, 'menu': menuList}))
      ..close();
  }

  void _handleOrderStatusApi(HttpRequest request) {
    try {
      final orderId = request.uri.queryParameters['orderId'] ??
          request.uri.queryParameters['id'] ??
          request.uri.queryParameters['orderNumber'] ??
          '';
      final cleanId = orderId.trim().toLowerCase();

      final activeList = getActiveOrdersJson != null ? getActiveOrdersJson!() : <Map<String, dynamic>>[];
      final List<String> currentlyPreparing = [];
      final List<String> currentlyInQueue = [];
      final List<String> currentlyReady = [];

      for (var o in activeList) {
        final s = (o['status'] as String? ?? '').toLowerCase();
        final num = o['orderNumber'] as String? ?? '';
        final rawTable = (o['tableNumber'] as String? ?? '').trim();
        String displayTable = '';
        if (rawTable.isNotEmpty) {
          if (rawTable.toLowerCase() == 'takeout' || rawTable.toLowerCase() == 'takeaway') {
            displayTable = 'Takeout';
          } else if (rawTable.toLowerCase().startsWith('ttable')) {
            displayTable = 'Table ${rawTable.substring(6).trim()}';
          } else if (rawTable.toLowerCase().startsWith('table')) {
            displayTable = rawTable;
          } else if (rawTable.toLowerCase().startsWith('t') && rawTable.length > 1 && int.tryParse(rawTable.substring(1)) != null) {
            displayTable = 'Table ${rawTable.substring(1).trim()}';
          } else {
            displayTable = 'Table $rawTable';
          }
        }
        final tableLabel = displayTable.isNotEmpty ? ' · $displayTable' : '';
        final chip = num.isNotEmpty ? '$num$tableLabel' : '';
        if (chip.isNotEmpty) {
          if (s == 'preparing' || s == 'brewing' || s == 'kitchen') {
            currentlyPreparing.add(chip);
          } else if (s == 'confirmed' || s == 'inqueue' || s == 'queue') {
            currentlyInQueue.add(chip);
          } else if (s == 'ready') {
            currentlyReady.add(chip);
          }
        }
      }

      dynamic matchedOrder;
      if (getOrderByIdCallback != null && cleanId.isNotEmpty) {
        matchedOrder = getOrderByIdCallback!(cleanId);
      }

      if (matchedOrder == null && activeList.isNotEmpty) {
        for (var o in activeList) {
          final oId = (o['id'] as String? ?? '').toLowerCase();
          final oNum = (o['orderNumber'] as String? ?? '').toLowerCase();
          if (oId == cleanId || oNum == cleanId || oNum.replaceAll('#', '').trim() == cleanId) {
            matchedOrder = o;
            break;
          }
        }
      }

      if (matchedOrder != null) {
        final String orderIdVal = matchedOrder is Order
            ? matchedOrder.id
            : (matchedOrder['id']?.toString() ?? '');
        final String orderNumberVal = matchedOrder is Order
            ? matchedOrder.orderNumber
            : (matchedOrder['orderNumber']?.toString() ?? '');
        final String statusVal = matchedOrder is Order
            ? matchedOrder.status.name
            : (matchedOrder['status']?.toString() ?? 'pending');
        final String tableVal = matchedOrder is Order
            ? (matchedOrder.tableNumber ?? '')
            : (matchedOrder['tableNumber']?.toString() ?? '');
        final double totalVal = matchedOrder is Order
            ? matchedOrder.totalAmount
            : ((matchedOrder['totalAmount'] as num?)?.toDouble() ?? 0.0);
        final double subtotalVal = matchedOrder is Order
            ? matchedOrder.subtotal
            : ((matchedOrder['subtotal'] as num?)?.toDouble() ?? totalVal);
        final double discountVal = matchedOrder is Order
            ? matchedOrder.discountAmount
            : ((matchedOrder['discountAmount'] as num?)?.toDouble() ?? 0.0);
        final double discountPct = matchedOrder is Order
            ? matchedOrder.discountPercentage
            : ((matchedOrder['discountPercentage'] as num?)?.toDouble() ?? 0.0);
        final String paymentMethodVal = matchedOrder is Order
            ? matchedOrder.paymentMethod.label
            : (matchedOrder['paymentMethod']?.toString() ?? 'Cash');
        final double amountTenderedVal = matchedOrder is Order
            ? matchedOrder.amountTendered
            : ((matchedOrder['amountTendered'] as num?)?.toDouble() ?? totalVal);
        final double changeDueVal = matchedOrder is Order
            ? matchedOrder.changeDue
            : ((matchedOrder['changeDue'] as num?)?.toDouble() ?? 0.0);
        final String customerNameVal = matchedOrder is Order
            ? matchedOrder.customerName
            : (matchedOrder['customerName']?.toString() ?? 'Guest Patron');
        final String cashierNameVal = matchedOrder is Order
            ? matchedOrder.cashierName
            : (matchedOrder['cashierName']?.toString() ?? 'Cashier Staff');
        final String createdAtVal = matchedOrder is Order
            ? matchedOrder.createdAt.toIso8601String()
            : (matchedOrder['createdAt']?.toString() ?? '');
        final String orderTypeVal = matchedOrder is Order
            ? matchedOrder.orderType.name
            : (matchedOrder['orderType']?.toString() ?? 'dineIn');
        final bool isPaid = statusVal != 'pending' && statusVal != 'cancelled';

        final dynamic orderItems = matchedOrder is Order ? matchedOrder.items : matchedOrder['items'];
        List<Map<String, dynamic>> itemsJson = [];
        if (orderItems is List) {
          for (var i in orderItems) {
            if (i is OrderItem) {
              itemsJson.add({
                'name': i.menuItem.name,
                'quantity': i.quantity,
                'price': i.totalPrice,
                'unitPrice': i.unitPrice,
                'notes': i.notes ?? '',
                'customizations': i.customizations.map((c) => c.optionName).toList(),
              });
            } else if (i is Map) {
              itemsJson.add({
                'name': i['name'] ?? i['itemName'] ?? 'Item',
                'quantity': i['quantity'] ?? 1,
                'price': i['price'] ?? i['totalPrice'] ?? 0.0,
                'unitPrice': i['unitPrice'] ?? 0.0,
                'notes': i['notes'] ?? '',
                'customizations': (i['customizations'] as List?)
                        ?.map((c) => c is Map ? (c['optionName'] ?? c['name'] ?? '') : c.toString())
                        .toList() ??
                    [],
              });
            }
          }
        }

        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({
            'success': true,
            'orderId': orderIdVal,
            'orderNumber': orderNumberVal,
            'status': statusVal,
            'orderType': orderTypeVal,
            'isPaid': isPaid,
            'tableNumber': tableVal,
            'totalAmount': totalVal,
            'subtotal': subtotalVal,
            'discountAmount': discountVal,
            'discountPercentage': discountPct,
            'paymentMethod': paymentMethodVal,
            'amountTendered': amountTenderedVal,
            'changeDue': changeDueVal,
            'customerName': customerNameVal,
            'cashierName': cashierNameVal,
            'createdAt': createdAtVal,
            'items': itemsJson,
            'currentlyPreparing': currentlyPreparing,
            'currentlyInQueue': currentlyInQueue,
            'currentlyReady': currentlyReady,
          }))
          ..close();
      } else {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({
            'success': cleanId.isEmpty,
            'status': cleanId.isEmpty ? 'idle' : 'not_found',
            'isPaid': false,
            'error': cleanId.isNotEmpty ? 'Order not found in cafe records' : null,
            'currentlyPreparing': currentlyPreparing,
            'currentlyInQueue': currentlyInQueue,
            'currentlyReady': currentlyReady,
          }))
          ..close();
      }
    } catch (e, stack) {
      if (kDebugMode) print('Error in _handleOrderStatusApi: $e\n$stack');
      try {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({
            'success': true,
            'status': 'pending',
            'isPaid': false,
            'error': e.toString(),
            'currentlyPreparing': [],
            'currentlyInQueue': [],
            'currentlyReady': [],
          }))
          ..close();
      } catch (_) {}
    }
  }

  void _handleCustomerOrderApi(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join().timeout(const Duration(seconds: 25));
      final data = jsonDecode(content) as Map<String, dynamic>;

      if (onCustomerOrderSubmitted != null) {
        final result = onCustomerOrderSubmitted!(data);
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode(result));
        await request.response.close();
      } else {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.internalServerError
          ..write(jsonEncode({'success': false, 'error': 'Server callback not initialized'}));
        await request.response.close();
      }
    } catch (e) {
      try {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.badRequest
          ..write(jsonEncode({'success': false, 'error': e.toString()}));
        await request.response.close();
      } catch (_) {}
    }
  }

  void _handleCustomerChangeOrderApi(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final orderId = data['orderId'] as String? ?? data['id'] as String? ?? '';

      if (onCustomerChangeOrder != null && orderId.isNotEmpty) {
        final result = onCustomerChangeOrder!(orderId);
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode(result))
          ..close();
      } else {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.badRequest
          ..write(jsonEncode({'success': false, 'error': 'Missing order ID or change handler not initialized'}))
          ..close();
      }
    } catch (e) {
      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.badRequest
        ..write(jsonEncode({'success': false, 'error': e.toString()}))
        ..close();
    }
  }

  void _handleCustomerCancelOrderApi(HttpRequest request) async {
    try {
      String orderId = request.uri.queryParameters['orderId'] ??
          request.uri.queryParameters['id'] ??
          request.uri.queryParameters['orderNumber'] ??
          '';

      // Always fully read and drain request body to maintain persistent HTTP keep-alive connection
      String content = '';
      try {
        content = await utf8.decoder.bind(request).join();
      } catch (_) {}

      if (orderId.isEmpty && content.isNotEmpty) {
        try {
          final data = jsonDecode(content) as Map<String, dynamic>;
          orderId = data['orderId'] as String? ??
              data['id'] as String? ??
              data['orderNumber'] as String? ??
              '';
        } catch (_) {}
      }

      if (onCustomerCancelOrder != null && orderId.isNotEmpty) {
        final result = onCustomerCancelOrder!(orderId);
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode(result))
          ..close();
      } else {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({'success': false, 'error': 'Missing order ID or order not found'}))
          ..close();
      }
    } catch (e) {
      try {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({'success': false, 'error': e.toString()}))
          ..close();
      } catch (_) {}
    }
  }

  bool _isBaristaAuthorized(HttpRequest request, [Map<String, dynamic>? body]) {
    final qPin = request.uri.queryParameters['pin'];
    if (qPin != null && qPin.trim() == _baristaPin) return true;

    final hPin = request.headers.value('X-Barista-Pin');
    if (hPin != null && hPin.trim() == _baristaPin) return true;

    final auth = request.headers.value('Authorization');
    if (auth != null) {
      final cleanAuth = auth.replaceFirst('Bearer ', '').trim();
      if (cleanAuth == _baristaPin) return true;
    }

    if (body != null && body['pin']?.toString().trim() == _baristaPin) return true;

    return false;
  }

  void _handleBaristaVerifyPinApi(HttpRequest request) async {
    try {
      String pin = request.uri.queryParameters['pin'] ?? '';
      if (pin.isEmpty && (request.method == 'POST' || request.method == 'PUT')) {
        final content = await utf8.decoder.bind(request).join();
        if (content.isNotEmpty) {
          final data = jsonDecode(content) as Map<String, dynamic>;
          pin = data['pin']?.toString() ?? '';
        }
      }
      final isValid = pin.isNotEmpty && pin.trim() == _baristaPin;
      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = isValid ? HttpStatus.ok : HttpStatus.unauthorized
        ..write(jsonEncode({
          'success': isValid,
          'valid': isValid,
          if (!isValid) 'error': 'Invalid Barista Security PIN',
        }))
        ..close();
    } catch (e) {
      try {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.badRequest
          ..write(jsonEncode({'success': false, 'valid': false, 'error': e.toString()}))
          ..close();
      } catch (_) {}
    }
  }

  void _handleOrdersApi(HttpRequest request) {
    if (!_isBaristaAuthorized(request)) {
      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.unauthorized
        ..write(jsonEncode({'success': false, 'error': 'Unauthorized: Valid Barista PIN required'}))
        ..close();
      return;
    }
    final ordersList = getActiveOrdersJson != null ? getActiveOrdersJson!() : [];
    request.response
      ..headers.contentType = ContentType.json
      ..statusCode = HttpStatus.ok
      ..write(jsonEncode({'success': true, 'orders': ordersList}))
      ..close();
  }

  /// Returns the most recent non-completed, non-cancelled active order for a given table number.
  /// Used by customer page to auto-restore tracking on any device that opens the same table URL.
  void _handleTableOrderApi(HttpRequest request) {
    final raw = request.uri.queryParameters['table'] ?? '';
    final tableNum = raw.replaceAll(RegExp(r'table\s*', caseSensitive: false), '').trim();
    if (tableNum.isEmpty) {
      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'success': false, 'error': 'No table specified'}))
        ..close();
      return;
    }

    final activeList = getActiveOrdersJson != null ? getActiveOrdersJson!() : <Map<String, dynamic>>[];
    Map<String, dynamic>? matched;
    for (final o in activeList.reversed.toList()) {
      final t = (o['tableNumber'] as String? ?? '')
          .replaceAll(RegExp(r'table\s*', caseSensitive: false), '')
          .trim();
      final s = (o['status'] as String? ?? '').toLowerCase();
      if (t == tableNum && s != 'completed' && s != 'cancelled') {
        matched = o;
        break;
      }
    }

    if (matched != null) {
      final double totalVal = (matched['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final double subtotalVal = (matched['subtotal'] as num?)?.toDouble() ?? totalVal;
      final double discountVal = (matched['discountAmount'] as num?)?.toDouble() ?? 0.0;
      final double discountPct = (matched['discountPercentage'] as num?)?.toDouble() ?? 0.0;
      final String paymentMethodVal = matched['paymentMethod']?.toString() ?? 'Cash';
      final double amountTenderedVal = (matched['amountTendered'] as num?)?.toDouble() ?? totalVal;
      final double changeDueVal = (matched['changeDue'] as num?)?.toDouble() ?? 0.0;
      final String customerNameVal = matched['customerName']?.toString() ?? 'Guest Patron';
      final String cashierNameVal = matched['cashierName']?.toString() ?? 'Cashier Staff';
      final String createdAtVal = matched['createdAt']?.toString() ?? '';

      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({
          'success': true,
          'orderId': matched['id'],
          'orderNumber': matched['orderNumber'],
          'status': matched['status'],
          'tableNumber': matched['tableNumber'],
          'totalAmount': totalVal,
          'subtotal': subtotalVal,
          'discountAmount': discountVal,
          'discountPercentage': discountPct,
          'paymentMethod': paymentMethodVal,
          'amountTendered': amountTenderedVal,
          'changeDue': changeDueVal,
          'customerName': customerNameVal,
          'cashierName': cashierNameVal,
          'createdAt': createdAtVal,
          'items': matched['items'] ?? [],
        }))
        ..close();
    } else {
      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'success': false, 'error': 'No active order for this table'}))
        ..close();
    }
  }

  void _handleUpdateStatusApi(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      final data = jsonDecode(content) as Map<String, dynamic>;

      if (!_isBaristaAuthorized(request, data)) {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.unauthorized
          ..write(jsonEncode({'success': false, 'error': 'Unauthorized: Valid Barista PIN required'}))
          ..close();
        return;
      }

      final orderId = data['orderId'] as String?;
      final status = data['status'] as String?;

      if (orderId != null && status != null) {
        onOrderStatusUpdate?.call(orderId, status);
      }

      final ordersList = getActiveOrdersJson != null ? getActiveOrdersJson!() : [];
      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'success': true, 'orders': ordersList}))
        ..close();
    } catch (e) {
      try {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.badRequest
          ..write(jsonEncode({'success': false, 'error': e.toString()}))
          ..close();
      } catch (_) {}
    }
  }

  void _handleItemPrepApi(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      final data = jsonDecode(content) as Map<String, dynamic>;

      if (!_isBaristaAuthorized(request, data)) {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.unauthorized
          ..write(jsonEncode({'success': false, 'error': 'Unauthorized: Valid Barista PIN required'}))
          ..close();
        return;
      }

      final orderId = data['orderId'] as String?;
      final itemIndex = (data['itemIndex'] as num?)?.toInt();
      final isPrepared = data['isPrepared'] as bool? ?? true;

      if (orderId != null && itemIndex != null) {
        onOrderItemPrepared?.call(orderId, itemIndex, isPrepared);
      }

      final ordersList = getActiveOrdersJson != null ? getActiveOrdersJson!() : [];
      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'success': true, 'orders': ordersList}))
        ..close();
    } catch (e) {
      try {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.badRequest
          ..write(jsonEncode({'success': false, 'error': e.toString()}))
          ..close();
      } catch (_) {}
    }
  }

  void _handleWebSocket(HttpRequest request) async {
    try {
      final isBarista = _isBaristaAuthorized(request);
      final socket = await WebSocketTransformer.upgrade(request);
      socket.pingInterval = const Duration(seconds: 6);
      _clients.add(socket);
      if (isBarista) {
        _baristaClients.add(socket);
      }

      // Only send full kitchen ticket backlog to authorized Barista sockets
      if (isBarista && getActiveOrdersJson != null) {
        socket.add(jsonEncode({
          'type': 'SYNC_ORDERS',
          'orders': getActiveOrdersJson!(),
        }));
      }

      socket.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            final action = msg['action'] as String?;
            final orderId = msg['orderId'] as String?;
            final status = msg['status'] as String?;
            final pin = msg['pin']?.toString();

            if (action == 'update_status' && orderId != null && status != null) {
              if (isBarista || (pin != null && pin.trim() == _baristaPin)) {
                onOrderStatusUpdate?.call(orderId, status);
              } else if (kDebugMode) {
                print('Rejected unauthorized update_status on WebSocket');
              }
            } else if (action == 'toggle_item_prep' && orderId != null && msg['itemIndex'] != null) {
              final itemIdx = (msg['itemIndex'] as num).toInt();
              final isPrepared = msg['isPrepared'] as bool? ?? true;
              if (isBarista || (pin != null && pin.trim() == _baristaPin)) {
                onOrderItemPrepared?.call(orderId, itemIdx, isPrepared);
              }
            }
          } catch (e) {
            if (kDebugMode) print('Error parsing KDS WS message: $e');
          }
        },
        onDone: () {
          _clients.remove(socket);
          _baristaClients.remove(socket);
          try { socket.close(); } catch (_) {}
        },
        onError: (err) {
          _clients.remove(socket);
          _baristaClients.remove(socket);
          try { socket.close(); } catch (_) {}
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (kDebugMode) print('WebSocket upgrade failed: $e');
    }
  }

  static List<int>? _gzippedKdsHtml;

  void _serveKdsWebPage(HttpRequest request) {
    final acceptEncoding = request.headers.value(HttpHeaders.acceptEncodingHeader) ?? '';
    final canGzip = acceptEncoding.contains('gzip');

    request.response
      ..headers.contentType = ContentType.html
      ..headers.add('Cache-Control', 'no-cache');

    if (canGzip) {
      _gzippedKdsHtml ??= gzip.encode(utf8.encode(_kdsHtmlTemplate));
      request.response
        ..headers.add(HttpHeaders.contentEncodingHeader, 'gzip')
        ..statusCode = HttpStatus.ok
        ..add(_gzippedKdsHtml!)
        ..close();
    } else {
      request.response
        ..statusCode = HttpStatus.ok
        ..write(_kdsHtmlTemplate)
        ..close();
    }
  }

  void _serveCustomerOrderWebPage(HttpRequest request) {
    final menuJson = jsonEncode(getMenuCallback != null ? getMenuCallback!() : []);
    final html = _customerOrderHtmlTemplate.replaceFirst(
      '/*__INITIAL_MENU_DATA__*/',
      'window.INITIAL_MENU = $menuJson;',
    );
    final acceptEncoding = request.headers.value(HttpHeaders.acceptEncodingHeader) ?? '';
    final canGzip = acceptEncoding.contains('gzip');

    request.response
      ..headers.contentType = ContentType.html
      ..headers.add('Cache-Control', 'no-cache');

    if (canGzip) {
      final compressed = gzip.encode(utf8.encode(html));
      request.response
        ..headers.add(HttpHeaders.contentEncodingHeader, 'gzip')
        ..statusCode = HttpStatus.ok
        ..add(compressed)
        ..close();
    } else {
      request.response
        ..statusCode = HttpStatus.ok
        ..write(html)
        ..close();
    }
  }

  // 1:1 Matched Fast Local KDS HTML Template (0s load, no external fonts)
  static const String _kdsHtmlTemplate = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Celestial Cafe — Barista KDS</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@700;800;900&family=Outfit:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-dark: #0A070D;
      --bg-surface: #140E18;
      --bg-card: #1A1320;
      --gold-primary: #D4AF37;
      --gold-light: #F5D780;
      --brown-warm: #432C1D;
      --emerald-ready: #2EC4B6;
      --amber-brewing: #FF9F1C;
      --rose-alert: #E71D36;
      --blue-info: #4CC9F0;
      --text-light: #F7EFE8;
      --text-muted: #AFA399;
      --text-subtle: #736962;
      --kds-zoom: 1;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: 'Outfit', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      -webkit-tap-highlight-color: transparent;
    }
    body {
      background-color: var(--bg-dark);
      color: var(--text-light);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    
    header {
      background: var(--bg-surface);
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      padding: 10px 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      position: sticky;
      top: 0;
      z-index: 100;
      box-shadow: 0 4px 12px rgba(0,0,0,0.5);
      flex-wrap: wrap;
      gap: 8px;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .brand-title {
      font-weight: 800;
      font-size: 15px;
      letter-spacing: 2px;
      color: var(--gold-primary);
      line-height: 1.1;
    }
    .brand-sub {
      font-size: 9.5px;
      letter-spacing: 1px;
      font-weight: 600;
      color: var(--gold-light);
      opacity: 0.8;
      margin-top: 1px;
    }

    /* KDS Text Size & Display Zoom Controls */
    .kds-zoom-toolbar {
      display: inline-flex;
      align-items: center;
      background: var(--bg-card);
      border: 1.2px solid rgba(212, 175, 55, 0.3);
      border-radius: 20px;
      padding: 3px 8px;
      gap: 4px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.3);
    }
    .zoom-btn {
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.15);
      color: var(--gold-light);
      border-radius: 8px;
      padding: 3px 7px;
      font-size: 11px;
      font-weight: 800;
      cursor: pointer;
      line-height: 1;
      transition: all 0.15s ease;
    }
    .zoom-btn:hover {
      background: var(--gold-primary);
      color: var(--bg-dark);
    }
    .zoom-btn:active {
      transform: scale(0.92);
    }
    .zoom-label {
      font-size: 11px;
      font-weight: 800;
      color: var(--gold-light);
      min-width: 36px;
      text-align: center;
    }
    .zoom-presets {
      display: flex;
      gap: 3px;
      margin-left: 2px;
    }
    .zoom-pill {
      background: transparent;
      border: 1px solid transparent;
      color: var(--text-muted);
      border-radius: 12px;
      padding: 2px 7px;
      font-size: 10px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.15s ease;
    }
    .zoom-pill.active {
      background: rgba(212, 175, 55, 0.25);
      border-color: var(--gold-primary);
      color: var(--gold-light);
      font-weight: 800;
    }
    .zoom-pill:hover {
      color: var(--text-light);
    }
    @media (max-width: 680px) {
      .zoom-presets { display: none; }
    }
    
    .status-badge {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 5px 12px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 700;
      background: rgba(46, 196, 182, 0.15);
      color: var(--emerald-ready);
      border: 1px solid rgba(46, 196, 182, 0.4);
    }
    .status-badge.disconnected {
      background: rgba(231, 29, 54, 0.15);
      color: var(--rose-alert);
      border-color: rgba(231, 29, 54, 0.4);
    }
    .dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: currentColor;
      animation: pulse 2s infinite;
    }
    @keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.3; } 100% { opacity: 1; } }

    .filter-bar {
      background: var(--bg-surface);
      padding: 10px 16px;
      display: flex;
      gap: 8px;
      overflow-x: auto;
      border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    }
    .tab-btn {
      background: var(--bg-card);
      border: 1px solid rgba(255, 255, 255, 0.08);
      color: var(--text-muted);
      padding: 7px 14px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      white-space: nowrap;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.15s ease;
    }
    .tab-btn.active {
      background: rgba(212, 175, 55, 0.2);
      border-color: var(--gold-primary);
      color: var(--text-light);
      font-weight: 700;
    }
    .tab-count {
      padding: 1px 6px;
      border-radius: 10px;
      font-size: 10px;
      font-weight: 800;
      background: rgba(255, 255, 255, 0.1);
    }
    .tab-btn.active .tab-count {
      background: var(--gold-primary);
      color: var(--bg-dark);
    }

    main {
      flex: 1;
      padding: 16px;
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(310px, 1fr));
      gap: 16px;
      align-content: start;
    }

    .ticket {
      background: linear-gradient(170deg, #1C1522 0%, #120D17 100%);
      border-radius: 20px;
      border: 1.5px solid rgba(255, 255, 255, 0.08);
      overflow: hidden;
      display: flex;
      flex-direction: column;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.6);
      transition: all 0.2s cubic-bezier(0.2, 0.8, 0.4, 1);
    }
    .ticket:hover {
      border-color: rgba(255, 255, 255, 0.16);
      transform: translateY(-2px);
      box-shadow: 0 14px 38px rgba(0, 0, 0, 0.7);
    }
    .ticket.pending {
      border-color: rgba(212, 175, 55, 0.38);
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.6), 0 0 15px rgba(212, 175, 55, 0.08);
    }
    .ticket.preparing {
      border-color: rgba(255, 159, 28, 0.65);
      box-shadow: 0 10px 32px rgba(255, 159, 28, 0.2), 0 0 18px rgba(255, 159, 28, 0.1);
    }
    .ticket.ready {
      border-color: rgba(46, 196, 182, 0.65);
      box-shadow: 0 10px 32px rgba(46, 196, 182, 0.2), 0 0 18px rgba(46, 196, 182, 0.1);
    }

    .ticket-header {
      padding: 14px 16px 11px 16px;
      background: rgba(255, 255, 255, 0.02);
      border-bottom: 1px solid rgba(255, 255, 255, 0.07);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .ticket-title-group { display: flex; align-items: center; gap: 9px; }
    .ticket-number {
      font-family: 'Cinzel', 'Outfit', serif;
      font-size: 20px;
      font-weight: 900;
      color: var(--gold-light);
      letter-spacing: 0.8px;
      text-shadow: 0 2px 8px rgba(212, 175, 55, 0.25);
    }
    .order-type-badge {
      padding: 3px 9px;
      border-radius: 8px;
      font-size: 11px;
      font-weight: 800;
      background: rgba(67, 44, 29, 0.45);
      color: var(--gold-light);
      border: 1px solid rgba(212, 175, 55, 0.3);
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }
    .order-type-badge.takeout-badge {
      background: linear-gradient(135deg, #FF9F1C 0%, #E07A00 100%) !important;
      color: #000000 !important;
      font-weight: 900 !important;
      border: 1px solid #FFA000 !important;
      box-shadow: 0 0 12px rgba(255, 159, 28, 0.5);
    }
    .ticket.takeout-ticket {
      border-left: 5px solid #FF9F1C !important;
    }
    .takeout-banner {
      background: rgba(255, 159, 28, 0.16);
      border: 1.2px solid rgba(255, 159, 28, 0.55);
      color: #FFB74D;
      font-size: 11px;
      font-weight: 900;
      letter-spacing: 0.5px;
      padding: 6px 12px;
      border-radius: 8px;
      margin: 8px 16px 2px 16px;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .takeout-item-badge {
      background: rgba(255, 159, 28, 0.24);
      border: 1px solid rgba(255, 159, 28, 0.65);
      color: #FFB74D;
      font-size: 10px;
      font-weight: 900;
      padding: 1px 6px;
      border-radius: 4px;
      margin-left: 6px;
      display: inline-flex;
      align-items: center;
      gap: 3px;
    }

    .ticket-header-right { display: flex; align-items: center; gap: 6px; }
    .timer-badge { display: flex; align-items: center; gap: 4px; padding: 4px 8px; border-radius: 8px; font-size: 11px; font-weight: 700; }
    .timer-green { background: rgba(46, 196, 182, 0.15); border: 1px solid rgba(46, 196, 182, 0.5); color: var(--emerald-ready); }
    .timer-amber { background: rgba(255, 159, 28, 0.15); border: 1px solid rgba(255, 159, 28, 0.5); color: var(--amber-brewing); }
    .timer-red { background: rgba(231, 29, 54, 0.15); border: 1px solid rgba(231, 29, 54, 0.5); color: var(--rose-alert); }

    .void-btn {
      background: rgba(231, 29, 54, 0.15);
      border: 1px solid rgba(231, 29, 54, 0.4);
      color: var(--rose-alert);
      border-radius: 6px;
      width: 26px;
      height: 26px;
      font-size: 13px;
      font-weight: bold;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: background 0.15s;
    }
    .void-btn:active { background: var(--rose-alert); color: #fff; }

    .ticket-sub {
      padding: 8px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid rgba(255, 255, 255, 0.05);
      font-size: 12px;
    }
    .guest-name { font-weight: 600; color: var(--text-light); }
    .item-count-text { color: var(--text-muted); font-size: 11px; }

    .ticket-body { padding: 14px 16px; flex: 1; }
    
    .item-row {
      margin-bottom: 10px;
      padding: 6px 8px;
      border-radius: 8px;
      border-bottom: 1px dashed rgba(255, 255, 255, 0.07);
      cursor: pointer;
      user-select: none;
      transition: all 0.18s ease;
      position: relative;
    }
    .item-row:hover {
      background: rgba(255, 255, 255, 0.035);
    }
    .item-row:active {
      transform: scale(0.99);
    }
    .item-row:last-child { margin-bottom: 0; padding-bottom: 4px; border-bottom: none; }
    
    .item-row.item-done {
      opacity: 0.52;
      background: rgba(46, 196, 182, 0.06);
      border: 1px solid rgba(46, 196, 182, 0.25);
    }
    .item-row.item-done .item-name {
      text-decoration: line-through;
      color: #A39B94;
    }
    .item-row.item-done .custom-list {
      opacity: 0.45;
      text-decoration: line-through;
    }
    .item-row.item-done .note-box {
      text-decoration: line-through;
      opacity: 0.5;
      background: rgba(255, 255, 255, 0.04);
      border-color: rgba(255, 255, 255, 0.1);
      color: var(--text-muted);
    }
    .item-row.item-done .item-qty {
      background: rgba(46, 196, 182, 0.35);
      color: #2EC4B6;
    }
    .item-row.item-row-locked {
      cursor: default;
    }
    .item-row.item-row-locked:hover {
      background: transparent;
    }
    .item-row.item-row-locked .item-prep-toggle {
      border-color: rgba(255, 255, 255, 0.12);
      opacity: 0.55;
    }

    .item-prep-toggle {
      width: 18px;
      height: 18px;
      border-radius: 5px;
      border: 1.5px solid rgba(255, 255, 255, 0.28);
      background: rgba(255, 255, 255, 0.04);
      display: inline-flex;
      align-items: center;
      justify-content: center;
      color: transparent;
      font-size: 11px;
      font-weight: 900;
      margin-right: 2px;
      flex-shrink: 0;
      transition: all 0.15s ease;
    }
    .item-row.item-done .item-prep-toggle {
      background: #2EC4B6;
      border-color: #2EC4B6;
      color: #0D0B10;
      box-shadow: 0 0 8px rgba(46, 196, 182, 0.45);
    }
    .item-prepared-badge {
      display: inline-flex;
      align-items: center;
      gap: 3px;
      font-size: 9.5px;
      font-weight: 900;
      color: #2EC4B6;
      background: rgba(46, 196, 182, 0.16);
      border: 1px solid rgba(46, 196, 182, 0.45);
      padding: 1.5px 6px;
      border-radius: 8px;
      letter-spacing: 0.4px;
      margin-left: auto;
    }
    .note-box {
      margin-top: 5px;
      margin-left: 28px;
      padding: 4px 8px;
      background: rgba(231, 29, 54, 0.12);
      border: 1px solid rgba(231, 29, 54, 0.35);
      border-radius: 6px;
      font-size: 11px;
      font-weight: 700;
      color: #FF6B6B;
      display: inline-flex;
      align-items: center;
      gap: 5px;
    }
    .all-prepared-banner {
      margin: 8px 14px 2px 14px;
      padding: 6px 10px;
      background: rgba(46, 196, 182, 0.14);
      border: 1.2px solid rgba(46, 196, 182, 0.45);
      border-radius: 8px;
      color: #2EC4B6;
      font-size: 11.5px;
      font-weight: 800;
      text-align: center;
      letter-spacing: 0.3px;
      animation: kdsGlow 1.5s infinite alternate ease-in-out;
    }
    @keyframes kdsGlow {
      0% { box-shadow: 0 0 3px rgba(46,196,182,0.2); }
      100% { box-shadow: 0 0 12px rgba(46,196,182,0.55); }
    }
    
    .item-title-row { display: flex; align-items: center; gap: calc(8px * var(--kds-zoom, 1)); flex-wrap: wrap; }
    .item-qty {
      padding: calc(2px * var(--kds-zoom, 1)) calc(6px * var(--kds-zoom, 1));
      border-radius: 6px;
      background: var(--gold-primary);
      color: var(--bg-dark);
      font-size: calc(12px * var(--kds-zoom, 1));
      font-weight: 800;
      min-width: calc(24px * var(--kds-zoom, 1));
      text-align: center;
    }
    .item-name { font-weight: 700; font-size: calc(14px * var(--kds-zoom, 1)); color: var(--text-light); flex: 1; }

    /* Kitchen Cook Dish Highlighting */
    .ticket.has-kitchen {
      border-top: 3.5px solid #FF5722 !important;
      box-shadow: 0 4px 20px rgba(255, 87, 34, 0.16) !important;
    }
    .kitchen-item-row {
      background: linear-gradient(135deg, rgba(255, 87, 34, 0.16) 0%, rgba(255, 112, 67, 0.05) 100%) !important;
      border: 1.5px solid rgba(255, 87, 34, 0.5) !important;
      border-left: 4px solid #FF5722 !important;
      border-radius: 10px;
      padding: 9px 11px !important;
      margin-bottom: 9px !important;
      box-shadow: 0 2px 10px rgba(255, 87, 34, 0.15);
    }
    .kitchen-tag {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      font-size: calc(10px * var(--kds-zoom, 1));
      font-weight: 900;
      letter-spacing: 0.8px;
      text-transform: uppercase;
      color: #FF7043;
      background: rgba(255, 87, 34, 0.22);
      border: 1px solid rgba(255, 87, 34, 0.45);
      border-radius: 5px;
      padding: 2px 7px;
      margin-bottom: 5px;
    }
    .kitchen-name {
      color: #FFE0B2 !important;
      font-size: calc(15px * var(--kds-zoom, 1)) !important;
      font-weight: 800 !important;
    }
    .kitchen-qty {
      background: #FF5722 !important;
      color: #FFFFFF !important;
      box-shadow: 0 2px 8px rgba(255, 87, 34, 0.4);
    }
    .custom-item {
      font-size: calc(11.5px * var(--kds-zoom, 1));
      color: var(--text-muted);
      margin-bottom: 2px;
    }
    .note-box {
      font-size: calc(11.5px * var(--kds-zoom, 1));
    }
    .station-badge-kitchen {
      background: rgba(255, 87, 34, 0.2);
      border: 1.2px solid rgba(255, 87, 34, 0.65);
      color: #FF7043;
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 10.5px;
      font-weight: 800;
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }
    .station-badge-bar {
      background: rgba(255, 159, 28, 0.16);
      border: 1.2px solid rgba(255, 159, 28, 0.5);
      color: var(--gold-light);
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 10.5px;
      font-weight: 800;
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }

    .size-badge { font-size: 11px; font-weight: 800; padding: 3px 8px; border-radius: 6px; letter-spacing: 0.5px; }
    .size-16oz { background: rgba(76, 201, 240, 0.25); color: var(--blue-info); border: 1.2px solid var(--blue-info); }
    .size-22oz { background: rgba(255, 159, 28, 0.25); color: var(--amber-brewing); border: 1.2px solid var(--amber-brewing); }

    .custom-list { margin-top: 4px; padding-left: 32px; font-size: 11.5px; font-weight: 500; color: var(--gold-light); }
    .custom-item { margin-top: 2px; }

    .order-memo-box {
      margin: 8px 16px 0 16px;
      padding: 8px 10px;
      background: rgba(255, 159, 28, 0.1);
      border: 1px solid rgba(255, 159, 28, 0.3);
      border-radius: 8px;
      font-size: 11px;
      color: var(--amber-brewing);
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .ticket-footer {
      padding: 12px 14px;
      background: var(--bg-surface);
      border-top: 1px solid rgba(255, 255, 255, 0.05);
      display: flex;
      gap: 8px;
    }
    .action-btn {
      width: 100%;
      padding: 12px 10px;
      border-radius: 12px;
      border: none;
      font-size: 13px;
      font-weight: 800;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      transition: all 0.16s cubic-bezier(0.2, 0.8, 0.4, 1);
      letter-spacing: 0.3px;
    }
    .action-btn:hover {
      transform: translateY(-1.5px);
      filter: brightness(1.08);
    }
    .action-btn:active {
      transform: scale(0.96) translateY(1px);
      filter: brightness(0.95);
    }
    .btn-brew {
      background: linear-gradient(135deg, #FF9F1C 0%, #D87700 100%);
      color: #0B080D;
      box-shadow: 0 4px 16px rgba(255, 159, 28, 0.4);
    }
    .btn-ready {
      background: linear-gradient(135deg, #2EC4B6 0%, #178B81 100%);
      color: #0B080D;
      box-shadow: 0 4px 16px rgba(46, 196, 182, 0.4);
    }
    .btn-done {
      background: linear-gradient(135deg, #22C55E 0%, #15803D 100%);
      color: #FFFFFF;
      font-weight: 800;
      box-shadow: 0 4px 16px rgba(34, 197, 94, 0.45);
    }

    .btn-spinner {
      display: inline-block;
      width: 14px;
      height: 14px;
      border: 2px solid rgba(0, 0, 0, 0.25);
      border-top-color: currentColor;
      border-radius: 50%;
      animation: spin 0.6s linear infinite;
    }
    .btn-done .btn-spinner {
      border: 2px solid rgba(255, 255, 255, 0.35);
      border-top-color: #ffffff;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }

    /* Live Barista Order Action & Checklist Confirmation Modal (Matched 1:1 to KDS) */
    .kds-modal-overlay {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0, 0, 0, 0.8);
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
      z-index: 99999;
      display: none;
      align-items: center;
      justify-content: center;
      padding: 16px;
      overflow-y: auto;
    }
    .kds-confirm-card {
      max-width: 440px;
      width: 100%;
      background: var(--bg-surface);
      border: 1.5px solid rgba(46, 196, 182, 0.5);
      border-radius: 18px;
      padding: 22px 20px 20px 20px;
      text-align: left;
      box-shadow: 0 16px 50px rgba(0, 0, 0, 0.9), 0 0 24px rgba(0, 0, 0, 0.6);
      margin: auto;
      animation: kdsModalPop 0.22s cubic-bezier(0.16, 1, 0.3, 1);
      box-sizing: border-box;
    }
    @keyframes kdsModalPop {
      0% { opacity: 0; transform: scale(0.92) translateY(8px); }
      100% { opacity: 1; transform: scale(1) translateY(0); }
    }
    .kds-chk-item {
      display: flex;
      align-items: flex-start;
      gap: 10px;
      padding: 6px 6px;
      border-radius: 8px;
      cursor: pointer;
      user-select: none;
      transition: background 0.15s ease;
    }
    .kds-chk-item:hover {
      background: rgba(255, 255, 255, 0.04);
    }
    .kds-chk-box {
      width: 17px;
      height: 17px;
      min-width: 17px;
      border: 1.8px solid var(--gold-primary);
      border-radius: 4px;
      margin-top: 2px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      transition: all 0.15s ease;
      box-sizing: border-box;
      background: transparent;
    }
    .kds-chk-box.checked {
      background: var(--gold-primary);
      border-color: var(--gold-primary);
    }
    .kds-chk-box svg {
      display: none;
      width: 11px;
      height: 11px;
    }
    .kds-chk-box.checked svg {
      display: block;
    }
    .kds-chk-card-scroll::-webkit-scrollbar {
      width: 5px;
    }
    .kds-chk-card-scroll::-webkit-scrollbar-track {
      background: rgba(0, 0, 0, 0.15);
      border-radius: 4px;
    }
    .kds-chk-card-scroll::-webkit-scrollbar-thumb {
      background: rgba(212, 175, 55, 0.35);
      border-radius: 4px;
    }
    .kds-chk-card-scroll::-webkit-scrollbar-thumb:hover {
      background: rgba(212, 175, 55, 0.6);
    }

    .pin-modal-overlay {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: radial-gradient(circle at 50% 32%, rgba(38, 26, 48, 0.94) 0%, rgba(9, 6, 12, 0.98) 100%);
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
      z-index: 99999;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
      animation: pinFadeIn 0.25s ease-out;
    }
    @keyframes pinFadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    .pin-card {
      position: relative;
      background: linear-gradient(170deg, rgba(30, 22, 36, 0.96) 0%, rgba(14, 10, 18, 0.98) 100%);
      border: 1.5px solid rgba(212, 175, 55, 0.45);
      border-radius: 28px;
      padding: 32px 28px 26px 28px;
      max-width: 375px;
      width: 100%;
      text-align: center;
      box-shadow: 0 24px 70px rgba(0, 0, 0, 0.9), 0 0 45px rgba(212, 175, 55, 0.18);
      overflow: hidden;
      animation: pinPopCard 0.32s cubic-bezier(0.16, 1, 0.3, 1);
    }
    .pin-card::before {
      content: '';
      position: absolute;
      top: 0;
      left: 15%;
      right: 15%;
      height: 2px;
      background: linear-gradient(90deg, transparent, var(--gold-primary), transparent);
      box-shadow: 0 0 12px var(--gold-primary);
    }
    @keyframes pinPopCard {
      0% { opacity: 0; transform: scale(0.9) translateY(16px); }
      100% { opacity: 1; transform: scale(1) translateY(0); }
    }
    .pin-logo-box {
      margin-bottom: 14px;
      display: flex;
      justify-content: center;
    }
    .pin-logo-frame {
      width: 60px;
      height: 60px;
      border-radius: 18px;
      background: linear-gradient(135deg, rgba(212, 175, 55, 0.22) 0%, rgba(67, 44, 29, 0.4) 100%);
      border: 1.5px solid rgba(212, 175, 55, 0.55);
      box-shadow: 0 4px 20px rgba(212, 175, 55, 0.35);
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .pin-title {
      font-family: 'Outfit', sans-serif;
      font-weight: 900;
      font-size: 17px;
      letter-spacing: 1.8px;
      color: var(--gold-light);
      margin-bottom: 3px;
      text-shadow: 0 2px 10px rgba(212, 175, 55, 0.3);
    }
    .pin-sub {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      background: rgba(255, 159, 28, 0.16);
      border: 1px solid rgba(255, 159, 28, 0.45);
      color: var(--amber-brewing);
      font-size: 10px;
      font-weight: 800;
      letter-spacing: 1px;
      text-transform: uppercase;
      padding: 3px 10px;
      border-radius: 20px;
      margin: 6px 0 10px 0;
    }
    .pin-desc {
      font-size: 12.5px;
      color: var(--text-muted);
      margin-bottom: 18px;
      line-height: 1.45;
    }
    .pin-dots-container {
      display: flex;
      justify-content: center;
      gap: 16px;
      margin-bottom: 16px;
      padding: 6px 0;
    }
    .pin-dot {
      width: 18px;
      height: 18px;
      border-radius: 50%;
      border: 2px solid rgba(212, 175, 55, 0.4);
      background: rgba(255, 255, 255, 0.04);
      box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.6);
      transition: all 0.22s cubic-bezier(0.34, 1.56, 0.64, 1);
    }
    .pin-dot.filled {
      background: linear-gradient(135deg, #FFF0B3 0%, var(--gold-primary) 50%, #B89025 100%);
      border-color: #FFF0B3;
      box-shadow: 0 0 16px rgba(212, 175, 55, 0.9), 0 0 28px rgba(212, 175, 55, 0.4);
      transform: scale(1.25);
    }
    .pin-dots-container.shake {
      animation: shakeDots 0.45s ease;
    }
    @keyframes shakeDots {
      0%, 100% { transform: translateX(0); }
      15%, 45%, 75% { transform: translateX(-9px); }
      30%, 60%, 90% { transform: translateX(9px); }
    }
    .pin-error-msg {
      font-size: 12px;
      color: var(--rose-alert);
      font-weight: 800;
      min-height: 20px;
      margin-bottom: 14px;
      letter-spacing: 0.3px;
      text-shadow: 0 0 10px rgba(231, 29, 54, 0.35);
    }
    .pin-keypad {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 11px;
      max-width: 290px;
      margin: 0 auto;
    }
    .pin-key {
      background: linear-gradient(165deg, rgba(255, 255, 255, 0.07) 0%, rgba(255, 255, 255, 0.02) 100%);
      border: 1.2px solid rgba(255, 255, 255, 0.12);
      border-radius: 16px;
      height: 54px;
      color: var(--text-light);
      font-size: 21px;
      font-weight: 800;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.16s cubic-bezier(0.2, 0.8, 0.4, 1);
      user-select: none;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.35);
    }
    .pin-key:hover {
      background: linear-gradient(165deg, rgba(212, 175, 55, 0.25) 0%, rgba(212, 175, 55, 0.08) 100%);
      border-color: rgba(212, 175, 55, 0.6);
      color: var(--gold-light);
      box-shadow: 0 6px 18px rgba(212, 175, 55, 0.25);
      transform: translateY(-1.5px);
    }
    .pin-key:active {
      transform: scale(0.92) translateY(1px);
      background: rgba(212, 175, 55, 0.35);
      box-shadow: 0 2px 6px rgba(0, 0, 0, 0.5);
    }
    .pin-key-clear {
      font-size: 15px;
      font-weight: 800;
      color: var(--amber-brewing);
      background: rgba(255, 159, 28, 0.1);
      border-color: rgba(255, 159, 28, 0.3);
    }
    .pin-key-clear:hover {
      background: rgba(255, 159, 28, 0.25);
      border-color: rgba(255, 159, 28, 0.5);
      color: #FFB74D;
    }
    .pin-key-backspace {
      font-size: 17px;
      color: #FF6B6B;
      background: rgba(231, 29, 54, 0.1);
      border-color: rgba(231, 29, 54, 0.3);
    }
    .pin-key-backspace:hover {
      background: rgba(231, 29, 54, 0.25);
      border-color: rgba(231, 29, 54, 0.5);
      color: #FF8787;
    }

    .empty-state { grid-column: 1 / -1; text-align: center; padding: 60px 20px; color: var(--text-muted); }
    .empty-icon { font-size: 48px; margin-bottom: 12px; }
  </style>
</head>
<body>
  <header>
    <div class="brand">
      <img src="/logo.png" style="height: 38px; width: 38px; border-radius: 8px; object-fit: cover; border: 1px solid rgba(212, 175, 55, 0.4); box-shadow: 0 2px 8px rgba(212,175,55,0.25);" alt="Logo" onerror="this.style.display='none'">
      <div>
        <div class="brand-title">CELESTIAL</div>
        <div class="brand-sub">KITCHEN DISPLAY SYSTEM (KDS)</div>
      </div>
    </div>
    <div style="display: flex; align-items: center; gap: 10px; flex-wrap: wrap;">
      <!-- Zoom & Text Size Toolbar for Baristas & Kitchen -->
      <div class="kds-zoom-toolbar" title="Barista Text Size / Zoom Scaling">
        <span style="font-size: 11px; color: var(--gold-light); font-weight: 700; margin-right: 2px;">👁️ Zoom:</span>
        <button type="button" class="zoom-btn" onclick="adjustKdsZoom(-0.15)" title="Decrease Text Size">A−</button>
        <span id="kdsZoomLabel" class="zoom-label">100%</span>
        <button type="button" class="zoom-btn" onclick="adjustKdsZoom(0.15)" title="Increase Text Size (Vision Aid)">A+</button>
        <div class="zoom-presets">
          <button type="button" class="zoom-pill active" data-zoom="1.0" onclick="setKdsZoom(1.0)">100%</button>
          <button type="button" class="zoom-pill" data-zoom="1.2" onclick="setKdsZoom(1.2)">120%</button>
          <button type="button" class="zoom-pill" data-zoom="1.4" onclick="setKdsZoom(1.4)">140%</button>
          <button type="button" class="zoom-pill" data-zoom="1.65" onclick="setKdsZoom(1.65)">165% (Huge)</button>
        </div>
      </div>

      <div id="statusBadge" class="status-badge">
        <div class="dot"></div>
        <span id="statusText">Live Sync</span>
      </div>
    </div>
  </header>

  <!-- Barista Security PIN Unlock Screen -->
  <div id="pinModal" class="pin-modal-overlay" style="display: none;">
    <div class="pin-card">
      <div class="pin-logo-box">
        <div class="pin-logo-frame">
          <img src="/logo.png" style="height: 42px; width: 42px; border-radius: 12px; object-fit: cover;" alt="Logo" onerror="this.style.display='none'">
        </div>
      </div>
      <div class="pin-title">BARISTA & KITCHEN CONSOLE</div>
      <div class="pin-sub">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
        <span>Security PIN Required</span>
      </div>
      <div class="pin-desc">Enter 4-digit security PIN to unlock the live kitchen display.</div>

      <div class="pin-dots-container" id="pinDots">
        <div class="pin-dot"></div>
        <div class="pin-dot"></div>
        <div class="pin-dot"></div>
        <div class="pin-dot"></div>
      </div>

      <div id="pinError" class="pin-error-msg"></div>

      <div class="pin-keypad">
        <button type="button" class="pin-key" onclick="handlePinKey('1')">1</button>
        <button type="button" class="pin-key" onclick="handlePinKey('2')">2</button>
        <button type="button" class="pin-key" onclick="handlePinKey('3')">3</button>
        <button type="button" class="pin-key" onclick="handlePinKey('4')">4</button>
        <button type="button" class="pin-key" onclick="handlePinKey('5')">5</button>
        <button type="button" class="pin-key" onclick="handlePinKey('6')">6</button>
        <button type="button" class="pin-key" onclick="handlePinKey('7')">7</button>
        <button type="button" class="pin-key" onclick="handlePinKey('8')">8</button>
        <button type="button" class="pin-key" onclick="handlePinKey('9')">9</button>
        <button type="button" class="pin-key pin-key-clear" onclick="handlePinClear()">C</button>
        <button type="button" class="pin-key" onclick="handlePinKey('0')">0</button>
        <button type="button" class="pin-key pin-key-backspace" onclick="handlePinBackspace()">⌫</button>
      </div>

      <div style="margin-top: 18px; font-size: 11px; color: var(--text-subtle); display: flex; align-items: center; justify-content: center; gap: 5px;">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
        <span>Security protected • Check POS Hotspot Dialog for PIN</span>
      </div>
    </div>
  </div>

  <!-- Barista Action Confirmation Modal (Matched 1:1 to KDS Order Checklist) -->
  <div class="kds-modal-overlay" id="kdsConfirmModal" onclick="if(event.target===this) closeKdsConfirmModal()">
    <div class="kds-confirm-card" id="kdsConfirmCard">
      
      <!-- Top Title Header -->
      <div style="display: flex; align-items: center; gap: 12px;">
        <div id="kdsConfirmIconBox" style="width: 44px; height: 44px; min-width: 44px; border-radius: 12px; background: rgba(46,196,182,0.15); border: 1.2px solid rgba(46,196,182,0.4); display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
          <!-- SVG Icon inserted dynamically -->
        </div>
        <div style="flex: 1; min-width: 0;">
          <div id="kdsConfirmTitle" style="font-size: 16.5px; font-weight: 800; color: #FFFFFF; letter-spacing: -0.2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
            Mark Ready for Pickup • #11
          </div>
          <div id="kdsConfirmSubtitle" style="font-size: 12px; color: var(--text-muted); font-weight: 600; margin-top: 2px;">
            Dine-In • Table 1
          </div>
        </div>
      </div>

      <!-- Warning / Double-Check Notice Banner -->
      <div id="kdsConfirmNotice" style="margin-top: 15px; padding: 11px 13px; background: rgba(212, 175, 55, 0.12); border: 1px solid rgba(212, 175, 55, 0.35); border-radius: 10px; display: flex; align-items: flex-start; gap: 10px;">
        <div style="color: var(--gold-light); display: flex; align-items: center; margin-top: 1px; flex-shrink: 0;">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
            <path d="M3 7l3 3 5-5"></path>
            <path d="M14 6h7"></path>
            <path d="M3 17l3 3 5-5"></path>
            <path d="M14 16h7"></path>
          </svg>
        </div>
        <div id="kdsConfirmNoticeText" style="font-size: 12px; font-weight: 700; color: var(--gold-light); line-height: 1.38; flex: 1;">
          Kindly double check if the item is correct and complete before proceeding.
        </div>
      </div>

      <!-- Order Items Checklist Summary Label -->
      <div id="kdsConfirmChecklistLabel" style="margin-top: 15px; margin-bottom: 8px; font-size: 12px; font-weight: 700; color: var(--text-muted); letter-spacing: 0.3px;">
        Order Items Checklist (2 pcs):
      </div>

      <!-- Checklist Items Card -->
      <div class="kds-chk-card-scroll" id="kdsConfirmChecklistCard" style="background: var(--bg-card); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 12px; padding: 12px 14px; max-height: 230px; overflow-y: auto;">
        <!-- Checklist items rendered dynamically -->
      </div>

      <!-- Actions (Cancel / Review, Confirm) -->
      <div style="margin-top: 18px; display: flex; align-items: center; justify-content: flex-end; gap: 10px;">
        <button type="button" onclick="closeKdsConfirmModal()" style="background: transparent; border: none; color: var(--text-muted); font-size: 13px; font-weight: 700; padding: 10px 14px; border-radius: 8px; cursor: pointer; transition: color 0.15s ease;" onmouseover="this.style.color='#FFFFFF'" onmouseout="this.style.color='var(--text-muted)'">
          Cancel / Review
        </button>
        <button type="button" id="btnKdsConfirmAction" style="background: var(--emerald-ready); border: none; color: #0D0B10; border-radius: 10px; padding: 11px 18px; font-weight: 800; font-size: 13px; cursor: pointer; display: inline-flex; align-items: center; gap: 8px; box-shadow: 0 4px 14px rgba(46,196,182,0.35); transition: transform 0.1s ease, filter 0.15s ease;">
          <span id="kdsConfirmActionIcon" style="display: inline-flex; align-items: center;"></span>
          <span id="kdsConfirmActionText">Confirm Ready</span>
        </button>
      </div>

    </div>
  </div>

  <div class="filter-bar">
    <button class="tab-btn active" onclick="setFilter('all', this)">Active Queue <span class="tab-count" id="countAll">0</span></button>
    <button class="tab-btn" onclick="setFilter('confirmed', this)">Confirmed <span class="tab-count" id="countQueue">0</span></button>
    <button class="tab-btn" onclick="setFilter('preparing', this)">Brewing / Prep <span class="tab-count" id="countBrewing">0</span></button>
    <button class="tab-btn" onclick="setFilter('ready', this)">Ready for Pickup <span class="tab-count" id="countReady">0</span></button>
    <button class="tab-btn" onclick="setFilter('kitchen', this)" style="border: 1px solid rgba(255,87,34,0.5); color: #FF7043;">Kitchen Food <span class="tab-count" id="countKitchen" style="background: rgba(255,87,34,0.25); color: #FF7043;">0</span></button>
    <button class="tab-btn" onclick="setFilter('barista', this)" style="border: 1px solid rgba(255,159,28,0.4); color: var(--gold-light);">Barista Drinks <span class="tab-count" id="countBarista">0</span></button>
    <button class="tab-btn" onclick="setFilter('takeout', this)" style="border: 1px solid #FF9F1C; color: #FFB74D; font-weight: 800;">🥡 Takeout <span class="tab-count" id="countTakeout" style="background: rgba(255,159,28,0.3); color: #FFB74D;">0</span></button>
  </div>

  <main id="ticketsContainer">
    <div class="empty-state">
      <div class="empty-icon" style="font-size:36px;opacity:0.3;">—</div>
      <h3>No Active Kitchen Tickets</h3>
      <p style="font-size: 13px; margin-top: 4px;">Orders approved & confirmed at the POS will appear here live.</p>
    </div>
  </main>

  <script>
    let authPin = sessionStorage.getItem('celestial_barista_pin') || localStorage.getItem('celestial_barista_pin') || '';
    let isAuthorized = false;
    let currentOrders = [];
    let enteredDigits = '';
    let ws;
    let audioContext;
    let activeFilter = 'all';
    let preparedItemKeys = new Set();
    try {
      const savedPrep = JSON.parse(sessionStorage.getItem('celestial_kds_prepared_items') || '[]');
      if (Array.isArray(savedPrep)) preparedItemKeys = new Set(savedPrep);
    } catch(e) {}

    // Instant local cache restore (0.00s instant ticket render on open/refresh)
    try {
      const cached = localStorage.getItem('celestial_kds_orders_cache');
      if (cached) {
        currentOrders = JSON.parse(cached);
        if (Array.isArray(currentOrders) && currentOrders.length > 0) {
          renderOrders(currentOrders);
        }
      }
    } catch(e) {}

    function updatePinDots() {
      const dots = document.querySelectorAll('.pin-dot');
      dots.forEach((d, i) => {
        if (i < enteredDigits.length) {
          d.classList.add('filled');
        } else {
          d.classList.remove('filled');
        }
      });
    }

    function playAudioClick(freq, duration) {
      try {
        if (!audioContext) audioContext = new (window.AudioContext || window.webkitAudioContext)();
        if (audioContext.state === 'suspended') audioContext.resume();
        const f = freq || 700;
        const d = duration || 0.035;
        const osc = audioContext.createOscillator();
        const gain = audioContext.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(f, audioContext.currentTime);
        gain.gain.setValueAtTime(0.12, audioContext.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + d);
        osc.connect(gain);
        gain.connect(audioContext.destination);
        osc.start();
        osc.stop(audioContext.currentTime + d);
        if (navigator.vibrate) navigator.vibrate(12);
      } catch(e) {}
    }

    function playPinSuccess() {
      try {
        if (!audioContext) audioContext = new (window.AudioContext || window.webkitAudioContext)();
        if (audioContext.state === 'suspended') audioContext.resume();
        const chord = [523.25, 659.25, 783.99, 1046.50];
        chord.forEach((freq, idx) => {
          setTimeout(() => {
            try {
              const osc = audioContext.createOscillator();
              const gain = audioContext.createGain();
              osc.type = 'triangle';
              osc.frequency.setValueAtTime(freq, audioContext.currentTime);
              gain.gain.setValueAtTime(0.12, audioContext.currentTime);
              gain.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + 0.16);
              osc.connect(gain);
              gain.connect(audioContext.destination);
              osc.start();
              osc.stop(audioContext.currentTime + 0.16);
            } catch(e) {}
          }, idx * 55);
        });
        if (navigator.vibrate) navigator.vibrate([30, 40, 50]);
      } catch(e) {}
    }

    function playPinFailure() {
      try {
        if (!audioContext) audioContext = new (window.AudioContext || window.webkitAudioContext)();
        if (audioContext.state === 'suspended') audioContext.resume();
        const osc = audioContext.createOscillator();
        const gain = audioContext.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(160, audioContext.currentTime);
        gain.gain.setValueAtTime(0.18, audioContext.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + 0.22);
        osc.connect(gain);
        gain.connect(audioContext.destination);
        osc.start();
        osc.stop(audioContext.currentTime + 0.22);
        if (navigator.vibrate) navigator.vibrate([60, 50, 60]);
      } catch(e) {}
    }

    function handlePinKey(digit) {
      if (enteredDigits.length >= 4) return;
      playAudioClick(650 + (parseInt(digit, 10) * 35), 0.035);
      enteredDigits += digit;
      updatePinDots();
      document.getElementById('pinError').innerText = '';
      if (enteredDigits.length === 4) {
        verifyEnteredPin(enteredDigits);
      }
    }

    function handlePinClear() {
      playAudioClick(400, 0.04);
      enteredDigits = '';
      updatePinDots();
      document.getElementById('pinError').innerText = '';
    }

    function handlePinBackspace() {
      if (enteredDigits.length > 0) {
        playAudioClick(460, 0.035);
        enteredDigits = enteredDigits.slice(0, -1);
        updatePinDots();
        document.getElementById('pinError').innerText = '';
      }
    }

    window.addEventListener('keydown', (e) => {
      const modal = document.getElementById('pinModal');
      if (!modal || modal.style.display === 'none') return;
      if (e.key >= '0' && e.key <= '9') {
        handlePinKey(e.key);
      } else if (e.key === 'Backspace') {
        handlePinBackspace();
      } else if (e.key === 'Escape' || e.key === 'c' || e.key === 'C') {
        handlePinClear();
      }
    });

    function verifyEnteredPin(pinToTest) {
      const errEl = document.getElementById('pinError');
      errEl.innerText = 'Verifying PIN...';
      fetch('/api/barista/verify-pin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pin: pinToTest })
      })
      .then(res => res.json())
      .then(data => {
        if (data && data.valid) {
          onPinSuccess(pinToTest);
        } else {
          showPinFailure();
        }
      })
      .catch(() => showPinFailure());
    }

    function showPinFailure() {
      playPinFailure();
      const dotsEl = document.getElementById('pinDots');
      dotsEl.classList.add('shake');
      const errEl = document.getElementById('pinError');
      errEl.innerText = 'Incorrect PIN. Access Denied.';
      setTimeout(() => {
        dotsEl.classList.remove('shake');
        handlePinClear();
      }, 550);
    }

    function onPinSuccess(validPin) {
      playPinSuccess();
      authPin = validPin;
      isAuthorized = true;
      try {
        sessionStorage.setItem('celestial_barista_pin', validPin);
        localStorage.setItem('celestial_barista_pin', validPin);
      } catch(e) {}
      const card = document.querySelector('.pin-card');
      if (card) {
        card.style.transform = 'scale(1.02)';
        card.style.borderColor = 'var(--emerald-ready)';
        card.style.boxShadow = '0 0 50px rgba(46,196,182,0.4)';
      }
      setTimeout(() => {
        document.getElementById('pinModal').style.display = 'none';
        if (card) {
          card.style.transform = '';
          card.style.borderColor = '';
          card.style.boxShadow = '';
        }
      }, 280);
      connectWs();
      fetch('/api/orders?pin=' + encodeURIComponent(validPin))
        .then(res => res.json())
        .then(data => {
          if (data && data.orders) {
            currentOrders = data.orders;
            renderOrders(currentOrders);
          }
        })
        .catch(() => {});
    }

    function showPinModal() {
      enteredDigits = '';
      updatePinDots();
      document.getElementById('pinError').innerText = '';
      document.getElementById('pinModal').style.display = 'flex';
    }

    function lockKds() {
      authPin = '';
      isAuthorized = false;
      try {
        sessionStorage.removeItem('celestial_barista_pin');
        localStorage.removeItem('celestial_barista_pin');
      } catch(e) {}
      if (ws) {
        try { ws.close(); } catch(e) {}
        ws = null;
      }
      currentOrders = [];
      renderOrders([]);
      showPinModal();
    }

    function playChime() {
      try {
        if (!audioContext) audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const doPlay = () => {
          if (!audioContext) return;
          try {
            const osc = audioContext.createOscillator();
            const gain = audioContext.createGain();
            osc.type = 'triangle';
            osc.connect(gain);
            gain.connect(audioContext.destination);
            osc.frequency.setValueAtTime(659.25, audioContext.currentTime);
            osc.frequency.setValueAtTime(1046.5, audioContext.currentTime + 0.12);
            gain.gain.setValueAtTime(0.65, audioContext.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.55);
            osc.start();
            osc.stop(audioContext.currentTime + 0.55);
          } catch(_) {}
        };

        if (audioContext && audioContext.state === 'suspended') {
          audioContext.resume().then(doPlay).catch(() => {});
        } else {
          doPlay();
        }

        if (navigator.vibrate) {
          navigator.vibrate([400, 150, 400]);
        }
      } catch (e) {}
    }

    function setFilter(filter, btn) {
      activeFilter = filter;
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      renderOrders(currentOrders);
    }

    function connectWs() {
      if (!authPin) return;
      const loc = window.location;
      const wsUrl = (loc.protocol === 'https:' ? 'wss://' : 'ws://') + loc.host + '/ws?pin=' + encodeURIComponent(authPin);
      
      try {
        ws = new WebSocket(wsUrl);

        ws.onopen = () => {
          document.getElementById('statusBadge').className = 'status-badge';
          document.getElementById('statusText').innerText = 'Live Sync';
        };

        ws.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data);
            if (data.type === 'SYNC_ORDERS') {
              currentOrders = data.orders || [];
              renderOrders(currentOrders);
            } else if (data.type === 'ITEM_PREPARED') {
              const order = (currentOrders || []).find(o => o.id === data.orderId);
              if (order && order.items && order.items[data.itemIndex]) {
                order.items[data.itemIndex].isPrepared = data.isPrepared;
                renderOrders(currentOrders);
              }
            }
          } catch (e) { console.error(e); }
        };

        ws.onclose = () => {
          document.getElementById('statusBadge').className = 'status-badge disconnected';
          document.getElementById('statusText').innerText = 'Reconnecting...';
          setTimeout(connectWs, 2500);
        };

        ws.onerror = () => { ws.close(); };
      } catch (e) {
        setTimeout(connectWs, 2500);
      }
    }

    function fetchOrdersHttp() {
      if (!authPin) return;
      fetch('/api/orders?pin=' + encodeURIComponent(authPin))
        .then(res => res.json())
        .then(data => {
          if (data && data.orders) {
            currentOrders = data.orders;
            renderOrders(currentOrders);
          }
        })
        .catch(err => console.warn('Poll err:', err));
    }

    function isItemKitchen(item) {
      if (item.isKitchen === true) return true;
      const cat = (item.category || '').toLowerCase();
      if (cat.includes('street') || cat.includes('pasta') || cat.includes('sandwich') || cat.includes('bites') || cat.includes('food')) {
        return true;
      }
      const n = (item.name || item.menuItem?.name || '').toLowerCase();
      return n.includes('buffalo') || n.includes('wing') || n.includes('fries') ||
        n.includes('stick') || n.includes('lumpia') || n.includes('shanghai') ||
        n.includes('pasta') || n.includes('carbonara') || n.includes('aglio') ||
        n.includes('sandwich') || n.includes('toast') || n.includes('burger');
    }

    function orderHasKitchen(order) {
      if (order.hasKitchenDishes === true) return true;
      return (order.items || []).some(isItemKitchen);
    }

    function orderHasBarista(order) {
      if (order.hasBaristaDrinks === true) return true;
      return (order.items || []).some(i => !isItemKitchen(i));
    }

    let prevCount = 0;
    function renderOrders(orders) {
      currentOrders = orders;
      try {
        localStorage.setItem('celestial_kds_orders_cache', JSON.stringify(orders));
      } catch(e) {}
      const active = orders.filter(o => o.status === 'confirmed' || o.status === 'inqueue' || o.status === 'preparing' || o.status === 'ready');
      
      document.getElementById('countAll').innerText = active.length;
      const countQueueEl = document.getElementById('countQueue');
      if (countQueueEl) countQueueEl.innerText = active.filter(o => o.status === 'confirmed' || o.status === 'inqueue').length;
      document.getElementById('countBrewing').innerText = active.filter(o => o.status === 'preparing').length;
      document.getElementById('countReady').innerText = active.filter(o => o.status === 'ready').length;

      const kitchenOrders = active.filter(orderHasKitchen);
      const baristaOrders = active.filter(orderHasBarista);
      const countKitchenEl = document.getElementById('countKitchen');
      if (countKitchenEl) countKitchenEl.innerText = kitchenOrders.length;
      const countBaristaEl = document.getElementById('countBarista');
      if (countBaristaEl) countBaristaEl.innerText = baristaOrders.length;

      const takeoutOrders = active.filter(o => o.orderType === 'takeaway' || o.orderType === 'takeout' || o.orderType === 'delivery' || (o.items || []).some(i => i.notes && (i.notes.toLowerCase().includes('take') || i.notes.toLowerCase().includes('to-go') || i.notes.toLowerCase().includes('togo') || i.notes.toLowerCase().includes('balot'))));
      const countTakeoutEl = document.getElementById('countTakeout');
      if (countTakeoutEl) countTakeoutEl.innerText = takeoutOrders.length;

      if (active.length > prevCount) {
        playChime();
      }
      prevCount = active.length;

      const filtered = activeFilter === 'all'
        ? active
        : (activeFilter === 'confirmed'
            ? active.filter(o => o.status === 'confirmed' || o.status === 'inqueue')
            : (activeFilter === 'kitchen'
                ? kitchenOrders
                : (activeFilter === 'barista'
                    ? baristaOrders
                    : (activeFilter === 'takeout'
                        ? takeoutOrders
                        : active.filter(o => o.status === activeFilter)))));

      const container = document.getElementById('ticketsContainer');

      if (filtered.length === 0) {
        container.innerHTML = `
          <div class="empty-state">
            <div class="empty-icon" style="font-size:36px;opacity:0.3;">—</div>
            <h3>No Active Kitchen Tickets</h3>
            <p style="font-size: 13px; margin-top: 4px;">Orders rung up on the POS will appear here live.</p>
          </div>
        `;
        return;
      }

      container.innerHTML = filtered.map(order => {
        const elapsedMins = Math.max(0, Math.floor((new Date() - new Date(order.createdAt)) / 60000));
        let timerClass = 'timer-green';
        if (elapsedMins >= 14) {
          timerClass = 'timer-red';
        } else if (elapsedMins >= 6) {
          timerClass = 'timer-amber';
        }

        let kitchenCount = 0;
        let baristaCount = 0;
        (order.items || []).forEach(i => {
          if (isItemKitchen(i)) {
            kitchenCount += (i.quantity || 1);
          } else {
            baristaCount += (i.quantity || 1);
          }
        });

        let stationBadgesHtml = '';
        if (kitchenCount > 0) {
          stationBadgesHtml += `<span class="station-badge-kitchen">\${kitchenCount} Kitchen</span>`;
        }
        if (baristaCount > 0) {
          stationBadgesHtml += `<span class="station-badge-bar">\${baristaCount} Bar</span>`;
        }

        let allItemsDone = (order.items || []).length > 0;
        const isTakeout = order.orderType === 'takeaway' || order.orderType === 'takeout' || order.orderType === 'delivery';
        const takeoutTicketClass = isTakeout ? 'takeout-ticket' : '';
        const orderTypeBadgeClass = isTakeout ? 'order-type-badge takeout-badge' : 'order-type-badge';
        const tableInfo = order.tableNumber ? ` • \${order.tableNumber}` : '';
        const orderTypeLabel = isTakeout ? '🥡 TAKEOUT / TO-GO' : (order.orderType === 'dineIn' ? `Dine-In\${tableInfo}` : 'Takeaway');
        const takeoutBannerHtml = isTakeout ? `<div class="takeout-banner"><span>🛍️</span> <span>TAKEOUT / TO-GO • PACK IN BAG (USE PAPER CUPS & LIDS)</span></div>` : '';

        const itemsHtml = (order.items || []).map((item, itemIdx) => {
          const itemName = item.name || item.menuItem?.name || 'Item';
          const isKitchen = isItemKitchen(item);
          const isDone = item.isPrepared === true;
          if (!isDone) allItemsDone = false;
          let sizeHtml = '';
          const nonSizeCustoms = [];

          (item.customizations || []).forEach(c => {
            const name = (c.optionName || '').toLowerCase();
            if (name.includes('16oz') || name.includes('16 oz')) {
              sizeHtml = '<span class="size-badge size-16oz">16 oz</span>';
            } else if (name.includes('22oz') || name.includes('22 oz')) {
              sizeHtml = '<span class="size-badge size-22oz">22 oz</span>';
            } else {
              nonSizeCustoms.push(c.summary || c.optionName);
            }
          });

          const customsListHtml = nonSizeCustoms.length > 0
            ? `<div class="custom-list">\${nonSizeCustoms.map(c => `<div class="custom-item">› \${c}</div>`).join('')}</div>`
            : '';

          const isItemTakeout = isTakeout || (item.notes && (item.notes.toLowerCase().includes('take') || item.notes.toLowerCase().includes('to-go') || item.notes.toLowerCase().includes('togo') || item.notes.toLowerCase().includes('balot')));
          const takeoutItemBadge = isItemTakeout ? '<span class="takeout-item-badge">🥡 TO-GO</span>' : '';

          const noteHtml = item.notes ? `<div class="note-box">📝 Note: \${item.notes}</div>` : '';
          const doneClass = isDone ? 'item-done' : '';
          const prepBadgeHtml = isDone ? '<span class="item-prepared-badge">✓ PREPARED</span>' : '';
          const kitchenTag = isKitchen ? '<div class="kitchen-tag">KITCHEN COOK DISH</div>' : '';

          const isPreparing = order.status === 'preparing';
          const rowTitle = isPreparing ? 'Click to mark as prepared' : '⚠️ Tap "Start Brewing / Prep" first before checking off items';
          const rowLockedClass = isPreparing ? '' : 'item-row-locked';
          const toggleContent = isDone ? '✓' : '';

          return `
            <div class="item-row \${isKitchen ? 'kitchen-item-row' : ''} \${doneClass} \${rowLockedClass}" onclick="toggleItemPrepared('\${order.id}', \${itemIdx}, event)" title="\${rowTitle}">
              \${kitchenTag}
              <div class="item-title-row">
                <span class="item-prep-toggle">\${toggleContent}</span>
                <span class="item-qty \${isKitchen ? 'kitchen-qty' : ''}">\${item.quantity}x</span>
                <span class="item-name \${isKitchen ? 'kitchen-name' : ''}">\${itemName}</span>
                \${sizeHtml}
                \${takeoutItemBadge}
                \${prepBadgeHtml}
              </div>
              \${customsListHtml}
              \${noteHtml}
            </div>
          `;
        }).join('');

        let actionBtn = '';
        let statusBadgeHtml = '';
        if (order.status === 'confirmed') {
          statusBadgeHtml = `<div style="background: rgba(46,196,182,0.14); border: 1.2px solid rgba(46,196,182,0.45); border-radius: 6px; padding: 4px 8px; font-size: 11px; font-weight: 800; color: #2EC4B6; margin-bottom: 8px; text-align: center; letter-spacing: 0.5px;">✓ CONFIRMED BY CASHIER</div>`;
          actionBtn = `<button class="action-btn btn-brew" onclick="confirmStatusChange('\${order.id}', '\${order.orderNumber}', 'preparing')">Start Brewing / Prep</button>`;
        } else if (order.status === 'pending') {
          statusBadgeHtml = `<div style="background: rgba(255,159,28,0.15); border: 1px solid rgba(255,159,28,0.4); border-radius: 6px; padding: 4px 8px; font-size: 11px; font-weight: bold; color: var(--amber-brewing); margin-bottom: 8px; text-align: center;">Awaiting Cashier Payment</div>`;
          actionBtn = `<button class="action-btn btn-brew" onclick="confirmStatusChange('\${order.id}', '\${order.orderNumber}', 'preparing')">Start Brewing / Confirm</button>`;
        } else if (order.status === 'preparing') {
          const readyGlow = allItemsDone ? 'style="box-shadow: 0 0 16px rgba(46,196,182,0.7);"' : '';
          actionBtn = `<button class="action-btn btn-ready" \${readyGlow} onclick="confirmStatusChange('\${order.id}', '\${order.orderNumber}', 'ready')">Mark Ready for Pickup</button>`;
        } else if (order.status === 'ready') {
          actionBtn = `<button class="action-btn btn-done" onclick="confirmStatusChange('\${order.id}', '\${order.orderNumber}', 'completed')">Complete & Hand Over</button>`;
        }

        const totalItems = (order.items || []).reduce((sum, i) => sum + (i.quantity || 1), 0);

        const allPreparedHtml = (allItemsDone && (order.items || []).length > 0 && order.status === 'preparing')
          ? '<div class="all-prepared-banner">✨ All Items Prepared & Ready!</div>'
          : '';

        const ticketHasKitchen = kitchenCount > 0 ? 'has-kitchen' : '';
        return `
          <div class="ticket \${order.status} \${ticketHasKitchen} \${takeoutTicketClass}">
            <div class="ticket-header">
              <div class="ticket-title-group">
                <div class="ticket-number">\${order.orderNumber}</div>
                <div class="\${orderTypeBadgeClass}">\${orderTypeLabel}</div>
              </div>
              <div class="ticket-header-right">
                <div class="timer-badge \${timerClass}">\${elapsedMins}m ago</div>
                <button class="void-btn" onclick="voidOrder('\${order.id}', '\${order.orderNumber}')" title="Void / Cancel Ticket">✕</button>
              </div>
            </div>
            <div class="ticket-sub">
              <div style="display: flex; align-items: center; gap: 6px; flex-wrap: wrap;">
                <span class="guest-name">Guest: \${order.customerName || 'Guest Patron'}</span>
                \${stationBadgesHtml}
              </div>
              <span class="item-count-text">\${totalItems} items</span>
            </div>
            \${takeoutBannerHtml}
            <div class="ticket-body">
              \${statusBadgeHtml}
              \${itemsHtml}
            </div>
            \${order.orderNotes ? `<div class="order-memo-box">Memo: \${order.orderNotes}</div>` : ''}
            \${allPreparedHtml}
            <div class="ticket-footer">
              \${actionBtn}
            </div>
          </div>
        `;
      }).join('');
    }

    function showKdsNotification(msg, isWarning) {
      let toast = document.getElementById('kdsToast');
      if (!toast) {
        toast = document.createElement('div');
        toast.id = 'kdsToast';
        toast.style.cssText = 'position:fixed;bottom:24px;left:50%;transform:translateX(-50%);background:#18131E;border:1.5px solid #FF9F1C;color:#FFF;padding:12px 22px;border-radius:12px;font-size:13px;font-weight:700;z-index:99999;box-shadow:0 8px 32px rgba(0,0,0,0.7);transition:opacity 0.25s,transform 0.25s;pointer-events:none;display:flex;align-items:center;gap:8px;';
        document.body.appendChild(toast);
      }
      toast.innerText = msg;
      toast.style.borderColor = isWarning ? '#FF9F1C' : '#2EC4B6';
      toast.style.opacity = '1';
      toast.style.transform = 'translateX(-50%) translateY(0)';
      clearTimeout(toast._timer);
      toast._timer = setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateX(-50%) translateY(8px)';
      }, 2600);
    }

    function toggleItemPrepared(orderId, itemIdx, e) {
      if (e) {
        e.stopPropagation();
        e.preventDefault();
      }
      const order = (currentOrders || []).find(o => o.id === orderId);
      if (!order || !order.items || !order.items[itemIdx]) return;

      if (order.status !== 'preparing') {
        showKdsNotification('⚠️ Please tap "Start Brewing / Prep" first before checking off items', true);
        return;
      }

      const targetItem = order.items[itemIdx];
      const newPrepared = !(targetItem.isPrepared === true);
      targetItem.isPrepared = newPrepared;

      if (navigator.vibrate) {
        try { navigator.vibrate(35); } catch(_) {}
      }

      // 1. Optimistic instant screen render
      renderOrders(currentOrders);

      // 2. Real-time WebSocket sync to POS App & other live screens
      if (ws && ws.readyState === WebSocket.OPEN) {
        try {
          ws.send(JSON.stringify({
            action: 'toggle_item_prep',
            orderId: orderId,
            itemIndex: itemIdx,
            isPrepared: newPrepared,
            pin: authPin
          }));
        } catch(e) {}
      } else {
        // 3. HTTP Fallback sync only when WebSocket is not connected
        fetch('/api/orders/item-prep', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Barista-Pin': authPin
          },
          body: JSON.stringify({
            orderId: orderId,
            itemIndex: itemIdx,
            isPrepared: newPrepared,
            pin: authPin
          })
        })
        .then(res => res.json())
        .then(data => {
          if (data && data.orders) {
            currentOrders = data.orders;
            renderOrders(currentOrders);
          }
        })
        .catch(() => {});
      }
    }

    let pendingKdsAction = null;
    let isKdsConfirmSubmitting = false;

    function toggleChecklistRow(row) {
      const box = row.querySelector('.kds-chk-box');
      if (box) box.classList.toggle('checked');
    }

    function closeKdsConfirmModal() {
      const modal = document.getElementById('kdsConfirmModal');
      if (modal) modal.style.display = 'none';
      pendingKdsAction = null;
      isKdsConfirmSubmitting = false;
    }

    function showKdsConfirmModal(opts) {
      isKdsConfirmSubmitting = false;
      pendingKdsAction = opts.onConfirm;

      const order = (currentOrders || []).find(o => o.id === opts.orderId) || opts.order || {};
      const card = document.getElementById('kdsConfirmCard');
      if (card) {
        card.style.borderColor = opts.borderColor || 'rgba(46, 196, 182, 0.5)';
      }

      // 1. Icon Box & Header Icon
      const iconBox = document.getElementById('kdsConfirmIconBox');
      if (iconBox) {
        iconBox.style.background = opts.iconBg || 'rgba(46, 196, 182, 0.15)';
        iconBox.style.borderColor = opts.iconBorder || 'rgba(46, 196, 182, 0.4)';
        iconBox.innerHTML = opts.headerIcon || '';
      }

      // 2. Title & Subtitle
      const titleEl = document.getElementById('kdsConfirmTitle');
      if (titleEl) {
        let orderNumDisplay = String(order.orderNumber || opts.orderNumber || '').trim();
        if (orderNumDisplay && !orderNumDisplay.startsWith('#')) {
          orderNumDisplay = '#' + orderNumDisplay;
        }
        titleEl.innerText = (opts.title || 'Confirm Action') + (orderNumDisplay ? ' • ' + orderNumDisplay : '');
      }

      const subEl = document.getElementById('kdsConfirmSubtitle');
      if (subEl) {
        const orderType = order.orderType || 'dineIn';
        const isDineIn = (orderType === 'dineIn' || orderType === 'dine_in');
        const typeLabel = isDineIn ? 'Dine-In' : 'Takeaway';
        let tableText = '';
        if (order.tableNumber) {
          const t = String(order.tableNumber).trim();
          tableText = t.toLowerCase().startsWith('table') ? t : 'Table ' + t;
        }
        subEl.innerText = isDineIn ? (typeLabel + ' • ' + (tableText || 'Table 1')) : typeLabel;
      }

      // 3. Notice Banner
      const noticeTextEl = document.getElementById('kdsConfirmNoticeText');
      if (noticeTextEl) {
        noticeTextEl.innerText = opts.noticeText || 'Kindly double check if the item is correct and complete before proceeding.';
      }

      // 4. Checklist Items
      const items = order.items || [];
      const totalPcs = items.reduce((sum, i) => sum + (i.quantity || 1), 0);
      const labelEl = document.getElementById('kdsConfirmChecklistLabel');
      if (labelEl) {
        labelEl.innerText = 'Order Items Checklist (' + totalPcs + ' pcs):';
      }

      const checklistCard = document.getElementById('kdsConfirmChecklistCard');
      if (checklistCard) {
        if (items.length === 0) {
          checklistCard.innerHTML = '<div style="color: var(--text-muted); font-size: 12px; font-style: italic; padding: 8px 4px;">No items listed in ticket</div>';
        } else {
          checklistCard.innerHTML = items.map(item => {
            const itemName = item.name || item.menuItem?.name || 'Item';
            const customs = [];
            if (item.customizations && Array.isArray(item.customizations)) {
              item.customizations.forEach(c => {
                const text = c.summary || c.optionName || '';
                if (text) customs.push(text);
              });
            }
            const customsText = customs.join(', ');
            const noteText = item.notes ? item.notes.trim() : '';

            return `
              <div class="kds-chk-item" onclick="toggleChecklistRow(this)">
                <div class="kds-chk-box">
                  <svg viewBox="0 0 24 24" fill="none" stroke="#0D0B10" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="20 6 9 17 4 12"></polyline>
                  </svg>
                </div>
                <div style="flex: 1; min-width: 0;">
                  <div style="font-size: 13px; line-height: 1.35;">
                    <span style="color: var(--gold-primary); font-weight: 700;">\${item.quantity || 1}x </span>
                    <span style="color: var(--text-light); font-weight: 700;">\${itemName}</span>
                  </div>
                  \${customsText ? `<div style="font-size: 11px; color: var(--gold-light); margin-top: 2px; line-height: 1.3;">› \${customsText}</div>` : ''}
                  \${noteText ? `<div style="font-size: 11px; color: var(--rose-alert); font-weight: 700; margin-top: 2px;">Note: "\${noteText}"</div>` : ''}
                </div>
              </div>
            `;
          }).join('');
        }
      }

      // 5. Action Button
      const actionBtn = document.getElementById('btnKdsConfirmAction');
      const actionIcon = document.getElementById('kdsConfirmActionIcon');
      const actionText = document.getElementById('kdsConfirmActionText');

      if (actionBtn) {
        actionBtn.disabled = false;
        actionBtn.style.opacity = '1';
        actionBtn.style.background = opts.buttonBg || 'var(--emerald-ready)';
        actionBtn.style.color = opts.buttonColor || '#0D0B10';
        actionBtn.style.boxShadow = opts.buttonShadow || '0 4px 14px rgba(46,196,182,0.35)';
      }
      if (actionIcon) actionIcon.innerHTML = opts.buttonIcon || '';
      if (actionText) actionText.innerText = opts.confirmText || 'Confirm Ready';

      document.getElementById('kdsConfirmModal').style.display = 'flex';
    }

    function confirmStatusChange(orderId, orderNumber, newStatus) {
      if (newStatus === 'ready') {
        showKdsConfirmModal({
          orderId: orderId,
          orderNumber: orderNumber,
          title: 'Mark Ready for Pickup',
          noticeText: 'Kindly double check if the item is correct and complete before proceeding.',
          confirmText: 'Confirm Ready',
          borderColor: 'rgba(46, 196, 182, 0.5)',
          iconBg: 'rgba(46, 196, 182, 0.15)',
          iconBorder: 'rgba(46, 196, 182, 0.4)',
          headerIcon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2EC4B6" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path>
            <path d="M13.73 21a2 2 0 0 1-3.46 0"></path>
          </svg>`,
          buttonBg: 'var(--emerald-ready)',
          buttonColor: '#0D0B10',
          buttonShadow: '0 4px 14px rgba(46, 196, 182, 0.35)',
          buttonIcon: `<svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 22a2 2 0 0 0 2-2h-4a2 2 0 0 0 2 2zm6-6v-5a6 6 0 0 0-5-5.91V4a1 1 0 0 0-2 0v1.09A6 6 0 0 0 6 11v5l-2 2v1h16v-1l-2-2z"/>
          </svg>`,
          onConfirm: () => updateStatus(orderId, 'ready')
        });
      } else if (newStatus === 'preparing') {
        showKdsConfirmModal({
          orderId: orderId,
          orderNumber: orderNumber,
          title: 'Start Brewing',
          noticeText: 'Kindly double check recipe, size, and modifications before brewing.',
          confirmText: 'Brew Now',
          borderColor: 'rgba(255, 159, 28, 0.5)',
          iconBg: 'rgba(255, 159, 28, 0.15)',
          iconBorder: 'rgba(255, 159, 28, 0.4)',
          headerIcon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#FF9F1C" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 8h1a4 4 0 0 1 0 8h-1"></path>
            <path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path>
            <line x1="6" y1="1" x2="6" y2="4"></line>
            <line x1="10" y1="1" x2="10" y2="4"></line>
            <line x1="14" y1="1" x2="14" y2="4"></line>
          </svg>`,
          buttonBg: 'var(--amber-brewing)',
          buttonColor: '#0D0B10',
          buttonShadow: '0 4px 14px rgba(255, 159, 28, 0.35)',
          buttonIcon: `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 8h1a4 4 0 0 1 0 8h-1"></path>
            <path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path>
            <line x1="6" y1="1" x2="6" y2="4"></line>
            <line x1="10" y1="1" x2="10" y2="4"></line>
            <line x1="14" y1="1" x2="14" y2="4"></line>
          </svg>`,
          onConfirm: () => updateStatus(orderId, 'preparing')
        });
      } else if (newStatus === 'completed') {
        showKdsConfirmModal({
          orderId: orderId,
          orderNumber: orderNumber,
          title: 'Complete & Hand Over',
          noticeText: 'Kindly double check if all items have been served and handed over to guest.',
          confirmText: 'Complete Order',
          borderColor: 'rgba(34, 197, 94, 0.5)',
          iconBg: 'rgba(34, 197, 94, 0.15)',
          iconBorder: 'rgba(34, 197, 94, 0.4)',
          headerIcon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#22C55E" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
            <polyline points="22 4 12 14.01 9 11.01"></polyline>
          </svg>`,
          buttonBg: '#22C55E',
          buttonColor: '#FFFFFF',
          buttonShadow: '0 4px 14px rgba(34, 197, 94, 0.35)',
          buttonIcon: `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>`,
          onConfirm: () => updateStatus(orderId, 'completed')
        });
      }
    }

    function voidOrder(orderId, orderNumber) {
      showKdsConfirmModal({
        orderId: orderId,
        orderNumber: orderNumber,
        title: 'Void Order',
        noticeText: 'Are you sure you want to cancel and remove this ticket from the kitchen queue? All items will be returned to stock.',
        confirmText: 'Void Ticket',
        borderColor: 'rgba(231, 29, 54, 0.5)',
        iconBg: 'rgba(231, 29, 54, 0.15)',
        iconBorder: 'rgba(231, 29, 54, 0.4)',
        headerIcon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#E71D36" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"></circle>
          <line x1="15" y1="9" x2="9" y2="15"></line>
          <line x1="9" y1="9" x2="15" y2="15"></line>
        </svg>`,
        buttonBg: '#E71D36',
        buttonColor: '#FFFFFF',
        buttonShadow: '0 4px 14px rgba(231, 29, 54, 0.35)',
        buttonIcon: `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="3 6 5 6 21 6"></polyline>
          <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
        </svg>`,
        onConfirm: () => updateStatus(orderId, 'cancelled')
      });
    }

    function updateStatus(orderId, newStatus, btn) {
      if (btn) {
        btn.disabled = true;
        const actionLabel = newStatus === 'preparing'
          ? 'Brewing...'
          : (newStatus === 'ready' ? 'Marking Ready...' : 'Completing...');
        btn.innerHTML = '<span class="btn-spinner"></span><span>' + actionLabel + '</span>';
      }

      const idx = currentOrders.findIndex(o => o.id === orderId);
      if (idx >= 0) {
        if (newStatus === 'completed' || newStatus === 'cancelled') {
          currentOrders.splice(idx, 1);
        } else {
          currentOrders[idx].status = newStatus;
        }
        if (newStatus === 'completed' || newStatus === 'cancelled' || newStatus === 'ready') {
          for (const k of Array.from(preparedItemKeys)) {
            if (k.startsWith(orderId + '_')) preparedItemKeys.delete(k);
          }
          try {
            sessionStorage.setItem('celestial_kds_prepared_items', JSON.stringify([...preparedItemKeys]));
          } catch(e) {}
        }
        renderOrders(currentOrders);
      }

      if (ws && ws.readyState === WebSocket.OPEN) {
        try {
          ws.send(JSON.stringify({
            action: 'update_status',
            orderId: orderId,
            status: newStatus,
            pin: authPin
          }));
        } catch (e) {}
      } else {
        fetch('/api/orders/update-status', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Barista-Pin': authPin
          },
          body: JSON.stringify({ orderId: orderId, status: newStatus, pin: authPin })
        })
        .then(res => res.json())
        .then(data => {
          if (data && data.orders) {
            renderOrders(data.orders);
          }
        })
        .catch(err => {
          console.warn('HTTP status sync fallback error:', err);
        });
      }
    }

    const kdsConfirmBtn = document.getElementById('btnKdsConfirmAction');
    if (kdsConfirmBtn) {
      kdsConfirmBtn.onclick = () => {
        if (isKdsConfirmSubmitting) return;
        isKdsConfirmSubmitting = true;
        const fn = pendingKdsAction;
        const actionBtn = document.getElementById('btnKdsConfirmAction');
        const actionIcon = document.getElementById('kdsConfirmActionIcon');
        const actionText = document.getElementById('kdsConfirmActionText');

        if (actionBtn) {
          actionBtn.disabled = true;
          actionBtn.style.opacity = '0.85';
        }
        if (actionIcon) {
          actionIcon.innerHTML = '<span class="btn-spinner" style="width:13px;height:13px;border-width:2px;margin-right:2px;"></span>';
        }
        if (actionText) {
          const currentText = actionText.innerText;
          if (currentText.includes('Ready')) actionText.innerText = 'Marking Ready...';
          else if (currentText.includes('Brew')) actionText.innerText = 'Starting Brew...';
          else if (currentText.includes('Complete')) actionText.innerText = 'Completing...';
          else if (currentText.includes('Void')) actionText.innerText = 'Voiding...';
        }

        setTimeout(() => {
          closeKdsConfirmModal();
          if (typeof fn === 'function') fn();
        }, 100);
      };
    }

    // KDS Live Text Zoom & Font Scaling System (Persistent across shifts)
    let currentKdsZoom = 1.0;

    function initKdsZoom() {
      try {
        const saved = localStorage.getItem('celestial_kds_text_zoom');
        if (saved) {
          const z = parseFloat(saved);
          if (!isNaN(z) && z >= 0.8 && z <= 2.2) {
            setKdsZoom(z, false);
            return;
          }
        }
      } catch(e) {}
      setKdsZoom(1.0, false);
    }

    function setKdsZoom(val, save = true) {
      currentKdsZoom = Math.min(2.2, Math.max(0.85, Math.round(val * 100) / 100));
      document.documentElement.style.setProperty('--kds-zoom', currentKdsZoom);
      const lbl = document.getElementById('kdsZoomLabel');
      if (lbl) lbl.textContent = Math.round(currentKdsZoom * 100) + '%';
      
      document.querySelectorAll('.zoom-pill').forEach(btn => {
        const bz = parseFloat(btn.getAttribute('data-zoom'));
        if (Math.abs(bz - currentKdsZoom) < 0.08) {
          btn.classList.add('active');
        } else {
          btn.classList.remove('active');
        }
      });

      if (save) {
        try { localStorage.setItem('celestial_kds_text_zoom', currentKdsZoom); } catch(e){}
      }
    }

    function adjustKdsZoom(delta) {
      setKdsZoom(currentKdsZoom + delta);
    }

    // Live automatic sync fallback: only poll if WebSocket is not open
    setInterval(() => {
      if (isAuthorized && authPin && (!ws || ws.readyState !== WebSocket.OPEN)) {
        fetchOrdersHttp();
      }
    }, 3500);

    // Initialize display zoom on load
    initKdsZoom();

    // Fast-boot: If previously authenticated, launch immediately with 0 delay
    if (authPin) {
      onPinSuccess(authPin);
    } else {
      showPinModal();
    }
  </script>
</body>
</html>
''';

  // Luxury Modern Customer Mobile Ordering & Live Tracking Web App
  static const String _customerOrderHtmlTemplate = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Celestial Cafe — Table Self-Ordering</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700;800;900&family=Outfit:wght@300;400;500;600;700;800&display=swap" rel="stylesheet" media="print" onload="this.media='all'">
  <style>
    /* System-font fallbacks for no-internet (local network) environments */
    @font-face {
      font-family: 'Outfit';
      src: local('-apple-system'), local('SF Pro Display'), local('Helvetica Neue'), local('Arial');
      font-weight: 100 900;
    }
    @font-face {
      font-family: 'Cinzel';
      src: local('Georgia'), local('Times New Roman'), local('Times');
      font-weight: 600 900;
    }
  </style>
  <style>
    :root {
      --bg-dark: #0D0A0F;
      --bg-surface: #17121A;
      --bg-card: #201924;
      --bg-card-elevated: #2A2130;
      --gold-primary: #D4AF37;
      --gold-light: #F4E295;
      --gold-dark: #997A15;
      --gold-glow: rgba(212, 175, 55, 0.28);
      --brown-warm: #3A2315;
      --emerald: #2EC4B6;
      --emerald-glow: rgba(46, 196, 182, 0.3);
      --amber: #FF9F1C;
      --rose: #E71D36;
      --blue: #4CC9F0;
      --text-light: #FDF8F3;
      --text-muted: #B8ABA0;
      --text-subtle: #756960;
      --border-subtle: rgba(255, 255, 255, 0.08);
      --border-gold: rgba(212, 175, 55, 0.35);
      --radius-sm: 8px;
      --radius-md: 14px;
      --radius-lg: 20px;
      --radius-xl: 26px;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: 'Outfit', -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      -webkit-tap-highlight-color: transparent;
    }
    body {
      background-color: var(--bg-dark);
      background-image: radial-gradient(circle at 50% 0%, rgba(212, 175, 55, 0.08) 0%, transparent 60%),
                        radial-gradient(circle at 100% 100%, rgba(58, 35, 21, 0.15) 0%, transparent 50%);
      color: var(--text-light);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      padding-bottom: 96px;
    }

    /* SVG Icon Helpers */
    .icon-svg {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      vertical-align: middle;
      flex-shrink: 0;
    }

    /* Top Glassmorphic Header */
    header {
      background: rgba(23, 18, 26, 0.88);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border-bottom: 1px solid var(--border-gold);
      padding: 12px 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      position: sticky;
      top: 0;
      z-index: 100;
      box-shadow: 0 4px 20px rgba(0,0,0,0.6);
    }
    .brand { display: flex; align-items: center; gap: 12px; }
    .brand-logo-frame {
      height: 40px;
      width: 40px;
      border-radius: var(--radius-sm);
      overflow: hidden;
      border: 1.5px solid var(--gold-primary);
      box-shadow: 0 2px 10px var(--gold-glow);
      background: var(--bg-surface);
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .brand-logo-frame img { width: 100%; height: 100%; object-fit: cover; }
    .brand-title {
      font-family: 'Cinzel', Georgia, 'Times New Roman', 'Palatino Linotype', serif;
      font-weight: 800;
      font-size: 16px;
      letter-spacing: 2px;
      color: var(--gold-primary);
      line-height: 1.1;
      text-shadow: 0 1px 4px rgba(0,0,0,0.8);
    }
    .brand-sub {
      font-size: 10px;
      font-weight: 600;
      letter-spacing: 0.8px;
      color: var(--gold-light);
      opacity: 0.85;
      text-transform: uppercase;
    }

    .header-right {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .live-dot-pulse {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: var(--emerald);
      box-shadow: 0 0 8px var(--emerald);
      animation: livePulse 2s infinite;
    }
    @keyframes livePulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.4; transform: scale(0.8); }
    }
    .table-pill {
      background: rgba(212, 175, 55, 0.16);
      border: 1.2px solid var(--gold-primary);
      color: var(--gold-light);
      padding: 6px 14px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 800;
      box-shadow: 0 0 12px var(--gold-glow);
      display: flex;
      align-items: center;
      gap: 6px;
      letter-spacing: 0.5px;
      cursor: pointer;
      user-select: none;
      transition: all 0.18s ease;
    }
    .table-pill:active { transform: scale(0.95); }
    .table-pill.takeout {
      background: linear-gradient(135deg, rgba(255, 159, 28, 0.28) 0%, rgba(224, 122, 0, 0.18) 100%);
      border-color: #FF9F1C;
      color: #FFB74D;
      box-shadow: 0 0 14px rgba(255, 159, 28, 0.4);
    }
    .dining-card {
      background: var(--bg-card);
      border: 1.5px solid var(--border-subtle);
      border-radius: var(--radius-lg);
      padding: 16px;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 14px;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
      position: relative;
      overflow: hidden;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
    }
    .dining-card:hover {
      border-color: var(--gold-primary);
      transform: translateY(-2px);
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.6);
    }
    .dining-card:active { transform: scale(0.97); }
    .dining-card.selected {
      border-color: var(--gold-primary);
      background: linear-gradient(135deg, rgba(212, 175, 55, 0.18) 0%, rgba(153, 122, 21, 0.08) 100%);
      box-shadow: 0 0 20px var(--gold-glow);
    }
    .dining-card.takeout-card.selected, .dining-card.takeout-card:hover {
      border-color: #FF9F1C;
      background: linear-gradient(135deg, rgba(255, 159, 28, 0.2) 0%, rgba(224, 122, 0, 0.08) 100%);
      box-shadow: 0 0 20px rgba(255, 159, 28, 0.35);
    }
    .dining-icon-box {
      width: 52px;
      height: 52px;
      border-radius: 16px;
      background: rgba(255, 255, 255, 0.06);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 26px;
      flex-shrink: 0;
      border: 1px solid rgba(255, 255, 255, 0.12);
    }
    .takeout-card .dining-icon-box {
      background: rgba(255, 159, 28, 0.16);
      border-color: rgba(255, 159, 28, 0.45);
    }
    .order-type-tab-btn {
      flex: 1;
      padding: 11px 14px;
      border-radius: var(--radius-md);
      font-size: 13px;
      font-weight: 800;
      border: 1.2px solid var(--border-subtle);
      background: var(--bg-card);
      color: var(--text-muted);
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      transition: all 0.18s ease;
    }
    .order-type-tab-btn.active {
      border-color: var(--gold-primary);
      background: linear-gradient(135deg, rgba(212, 175, 55, 0.25) 0%, rgba(153, 122, 21, 0.15) 100%);
      color: var(--gold-light);
      box-shadow: 0 2px 12px var(--gold-glow);
    }
    .order-type-tab-btn.takeout.active {
      border-color: #FF9F1C;
      background: linear-gradient(135deg, rgba(255, 159, 28, 0.3) 0%, rgba(224, 122, 0, 0.15) 100%);
      color: #FFB74D;
      box-shadow: 0 2px 14px rgba(255, 159, 28, 0.35);
    }

    /* Hero Banner Greeting */
    .hero-banner {
      padding: 16px 18px 8px 18px;
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
    }
    .hero-greeting {
      font-size: 20px;
      font-weight: 800;
      color: var(--text-light);
      font-family: 'Cinzel', Georgia, 'Times New Roman', 'Palatino Linotype', serif;
      letter-spacing: 0.5px;
    }
    .hero-sub {
      font-size: 12px;
      color: var(--text-muted);
      margin-top: 2px;
    }

    /* Sticky Controls: Search Bar + Categories */
    .controls-wrapper {
      background: rgba(23, 18, 26, 0.92);
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
      position: sticky;
      top: 65px;
      z-index: 95;
      border-bottom: 1px solid var(--border-subtle);
      padding-top: 4px;
    }

    /* Modern Search Box */
    .search-box {
      padding: 6px 18px 8px 18px;
      position: relative;
      display: flex;
      align-items: center;
    }
    .search-input {
      width: 100%;
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-md);
      padding: 10px 40px 10px 42px;
      font-size: 13.5px;
      color: var(--text-light);
      outline: none;
      transition: all 0.2s ease;
      box-shadow: inset 0 2px 4px rgba(0,0,0,0.3);
    }
    .search-input::placeholder { color: var(--text-subtle); }
    .search-input:focus {
      border-color: var(--gold-primary);
      background: var(--bg-card-elevated);
      box-shadow: 0 0 14px var(--gold-glow);
    }
    .search-icon-pos {
      position: absolute;
      left: 32px;
      color: var(--gold-primary);
      pointer-events: none;
    }
    .clear-search-btn {
      position: absolute;
      right: 28px;
      background: rgba(255, 255, 255, 0.12);
      border: none;
      color: var(--text-muted);
      border-radius: 50%;
      width: 22px;
      height: 22px;
      font-size: 11px;
      cursor: pointer;
      display: none;
      align-items: center;
      justify-content: center;
      transition: background 0.15s;
    }
    .clear-search-btn:active { background: rgba(255,255,255,0.25); }

    /* Category Navigation Bar */
    .cat-bar {
      padding: 4px 18px 10px 18px;
      display: flex;
      gap: 8px;
      overflow-x: auto;
      scrollbar-width: none;
      -webkit-overflow-scrolling: touch;
    }
    .cat-bar::-webkit-scrollbar { display: none; }
    .cat-tab {
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      color: var(--text-muted);
      padding: 8px 16px;
      border-radius: 24px;
      font-size: 12.5px;
      font-weight: 600;
      cursor: pointer;
      white-space: nowrap;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.18s cubic-bezier(0.4, 0, 0.2, 1);
    }
    .cat-tab:active { transform: scale(0.95); }
    .cat-tab.active {
      background: linear-gradient(135deg, rgba(212, 175, 55, 0.3) 0%, rgba(153, 122, 21, 0.2) 100%);
      border-color: var(--gold-primary);
      color: var(--gold-light);
      font-weight: 700;
      box-shadow: 0 2px 10px var(--gold-glow);
    }

    /* Section Title & Items Count */
    .section-header {
      padding: 16px 18px 8px 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .section-title {
      font-size: 15px;
      font-weight: 800;
      font-family: 'Cinzel', serif;
      color: var(--gold-light);
      display: flex;
      align-items: center;
      gap: 8px;
      letter-spacing: 0.5px;
    }
    .item-counter-badge {
      font-size: 11px;
      font-weight: 700;
      color: var(--gold-light);
      background: rgba(212, 175, 55, 0.14);
      border: 1px solid rgba(212, 175, 55, 0.3);
      padding: 3px 10px;
      border-radius: 12px;
    }

    /* Menu Grid Container - GUARANTEED 2 COLUMNS ON ALL PHONES */
    .menu-container {
      padding: 6px 10px 24px 10px;
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
    }

    @media (min-width: 600px) {
      .menu-container {
        padding: 10px 20px 30px 20px;
        grid-template-columns: repeat(auto-fill, minmax(170px, 1fr));
        gap: 14px;
      }
      .item-img-container {
        height: 125px !important;
      }
    }

    /* Item Card */
    .item-card {
      background: var(--bg-card);
      border-radius: var(--radius-lg);
      border: 1px solid var(--border-subtle);
      padding: 10px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
      cursor: pointer;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
      position: relative;
      overflow: hidden;
      min-width: 0;
    }
    .item-card:hover {
      border-color: rgba(212, 175, 55, 0.4);
      transform: translateY(-2px);
      box-shadow: 0 10px 24px rgba(0, 0, 0, 0.6);
    }
    .item-card:active {
      transform: scale(0.97);
    }

    .item-img-container {
      width: 100%;
      height: 105px;
      border-radius: var(--radius-md);
      overflow: hidden;
      margin-bottom: 8px;
      background: rgba(0, 0, 0, 0.45);
      border: 1px solid rgba(255, 255, 255, 0.05);
      position: relative;
    }
    .item-img-container img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      transition: transform 0.3s ease;
    }
    .item-card:hover .item-img-container img {
      transform: scale(1.05);
    }
    .item-img-placeholder {
      width: 100%;
      height: 100%;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #1f1723 0%, #2b1f32 100%);
      color: var(--gold-light);
    }
    .item-img-placeholder svg { opacity: 0.7; }

    .item-cat-badge {
      font-size: 9.5px;
      font-weight: 700;
      color: var(--gold-light);
      text-transform: uppercase;
      letter-spacing: 0.6px;
      margin-bottom: 3px;
      display: inline-block;
    }
    .item-card-name {
      font-weight: 700;
      font-size: 13px;
      color: var(--text-light);
      line-height: 1.3;
      margin-bottom: 3px;
      word-break: break-word;
    }
    .item-card-desc {
      font-size: 10.5px;
      color: var(--text-muted);
      line-height: 1.3;
      max-height: 30px;
      overflow: hidden;
      text-overflow: ellipsis;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
    }

    .item-card-bottom {
      display: flex;
      flex-direction: column;
      margin-top: 8px;
      padding-top: 8px;
      border-top: 1px dashed rgba(255, 255, 255, 0.08);
      gap: 12px;
    }
    .item-card-bottom-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      width: 100%;
    }
    .item-price {
      font-size: 15.5px;
      font-weight: 900;
      color: var(--gold-light);
      letter-spacing: 0.3px;
    }
    .btn-add-pill {
      background: var(--gold-primary);
      color: #000000;
      width: 100%;
      justify-content: center;
      border: none;
      border-radius: 9px;
      padding: 10px 14px;
      font-weight: 800;
      font-size: 13.5px;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.15s ease;
    }
    .btn-add-pill:active { transform: scale(0.92); }

    /* Floating Cart Tray Bar */
    .cart-bar {
      position: fixed;
      bottom: 14px;
      left: 16px;
      right: 16px;
      background: rgba(23, 18, 26, 0.94);
      backdrop-filter: blur(18px);
      -webkit-backdrop-filter: blur(18px);
      border: 1.5px solid var(--gold-primary);
      border-radius: var(--radius-xl);
      padding: 12px 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      z-index: 100;
      box-shadow: 0 10px 30px rgba(0,0,0,0.8), 0 0 20px var(--gold-glow);
      animation: slideUpTray 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    }
    @keyframes slideUpTray {
      from { transform: translateY(100px); opacity: 0; }
      to { transform: translateY(0); opacity: 1; }
    }
    .cart-summary { display: flex; flex-direction: column; }
    .cart-count { font-size: 11.5px; color: var(--text-muted); font-weight: 600; letter-spacing: 0.4px; }
    .cart-total { font-size: 20px; font-weight: 800; color: var(--gold-light); letter-spacing: 0.5px; }
    .btn-view-tray {
      background: linear-gradient(135deg, var(--gold-primary) 0%, #C49822 100%);
      color: #0D0A0F;
      border: none;
      border-radius: 14px;
      padding: 12px 22px;
      font-size: 14px;
      font-weight: 800;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 8px;
      box-shadow: 0 4px 14px rgba(212, 175, 55, 0.4);
      transition: all 0.15s ease;
    }
    .btn-view-tray:active { transform: scale(0.96); }

    /* Modal Overlay & Bottom Sheet */
    .modal-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.82);
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
      z-index: 200;
      display: none;
      align-items: flex-end;
      animation: fadeInModal 0.2s ease-out;
    }
    @keyframes fadeInModal {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    .modal-content {
      background: var(--bg-surface);
      border-radius: 28px 28px 0 0;
      border-top: 2px solid var(--gold-primary);
      width: 100%;
      max-height: 90vh;
      overflow-y: auto;
      padding: 20px 20px 32px 20px;
      box-shadow: 0 -10px 40px rgba(0,0,0,0.9);
      animation: slideUpSheet 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    }
    @keyframes slideUpSheet {
      from { transform: translateY(100%); }
      to { transform: translateY(0); }
    }
    .modal-drag-pill {
      width: 44px;
      height: 4px;
      border-radius: 4px;
      background: rgba(255, 255, 255, 0.2);
      margin: 0 auto 16px auto;
    }

    .modal-title { font-size: 19px; font-weight: 800; font-family: 'Cinzel', serif; color: var(--text-light); }
    .modal-desc { font-size: 12px; color: var(--text-muted); margin-top: 4px; margin-bottom: 16px; line-height: 1.4; }
    
    .opt-group-title {
      font-size: 12px;
      font-weight: 700;
      color: var(--gold-light);
      text-transform: uppercase;
      margin-top: 16px;
      margin-bottom: 8px;
      letter-spacing: 0.8px;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .opt-grid { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 6px; }
    .opt-chip {
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      color: var(--text-muted);
      padding: 9px 15px;
      border-radius: var(--radius-md);
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.15s ease;
    }
    .opt-chip.selected {
      background: linear-gradient(135deg, rgba(212, 175, 55, 0.28) 0%, rgba(153, 122, 21, 0.18) 100%);
      border-color: var(--gold-primary);
      color: var(--gold-light);
      font-weight: 700;
      box-shadow: 0 2px 8px var(--gold-glow);
    }

    /* ── POS Customization Dialog Replica Styles ── */
    #customModal {
      align-items: center;
      justify-content: center;
      padding: 16px;
    }
    @media (max-width: 600px) {
      #customModal {
        align-items: flex-end;
        padding: 0;
      }
    }
    .custom-dialog-card {
      background: #1C1622;
      border: 1.5px solid rgba(212, 175, 55, 0.35);
      border-radius: 24px;
      width: 100%;
      max-width: 520px;
      max-height: 90vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.95), 0 0 30px rgba(212, 175, 55, 0.12);
      overflow: hidden;
      animation: popIn 0.22s cubic-bezier(0.18, 0.89, 0.32, 1.28);
    }
    @media (max-width: 600px) {
      .custom-dialog-card {
        border-radius: 24px 24px 0 0;
        max-height: 92vh;
      }
    }

    .cust-dlg-header {
      padding: 16px 18px;
      background: linear-gradient(135deg, #251B29 0%, #1A131E 100%);
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      display: flex;
      align-items: flex-start;
      gap: 14px;
    }
    .cust-dlg-thumb {
      width: 62px;
      height: 62px;
      border-radius: 16px;
      border: 1.5px solid rgba(212, 175, 55, 0.5);
      overflow: hidden;
      background: #140E18;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.6), 0 0 16px rgba(212, 175, 55, 0.15);
      flex-shrink: 0;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .cust-dlg-thumb img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .cust-dlg-info {
      flex: 1;
      min-width: 0;
    }
    .cust-dlg-title-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
    }
    .cust-dlg-name {
      font-size: 18.5px;
      font-weight: 800;
      font-family: 'Outfit', sans-serif;
      color: #FFFFFF;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      letter-spacing: 0.2px;
    }
    .cust-dlg-price-badge {
      background: rgba(212, 175, 55, 0.15);
      border: 1px solid rgba(212, 175, 55, 0.5);
      color: var(--gold-light);
      font-size: 13.5px;
      font-weight: 800;
      font-family: 'Outfit', sans-serif;
      padding: 3px 10px;
      border-radius: 8px;
      white-space: nowrap;
      flex-shrink: 0;
    }
    .cust-dlg-close {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.14);
      color: var(--text-muted);
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 15px;
      flex-shrink: 0;
      transition: all 0.15s ease;
    }
    .cust-dlg-close:hover {
      background: rgba(255, 255, 255, 0.15);
      color: #FFFFFF;
    }
    .cust-dlg-tags {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 6px;
      margin-top: 4px;
    }
    .cust-dlg-tag {
      background: rgba(255, 255, 255, 0.06);
      border-radius: 6px;
      padding: 2px 7px;
      font-size: 10.5px;
      font-weight: 600;
      color: var(--text-muted);
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }
    .cust-dlg-tag.gold {
      background: rgba(212, 175, 55, 0.12);
      color: var(--gold-light);
      border: 0.5px solid rgba(212, 175, 55, 0.3);
    }
    .cust-dlg-desc {
      font-size: 11.5px;
      color: var(--text-muted);
      margin-top: 5px;
      line-height: 1.35;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }

    .cust-dlg-body {
      padding: 16px 18px;
      overflow-y: auto;
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    
    .cust-group-header {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 10px;
    }
    .cust-group-icon {
      width: 24px;
      height: 24px;
      border-radius: 6px;
      background: rgba(212, 175, 55, 0.14);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 12px;
      color: var(--gold-primary);
    }
    .cust-group-title {
      font-size: 14px;
      font-weight: 700;
      font-family: 'Outfit', sans-serif;
      color: #FFFFFF;
      letter-spacing: 0.2px;
    }
    .cust-badge-required {
      background: rgba(212, 175, 55, 0.15);
      border: 1px solid var(--gold-primary);
      color: var(--gold-light);
      font-size: 9.5px;
      font-weight: 800;
      letter-spacing: 0.5px;
      padding: 2px 7px;
      border-radius: 8px;
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }
    .cust-badge-required::before {
      content: '';
      width: 5px;
      height: 5px;
      border-radius: 50%;
      background: var(--gold-primary);
      display: inline-block;
    }
    .cust-badge-optional {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.1);
      color: var(--text-subtle);
      font-size: 9.5px;
      font-weight: 600;
      letter-spacing: 0.4px;
      padding: 2px 7px;
      border-radius: 8px;
    }

    .cust-opt-grid-2col {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
    }

    .cust-opt-card {
      background: #17111C;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 14px;
      padding: 10px 12px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      cursor: pointer;
      transition: all 0.16s cubic-bezier(0.4, 0, 0.2, 1);
      user-select: none;
    }
    .cust-opt-card:active {
      transform: scale(0.97);
    }
    .cust-opt-card.selected {
      background: rgba(212, 175, 55, 0.12);
      border: 1.6px solid var(--gold-primary);
      box-shadow: 0 0 14px rgba(212, 175, 55, 0.15);
    }

    .cust-temp-card {
      padding: 10px 12px;
    }
    .cust-temp-icon-box {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 16px;
      background: rgba(255, 255, 255, 0.06);
      flex-shrink: 0;
    }
    .cust-opt-card.selected .cust-temp-icon-box.hot {
      background: rgba(255, 122, 69, 0.2);
    }
    .cust-opt-card.selected .cust-temp-icon-box.iced {
      background: rgba(76, 201, 240, 0.2);
    }

    .cust-opt-text-col {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
    }
    .cust-opt-label {
      font-size: 13px;
      font-weight: 600;
      color: var(--text-muted);
      font-family: 'Outfit', sans-serif;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .cust-opt-card.selected .cust-opt-label {
      font-weight: 700;
      color: #FFFFFF;
    }
    .cust-opt-sublabel {
      font-size: 10px;
      color: var(--text-subtle);
      margin-top: 1px;
    }
    .cust-opt-card.selected .cust-opt-sublabel {
      color: var(--gold-light);
    }

    .cust-radio-circle {
      width: 17px;
      height: 17px;
      border-radius: 50%;
      border: 1.5px solid rgba(255, 255, 255, 0.2);
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      transition: all 0.15s ease;
    }
    .cust-opt-card.selected .cust-radio-circle {
      border-color: var(--gold-primary);
    }
    .cust-opt-card.selected .cust-radio-circle::after {
      content: '';
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--gold-primary);
      box-shadow: 0 0 6px var(--gold-primary);
    }

    .cust-check-box {
      width: 22px;
      height: 22px;
      border-radius: 6px;
      border: 1.2px solid rgba(255, 255, 255, 0.2);
      background: rgba(255, 255, 255, 0.05);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 13px;
      font-weight: bold;
      color: var(--text-subtle);
      flex-shrink: 0;
      transition: all 0.15s ease;
    }
    .cust-opt-card.selected .cust-check-box {
      border-color: var(--gold-primary);
      background: var(--gold-primary);
      color: #0D0A0F;
    }

    .cust-price-pill {
      background: rgba(212, 175, 55, 0.18);
      border: 0.8px solid rgba(212, 175, 55, 0.4);
      color: var(--gold-light);
      font-size: 11px;
      font-weight: 800;
      font-family: 'Outfit', sans-serif;
      padding: 2px 7px;
      border-radius: 6px;
      white-space: nowrap;
      flex-shrink: 0;
    }

    .cust-notes-input {
      width: 100%;
      background: #17111C;
      border: 1px solid rgba(255, 255, 255, 0.09);
      border-radius: 12px;
      padding: 12px 14px;
      color: #FFFFFF;
      font-size: 13px;
      font-family: 'Outfit', sans-serif;
      outline: none;
      transition: border-color 0.15s ease;
    }
    .cust-notes-input:focus {
      border-color: var(--gold-primary);
    }
    .cust-notes-input::placeholder {
      color: var(--text-subtle);
    }

    .cust-dlg-footer {
      padding: 14px 18px 18px 18px;
      background: #17111C;
      border-top: 1px solid rgba(255, 255, 255, 0.08);
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .cust-stepper {
      height: 48px;
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.15);
      border-radius: 14px;
      display: flex;
      align-items: center;
      padding: 0 4px;
      flex-shrink: 0;
    }
    .cust-stepper-btn {
      width: 34px;
      height: 36px;
      background: none;
      border: none;
      color: var(--gold-primary);
      font-size: 18px;
      font-weight: bold;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: transform 0.1s ease;
    }
    .cust-stepper-btn:active {
      transform: scale(0.88);
    }
    .cust-stepper-val {
      font-size: 16px;
      font-weight: 800;
      font-family: 'Outfit', sans-serif;
      color: #FFFFFF;
      min-width: 24px;
      text-align: center;
    }
    .cust-add-btn {
      flex: 1;
      height: 48px;
      background: linear-gradient(135deg, #D4AF37 0%, #C49822 100%);
      color: #0D0A0F;
      border: none;
      border-radius: 14px;
      font-size: 15px;
      font-weight: 900;
      font-family: 'Outfit', sans-serif;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      box-shadow: 0 4px 18px rgba(212, 175, 55, 0.4);
      transition: all 0.15s ease;
    }
    .cust-add-btn:active {
      transform: scale(0.97);
    }

    /* Quantity Stepper Control in Customization Modal */
    .qty-stepper-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-md);
      padding: 10px 14px;
      margin-top: 14px;
      margin-bottom: 14px;
    }
    .qty-controls {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .btn-qty {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.15);
      color: var(--text-light);
      font-weight: bold;
      font-size: 16px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.15s;
    }
    .btn-qty:active { background: var(--gold-primary); color: #0D0A0F; }
    .qty-display { font-size: 16px; font-weight: 800; color: var(--gold-light); min-width: 24px; text-align: center; }

    /* Order Tracker Card */
    .tracker-card {
      background: var(--bg-card);
      border-radius: var(--radius-xl);
      border: 1.5px solid var(--gold-primary);
      padding: 26px 20px;
      margin: 16px 18px;
      text-align: center;
      box-shadow: 0 10px 36px rgba(0,0,0,0.8), 0 0 20px var(--gold-glow);
      animation: fadeInModal 0.3s ease;
    }
    .tracker-num-box {
      background: rgba(212, 175, 55, 0.12);
      border: 1px dashed var(--gold-primary);
      border-radius: var(--radius-lg);
      padding: 16px;
      margin: 12px 0 16px 0;
    }
    .tracker-num {
      font-size: 44px;
      font-weight: 800;
      font-family: 'Cinzel', serif;
      color: var(--gold-light);
      letter-spacing: 2px;
      text-shadow: 0 2px 10px var(--gold-glow);
    }
    .tracker-table { font-size: 13px; font-weight: 700; color: var(--text-muted); margin-top: 2px; }
    
    /* Timeline Milestone Stepper */
    .status-steps {
      display: flex;
      justify-content: space-between;
      margin-top: 24px;
      margin-bottom: 24px;
      position: relative;
    }
    .status-steps::before {
      content: '';
      position: absolute;
      top: 19px;
      left: 15%;
      right: 15%;
      height: 2px;
      background: rgba(255, 255, 255, 0.12);
      z-index: 1;
    }
    .status-step { display: flex; flex-direction: column; align-items: center; gap: 8px; z-index: 2; flex: 1; }
    .step-dot {
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: var(--bg-surface);
      border: 2px solid rgba(255,255,255,0.2);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 14px;
      font-weight: 800;
      color: var(--text-muted);
      transition: all 0.3s ease;
    }
    .step-label { font-size: 11.5px; font-weight: 700; color: var(--text-muted); transition: color 0.3s ease; }
    
    .status-step.active .step-dot {
      background: linear-gradient(135deg, var(--gold-primary) 0%, #C49822 100%);
      border-color: var(--gold-light);
      color: #0D0A0F;
      box-shadow: 0 0 20px rgba(212, 175, 55, 0.8);
      transform: scale(1.1);
    }
    .status-step.active .step-label { color: var(--gold-light); font-weight: 800; }
    
    .status-step.completed .step-dot {
      background: var(--emerald);
      border-color: var(--emerald);
      color: #000;
      box-shadow: 0 0 12px var(--emerald-glow);
    }
    .status-step.completed .step-label { color: var(--emerald); }

    /* READY ALARM BANNER & SILENT-MODE HIGH-CONTRAST STROBE */
    body.alarm-active {
      animation: screenStrobe 0.65s infinite alternate !important;
    }
    @keyframes screenStrobe {
      0% {
        background-color: #0D0A0F;
        box-shadow: inset 0 0 40px rgba(0, 0, 0, 0.8);
      }
      50% {
        background-color: #073832;
        box-shadow: inset 0 0 160px rgba(46, 196, 182, 0.95), 0 0 80px rgba(46, 196, 182, 0.8);
      }
      100% {
        background-color: #382A0A;
        box-shadow: inset 0 0 160px rgba(212, 175, 55, 0.95), 0 0 80px rgba(212, 175, 55, 0.8);
      }
    }
    .ready-alarm-box {
      background: rgba(46, 196, 182, 0.2);
      border: 2px solid var(--emerald);
      border-radius: var(--radius-lg);
      padding: 20px 16px;
      margin-top: 16px;
      animation: alertPulse 0.9s infinite alternate;
    }
    @keyframes alertPulse {
      0% { box-shadow: 0 0 12px rgba(46,196,182,0.3); transform: scale(0.99); }
      100% { box-shadow: 0 0 32px rgba(46,196,182,0.95); transform: scale(1.01); }
    }
    .ready-alarm-title { font-size: 20px; font-weight: 800; font-family: 'Cinzel', serif; color: var(--emerald); letter-spacing: 1px; }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    .btn-spinner {
      width: 14px;
      height: 14px;
      border: 2px solid currentColor;
      border-top-color: transparent;
      border-radius: 50%;
      display: inline-block;
      animation: spin 0.7s linear infinite;
      vertical-align: middle;
      margin-right: 6px;
    }
    .ready-alarm-sub { font-size: 13px; color: var(--text-light); margin-top: 6px; font-weight: 600; }
    .btn-silence {
      background: var(--emerald);
      color: #000;
      border: none;
      border-radius: var(--radius-md);
      padding: 12px 26px;
      font-size: 14px;
      font-weight: 800;
      margin-top: 14px;
      cursor: pointer;
      box-shadow: 0 4px 16px rgba(46, 196, 182, 0.4);
    }

    .empty-state {
      grid-column: 1 / -1;
      text-align: center;
      padding: 60px 20px;
      color: var(--text-muted);
    }
    .empty-icon { font-size: 40px; margin-bottom: 10px; opacity: 0.6; }

    @media print {
      body * { visibility: hidden; }
      #orderReceiptModal, #orderReceiptModal .modal-content, #orderReceiptModal .modal-content * {
        visibility: visible;
      }
      #orderReceiptModal {
        position: fixed;
        left: 0;
        top: 0;
        width: 100vw;
        height: auto;
        background: #ffffff !important;
        color: #000000 !important;
        display: block !important;
        padding: 0 !important;
        margin: 0 !important;
      }
      #orderReceiptModal .modal-content {
        background: #ffffff !important;
        color: #000000 !important;
        border: none !important;
        box-shadow: none !important;
        padding: 10px !important;
        max-width: 100% !important;
      }
      .no-print { display: none !important; }
    }
  </style>
</head>
<body>
  <!-- Header Bar -->
  <header>
    <div class="brand">
      <div class="brand-logo-frame">
        <img src="/logo.png" alt="Logo" onerror="this.parentElement.innerHTML='<span style=\\'font-weight:800;color:#D4AF37;\\'>C</span>'">
      </div>
      <div>
        <div class="brand-title">CELESTIAL</div>
        <div class="brand-sub">Cozy & Classic</div>
      </div>
    </div>
    <div class="header-right" style="display: flex; align-items: center; gap: 8px;">
      <div class="live-dot-pulse" title="Connected to Cafe Hotspot"></div>
      <div id="tablePill" class="table-pill" onclick="showDiningOptionModal()" title="Tap to switch Dine-In or Takeout"><span>🍽️</span> <span>Table 1</span> <span style="font-size:10px;opacity:0.7;">▼</span></div>
    </div>
  </header>

  <!-- Sticky Controls: Search Bar + Category Pills -->
  <div class="controls-wrapper" id="controlsWrapper">
    <div class="search-box">
      <span class="search-icon-pos">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
      </span>
      <input type="text" id="searchInput" class="search-input" placeholder="Search coffee, tea, pastries, meals..." oninput="handleSearch(this.value)">
      <button id="clearSearchBtn" class="clear-search-btn" onclick="clearSearch()">✕</button>
    </div>

    <div class="cat-bar" id="catBar">
      <button class="cat-tab active" onclick="filterCategory('all', this)">All Items</button>
      <button class="cat-tab" onclick="filterCategory('coffee', this)">Coffee</button>
      <button class="cat-tab" onclick="filterCategory('frappe', this)">Frappe</button>
      <button class="cat-tab" onclick="filterCategory('milktea', this)">Milk Tea</button>
      <button class="cat-tab" onclick="filterCategory('cheesecakeSeries', this)">Cheesecake</button>
      <button class="cat-tab" onclick="filterCategory('streetBites', this)">Bites</button>
      <button class="cat-tab" onclick="filterCategory('pastaDishes', this)">Pasta</button>
      <button class="cat-tab" onclick="filterCategory('sandwich', this)">Sandwich</button>
    </div>
  </div>

  <!-- Normal Menu View -->
  <div id="menuView">
    <div class="section-header">
      <div class="section-title" id="sectionTitleLabel">All Menu Items</div>
      <div class="item-counter-badge" id="menuCountBadge">0 items</div>
    </div>
    <div class="menu-container" id="menuGrid"></div>
  </div>

  <!-- Active Order Tracker View -->
  <div id="trackerView" style="display: none;">
    <div class="tracker-card">
      <!-- Wi-Fi Disconnect Alert Banner -->
      <div id="wifiWarningBanner" style="display: none; background: rgba(231,29,54,0.18); border: 1.5px solid var(--rose); border-radius: var(--radius-md); padding: 12px 14px; margin-bottom: 14px; text-align: center; color: #FFA8B2; font-size: 12.5px; font-weight: 700; box-shadow: 0 4px 16px rgba(231,29,54,0.3); animation: pulse 2s infinite;">
        Wi-Fi Disconnected! Please reconnect to Cafe Wi-Fi to continue tracking your order live.
      </div>

      <!-- Slow Connection / Loading Banner -->
      <div id="slowConnectionBanner" style="display: none; text-align: center; margin-bottom: 12px;">
        <span style="width: 13px; height: 13px; border: 2px solid var(--amber-brewing); border-top-color: transparent; border-radius: 50%; display: inline-block; animation: spin 0.8s linear infinite;"></span>
      </div>

      <!-- Wi-Fi Keep Connected Notice Pill -->
      <div id="wifiStatusPill" style="display: inline-flex; align-items: center; justify-content: center; gap: 7px; background: rgba(46,196,182,0.12); border: 1px solid rgba(46,196,182,0.35); color: var(--emerald); border-radius: 20px; padding: 6px 14px; font-size: 11.5px; font-weight: 700; margin-bottom: 8px;">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.55a11 11 0 0 1 14.08 0"></path><path d="M1.42 9a16 16 0 0 1 21.16 0"></path><path d="M8.53 16.11a6 6 0 0 1 6.95 0"></path><line x1="12" y1="20" x2="12.01" y2="20"></line></svg>
        <span>Keep Wi-Fi connected to receive live updates & ready chime</span>
      </div>

      <div id="trackerHeaderTag" style="font-size: 11.5px; font-weight: 800; letter-spacing: 1.5px; color: var(--gold-light);">ORDER PLACED • AWAITING CASHIER</div>
      
      <div class="tracker-num-box">
        <div style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-muted); letter-spacing: 1px; margin-bottom: 4px;">Ticket Number</div>
        <div class="tracker-num" id="trackOrderNum">#1</div>
        <div class="tracker-table" id="trackTableInfo">Table 1 • Dine-In</div>
        <div id="trackTotal" style="font-size: 19px; font-weight: 800; color: var(--gold-light); margin-top: 6px;">Total: ₱0</div>
      </div>

      <!-- Pending Cashier Instruction Banner -->
      <div id="pendingPaymentNotice" style="background: rgba(212,175,55,0.12); border: 1.5px solid var(--gold-primary); border-radius: var(--radius-md); padding: 16px 14px; margin-top: 14px; text-align: center; box-shadow: 0 4px 20px rgba(0,0,0,0.5);">
        <div style="font-weight: 800; font-size: 14px; font-family: 'Cinzel', serif; color: var(--gold-light); letter-spacing: 0.5px;">PLEASE PROCEED TO CASHIER COUNTER</div>
        <div style="font-size: 12.5px; color: var(--text-light); margin-top: 6px; line-height: 1.45;">Present your <b id="promptOrderNum" style="color: var(--gold-light); font-size: 13.5px;">Order #1</b> to the cashier to confirm your order and settle payment.</div>
        <div style="font-size: 11.5px; color: var(--gold-primary); margin-top: 8px; font-weight: 700; letter-spacing: 0.5px;">Status: Awaiting Cashier Confirmation</div>
      </div>

      <!-- Confirmed / In Queue Banner -->
      <div id="confirmedPaymentNotice" style="display: none; background: rgba(46,196,182,0.12); border: 1.5px solid var(--emerald); border-radius: var(--radius-md); padding: 16px 14px; margin-top: 14px; text-align: center;">
        <div style="font-weight: 800; font-size: 14.5px; font-family: 'Cinzel', serif; color: var(--emerald); letter-spacing: 0.5px;">PAYMENT CONFIRMED • IN QUEUE</div>
        <div style="font-size: 12.5px; color: var(--text-light); margin-top: 6px;">Your order has been approved & paid. Ticket is queued in the kitchen.</div>
        <div style="font-size: 11px; color: var(--gold-light); margin-top: 6px; font-weight: 600;">The barista will start brewing your items shortly.</div>
      </div>

      <!-- Active Brewing / Preparing Banner -->
      <div id="brewingNotice" style="display: none; background: rgba(255,159,28,0.15); border: 1.5px solid var(--amber-brewing); border-radius: var(--radius-md); padding: 16px 14px; margin-top: 14px; text-align: center;">
        <div style="font-weight: 800; font-size: 14.5px; font-family: 'Cinzel', serif; color: var(--gold-light); letter-spacing: 0.5px;">NOW BREWING & PREPARING</div>
        <div style="font-size: 12.5px; color: var(--text-light); margin-top: 6px;">The barista is actively preparing your handcrafted items now.</div>
      </div>

      <!-- Completed / Served Banner -->
      <div id="completedNotice" style="display: none; background: rgba(46,196,182,0.14); border: 1.5px solid var(--emerald); border-radius: var(--radius-md); padding: 18px 14px; margin-top: 14px; text-align: center; box-shadow: 0 4px 20px rgba(46,196,182,0.25);">
        <div style="font-weight: 800; font-size: 15px; font-family: 'Cinzel', serif; color: var(--emerald); letter-spacing: 0.5px;">ORDER SERVED & COMPLETED</div>
        <div style="font-size: 12.5px; color: var(--text-light); margin-top: 6px;">Your order has been served. Thank you for dining with us!</div>
        <div style="font-size: 11.5px; color: var(--gold-light); margin-top: 8px; font-weight: 700;">Enjoy your handcrafted drinks & food!</div>
      </div>

      <!-- Stepper Milestone Tracker -->
      <div class="status-steps">
        <div class="status-step active" id="step1">
          <div class="step-dot">1</div>
          <div class="step-label">At Cashier</div>
        </div>
        <div class="status-step" id="step2">
          <div class="step-dot">2</div>
          <div class="step-label">Brewing / Preparing</div>
        </div>
        <div class="status-step" id="step3">
          <div class="step-dot">3</div>
          <div class="step-label">Ready</div>
        </div>
      </div>

      <!-- Live Kitchen Activity Pop-up Modal Button -->
      <div style="margin-top: 14px;">
        <button onclick="openKitchenQueueModal()" id="btnOpenKitchenQueueModal" style="width: 100%; background: linear-gradient(135deg, rgba(255,159,28,0.16) 0%, rgba(255,159,28,0.05) 100%); border: 1.5px solid var(--amber-brewing); color: var(--gold-light); border-radius: var(--radius-md); padding: 13px 16px; font-weight: 800; font-size: 13.5px; cursor: pointer; display: flex; align-items: center; justify-content: space-between; gap: 8px; box-shadow: 0 4px 14px rgba(255,159,28,0.15); transition: all 0.15s;">
          <div style="display: flex; align-items: center; gap: 8px;">
            <span style="width: 8px; height: 8px; border-radius: 50%; background: var(--amber-brewing); display: inline-block; animation: pulse 1.5s infinite;"></span>
            <span>Live Kitchen Activity</span>
          </div>
          <span id="trackerQueueSummaryBadge" style="background: rgba(255,159,28,0.22); border: 1px solid rgba(255,159,28,0.4); color: var(--amber-brewing); font-size: 11px; padding: 3px 9px; border-radius: 12px; font-weight: 800;">View Queue ➔</span>
        </button>
      </div>

      <!-- View Official Receipt Pop-up Modal Button (Hidden until settled by cashier) -->
      <div style="margin-top: 14px;">
        <button onclick="openOrderModal()" id="btnOpenOrderModal" style="display: none; width: 100%; background: linear-gradient(135deg, rgba(46,196,182,0.18) 0%, rgba(46,196,182,0.06) 100%); border: 1.5px solid var(--emerald); color: var(--gold-light); border-radius: var(--radius-md); padding: 13px 16px; font-weight: 800; font-size: 13.5px; cursor: pointer; align-items: center; justify-content: center; gap: 8px; box-shadow: 0 4px 14px rgba(46,196,182,0.25); transition: all 0.15s;">
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color: var(--emerald);"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
          <span>View Official Receipt (<span style="color: var(--emerald); font-weight: 800;">Paid ✓</span>)</span>
        </button>
      </div>

      <!-- Pending Order Actions: Cancel Order (Available while status is pending cashier payment) -->
      <div id="pendingActionButtons" style="margin-top: 16px;">
        <button onclick="cancelCustomerOrder()" id="btnCancelOrder" style="width: 100%; background: rgba(230, 57, 70, 0.12); border: 1.5px solid var(--rose); color: var(--rose); border-radius: var(--radius-md); padding: 12px; font-weight: 700; font-size: 13px; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px; transition: all 0.15s;">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>
          <span>Cancel Order</span>
        </button>
      </div>

      <div style="display: flex; gap: 10px; justify-content: center; margin-top: 18px;">
        <button onclick="newOrder(true)" id="btnOrderAnotherItem" style="display: none; background: linear-gradient(135deg, rgba(212,175,55,0.2) 0%, rgba(212,175,55,0.08) 100%); border: 1.5px solid var(--gold-primary); color: var(--gold-light); border-radius: var(--radius-md); padding: 12px 20px; font-weight: 800; font-size: 13px; cursor: pointer; align-items: center; gap: 6px; box-shadow: 0 4px 14px rgba(212,175,55,0.18);">
          + Order Another Item
        </button>
      </div>
    </div>
  </div>

  <!-- Bottom Floating Tray -->
  <div class="cart-bar" id="cartBar" style="display: none;">
    <div class="cart-summary">
      <span class="cart-count" id="cartCountText">0 items</span>
      <span class="cart-total" id="cartTotalText">₱0</span>
    </div>
    <button class="btn-view-tray" onclick="openTrayModal()">
      <span>View Tray</span>
      <span>➔</span>
    </button>
  </div>

  <!-- Customization Modal (Exact POS Dialog Replica for Customer Phone) -->
  <div class="modal-overlay" id="customModal" onclick="if(event.target===this) closeModal('customModal')">
    <div class="custom-dialog-card">
      <!-- Header -->
      <div class="cust-dlg-header">
        <div class="cust-dlg-thumb" id="modalThumbBox">
          <img src="" id="modalThumbImg" alt="Item" onerror="this.style.display='none'; document.getElementById('modalThumbIcon').style.display='block';">
          <span id="modalThumbIcon" style="font-size: 26px; display: none;">☕</span>
        </div>
        <div class="cust-dlg-info">
          <div class="cust-dlg-title-row">
            <div class="cust-dlg-name" id="modalItemName">Americano</div>
            <div class="cust-dlg-price-badge" id="modalBasePriceBadge">₱90</div>
            <button class="cust-dlg-close" onclick="closeModal('customModal')">✕</button>
          </div>
          <div class="cust-dlg-tags" id="modalTagsRow"></div>
          <div class="cust-dlg-desc" id="modalItemDesc"></div>
        </div>
      </div>

      <!-- Scrollable Body with Group Options -->
      <div class="cust-dlg-body">
        <div id="customGroupContainer"></div>
      </div>

      <!-- Footer Bar with Stepper & Add to Order Button -->
      <div class="cust-dlg-footer">
        <div class="cust-stepper">
          <button class="cust-stepper-btn" onclick="changeModalQty(-1)">−</button>
          <span class="cust-stepper-val" id="modalQtyDisplay">1</span>
          <button class="cust-stepper-btn" onclick="changeModalQty(1)">+</button>
        </div>
        <button class="cust-add-btn" id="btnAddItemToCart" onclick="confirmAddToCart()">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="21" r="1"></circle><circle cx="20" cy="21" r="1"></circle><path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"></path></svg>
          <span id="modalAddBtnText">Add to Order • ₱90</span>
        </button>
      </div>
    </div>
  </div>

  <!-- Tray & Checkout Modal -->
  <div class="modal-overlay" id="trayModal">
    <div class="modal-content">
      <div class="modal-drag-pill"></div>
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
        <div class="modal-title">Your Order Tray</div>
        <button onclick="closeModal('trayModal')" style="background: rgba(255,255,255,0.08); border: none; border-radius: 50%; width: 32px; height: 32px; font-size: 14px; color: var(--text-muted); cursor: pointer; display: flex; align-items: center; justify-content: center;">✕</button>
      </div>

      <div id="trayItemsList" style="max-height: 38vh; overflow-y: auto; margin-bottom: 16px;"></div>

      <!-- Single Confirmed Dining Option Banner (Dine-In OR Takeout) -->
      <div id="trayDineInBanner" style="margin-bottom: 14px; background: rgba(212,175,55,0.12); border: 1.2px solid var(--gold-primary); border-radius: var(--radius-md); padding: 10px 14px; display: flex; align-items: center; justify-content: space-between;">
        <div style="display: flex; align-items: center; gap: 8px;">
          <span style="font-size: 17px;">🍽️</span>
          <div>
            <div style="font-size: 13px; font-weight: 800; color: var(--gold-light); font-family: 'Cinzel', serif;">Dine-In Order</div>
            <div style="font-size: 11.5px; color: var(--text-muted);" id="trayDineInTableText">Table 1 (Dine-In at Table)</div>
          </div>
        </div>
        <span style="font-size: 10.5px; font-weight: 800; background: rgba(212,175,55,0.22); color: var(--gold-light); padding: 3px 8px; border-radius: 5px;">CONFIRMED</span>
      </div>

      <div id="trayTakeoutBanner" style="display: none; margin-bottom: 14px; background: rgba(255,159,28,0.14); border: 1.2px solid #FF9F1C; border-radius: var(--radius-md); padding: 10px 14px; display: flex; align-items: center; justify-content: space-between;">
        <div style="display: flex; align-items: center; gap: 8px;">
          <span style="font-size: 17px;">🥡</span>
          <div>
            <div style="font-size: 13px; font-weight: 800; color: #FFB74D; font-family: 'Cinzel', serif;">Takeout / To-Go Order</div>
            <div style="font-size: 11px; color: var(--text-light);">Packed in paper cups & bags for counter pickup</div>
          </div>
        </div>
        <span style="font-size: 10.5px; font-weight: 800; background: rgba(255,159,28,0.25); color: #FFB74D; padding: 3px 8px; border-radius: 5px;">TO-GO</span>
      </div>

      <div class="opt-group-title" id="custNameLabel">Guest Name</div>
      <input type="text" id="custNameInput" placeholder="Enter your name (e.g. Maria, John)" style="width: 100%; background: var(--bg-card); border: 1px solid var(--border-subtle); border-radius: var(--radius-md); padding: 12px 14px; color: var(--text-light); font-size: 13.5px; margin-bottom: 14px; outline: none;">

      <div class="opt-group-title">Payment Method</div>
      <div class="opt-grid">
        <div class="opt-chip selected" onclick="selectPayment('cash', this)">Pay Cash at Counter</div>
        <div class="opt-chip" onclick="selectPayment('gcash', this)">Pay GCash at Counter</div>
      </div>

      <div style="border-top: 1px dashed rgba(255,255,255,0.12); padding-top: 14px; margin-top: 16px; display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
        <span style="font-weight: 700; font-size: 14px; color: var(--text-muted);">Total Amount</span>
        <span style="font-weight: 800; font-size: 24px; color: var(--gold-light);" id="trayTotalAmount">₱0</span>
      </div>

      <button onclick="submitOrderToKitchen()" id="btnSendOrder" style="width: 100%; background: linear-gradient(135deg, var(--gold-primary) 0%, #B89025 100%); color: #0D0A0F; border: none; border-radius: var(--radius-md); padding: 16px; font-weight: 800; font-size: 15.5px; cursor: pointer; box-shadow: 0 4px 18px rgba(212, 175, 55, 0.4);">
        Submit Order to Cashier
      </button>
    </div>
  </div>

  <!-- Dining Option Modal (Dine-In or Takeout) - First Appearance Prompt -->
  <div class="modal-overlay" id="diningOptionModal" style="display: none;" onclick="if(event.target===this) closeModal('diningOptionModal')">
    <div class="modal-content" style="max-width: 440px; margin: 0 auto; background: #161219; border: 1.5px solid var(--gold-primary); border-radius: 24px; padding: 22px; box-shadow: 0 14px 50px rgba(0,0,0,0.95); animation: popIn 0.22s cubic-bezier(0.18, 0.89, 0.32, 1.28);">
      <div class="modal-drag-pill"></div>

      <div style="text-align: center; margin-bottom: 18px;">
        <div class="brand-logo-frame" style="margin: 0 auto 10px auto; width: 48px; height: 48px; border-radius: 12px;">
          <img src="/logo.png" alt="Logo" onerror="this.parentElement.innerHTML='<span style=\\'font-weight:800;color:#D4AF37;font-size:22px;\\'>C</span>'">
        </div>
        <div style="font-family: 'Cinzel', serif; font-size: 18.5px; font-weight: 800; color: var(--gold-light); letter-spacing: 1px;">WELCOME TO CELESTIAL</div>
        <div style="font-size: 12.5px; color: var(--text-muted); margin-top: 4px;">How will you enjoy your order today?</div>
      </div>

      <div style="display: flex; flex-direction: column; gap: 12px; margin-bottom: 18px;">
        <!-- Option 1: Dine-In -->
        <div class="dining-card selected" id="cardDineIn" onclick="selectDiningOption('dineIn')">
          <div class="dining-icon-box">🍽️</div>
          <div style="flex: 1;">
            <div style="display: flex; align-items: center; justify-content: space-between;">
              <span style="font-weight: 800; font-size: 15px; color: var(--gold-light); font-family: 'Cinzel', serif;">Dine-In</span>
              <span id="dineInCheck" style="font-size: 16px; color: var(--gold-primary); font-weight: 900;">✓</span>
            </div>
            <div style="font-size: 12px; color: var(--text-light); margin-top: 3px;">Enjoy inside our cafe at your table. Served in glassware and plates.</div>
            <div style="margin-top: 8px; display: inline-flex; align-items: center; gap: 6px; background: rgba(212,175,55,0.14); border: 1px solid rgba(212,175,55,0.4); border-radius: 6px; padding: 4px 10px; font-size: 12px; font-weight: 800; color: var(--gold-light);">
              <span style="font-size: 11px;">📍 Scanned Table:</span>
              <span id="welcomeScannedTable">Table 1</span>
            </div>
          </div>
        </div>

        <!-- Option 2: Takeout -->
        <div class="dining-card takeout-card" id="cardTakeout" onclick="selectDiningOption('takeaway')">
          <div class="dining-icon-box">🥡</div>
          <div style="flex: 1;">
            <div style="display: flex; align-items: center; justify-content: space-between;">
              <span style="font-weight: 800; font-size: 15px; color: #FFB74D; font-family: 'Cinzel', serif;">Takeout / To-Go</span>
              <span id="takeoutCheck" style="font-size: 16px; color: #FF9F1C; font-weight: 900; display: none;">✓</span>
            </div>
            <div style="font-size: 12px; color: var(--text-light); margin-top: 3px;">Packed in to-go paper cups, lids, and bags. Pick up freshly at the counter.</div>
            <div style="margin-top: 6px;">
              <span style="background: rgba(255,159,28,0.2); border: 1px solid rgba(255,159,28,0.5); color: #FFB74D; font-size: 10px; font-weight: 800; padding: 2px 8px; border-radius: 4px; display: inline-flex; align-items: center; gap: 4px;">
                🛍️ TO-GO PACKAGING
              </span>
            </div>
          </div>
        </div>
      </div>

      <button type="button" onclick="confirmDiningOptionAndClose()" style="width: 100%; background: linear-gradient(135deg, var(--gold-primary) 0%, #B89025 100%); color: #0D0A0F; border: none; border-radius: var(--radius-md); padding: 14px; font-weight: 800; font-size: 14.5px; cursor: pointer; box-shadow: 0 4px 18px rgba(212, 175, 55, 0.4);">
        Continue to Menu
      </button>
    </div>
  </div>

  <!-- Official Order Receipt Pop-up Modal -->
  <div class="modal-overlay" id="orderReceiptModal" onclick="if(event.target===this) closeModal('orderReceiptModal')">
    <div class="modal-content" style="max-width: 480px; margin: 0 auto; background: #161219; border: 1.5px solid var(--gold-primary); border-radius: 20px; padding: 20px; box-shadow: 0 10px 40px rgba(0,0,0,0.9);">
      <div class="modal-drag-pill"></div>

      <!-- Receipt Header -->
      <div style="text-align: center; margin-bottom: 12px;">
        <div style="font-family: 'Cinzel', serif; font-size: 20px; font-weight: 900; color: var(--gold-light); letter-spacing: 2px;">CELESTIAL</div>
        <div style="font-size: 10px; font-weight: 700; color: var(--gold-primary); letter-spacing: 1.5px; text-transform: uppercase; margin-top: 1px;">Cozy & Classic Artisanal Cafe</div>
        <div style="font-size: 9.5px; color: var(--text-muted); margin-top: 2px;">Coffee • Milk Tea • Cheesecake • Street Bites</div>
      </div>

      <!-- Paid Stamp / Status Badge -->
      <div id="receiptStampContainer" style="margin-bottom: 12px; text-align: center;">
        <div id="receiptStampBadge" style="display: inline-flex; align-items: center; gap: 6px; padding: 4px 14px; border-radius: 6px; font-weight: 900; font-size: 11.5px; letter-spacing: 1px; text-transform: uppercase; border: 1.5px solid #2EC4B6; color: #2EC4B6; background: rgba(46,196,182,0.12);">
          ✓ OFFICIAL RECEIPT • PAID
        </div>
      </div>

      <!-- Metadata Box -->
      <div style="background: rgba(255,255,255,0.03); border-top: 1px dashed rgba(255,255,255,0.15); border-bottom: 1px dashed rgba(255,255,255,0.15); padding: 10px 0; margin-bottom: 12px; font-size: 11.5px; color: var(--text-light); line-height: 1.65;">
        <div style="display: flex; justify-content: space-between;">
          <span style="color: var(--text-muted);">Receipt / Order No:</span>
          <span id="receiptOrderNum" style="font-weight: 800; color: var(--gold-light);">#1</span>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span style="color: var(--text-muted);">Date & Time:</span>
          <span id="receiptDateTime" style="font-weight: 600;">--</span>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span style="color: var(--text-muted);">Table / Type:</span>
          <span id="receiptTableType" style="font-weight: 700; color: var(--gold-light);">Table 1 • Dine-In</span>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span style="color: var(--text-muted);">Cashier / Staff:</span>
          <span id="receiptCashierName" style="font-weight: 600;">Cashier Staff</span>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span style="color: var(--text-muted);">Guest / Customer:</span>
          <span id="receiptCustName" style="font-weight: 600;">Guest Patron</span>
        </div>
      </div>

      <!-- Items List -->
      <div style="font-size: 11px; font-weight: 800; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.8px; margin-bottom: 6px;">Order Items</div>
      <div id="modalOrderItemsList" style="max-height: 32vh; overflow-y: auto; margin-bottom: 12px; background: rgba(0,0,0,0.3); border-radius: 8px; padding: 10px 12px;">
        <!-- Dynamically rendered items -->
      </div>

      <!-- Financial Breakdown -->
      <div style="border-top: 1px dashed rgba(255,255,255,0.15); padding-top: 10px; margin-bottom: 12px; font-size: 12px; line-height: 1.7;">
        <div style="display: flex; justify-content: space-between; color: var(--text-muted);">
          <span>Subtotal:</span>
          <span id="receiptSubtotal" style="font-weight: 700; color: var(--text-light);">₱0</span>
        </div>
        <div id="receiptDiscountRow" style="display: none; justify-content: space-between; color: var(--rose);">
          <span id="receiptDiscountLabel">Discount:</span>
          <span id="receiptDiscountAmount" style="font-weight: 700;">-₱0</span>
        </div>
        <div style="display: flex; justify-content: space-between; align-items: baseline; border-top: 1px solid rgba(255,255,255,0.1); padding-top: 6px; margin-top: 4px;">
          <span style="font-size: 13.5px; font-weight: 800; color: var(--gold-light);">TOTAL AMOUNT:</span>
          <span id="receiptGrandTotal" style="font-size: 20px; font-weight: 900; color: var(--gold-light);">₱0</span>
        </div>

        <!-- Payment Settlement Info (Visible when confirmed/paid) -->
        <div id="receiptPaymentDetails" style="margin-top: 8px; padding-top: 8px; border-top: 1px dotted rgba(255,255,255,0.12); font-size: 11.5px; color: var(--text-muted);">
          <div style="display: flex; justify-content: space-between;">
            <span>Payment Method:</span>
            <span id="receiptPayMethod" style="font-weight: 700; color: var(--text-light); text-transform: uppercase;">CASH</span>
          </div>
          <div style="display: flex; justify-content: space-between;">
            <span>Amount Tendered:</span>
            <span id="receiptTendered" style="font-weight: 700; color: var(--text-light);">₱0</span>
          </div>
          <div style="display: flex; justify-content: space-between;">
            <span>Change Due:</span>
            <span id="receiptChangeDue" style="font-weight: 800; color: var(--emerald);">₱0</span>
          </div>
        </div>
      </div>

      <!-- Footer Message -->
      <div style="text-align: center; margin-bottom: 14px; font-size: 10.5px; color: var(--text-muted); line-height: 1.4;">
        <div>Thank you for dining at Celestial Cafe!</div>
        <div style="color: var(--gold-light); font-weight: 600; margin-top: 2px;">Please present this official receipt upon order claim.</div>
      </div>

      <!-- Action Buttons -->
      <div>
        <button onclick="closeModal('orderReceiptModal')" class="no-print" style="width: 100%; background: rgba(255,255,255,0.08); border: 1.2px solid rgba(255,255,255,0.18); color: var(--text-light); border-radius: var(--radius-md); padding: 12px; font-weight: 700; font-size: 13px; cursor: pointer; transition: all 0.15s ease;">
          Close
        </button>
      </div>
    </div>
  </div>

  <!-- Dynamic Pop-Up Confirmation Modal -->
  <div class="modal-overlay" id="confirmModal" style="align-items: center; justify-content: center; padding: 20px;" onclick="if(event.target===this) closeModal('confirmModal')">
    <div class="modal-content" style="max-width: 400px; border-radius: var(--radius-xl); border: 1.5px solid var(--border-gold); padding: 26px 20px; text-align: center; margin: auto;">
      <div id="confirmModalIconContainer" style="width: 58px; height: 58px; border-radius: 50%; background: rgba(230,57,70,0.14); border: 1.5px solid var(--rose); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; color: var(--rose);">
        <svg id="confirmModalIcon" width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>
      </div>
      <div class="modal-title" id="confirmModalTitle" style="font-size: 18px; color: var(--text-light); margin-bottom: 8px;">Please Confirm</div>
      <div class="modal-desc" id="confirmModalMsg" style="font-size: 13px; color: var(--text-muted); line-height: 1.5; margin-bottom: 22px;">Are you sure you want to proceed?</div>
      <div style="display: flex; gap: 10px;">
        <button id="btnConfirmCancel" onclick="closeModal('confirmModal')" style="flex: 1; background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.18); color: var(--text-light); border-radius: var(--radius-md); padding: 12px; font-weight: 700; font-size: 13px; cursor: pointer;">
          Cancel
        </button>
        <button id="btnConfirmAction" style="flex: 1; background: linear-gradient(135deg, var(--rose) 0%, #B82535 100%); border: none; color: #FFFFFF; border-radius: var(--radius-md); padding: 12px; font-weight: 800; font-size: 13px; cursor: pointer; box-shadow: 0 4px 14px rgba(230,57,70,0.35);">
          Confirm
        </button>
      </div>
    </div>
  </div>

  <!-- Dynamic Pop-Up Success / Notice Modal -->
  <div class="modal-overlay" id="successModal" style="align-items: center; justify-content: center; padding: 20px; z-index: 99999;" onclick="if(event.target===this) closeModal('successModal')">
    <div class="modal-content" style="max-width: 400px; border-radius: var(--radius-xl); border: 1.5px solid var(--emerald); padding: 26px 20px; text-align: center; margin: auto;">
      <div id="successModalIconContainer" style="width: 58px; height: 58px; border-radius: 50%; background: rgba(46,196,182,0.15); border: 1.5px solid var(--emerald); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; color: var(--emerald);">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
      </div>
      <div class="modal-title" id="successModalTitle" style="font-size: 18.5px; color: var(--text-light); margin-bottom: 8px;">Success!</div>
      <div class="modal-desc" id="successModalMsg" style="font-size: 13px; color: var(--text-muted); line-height: 1.5; margin-bottom: 22px;">Your request was completed successfully.</div>
      <button id="btnSuccessDismiss" onclick="closeModal('successModal')" style="width: 100%; background: linear-gradient(135deg, var(--gold-primary) 0%, #B89025 100%); border: none; color: #0D0A0F; border-radius: var(--radius-md); padding: 13px; font-weight: 800; font-size: 14px; cursor: pointer; box-shadow: 0 4px 14px rgba(212,175,55,0.35);">
        Continue
      </button>
    </div>
  </div>

  <!-- Ready For Pickup Pop-Up Alarm Modal -->
  <div class="modal-overlay" id="readyAlarmModal" style="align-items: center; justify-content: center; padding: 20px; z-index: 300;" onclick="if(event.target===this) stopAlarm()">
    <div class="modal-content" style="max-width: 420px; border-radius: var(--radius-xl); border: 2px solid var(--emerald); padding: 28px 22px; text-align: center; margin: auto; box-shadow: 0 0 40px var(--emerald-glow), 0 20px 60px rgba(0,0,0,0.95); animation: alertPulse 0.9s infinite alternate;">
      <div style="width: 68px; height: 68px; border-radius: 50%; background: rgba(46,196,182,0.18); border: 2px solid var(--emerald); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; color: var(--emerald); box-shadow: 0 0 24px var(--emerald-glow);">
        <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path>
          <path d="M13.73 21a2 2 0 0 1-3.46 0"></path>
        </svg>
      </div>

      <div style="font-size: 11px; font-weight: 800; letter-spacing: 2px; text-transform: uppercase; color: var(--emerald); margin-bottom: 6px;">Order Is Ready For Pickup</div>
      
      <div class="modal-title" id="alarmModalOrderNum" style="font-size: 42px; font-family: 'Cinzel', serif; font-weight: 800; color: var(--emerald); letter-spacing: 2px; text-shadow: 0 2px 14px var(--emerald-glow);">#1</div>
      <div id="alarmModalTableInfo" style="font-size: 13px; font-weight: 700; color: var(--text-muted); margin-top: 4px;">Table 1 • Dine-In</div>

      <div style="font-size: 13.5px; color: var(--text-light); line-height: 1.5; margin-top: 16px; padding: 12px 14px; background: rgba(46,196,182,0.1); border-radius: var(--radius-md); border: 1px dashed rgba(46,196,182,0.3);">
        Your handcrafted drinks & food are freshly prepared. Please proceed to the <b>Pickup Counter</b> to claim your order.
      </div>

      <button id="btnDismissReadyAlarmModal" onclick="stopAlarm()" style="width: 100%; background: linear-gradient(135deg, var(--emerald) 0%, #1FA295 100%); border: none; color: #000000; border-radius: var(--radius-md); padding: 15px; font-weight: 900; font-size: 15px; cursor: pointer; box-shadow: 0 4px 20px var(--emerald-glow); margin-top: 20px; display: flex; align-items: center; justify-content: center; gap: 8px;">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
        <span>Silence Alarm & Claim Order</span>
      </button>
    </div>
  </div>

  <!-- Order Completed Pop-Up Modal -->
  <div class="modal-overlay" id="orderCompletedModal" style="align-items: center; justify-content: center; padding: 20px; z-index: 99999;" onclick="if(event.target===this) closeModal('orderCompletedModal')">
    <div class="modal-content" style="max-width: 400px; border-radius: var(--radius-xl); border: 2px solid var(--emerald); padding: 28px 22px; text-align: center; margin: auto; box-shadow: 0 0 35px var(--emerald-glow), 0 20px 60px rgba(0,0,0,0.95); animation: fadeInModal 0.25s ease-out;">
      <div style="width: 68px; height: 68px; border-radius: 50%; background: rgba(46,196,182,0.18); border: 2px solid var(--emerald); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; color: var(--emerald); box-shadow: 0 0 24px var(--emerald-glow);">
        <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
          <polyline points="22 4 12 14.01 9 11.01"></polyline>
        </svg>
      </div>

      <div style="font-size: 11px; font-weight: 800; letter-spacing: 2px; text-transform: uppercase; color: var(--emerald); margin-bottom: 6px;">Order Served & Completed</div>
      
      <div class="modal-title" id="completedModalOrderNum" style="font-size: 38px; font-family: 'Cinzel', serif; font-weight: 800; color: var(--gold-light); letter-spacing: 1px;">#1</div>
      <div id="completedModalTableInfo" style="font-size: 13px; font-weight: 700; color: var(--text-muted); margin-top: 4px;">Table 1 • Dine-In</div>

      <div style="font-size: 13.5px; color: var(--text-light); line-height: 1.5; margin-top: 16px; padding: 12px 14px; background: rgba(46,196,182,0.08); border-radius: var(--radius-md); border: 1px dashed rgba(46,196,182,0.3);">
        Your order has been served. Thank you for dining with Celestial Cafe! Would you like to order anything else?
      </div>

      <!-- Action Buttons: Order Again / No Thanks -->
      <div style="margin-top: 22px; display: flex; flex-direction: column; gap: 10px;">
        <button onclick="closeModal('orderCompletedModal'); newOrder(true);" style="width: 100%; background: linear-gradient(135deg, var(--gold-primary) 0%, #B89025 100%); border: none; color: #0D0A0F; border-radius: var(--radius-md); padding: 14px; font-weight: 900; font-size: 15px; cursor: pointer; box-shadow: 0 4px 18px var(--gold-glow); display: flex; align-items: center; justify-content: center; gap: 8px;">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"></path></svg>
          <span>Order Again</span>
        </button>

        <button onclick="dismissOrderCompleted()" style="width: 100%; background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.15); color: var(--text-muted); border-radius: var(--radius-md); padding: 12px; font-weight: 700; font-size: 13.5px; cursor: pointer; transition: all 0.15s;">
          No Thanks
        </button>
      </div>
    </div>
  </div>

  <!-- Live Kitchen Activity Pop-Up Modal -->
  <div class="modal-overlay" id="kitchenQueueModal" onclick="if(event.target===this) closeModal('kitchenQueueModal')">
    <div class="modal-content" style="max-width: 480px; margin: 0 auto; border-top: 2px solid var(--amber-brewing); box-shadow: 0 -10px 40px rgba(0,0,0,0.9), 0 0 30px rgba(255,159,28,0.15);">
      <div class="modal-drag-pill"></div>
      
      <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 14px;">
        <div>
          <div class="modal-title" style="display: flex; align-items: center; gap: 8px; font-size: 18px;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: var(--amber-brewing);"><path d="M18 8h1a4 4 0 0 1 0 8h-1"></path><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path><line x1="6" y1="1" x2="6" y2="4"></line><line x1="10" y1="1" x2="10" y2="4"></line><line x1="14" y1="1" x2="14" y2="4"></line></svg>
            <span>Live Kitchen Activity</span>
          </div>
          <div class="modal-desc" style="margin-bottom: 0; color: var(--text-muted); font-size: 12px; margin-top: 2px;">Real-time preparation queue from the barista bar & kitchen</div>
        </div>
        <div style="display: flex; align-items: center; gap: 8px;">
          <button onclick="refreshLiveQueueModal()" title="Refresh Queue" style="background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.15); border-radius: 50%; width: 30px; height: 30px; font-size: 13px; color: var(--gold-light); cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.2s;">
            <svg id="queueRefreshIcon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/></svg>
          </button>
          <div style="display: flex; align-items: center; gap: 5px; background: rgba(46,196,182,0.15); border: 1px solid rgba(46,196,182,0.4); border-radius: 12px; padding: 3px 8px; font-size: 10px; font-weight: 700; color: var(--emerald);">
            <span style="width: 6px; height: 6px; border-radius: 50%; background: var(--emerald); display: inline-block; animation: pulse 1.5s infinite;"></span>
            <span>Live Sync</span>
          </div>
          <button onclick="closeModal('kitchenQueueModal')" style="background: rgba(255,255,255,0.08); border: none; border-radius: 50%; width: 30px; height: 30px; font-size: 13px; color: var(--text-muted); cursor: pointer; display: flex; align-items: center; justify-content: center;">✕</button>
        </div>
      </div>

      <!-- Active Tracked Order Highlight in Modal -->
      <div id="modalActiveOrderBanner" style="display: none;"></div>

      <!-- Now Brewing / Preparing Section -->
      <div style="background: rgba(255,159,28,0.08); border: 1.5px solid rgba(255,159,28,0.35); border-radius: var(--radius-md); padding: 14px; margin-bottom: 12px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
          <div style="font-size: 11.5px; font-weight: 800; color: var(--amber-brewing); text-transform: uppercase; letter-spacing: 0.5px; display: flex; align-items: center; gap: 6px;">
            <span style="width: 6px; height: 6px; border-radius: 50%; background: var(--amber-brewing); display: inline-block; animation: pulse 1.2s infinite;"></span>
            <span>Now Brewing / Preparing</span>
          </div>
          <span id="modalNowPrepCount" style="font-size: 11px; font-weight: 800; color: var(--gold-light); background: rgba(255,159,28,0.2); border: 1px solid rgba(255,159,28,0.4); border-radius: 10px; padding: 2px 8px;">0 orders</span>
        </div>
        <div id="modalNowPreparingChips" style="display: flex; flex-wrap: wrap; gap: 8px; align-items: center; min-height: 34px;">
          <span style="font-size: 12px; color: var(--text-muted); font-style: italic;">No orders currently on bar</span>
        </div>
      </div>

      <!-- Orders in Queue Section -->
      <div style="background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.1); border-radius: var(--radius-md); padding: 14px; margin-bottom: 12px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
          <div style="font-size: 11.5px; font-weight: 800; color: var(--text-light); text-transform: uppercase; letter-spacing: 0.5px; display: flex; align-items: center; gap: 6px;">
            <span>Orders In Queue</span>
          </div>
          <span id="modalInQueueCount" style="font-size: 11px; font-weight: 700; color: var(--text-muted); background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.12); border-radius: 10px; padding: 2px 8px;">0 tickets</span>
        </div>
        <div id="modalInQueueChips" style="display: flex; flex-wrap: wrap; gap: 7px; align-items: center; min-height: 34px;">
          <span style="font-size: 12px; color: var(--text-muted);">Queue is currently clear</span>
        </div>
      </div>

      <!-- Ready for Pickup Section -->
      <div style="background: rgba(46,196,182,0.08); border: 1.5px solid rgba(46,196,182,0.3); border-radius: var(--radius-md); padding: 14px; margin-bottom: 16px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
          <div style="font-size: 11.5px; font-weight: 800; color: var(--emerald); text-transform: uppercase; letter-spacing: 0.5px; display: flex; align-items: center; gap: 6px;">
            <span style="width: 6px; height: 6px; border-radius: 50%; background: var(--emerald); display: inline-block;"></span>
            <span>Ready For Pickup</span>
          </div>
          <span id="modalReadyCount" style="font-size: 11px; font-weight: 800; color: var(--emerald); background: rgba(46,196,182,0.18); border: 1px solid rgba(46,196,182,0.4); border-radius: 10px; padding: 2px 8px;">0 ready</span>
        </div>
        <div id="modalReadyChips" style="display: flex; flex-wrap: wrap; gap: 7px; align-items: center; min-height: 32px;">
          <span style="font-size: 12px; color: var(--text-muted);">No orders at pickup counter</span>
        </div>
      </div>

      <button onclick="closeModal('kitchenQueueModal')" style="width: 100%; background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.18); color: var(--text-light); border-radius: var(--radius-md); padding: 13px; font-weight: 800; font-size: 13.5px; cursor: pointer; transition: all 0.15s;">
        Close Kitchen Queue
      </button>
    </div>
  </div>

  <script>
    /*__INITIAL_MENU_DATA__*/

    // ── Safe Storage Polyfill ────────────────────────────────────────────────
    // Tries localStorage first (best persistence), then sessionStorage (tab-scoped),
    // then falls back to a plain in-memory object (Safari Private / restricted envs).
    const _store = (() => {
      try {
        localStorage.setItem('__celestial_test__', '1');
        localStorage.removeItem('__celestial_test__');
        return localStorage;
      } catch (_) {
        try {
          sessionStorage.setItem('__celestial_test__', '1');
          sessionStorage.removeItem('__celestial_test__');
          return sessionStorage;
        } catch (_2) {
          const _mem = {};
          return {
            getItem(k) { return Object.prototype.hasOwnProperty.call(_mem, k) ? _mem[k] : null; },
            setItem(k, v) { _mem[k] = String(v); },
            removeItem(k) { delete _mem[k]; },
            get length() { return Object.keys(_mem).length; },
            key(i) { return Object.keys(_mem)[i] || null; }
          };
        }
      }
    })();
    // ────────────────────────────────────────────────────────────────────────

    let menuData = window.INITIAL_MENU || [];
    let cart = [];
    let currentTable = 'Table 1';
    let activeCategory = 'all';
    let currentSearch = '';
    let selectedItem = null;
    let selectedCustomizations = [];
    let selectedPayment = 'cash';
    let modalItemQty = 1;
    let activeTrackedOrderId = null;
    let activeTrackedOrderNum = null;
    let alarmInterval = null;
    let audioContext = null;
    let custWs = null;
    let pollInterval = null;
    let activeReceiptData = null;
    try {
      const savedReceipt = _store.getItem('activeReceiptData');
      if (savedReceipt) activeReceiptData = JSON.parse(savedReceipt);
    } catch(e) {}

    const categoryLabels = {
      all: 'All Menu Items',
      coffee: 'Coffee & Espresso',
      nonEspresso: 'Non-Coffee Specialties',
      milktea: 'Milk Tea & Boba',
      frappe: 'Ice Blended Frappes',
      cheesecakeSeries: 'Cheesecake Slices',
      streetBites: 'Street Food & Bites',
      pastaDishes: 'Pastas & Noodles',
      sandwich: 'Sandwiches & Snacks'
    };

    let currentOrderType = 'dineIn';
    const urlParams = new URLSearchParams(window.location.search);
    const tableParam = urlParams.get('table');
    if (tableParam) {
      currentTable = tableParam.toLowerCase().startsWith('table') ? tableParam : 'Table ' + tableParam;
    }
    const typeParam = urlParams.get('type') || urlParams.get('orderType');
    if (typeParam === 'takeaway' || typeParam === 'takeout' || typeParam === 'togo') {
      currentOrderType = 'takeaway';
    } else if (typeParam === 'dinein' || typeParam === 'dineIn') {
      currentOrderType = 'dineIn';
    } else {
      try {
        const savedType = _store.getItem('celestial_order_type');
        if (savedType === 'takeaway' || savedType === 'dineIn') {
          currentOrderType = savedType;
        }
      } catch(e) {}
    }

    function updateOrderTypeHeaderPill() {
      const pill = document.getElementById('tablePill');
      if (!pill) return;
      if (currentOrderType === 'takeaway') {
        pill.className = 'table-pill takeout';
        pill.innerHTML = '<span>🥡</span> <span>Takeout / To-Go</span> <span style="font-size:10px;opacity:0.7;">▼</span>';
      } else {
        pill.className = 'table-pill';
        pill.innerHTML = `<span>🍽️</span> <span>\${currentTable}</span> <span style="font-size:10px;opacity:0.7;">▼</span>`;
      }
      _updateTrayDiningUI();
    }

    function _updateTrayDiningUI() {
      const dineInBanner = document.getElementById('trayDineInBanner');
      const takeoutBanner = document.getElementById('trayTakeoutBanner');
      const dineInTableText = document.getElementById('trayDineInTableText');
      const custInput = document.getElementById('custNameInput');

      if (dineInTableText) {
        dineInTableText.innerText = `\${currentTable} (Dine-In at Table)`;
      }

      if (currentOrderType === 'takeaway') {
        if (dineInBanner) dineInBanner.style.display = 'none';
        if (takeoutBanner) takeoutBanner.style.display = 'flex';
        if (custInput) custInput.placeholder = 'Enter name for pickup (e.g. Maria)';
      } else {
        if (dineInBanner) dineInBanner.style.display = 'flex';
        if (takeoutBanner) takeoutBanner.style.display = 'none';
        if (custInput) custInput.placeholder = 'Enter your name (e.g. Maria, John)';
      }
    }

    function setOrderType(type, save = true) {
      currentOrderType = type;
      if (save) {
        try {
          _store.setItem('celestial_order_type', type);
          sessionStorage.setItem('celestial_dining_chosen', 'true');
        } catch(e) {}
      }
      updateOrderTypeHeaderPill();
      _updateDiningModalUI();
    }

    function showDiningOptionModal() {
      _updateDiningModalUI();
      const modal = document.getElementById('diningOptionModal');
      if (modal) modal.style.display = 'flex';
    }

    function selectDiningOption(type) {
      setOrderType(type, true);
    }

    function confirmDiningOptionAndClose() {
      closeModal('diningOptionModal');
      try {
        _store.setItem('celestial_order_type', currentOrderType);
        sessionStorage.setItem('celestial_dining_chosen', 'true');
      } catch(e) {}
      updateOrderTypeHeaderPill();
    }

    function _updateDiningModalUI() {
      const cardDineIn = document.getElementById('cardDineIn');
      const cardTakeout = document.getElementById('cardTakeout');
      const dineInCheck = document.getElementById('dineInCheck');
      const takeoutCheck = document.getElementById('takeoutCheck');
      const welcomeTableEl = document.getElementById('welcomeScannedTable');
      if (welcomeTableEl) welcomeTableEl.innerText = currentTable;

      if (currentOrderType === 'takeaway') {
        if (cardDineIn) cardDineIn.classList.remove('selected');
        if (cardTakeout) cardTakeout.classList.add('selected');
        if (dineInCheck) dineInCheck.style.display = 'none';
        if (takeoutCheck) takeoutCheck.style.display = 'inline';
      } else {
        if (cardDineIn) cardDineIn.classList.add('selected');
        if (cardTakeout) cardTakeout.classList.remove('selected');
        if (dineInCheck) dineInCheck.style.display = 'inline';
        if (takeoutCheck) takeoutCheck.style.display = 'none';
      }
    }

    updateOrderTypeHeaderPill();

    // Vibration Strategy
    let vibrateLoop = null;

    function doVibrate() {
      try {
        if (navigator.vibrate) {
          navigator.vibrate([600, 200, 600, 200, 1000]);
        }
      } catch(e) {}
    }

    function startVibrationLoop() {
      doVibrate();
      if (!vibrateLoop) {
        vibrateLoop = setInterval(doVibrate, 2000);
      }
    }

    function stopVibrationLoop() {
      if (vibrateLoop) {
        clearInterval(vibrateLoop);
        vibrateLoop = null;
      }
      try {
        if (navigator.vibrate) navigator.vibrate(0);
      } catch(e) {}
    }

    let audioUnlocked = false;
    let fallbackChimeDataUri = null;

    function getFallbackChimeUri() {
      if (fallbackChimeDataUri) return fallbackChimeDataUri;
      try {
        const sampleRate = 8000;
        const duration = 0.42;
        const numSamples = Math.floor(sampleRate * duration);
        const headerLength = 44;
        const totalLength = headerLength + numSamples;
        const buffer = new Uint8Array(totalLength);
        buffer[0] = 0x52; buffer[1] = 0x49; buffer[2] = 0x46; buffer[3] = 0x46; // RIFF
        const fileSize = totalLength - 8;
        buffer[4] = fileSize & 0xff; buffer[5] = (fileSize >> 8) & 0xff;
        buffer[6] = (fileSize >> 16) & 0xff; buffer[7] = (fileSize >> 24) & 0xff;
        buffer[8] = 0x57; buffer[9] = 0x41; buffer[10] = 0x56; buffer[11] = 0x45; // WAVE
        buffer[12] = 0x66; buffer[13] = 0x6d; buffer[14] = 0x74; buffer[15] = 0x20; // fmt
        buffer[16] = 16; buffer[17] = 0; buffer[18] = 0; buffer[19] = 0;
        buffer[20] = 1; buffer[21] = 0; // PCM
        buffer[22] = 1; buffer[23] = 0; // Mono
        buffer[24] = sampleRate & 0xff; buffer[25] = (sampleRate >> 8) & 0xff;
        buffer[26] = 0; buffer[27] = 0;
        buffer[28] = sampleRate & 0xff; buffer[29] = (sampleRate >> 8) & 0xff;
        buffer[30] = 0; buffer[31] = 0;
        buffer[32] = 1; buffer[33] = 0;
        buffer[34] = 8; buffer[35] = 0; // 8-bit
        buffer[36] = 0x64; buffer[37] = 0x61; buffer[38] = 0x74; buffer[39] = 0x61; // data
        buffer[40] = numSamples & 0xff; buffer[41] = (numSamples >> 8) & 0xff;
        buffer[42] = 0; buffer[43] = 0;
        for (let i = 0; i < numSamples; i++) {
          const t = i / sampleRate;
          const freq = (t < 0.18) ? 1046.5 : 1318.5;
          const decay = Math.max(0, 1 - (t / duration));
          const val = Math.sin(2 * Math.PI * freq * t) * decay * 0.85;
          buffer[headerLength + i] = Math.floor((val + 1) * 127.5);
        }
        let binary = '';
        for (let i = 0; i < buffer.length; i++) {
          binary += String.fromCharCode(buffer[i]);
        }
        fallbackChimeDataUri = 'data:audio/wav;base64,' + btoa(binary);
      } catch(e) {}
      return fallbackChimeDataUri;
    }

    function initAudio() {
      try {
        if (!audioContext) {
          const AudioContextClass = window.AudioContext || window.webkitAudioContext;
          if (AudioContextClass) audioContext = new AudioContextClass();
        }
        if (audioContext && audioContext.state === 'suspended') {
          return audioContext.resume().then(() => {
            audioUnlocked = true;
            updateSoundStatusBadge(true);
          }).catch(() => {});
        } else if (audioContext && audioContext.state === 'running') {
          audioUnlocked = true;
          updateSoundStatusBadge(true);
        }
      } catch(e) {}
      return Promise.resolve();
    }

    function testOrEnableSound(e) {
      if (e) e.stopPropagation();
      _unlockAudioOnGesture();
      playAlarmSound();
    }

    function updateSoundStatusBadge() {}

    // Auto-unlock AudioContext on any first interaction (silent probe)
    let _audioUnlockDone = false;
    function _unlockAudioOnGesture() {
      if (_audioUnlockDone) return;
      _audioUnlockDone = true;
      try {
        if (!audioContext) {
          const AC = window.AudioContext || window.webkitAudioContext;
          if (AC) audioContext = new AC();
        }
        if (audioContext && audioContext.state === 'suspended') {
          audioContext.resume().catch(() => {});
        }
        // Silent HTML5 probe to satisfy autoplay policy
        const silentUri = getFallbackChimeUri();
        if (silentUri) {
          const probe = new Audio(silentUri);
          probe.volume = 0;
          probe.play().catch(() => {});
        }
        audioUnlocked = true;
      } catch(e) {}
    }
    ['click','touchstart','touchend','keydown','scroll','pointerdown']
      .forEach(ev => document.addEventListener(ev, _unlockAudioOnGesture, { once: false, passive: true }));

    function playAlarmSound() {
      try {
        const doSynth = () => {
          if (!audioContext) return;
          try {
            const now = audioContext.currentTime;
            const notes = [880, 1174.66, 1760, 1174.66, 1760, 2093];
            notes.forEach((freq, i) => {
              const osc = audioContext.createOscillator();
              const gain = audioContext.createGain();
              osc.type = 'sawtooth';
              osc.connect(gain);
              gain.connect(audioContext.destination);
              osc.frequency.setValueAtTime(freq, now + i * 0.12);
              gain.gain.setValueAtTime(0.85, now + i * 0.12);
              gain.gain.exponentialRampToValueAtTime(0.01, now + i * 0.12 + 0.38);
              osc.start(now + i * 0.12);
              osc.stop(now + i * 0.12 + 0.38);
            });
          } catch(_) {}
        };

        // Always try to resume suspended context before playing
        if (!audioContext) initAudio();
        const doPlay = () => {
          if (audioContext && audioContext.state === 'suspended') {
            audioContext.resume().then(doSynth).catch(() => {});
          } else if (audioContext) {
            doSynth();
          }
          // HTML5 Audio fallback — plays regardless of AudioContext state
          try {
            const uri = getFallbackChimeUri();
            if (uri) {
              const a = new Audio(uri);
              a.volume = 1.0;
              a.play().catch(() => {});
            }
          } catch(_) {}
        };
        doPlay();
      } catch (e) {
        console.warn('Audio play err:', e);
      }
      doVibrate();
    }

    function startRepeatingAlarm() {
      const orderKey = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '1';
      if (_store.getItem('alarmDismissed_' + orderKey) === 'true') {
        return;
      }
      if (prevTrackStatus === 'completed' || _store.getItem('orderCompleted') === 'true') {
        return;
      }

      document.body.classList.add('alarm-active');
      const numEl = document.getElementById('alarmModalOrderNum');
      const tableEl = document.getElementById('alarmModalTableInfo');
      if (numEl) numEl.innerText = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '#1';
      if (tableEl) tableEl.innerText = `\${currentTable} • Dine-In`;

      const modal = document.getElementById('readyAlarmModal');
      if (modal) modal.style.display = 'flex';

      playAlarmSound();
      startVibrationLoop();

      try {
        if ('wakeLock' in navigator) {
          navigator.wakeLock.request('screen').catch(e => {});
        }
      } catch(e) {}

      try {
        if ('Notification' in window && Notification.permission === 'granted') {
          new Notification('ORDER READY ' + (activeTrackedOrderNum || '') + '!', {
            body: 'Your drink is ready! Please come to the pickup counter.',
            icon: '/logo.png',
            vibrate: [600, 200, 600, 200, 1000],
            requireInteraction: true
          });
        }
      } catch(e) {}

      if (!alarmInterval) {
        alarmInterval = setInterval(playAlarmSound, 2200);
      }

      // AI voice announcement in Filipino
      speakReadyAnnouncement();
    }

    function speakReadyAnnouncement() {
      try {
        if (!('speechSynthesis' in window)) return;
        window.speechSynthesis.cancel(); // clear any queued speech
        const utter = new SpeechSynthesisUtterance(
          'Ang iyong order ay pwede na i-claim! Pakiharapin na ang counter para kunin ang inyong order.'
        );
        // Try to find a Filipino / Tagalog voice, fall back to any available
        const trySpeak = () => {
          const voices = window.speechSynthesis.getVoices();
          const fil = voices.find(v =>
            v.lang.startsWith('fil') || v.lang.startsWith('tl') ||
            v.name.toLowerCase().includes('filipino') ||
            v.name.toLowerCase().includes('tagalog')
          );
          if (fil) {
            utter.voice = fil;
            utter.lang = fil.lang;
          } else {
            utter.lang = 'fil-PH'; // hint to browser even without exact voice match
          }
          utter.rate  = 0.88;  // slightly slower for clarity
          utter.pitch = 1.05;
          utter.volume = 1.0;
          window.speechSynthesis.speak(utter);
        };
        if (window.speechSynthesis.getVoices().length > 0) {
          trySpeak();
        } else {
          // Voices may not be loaded yet on first call
          window.speechSynthesis.onvoiceschanged = () => { trySpeak(); window.speechSynthesis.onvoiceschanged = null; };
        }
      } catch(e) {}
    }

    function stopAlarm() {
      const orderKey = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '1';
      try {
        _store.setItem('alarmDismissed_' + orderKey, 'true');
      } catch(e) {}

      if (alarmInterval) {
        clearInterval(alarmInterval);
        alarmInterval = null;
      }
      stopVibrationLoop();
      try { window.speechSynthesis.cancel(); } catch(e) {}
      document.body.classList.remove('alarm-active');
      const modal = document.getElementById('readyAlarmModal');
      if (modal) modal.style.display = 'none';
      const box = document.getElementById('readyAlarmBox');
      if (box) box.style.display = 'none';

      const orderAnotherBtn = document.getElementById('btnOrderAnotherItem');
      if (orderAnotherBtn) {
        orderAnotherBtn.style.display = 'inline-flex';
        orderAnotherBtn.innerText = '+ Order More / New Order';
      }
    }


    function connectCustomerWs() {
      const loc = window.location;
      const wsUrl = (loc.protocol === 'https:' ? 'wss://' : 'ws://') + loc.host + '/ws';
      try {
        custWs = new WebSocket(wsUrl);
        custWs.onmessage = (e) => {
          try {
            const data = JSON.parse(e.data);
            if (data.type === 'ORDER_STATUS_UPDATE') {
              const cleanId = (activeTrackedOrderId || '').toLowerCase();
              const cleanNum = (activeTrackedOrderNum || '').toLowerCase();
              const msgId = (data.orderId || '').toLowerCase();
              const msgNum = (data.orderNumber || '').toLowerCase();
              const cleanMsgNum = msgNum.replace('#', '').trim();
              const cleanCurrentNum = cleanNum.replace('#', '').trim();

              if (msgId === cleanId || msgNum === cleanNum || (cleanMsgNum && cleanMsgNum === cleanCurrentNum)) {
                if (data.status === 'cancelled') {
                  if (pollInterval) { clearInterval(pollInterval); pollInterval = null; }
                  showSuccessModal({
                    title: 'Order Cancelled',
                    message: 'Your order was cancelled by the cashier. You can now place a new order.',
                    buttonText: 'Return to Menu',
                    onDismiss: () => newOrder(true)
                  });
                  return;
                }
                updateTrackerUI(data.status);
              }
            } else if (data.type === 'SYNC_ORDERS') {
              if (activeTrackedOrderId || activeTrackedOrderNum) {
                const cleanId = (activeTrackedOrderId || '').toLowerCase();
                const cleanNum = (activeTrackedOrderNum || '').toLowerCase();
                const found = (data.orders || []).find(o => {
                  const oid = (o.id || '').toLowerCase();
                  const onum = (o.orderNumber || '').toLowerCase();
                  return oid === cleanId || onum === cleanNum || onum === cleanId;
                });
                if (found && found.status) {
                  updateTrackerUI(found.status);
                } else if (!found && prevTrackStatus && prevTrackStatus !== 'completed' && prevTrackStatus !== 'cancelled') {
                  // Order is no longer in active KDS queue (completed or cancelled by barista) -> check server status
                  checkOrderStatus();
                }
              }
              // Also update live queue from the broadcast order list
              const orders = data.orders || [];
              const formatChip = (o) => {
                if (!o) return '';
                const num = o.orderNumber || '';
                let tbl = (o.tableNumber || '').trim().replace(/^T+able/i, 'Table');
                const isTakeout = o.orderType === 'takeaway' || o.orderType === 'delivery' || tbl.toLowerCase().includes('take');
                const tablePart = isTakeout ? ' · Takeout' : (tbl ? (tbl.toLowerCase().startsWith('table') ? ' · ' + tbl : ' · Table ' + tbl) : '');
                return `\${num}\${tablePart}`;
              };
              const nowPreparing = orders.filter(o => ['preparing','brewing','kitchen'].includes((o.status||'').toLowerCase())).map(formatChip);
              const inQueue = orders.filter(o => ['confirmed','inqueue','queue'].includes((o.status||'').toLowerCase())).map(formatChip);
              const nowReady = orders.filter(o => (o.status||'').toLowerCase() === 'ready').map(formatChip);
              renderLiveQueue(nowPreparing, inQueue, nowReady);
            }
          } catch(err) {}
        };
        custWs.onclose = () => setTimeout(connectCustomerWs, 3000);
      } catch(err) {
        setTimeout(connectCustomerWs, 3000);
      }
    }

    function handleSearch(val) {
      currentSearch = (val || '').trim().toLowerCase();
      document.getElementById('clearSearchBtn').style.display = currentSearch ? 'flex' : 'none';
      renderMenu();
    }

    function clearSearch() {
      document.getElementById('searchInput').value = '';
      currentSearch = '';
      document.getElementById('clearSearchBtn').style.display = 'none';
      renderMenu();
    }

    function filterCategory(cat, btn) {
      activeCategory = cat;
      document.querySelectorAll('.cat-tab').forEach(b => b.classList.remove('active'));
      if (btn) btn.classList.add('active');
      renderMenu();
    }

    function renderMenu() {
      const grid = document.getElementById('menuGrid');
      let filtered = menuData;

      if (activeCategory !== 'all') {
        filtered = filtered.filter(m => m.category === activeCategory);
      }

      if (currentSearch) {
        filtered = filtered.filter(m => {
          const name = (m.name || '').toLowerCase();
          const desc = (m.description || '').toLowerCase();
          const cat = (m.categoryLabel || m.category || '').toLowerCase();
          const tags = (m.tags || []).join(' ').toLowerCase();
          return name.includes(currentSearch) || desc.includes(currentSearch) || cat.includes(currentSearch) || tags.includes(currentSearch);
        });
      }

      const label = currentSearch ? `Search Results for "\${currentSearch}"` : (categoryLabels[activeCategory] || 'Menu Items');
      document.getElementById('sectionTitleLabel').innerText = label;
      document.getElementById('menuCountBadge').innerText = `\${filtered.length} item\${filtered.length !== 1 ? 's' : ''}`;

      if (filtered.length === 0) {
        grid.innerHTML = `
          <div class="empty-state">
            <div class="empty-icon">✕</div>
            <h3>No matching items found</h3>
            <p style="font-size: 12px; margin-top: 4px;">Try searching for another coffee or dessert.</p>
          </div>
        `;
        return;
      }

      grid.innerHTML = filtered.map(item => {
        const isKitchen = (item.category === 'streetBites' || item.category === 'pastaDishes' || item.category === 'sandwich') ||
          ['wings', 'buffalo', 'fries', 'stick', 'lumpia', 'shanghai', 'pasta', 'carbonara', 'aglio', 'sandwich', 'toast'].some(k => (item.name || '').toLowerCase().includes(k));
        const kitchenTag = isKitchen ? '<span style="background: rgba(255,87,34,0.2); border: 1px solid rgba(255,87,34,0.5); color: #FF7043; font-size: 9.5px; font-weight: 800; padding: 2px 6px; border-radius: 5px; margin-left: 5px;">Kitchen Cooked</span>' : '';

        const imgUrl = item.imageBase64 ? ('data:image/png;base64,' + item.imageBase64) : (item.imageUrl || (item.imagePath ? `/api/item-image?id=\${item.id}` : ''));
        const imageCardHtml = imgUrl ? `
          <div class="item-img-container">
            <img src="\${imgUrl}" alt="\${item.name}" onerror="this.parentElement.innerHTML='<div class=\\'item-img-placeholder\\'><span style=\\'font-family:Cinzel;font-weight:bold;font-size:24px;color:#D4AF37;\\'>CELESTIAL</span></div>'">
          </div>
        ` : `
          <div class="item-img-container">
            <div class="item-img-placeholder">
              <span style="font-family:'Cinzel',serif;font-weight:800;font-size:24px;letter-spacing:2px;color:var(--gold-light);">C</span>
            </div>
          </div>
        `;

        return `
          <div class="item-card" onclick="openCustomModal('\${item.id}')">
            \${imageCardHtml}
            <div>
              <div class="item-card-name">\${item.name}</div>
              <div style="display: flex; align-items: center; flex-wrap: wrap; gap: 4px; margin-top: 4px;">
                <span class="item-cat-badge">\${item.categoryLabel || item.category}</span>
                \${kitchenTag}
              </div>
            </div>
            <div class="item-card-bottom">
              <div class="item-card-bottom-row">
                <span class="item-price">₱\${Math.round(item.price)}</span>
              </div>
              <button class="btn-add-pill" onclick="event.stopPropagation(); openCustomModal('\${item.id}')">
                Add to Tray
              </button>
            </div>
          </div>
        `;
      }).join('');
    }

    function openCustomModal(itemId) {
      initAudio();
      selectedItem = menuData.find(m => m.id === itemId);
      if (!selectedItem) return;

      modalItemQty = 1;
      document.getElementById('modalQtyDisplay').innerText = modalItemQty;
      selectedCustomizations = [];

      // Item Media / Photo Thumbnail
      const imgUrl = selectedItem.imageBase64 ? ('data:image/png;base64,' + selectedItem.imageBase64) : (selectedItem.imageUrl || (selectedItem.imagePath ? `/api/item-image?id=\${selectedItem.id}` : ''));
      const thumbImg = document.getElementById('modalThumbImg');
      const thumbIcon = document.getElementById('modalThumbIcon');
      if (imgUrl) {
        thumbImg.src = imgUrl;
        thumbImg.style.display = 'block';
        thumbIcon.style.display = 'none';
      } else {
        thumbImg.style.display = 'none';
        thumbIcon.innerText = selectedItem.icon || '☕';
        thumbIcon.style.display = 'block';
      }

      document.getElementById('modalItemName').innerText = selectedItem.name;
      document.getElementById('modalBasePriceBadge').innerText = `₱\${Math.round(selectedItem.price)}`;
      document.getElementById('modalItemDesc').innerText = selectedItem.description || '';


      // Tags Row
      const tagsRow = document.getElementById('modalTagsRow');
      const catLabel = selectedItem.categoryLabel || selectedItem.category;
      let tagsHtml = `<span class="cust-dlg-tag">\${selectedItem.icon || '☕'} \${catLabel}</span>`;
      if (selectedItem.tags && Array.isArray(selectedItem.tags)) {
        selectedItem.tags.forEach(t => {
          if (t && t !== 'All') {
            tagsHtml += `<span class="cust-dlg-tag gold">\${t}</span>`;
          }
        });
      }
      tagsRow.innerHTML = tagsHtml;

      // Customization Groups
      const container = document.getElementById('customGroupContainer');
      const groups = selectedItem.customizations || [];

      container.innerHTML = groups.map((g, gIdx) => {
        const titleLower = (g.groupTitle || '').toLowerCase();
        const idLower = (g.id || '').toLowerCase();
        const isTemp = titleLower.includes('temp') || idLower.includes('temp');
        const isSweet = titleLower.includes('sweet') || idLower.includes('sweet') || titleLower.includes('sugar');
        const isMulti = g.isMultiSelect === true;
        const isRequired = g.isRequired !== false && !isMulti;

        // Group Icon
        let gIcon = '⚙️';
        if (isTemp) gIcon = '🌡️';
        else if (isSweet) gIcon = '💧';
        else if (isMulti || titleLower.includes('addon') || titleLower.includes('extra') || titleLower.includes('sinker')) gIcon = '✨';
        else if (titleLower.includes('size') || titleLower.includes('cup')) gIcon = '☕';
        else if (titleLower.includes('prep') || titleLower.includes('cook')) gIcon = '🍽️';

        const badgeHtml = isRequired
          ? `<span class="cust-badge-required">REQUIRED</span>`
          : `<span class="cust-badge-optional">\${isMulti ? 'OPTIONAL' : 'CHOOSE ONE'}</span>`;

        let optionsHtml = '';

        if (isTemp && g.options.length === 2) {
          // Temperature specialized 2-card layout (Hot vs Iced)
          optionsHtml = `
            <div class="cust-opt-grid-2col">
              \${g.options.map((opt, oIdx) => {
                const optLower = opt.name.toLowerCase();
                const isHot = optLower.includes('hot');
                const isIced = optLower.includes('ice');
                const isDefault = oIdx === (g.defaultIndex || 0);
                if (isDefault) {
                  selectedCustomizations.push({
                    groupTitle: g.groupTitle,
                    optionName: opt.name,
                    extraPrice: opt.priceAdjustment || 0,
                    isMulti: false
                  });
                }
                const subLabel = isHot ? 'Steamed & Fresh' : (isIced ? 'Chilled with Ice' : '');
                const iconSymbol = isHot ? '🔥' : '❄️';
                const iconClass = isHot ? 'hot' : 'iced';
                return `
                  <div class="cust-opt-card cust-temp-card \${isDefault ? 'selected' : ''}" onclick="toggleCustomOption(\${gIdx}, \${oIdx}, this)">
                    <div class="cust-temp-icon-box \${iconClass}">\${iconSymbol}</div>
                    <div class="cust-opt-text-col">
                      <div class="cust-opt-label">\${opt.name}</div>
                      \${subLabel ? `<div class="cust-opt-sublabel">\${subLabel}</div>` : ''}
                    </div>
                    <div class="cust-radio-circle"></div>
                  </div>
                `;
              }).join('')}
            </div>
          `;
        } else if (isMulti) {
          // Multi-Select Add-ons with checkbox + price badge (+₱25)
          optionsHtml = `
            <div class="cust-opt-grid-2col">
              \${g.options.map((opt, oIdx) => {
                const extraPrice = opt.priceAdjustment || 0;
                const priceBadge = extraPrice > 0 ? `<span class="cust-price-pill">+₱\${Math.round(extraPrice)}</span>` : '';
                return `
                  <div class="cust-opt-card" onclick="toggleCustomOption(\${gIdx}, \${oIdx}, this)">
                    <div class="cust-check-box">+</div>
                    <div class="cust-opt-text-col">
                      <div class="cust-opt-label">\${opt.name}</div>
                    </div>
                    \${priceBadge}
                  </div>
                `;
              }).join('')}
            </div>
          `;
        } else {
          // Sweetness / Cup Size / Standard Single-Select (2-Column Radio Cards)
          optionsHtml = `
            <div class="cust-opt-grid-2col">
              \${g.options.map((opt, oIdx) => {
                const isDefault = oIdx === (g.defaultIndex || 0);
                if (isDefault) {
                  selectedCustomizations.push({
                    groupTitle: g.groupTitle,
                    optionName: opt.name,
                    extraPrice: opt.priceAdjustment || 0,
                    isMulti: false
                  });
                }
                const extraPrice = opt.priceAdjustment || 0;
                const priceBadge = extraPrice > 0 ? `<span class="cust-price-pill">+₱\${Math.round(extraPrice)}</span>` : '';
                return `
                  <div class="cust-opt-card \${isDefault ? 'selected' : ''}" onclick="toggleCustomOption(\${gIdx}, \${oIdx}, this)">
                    <div class="cust-radio-circle"></div>
                    <div class="cust-opt-text-col">
                      <div class="cust-opt-label">\${opt.name}</div>
                    </div>
                    \${priceBadge}
                  </div>
                `;
              }).join('')}
            </div>
          `;
        }

        return `
          <div>
            <div class="cust-group-header">
              <div class="cust-group-icon">\${gIcon}</div>
              <div class="cust-group-title">\${g.groupTitle}</div>
              \${badgeHtml}
            </div>
            \${optionsHtml}
          </div>
        `;
      }).join('');

      updateModalAddButtonPrice();
      document.getElementById('customModal').style.display = 'flex';
    }

    function changeModalQty(delta) {
      modalItemQty = Math.max(1, modalItemQty + delta);
      document.getElementById('modalQtyDisplay').innerText = modalItemQty;
      updateModalAddButtonPrice();
    }

    function toggleCustomOption(gIdx, oIdx, el) {
      const group = selectedItem.customizations[gIdx];
      const opt = group.options[oIdx];

      if (!group.isMultiSelect) {
        el.parentElement.querySelectorAll('.cust-opt-card').forEach(c => c.classList.remove('selected'));
        el.classList.add('selected');
        selectedCustomizations = selectedCustomizations.filter(c => c.groupTitle !== group.groupTitle);
        selectedCustomizations.push({
          groupTitle: group.groupTitle,
          optionName: opt.name,
          extraPrice: opt.priceAdjustment || 0,
          isMulti: false
        });
      } else {
        el.classList.toggle('selected');
        const checkEl = el.querySelector('.cust-check-box');
        if (el.classList.contains('selected')) {
          if (checkEl) checkEl.innerText = '✓';
          selectedCustomizations.push({
            groupTitle: group.groupTitle,
            optionName: opt.name,
            extraPrice: opt.priceAdjustment || 0,
            isMulti: true
          });
        } else {
          if (checkEl) checkEl.innerText = '+';
          selectedCustomizations = selectedCustomizations.filter(c => !(c.groupTitle === group.groupTitle && c.optionName === opt.name));
        }
      }
      updateModalAddButtonPrice();
    }

    function updateModalAddButtonPrice() {
      const extraTotal = selectedCustomizations.reduce((sum, c) => sum + (c.extraPrice || 0), 0);
      const unitTotal = selectedItem.price + extraTotal;
      const grandTotal = unitTotal * modalItemQty;
      const btnText = document.getElementById('modalAddBtnText');
      if (btnText) {
        btnText.innerText = `Add to Order • ₱\${Math.round(grandTotal)}`;
      }
    }

    function confirmAddToCart() {
      const btn = document.getElementById('btnAddItemToCart');
      const btnText = document.getElementById('modalAddBtnText');
      if (btn) {
        if (btnText) btnText.innerText = 'Adding to Order...';
        btn.disabled = true;
      }
      setTimeout(() => {
        const notes = '';
        const extraTotal = selectedCustomizations.reduce((sum, c) => sum + (c.extraPrice || 0), 0);

        cart.push({
          id: selectedItem.id,
          name: selectedItem.name,
          price: selectedItem.price,
          extraPrice: extraTotal,
          unitPrice: selectedItem.price + extraTotal,
          quantity: modalItemQty,
          customizations: [...selectedCustomizations],
          notes: notes
        });

        if (btn) btn.disabled = false;
        closeModal('customModal');
        updateCartBar();
      }, 160);
    }

    function updateCartBar() {
      const count = cart.reduce((sum, i) => sum + i.quantity, 0);
      const total = cart.reduce((sum, i) => sum + (i.unitPrice * i.quantity), 0);

      if (count > 0) {
        document.getElementById('cartBar').style.display = 'flex';
        document.getElementById('cartCountText').innerText = `\${count} item\${count > 1 ? 's' : ''}`;
        document.getElementById('cartTotalText').innerText = `₱\${Math.round(total)}`;
        // Persist cart so it survives an accidental page refresh
        try { _store.setItem('pendingCart', JSON.stringify(cart)); } catch(_) {}
      } else {
        document.getElementById('cartBar').style.display = 'none';
        try { _store.removeItem('pendingCart'); } catch(_) {}
      }
    }

    function openTrayModal() {
      const btn = document.getElementById('btnSendOrder');
      if (btn) {
        btn.innerText = 'Submit Order to Cashier';
        btn.disabled = false;
      }

      const list = document.getElementById('trayItemsList');
      const total = cart.reduce((sum, i) => sum + (i.unitPrice * i.quantity), 0);

      list.innerHTML = cart.map((item, idx) => {
        const customsText = item.customizations.map(c => c.optionName).join(', ');
        const isKitchen = (item.category === 'streetBites' || item.category === 'pastaDishes' || item.category === 'sandwich') ||
          ['wings', 'buffalo', 'fries', 'stick', 'lumpia', 'shanghai', 'pasta', 'carbonara', 'aglio', 'sandwich', 'toast'].some(k => (item.name || '').toLowerCase().includes(k));
        const kitchenBadge = isKitchen ? '<span style="background:rgba(255,87,34,0.2);border:1px solid rgba(255,87,34,0.55);color:#FF7043;font-size:10px;font-weight:800;padding:1px 5px;border-radius:4px;margin-left:5px;">KITCHEN</span>' : '';

        return `
          <div style="background: var(--bg-card); border-radius: var(--radius-md); border: 1px solid var(--border-subtle); padding: 12px; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center;">
            <div style="flex: 1; padding-right: 8px;">
              <div style="font-weight: 700; font-size: 14px; color: var(--text-light); display: flex; align-items: center;">\${item.name}\${kitchenBadge}</div>
              \${customsText ? `<div style="font-size: 11.5px; color: var(--gold-light); margin-top: 2px;">› \${customsText}</div>` : ''}
              \${item.notes ? `<div style="font-size: 11px; color: var(--rose); margin-top: 2px;">Note: "\${item.notes}"</div>` : ''}
              <div style="font-weight: 800; font-size: 14.5px; color: var(--gold-light); margin-top: 4px;">₱\${Math.round(item.unitPrice * item.quantity)}</div>
            </div>
            <div style="display: flex; align-items: center; gap: 8px;">
              <div style="display: flex; align-items: center; background: rgba(255,255,255,0.06); border-radius: 8px; border: 1px solid rgba(255,255,255,0.1);">
                <button onclick="changeTrayItemQty(\${idx}, -1)" style="background: none; border: none; color: var(--text-light); width: 28px; height: 28px; font-weight: bold; cursor: pointer;">−</button>
                <span style="font-size: 13px; font-weight: 800; color: var(--gold-light); min-width: 20px; text-align: center;">\${item.quantity}</span>
                <button onclick="changeTrayItemQty(\${idx}, 1)" style="background: none; border: none; color: var(--text-light); width: 28px; height: 28px; font-weight: bold; cursor: pointer;">+</button>
              </div>
              <button onclick="removeFromCart(\${idx})" style="background: rgba(231,29,54,0.15); border: 1px solid rgba(231,29,54,0.4); color: var(--rose); border-radius: 8px; width: 28px; height: 28px; font-weight: bold; cursor: pointer; display: flex; align-items: center; justify-content: center;">✕</button>
            </div>
          </div>
        `;
      }).join('');

      document.getElementById('trayTotalAmount').innerText = `₱\${Math.round(total)}`;
      document.getElementById('trayModal').style.display = 'flex';
    }

    function changeTrayItemQty(idx, delta) {
      if (cart[idx]) {
        cart[idx].quantity += delta;
        if (cart[idx].quantity <= 0) {
          cart.splice(idx, 1);
        }
        updateCartBar();
        if (cart.length === 0) {
          closeModal('trayModal');
        } else {
          openTrayModal();
        }
      }
    }

    function removeFromCart(idx) {
      cart.splice(idx, 1);
      updateCartBar();
      if (cart.length === 0) {
        closeModal('trayModal');
      } else {
        openTrayModal();
      }
    }

    function selectPayment(method, el) {
      selectedPayment = method;
      el.parentElement.querySelectorAll('.opt-chip').forEach(c => c.classList.remove('selected'));
      el.classList.add('selected');
    }

    let confirmModalCallback = null;
    function showConfirmModal(opts) {
      const options = opts || {};
      const modal = document.getElementById('confirmModal');
      const titleEl = document.getElementById('confirmModalTitle');
      const msgEl = document.getElementById('confirmModalMsg');
      const cancelBtn = document.getElementById('btnConfirmCancel');
      const actionBtn = document.getElementById('btnConfirmAction');

      if (titleEl) titleEl.innerText = options.title || 'Please Confirm';
      if (msgEl) msgEl.innerText = options.message || 'Are you sure you want to proceed?';
      if (cancelBtn) cancelBtn.innerText = options.cancelText || 'Cancel';
      if (actionBtn) {
        actionBtn.innerText = options.confirmText || 'Confirm';
        if (options.isDestructive) {
          actionBtn.style.background = 'linear-gradient(135deg, var(--rose) 0%, #B82535 100%)';
          actionBtn.style.color = '#FFFFFF';
        } else {
          actionBtn.style.background = 'linear-gradient(135deg, var(--gold-primary) 0%, #B89025 100%)';
          actionBtn.style.color = '#0D0A0F';
        }
      }

      confirmModalCallback = options.onConfirm;
      if (actionBtn) {
        actionBtn.onclick = function() {
          closeModal('confirmModal');
          if (typeof confirmModalCallback === 'function') {
            confirmModalCallback();
          }
        };
      }

      if (modal) modal.style.display = 'flex';
    }

    let successModalCallback = null;
    function showSuccessModal(opts) {
      const options = opts || {};
      const modal = document.getElementById('successModal');
      const titleEl = document.getElementById('successModalTitle');
      const msgEl = document.getElementById('successModalMsg');
      const btn = document.getElementById('btnSuccessDismiss');

      if (titleEl) titleEl.innerText = options.title || 'Success!';
      if (msgEl) msgEl.innerText = options.message || 'Action completed successfully.';
      if (btn) btn.innerText = options.buttonText || 'Continue';

      successModalCallback = options.onDismiss;
      if (btn) {
        btn.onclick = function() {
          closeModal('successModal');
          if (typeof successModalCallback === 'function') {
            successModalCallback();
          }
        };
      }

      if (modal) modal.style.display = 'flex';
    }

    function closeModal(modalId) {
      const el = document.getElementById(modalId);
      if (el) el.style.display = 'none';
    }

    async function submitOrderToKitchen() {
      if (!cart || cart.length === 0) {
        showSuccessModal({
          title: 'Your Tray is Empty',
          message: 'Please choose some delicious items and add them to your tray first.',
          buttonText: 'Browse Menu'
        });
        return;
      }

      // Block submission only if user is actively on tracker view
      const trackerEl = document.getElementById('trackerView');
      if (trackerEl && trackerEl.style.display === 'block' && activeTrackedOrderId && prevTrackStatus !== 'completed' && prevTrackStatus !== 'cancelled') {
        showSuccessModal({
          title: 'Active Order In Progress',
          message: 'You already have an active order (' + (activeTrackedOrderNum || '') + '). You cannot order again until your current order is completed or cancelled.',
          buttonText: 'View My Order',
          onDismiss: () => {
            closeModal('trayModal');
            document.getElementById('controlsWrapper').style.display = 'none';
            document.getElementById('menuView').style.display = 'none';
            document.getElementById('cartBar').style.display = 'none';
            document.getElementById('trackerView').style.display = 'block';
            window.scrollTo({ top: 0, behavior: 'smooth' });
          }
        });
        return;
      }
      initAudio();

      const btn = document.getElementById('btnSendOrder');
      if (btn) {
        btn.innerHTML = '<span class="btn-spinner"></span><span>Submitting to Cashier...</span>';
        btn.disabled = true;
      }

      try {
        if ('Notification' in window && Notification.permission === 'default') {
          Notification.requestPermission();
        }
        if ('wakeLock' in navigator) {
          navigator.wakeLock.request('screen').catch(e => {});
        }
      } catch(e) {}

      let submitTimeout = null;
      try {
        const custNameEl = document.getElementById('custNameInput');
        const defaultGuest = currentOrderType === 'takeaway' ? 'Guest (Takeout)' : `Guest (\${currentTable})`;
        const custName = (custNameEl && custNameEl.value.trim()) ? custNameEl.value.trim() : defaultGuest;

        const payload = {
          orderType: currentOrderType,
          tableNumber: currentOrderType === 'takeaway' ? 'Takeout' : currentTable,
          customerName: custName,
          paymentMethod: selectedPayment || 'cash',
          items: cart.map(i => ({
            id: i.id,
            quantity: i.quantity || 1,
            notes: i.notes || '',
            customizations: (i.customizations || []).map(c => ({
              groupTitle: c.groupTitle || '',
              optionName: c.optionName || '',
              extraPrice: c.extraPrice || 0
            }))
          }))
        };

        const controller = new AbortController();
        submitTimeout = setTimeout(() => controller.abort(), 15000);

        let res = null;
        try {
          res = await fetch('/api/customer/order', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
            signal: controller.signal
          });
        } catch (fetchErr) {
          if (submitTimeout) clearTimeout(submitTimeout);
          closeModal('trayModal');
          showSuccessModal({
            title: 'Connection Notice',
            message: 'Could not connect to Cafe server or request timed out. Please ensure you are connected to the Cafe hotspot and try again.',
            buttonText: 'OK'
          });
          return;
        }
        if (submitTimeout) clearTimeout(submitTimeout);

        let data = null;
        try {
          data = await res.json();
        } catch (_) {}

        if (data && data.success && data.orderId) {
          const submittedItems = cart.slice();
          cart = [];
          try { _store.removeItem('pendingCart'); } catch(_) {}
          updateCartBar();
          closeModal('trayModal');
          try {
            startOrderTracking(data.orderId, data.orderNumber, data.totalAmount, (data.items && data.items.length > 0) ? data.items : submittedItems);
          } catch(trackErr) {
            console.error('Tracking UI render notice:', trackErr);
          }
        } else {
          closeModal('trayModal');
          if (data && data.existingOrderId) {
            showSuccessModal({
              title: 'Order In Preparation',
              message: data.error || 'This table already has an order in preparation.',
              buttonText: 'View Active Order',
              onDismiss: () => {
                startOrderTracking(data.existingOrderId, data.existingOrderNumber || '#1', 0, [], data.status || 'pending');
              }
            });
            return;
          }
          showSuccessModal({
            title: 'Order Notice',
            message: (data && data.error) ? data.error : 'Could not submit order. Please try again.',
            buttonText: 'OK'
          });
        }
      } catch (err) {
        if (submitTimeout) clearTimeout(submitTimeout);
        closeModal('trayModal');
        showSuccessModal({
          title: 'Order Notice',
          message: 'An unexpected issue occurred while preparing your ticket. Please try again.',
          buttonText: 'OK'
        });
      } finally {
        if (btn) {
          btn.innerHTML = 'Submit Order to Cashier';
          btn.disabled = false;
        }
      }
    }

    let activeTrackedItems = [];

    function startOrderTracking(orderId, orderNumber, total, items, initialStatus) {
      activeTrackedOrderId = orderId;
      activeTrackedOrderNum = orderNumber;
      const statusToUse = initialStatus || 'pending';
      prevTrackStatus = statusToUse;
      if (items && Array.isArray(items)) {
        activeTrackedItems = items;
      }

      try {
        _store.setItem('activeOrderId', orderId);
        _store.setItem('activeOrderNum', orderNumber);
        _store.setItem('activeOrderTotal', total);
        _store.setItem('activeTableNumber', currentTable);
        if (items && items.length > 0) {
          _store.setItem('activeOrderItems', JSON.stringify(items));
        }
        _store.removeItem('pendingCart');
        if (orderNumber) _store.removeItem('alarmDismissed_' + orderNumber);
        if (orderId) _store.removeItem('alarmDismissed_' + orderId);
        _store.removeItem('alarmDismissed_#1');
      } catch(e) {}

      document.getElementById('controlsWrapper').style.display = 'none';
      document.getElementById('menuView').style.display = 'none';
      document.getElementById('cartBar').style.display = 'none';
      document.getElementById('trackerView').style.display = 'block';

      document.getElementById('trackOrderNum').innerText = orderNumber;
      const promptNum = document.getElementById('promptOrderNum');
      if (promptNum) promptNum.innerText = orderNumber;
      document.getElementById('trackTableInfo').innerText = `\${currentTable} • Dine-In`;
      document.getElementById('trackTotal').innerText = `Total: ₱\${Math.round(total)}`;

      const cancelBtn = document.getElementById('btnCancelOrder');
      if (cancelBtn) {
        cancelBtn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg><span>Cancel Order</span>';
        cancelBtn.disabled = false;
      }

      renderTrackedItemsList(activeTrackedItems, total);
      updateTrackerUI(statusToUse);

      if (pollInterval) clearInterval(pollInterval);
      if (statusToUse !== 'completed' && statusToUse !== 'cancelled') {
        checkOrderStatus();
        pollInterval = setInterval(checkOrderStatus, 1500);
      }
    }

    let prevTrackStatus = '';
    let slowFetchTimer = null;

    function checkOrderStatus() {
      if (!activeTrackedOrderId && !activeTrackedOrderNum) return;
      const qId = activeTrackedOrderId || activeTrackedOrderNum;

      if (slowFetchTimer) clearTimeout(slowFetchTimer);
      slowFetchTimer = setTimeout(() => {
        const slowBanner = document.getElementById('slowConnectionBanner');
        if (slowBanner && prevTrackStatus !== 'completed') {
          slowBanner.style.display = 'block';
        }
      }, 1200);

      fetch(`/api/order-status?orderId=\${encodeURIComponent(qId)}`)
        .then(r => r.json())
        .then(data => {
          if (slowFetchTimer) clearTimeout(slowFetchTimer);
          const slowBanner = document.getElementById('slowConnectionBanner');
          if (slowBanner) slowBanner.style.display = 'none';
          const banner = document.getElementById('wifiWarningBanner');
          if (banner) banner.style.display = 'none';

          if (!activeTrackedOrderId && !activeTrackedOrderNum) return;

          if (!data) return;

          // Order not found in cafe records (cleared, deleted or invalid)
          if (data.status === 'not_found' || data.success === false || (data.error && data.error.toLowerCase().includes('not found'))) {
            if (pollInterval) { clearInterval(pollInterval); pollInterval = null; }
            showSuccessModal({
              title: 'Order Notice',
              message: 'Order not found in cafe records. Please place a new order.',
              buttonText: 'OK',
              onDismiss: () => newOrder(true)
            });
            return;
          }

          // Order explicitly cancelled by cashier
          if (data.status === 'cancelled') {
            if (pollInterval) { clearInterval(pollInterval); pollInterval = null; }
            showSuccessModal({
              title: 'Order Cancelled',
              message: 'Your order was cancelled by the cashier. You can now place a new order.',
              buttonText: 'Return to Menu',
              onDismiss: () => newOrder(true)
            });
            return;
          }

          if (data && data.success) {
            activeReceiptData = data;
            try { _store.setItem('activeReceiptData', JSON.stringify(data)); } catch(e) {}
          }
          updateTrackerUI(data.status);
          if (data.items && Array.isArray(data.items) && data.items.length > 0) {
            activeTrackedItems = data.items;
            try { _store.setItem('activeOrderItems', JSON.stringify(data.items)); } catch(e) {}
            renderTrackedItemsList(data.items, data.totalAmount);
          }
          renderLiveQueue(data.currentlyPreparing, data.currentlyInQueue, data.currentlyReady);
        })
        .catch(e => {
          if (slowFetchTimer) clearTimeout(slowFetchTimer);
          const slowBanner = document.getElementById('slowConnectionBanner');
          if (slowBanner && navigator.onLine) {
            slowBanner.style.display = 'block';
          }
          const banner = document.getElementById('wifiWarningBanner');
          if (banner && !navigator.onLine) {
            banner.style.display = 'block';
          }
        });
    }

    function refreshLiveQueueModal() {
      const qIcon = document.getElementById('queueRefreshIcon');
      if (qIcon) qIcon.style.animation = 'spin 0.6s linear infinite';
      fetch('/api/order-status')
        .then(r => r.json())
        .then(data => {
          if (data) {
            renderLiveQueue(data.currentlyPreparing, data.currentlyInQueue, data.currentlyReady);
          }
        })
        .catch(() => {})
        .finally(() => {
          if (qIcon) {
            setTimeout(() => { qIcon.style.animation = 'none'; }, 600);
          }
        });
    }

    function openKitchenQueueModal() {
      const modal = document.getElementById('kitchenQueueModal');
      if (modal) modal.style.display = 'flex';
      refreshLiveQueueModal();
    }

    function parseChipItem(raw) {
      if (typeof raw === 'object' && raw !== null) {
        const num = raw.orderNumber || '';
        let tbl = (raw.tableNumber || '').trim();
        tbl = tbl.replace(/^T+able/i, 'Table');
        const isTakeout = raw.orderType === 'takeaway' || raw.orderType === 'delivery' || tbl.toLowerCase().includes('take');
        return {
          orderNum: num,
          tableText: isTakeout ? 'Takeout' : (tbl ? (tbl.toLowerCase().startsWith('table') ? tbl : 'Table ' + tbl) : ''),
          isTakeout: isTakeout
        };
      }

      const str = String(raw || '').trim();
      const parts = str.split(' ·').map(s => s.trim());
      const num = parts[0] || '';
      let tbl = '';

      for (let i = 1; i < parts.length; i++) {
        const p = parts[i];
        if (p.toUpperCase() !== 'KITCHEN' && p) {
          tbl = p.replace(/^T+able/i, 'Table');
        }
      }

      const isTakeout = tbl.toLowerCase().includes('take');
      if (tbl && !isTakeout && !tbl.toLowerCase().startsWith('table')) {
        tbl = 'Table ' + tbl;
      }

      return {
        orderNum: num,
        tableText: tbl,
        isTakeout: isTakeout
      };
    }

    function renderChipHtml(chip, statusType, currentNum) {
      const cleanChipNum = (chip.orderNum || '').toLowerCase();
      const cleanMyNum = (currentNum || '').toLowerCase();
      const isMine = cleanMyNum && (
        cleanChipNum === cleanMyNum ||
        cleanChipNum.replace('#','').trim() === cleanMyNum.replace('#','').trim()
      );

      let badgeColor = 'var(--amber-brewing)';
      let bgStyle = 'background: rgba(255,159,28,0.12);';
      let borderStyle = 'border: 1.5px solid rgba(255,159,28,0.4);';

      if (isMine) {
        badgeColor = 'var(--gold-light)';
        bgStyle = 'background: rgba(212,175,55,0.18);';
        borderStyle = 'border: 1.5px solid var(--gold-primary);';
      } else if (statusType === 'ready') {
        badgeColor = 'var(--emerald)';
        bgStyle = 'background: rgba(46,196,182,0.12);';
        borderStyle = 'border: 1.5px solid rgba(46,196,182,0.4);';
      } else if (statusType === 'queue') {
        badgeColor = 'var(--text-light)';
        bgStyle = 'background: rgba(255,255,255,0.05);';
        borderStyle = 'border: 1px solid rgba(255,255,255,0.15);';
      }

      const tableBadge = chip.tableText
        ? `<span style="font-size: 11px; font-weight: 700; color: \${isMine ? 'var(--gold-light)' : 'var(--text-muted)'}; display: inline-flex; align-items: center; gap: 3px; background: rgba(0,0,0,0.28); padding: 2px 7px; border-radius: 6px;">
            \${chip.isTakeout ? '🥡' : '🍽️'} \${chip.tableText}
           </span>`
        : '';

      return `
        <div style="\${bgStyle} \${borderStyle} border-radius: 12px; padding: 7px 12px; display: inline-flex; align-items: center; gap: 7px;">
          <span style="font-family: 'Outfit', sans-serif; font-weight: 900; font-size: 13.5px; color: \${isMine ? 'var(--gold-light)' : badgeColor}; letter-spacing: 0.3px;">
            \${chip.orderNum}
          </span>
          \${tableBadge}
        </div>
      `;
    }

    function renderLiveQueue(preparingList, queueList, readyList) {
      const nowPrepContainer = document.getElementById('modalNowPreparingChips');
      const inQueueContainer = document.getElementById('modalInQueueChips');
      const readyContainer = document.getElementById('modalReadyChips');
      const nowPrepCount = document.getElementById('modalNowPrepCount');
      const inQueueCount = document.getElementById('modalInQueueCount');
      const readyCount = document.getElementById('modalReadyCount');
      const summaryBadge = document.getElementById('trackerQueueSummaryBadge');
      const headerQueueText = document.getElementById('headerQueueText');

      const currentNum = (activeTrackedOrderNum || _store.getItem('activeOrderNum') || '').trim();
      const preps = (Array.isArray(preparingList) ? preparingList : []).map(parseChipItem).filter(c => c.orderNum);
      const queue = (Array.isArray(queueList) ? queueList : []).map(parseChipItem).filter(c => c.orderNum);
      const ready = (Array.isArray(readyList) ? readyList : []).map(parseChipItem).filter(c => c.orderNum);

      if (summaryBadge) {
        summaryBadge.innerText = `\${preps.length} brewing • \${queue.length} in queue`;
      }
      if (headerQueueText) {
        headerQueueText.innerText = preps.length > 0 ? `\${preps.length} Brewing` : (queue.length > 0 ? `\${queue.length} in Queue` : 'Kitchen Queue');
      }
      if (nowPrepCount) nowPrepCount.innerText = `\${preps.length} order\${preps.length !== 1 ? 's' : ''}`;
      if (inQueueCount) inQueueCount.innerText = `\${queue.length} ticket\${queue.length !== 1 ? 's' : ''}`;
      if (readyCount) readyCount.innerText = `\${ready.length} ready`;

      // Customer Active Order Hero Highlight inside Modal
      const activeBanner = document.getElementById('modalActiveOrderBanner');
      if (activeBanner) {
        if (currentNum) {
          const isPrep = preps.some(p => p.orderNum.toLowerCase() === currentNum.toLowerCase() || p.orderNum.replace('#','').trim() === currentNum.replace('#','').trim());
          const isQ = queue.some(p => p.orderNum.toLowerCase() === currentNum.toLowerCase() || p.orderNum.replace('#','').trim() === currentNum.replace('#','').trim());
          const isR = ready.some(p => p.orderNum.toLowerCase() === currentNum.toLowerCase() || p.orderNum.replace('#','').trim() === currentNum.replace('#','').trim());
          
          let myStatusLabel = 'Awaiting Cashier Confirmation';
          let myStatusColor = 'var(--gold-primary)';
          if (isPrep) { myStatusLabel = 'Now Brewing & Preparing'; myStatusColor = 'var(--amber-brewing)'; }
          else if (isR) { myStatusLabel = 'Ready for Pickup Counter!'; myStatusColor = 'var(--emerald)'; }
          else if (isQ) { myStatusLabel = 'In Kitchen Preparation Queue'; myStatusColor = 'var(--gold-light)'; }

          activeBanner.style.display = 'block';
          activeBanner.innerHTML = `
            <div style="background: rgba(212,175,55,0.14); border: 1.5px solid var(--gold-primary); border-radius: var(--radius-md); padding: 10px 14px; margin-bottom: 14px; display: flex; align-items: center; justify-content: space-between; gap: 8px;">
              <div>
                <div style="font-size: 11px; font-weight: 800; color: var(--gold-primary); text-transform: uppercase; letter-spacing: 0.5px;">Your Tracked Ticket</div>
                <div style="font-size: 15px; font-weight: 900; color: var(--gold-light); font-family: 'Cinzel', serif;">\${currentNum}</div>
              </div>
              <span style="font-size: 11px; font-weight: 800; color: \${myStatusColor}; background: rgba(0,0,0,0.35); border: 1px solid rgba(255,255,255,0.12); padding: 4px 10px; border-radius: 10px;">\${myStatusLabel}</span>
            </div>
          `;
        } else {
          activeBanner.style.display = 'none';
        }
      }

      if (nowPrepContainer) {
        if (preps.length === 0) {
          nowPrepContainer.innerHTML = '<div style="display: flex; align-items: center; gap: 8px; color: var(--text-muted); font-size: 12px; padding: 6px 2px;"><span style="font-size: 15px;">☕</span> <span>Barista station is standing by for new items</span></div>';
        } else {
          nowPrepContainer.innerHTML = preps.map(item => renderChipHtml(item, 'preparing', currentNum)).join('');
        }
      }

      if (inQueueContainer) {
        if (queue.length === 0) {
          inQueueContainer.innerHTML = '<div style="display: flex; align-items: center; gap: 8px; color: var(--text-muted); font-size: 12px; padding: 6px 2px;"><span style="font-size: 15px;">✨</span> <span>Queue is clear — orders start prep immediately!</span></div>';
        } else {
          inQueueContainer.innerHTML = queue.map(item => renderChipHtml(item, 'queue', currentNum)).join('');
        }
      }

      if (readyContainer) {
        if (ready.length === 0) {
          readyContainer.innerHTML = '<div style="display: flex; align-items: center; gap: 8px; color: var(--text-muted); font-size: 12px; padding: 6px 2px;"><span style="font-size: 15px;">🛎️</span> <span>All prepared orders have been collected</span></div>';
        } else {
          readyContainer.innerHTML = ready.map(item => renderChipHtml(item, 'ready', currentNum)).join('');
        }
      }
    }

    window.addEventListener('offline', () => {
      const banner = document.getElementById('wifiWarningBanner');
      if (banner) banner.style.display = 'block';
    });
    window.addEventListener('online', () => {
      const banner = document.getElementById('wifiWarningBanner');
      if (banner) banner.style.display = 'none';
    });

    function renderTrackedItemsList(items, total) {
      const countEl = document.getElementById('trackedItemsCount');
      const modalListEl = document.getElementById('modalOrderItemsList');
      const modalTotalEl = document.getElementById('modalReceiptTotal');

      const itemList = items || [];
      const totalQty = itemList.reduce((sum, i) => sum + (i.quantity || 1), 0);
      if (countEl) countEl.innerText = totalQty;
      if (modalTotalEl && total) modalTotalEl.innerText = `₱\${Math.round(total)}`;

      if (!modalListEl) return;
      if (itemList.length === 0) {
        modalListEl.innerHTML = '<div style="font-size:12.5px;color:var(--text-muted);text-align:center;padding:16px;">Order details registered with Cashier.</div>';
        return;
      }

      modalListEl.innerHTML = itemList.map(i => {
        const itemName = i.name || i.menuItem?.name || 'Item';
        const isKitchen = i.isKitchen === true ||
          ['streetBites', 'pastaDishes', 'sandwich'].includes((i.category || '').toLowerCase()) ||
          ['wings', 'buffalo', 'fries', 'stick', 'lumpia', 'shanghai', 'pasta', 'carbonara', 'aglio', 'sandwich', 'toast'].some(k => itemName.toLowerCase().includes(k));
        const kitchenBadge = isKitchen ? '<span style="background:rgba(255,87,34,0.22);border:1px solid rgba(255,87,34,0.55);color:#FF7043;font-size:10px;font-weight:900;padding:2px 6px;border-radius:4px;margin-left:6px;">KITCHEN</span>' : '';

        const customsList = i.customizations || [];
        const customsText = customsList.map(c => typeof c === 'string' ? c : (c.optionName || c.name || '')).filter(Boolean).join(', ');
        const notesText = i.notes ? `<div style="font-size:11px;color:var(--rose);margin-top:3px;font-weight:600;">Note: "\${i.notes}"</div>` : '';
        const customsHtml = customsText ? `<div style="font-size:11.5px;color:var(--text-muted);margin-top:2px;">› \${customsText}</div>` : '';
        const itemPrice = i.price || i.totalPrice || ((i.unitPrice || 0) * (i.quantity || 1));

        return `
          <div style="display:flex;justify-content:space-between;align-items:flex-start;padding:8px 0;border-bottom:1px solid rgba(255,255,255,0.06);">
            <div style="flex:1;padding-right:12px;">
              <div style="display:flex;align-items:center;gap:6px;">
                <span style="font-weight:800;color:var(--gold-primary);font-size:12.5px;">\${i.quantity || 1}x</span>
                <span style="font-weight:700;color:\${isKitchen ? '#FFE0B2' : 'var(--text-light)'};font-size:13.5px;">\${itemName}</span>
                \${kitchenBadge}
              </div>
              \${customsHtml}
              \${notesText}
            </div>
            <div style="font-weight:700;color:var(--gold-light);font-size:13.5px;white-space:nowrap;">
              ₱\${Math.round(itemPrice || 0)}
            </div>
          </div>
        `;
      }).join('');
    }

    function openOrderModal() {
      const r = activeReceiptData || {};
      const s = (r.status || prevTrackStatus || 'pending').toLowerCase();
      const isPaid = (s === 'confirmed' || s === 'inqueue' || s === 'queue' || s === 'preparing' || s === 'brewing' || s === 'kitchen' || s === 'ready' || s === 'completed');

      if (!isPaid) {
        // Do not display receipt if not settled by cashier
        return;
      }

      const modal = document.getElementById('orderReceiptModal');
      const stampBadge = document.getElementById('receiptStampBadge');
      const orderNumEl = document.getElementById('receiptOrderNum');
      const dateTimeEl = document.getElementById('receiptDateTime');
      const tableTypeEl = document.getElementById('receiptTableType');
      const cashierEl = document.getElementById('receiptCashierName');
      const custEl = document.getElementById('receiptCustName');
      const subtotalEl = document.getElementById('receiptSubtotal');
      const discountRow = document.getElementById('receiptDiscountRow');
      const discountLabel = document.getElementById('receiptDiscountLabel');
      const discountAmountEl = document.getElementById('receiptDiscountAmount');
      const grandTotalEl = document.getElementById('receiptGrandTotal');
      const payDetails = document.getElementById('receiptPaymentDetails');
      const payMethodEl = document.getElementById('receiptPayMethod');
      const tenderedEl = document.getElementById('receiptTendered');
      const changeDueEl = document.getElementById('receiptChangeDue');

      const orderNum = r.orderNumber || activeTrackedOrderNum || '#1';

      if (orderNumEl) orderNumEl.innerText = orderNum;
      const isTkReceipt = (r.orderType === 'takeaway' || r.orderType === 'takeout' || (r.tableNumber && r.tableNumber.toLowerCase().includes('take')) || currentOrderType === 'takeaway');
      if (tableTypeEl) tableTypeEl.innerText = isTkReceipt ? '🥡 Takeout / To-Go' : `\${r.tableNumber || currentTable} • Dine-In`;
      if (cashierEl) cashierEl.innerText = r.cashierName || (isPaid ? 'Cashier Staff' : 'Awaiting Cashier');
      if (custEl) custEl.innerText = r.customerName || 'Guest Patron';

      let dStr = '--';
      if (r.createdAt) {
        try {
          const d = new Date(r.createdAt);
          dStr = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) + ' • ' + d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
        } catch(_) {}
      } else {
        const d = new Date();
        dStr = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) + ' • ' + d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
      }
      if (dateTimeEl) dateTimeEl.innerText = dStr;

      if (stampBadge) {
        if (isPaid) {
          stampBadge.innerHTML = '✓ OFFICIAL RECEIPT • PAID';
          stampBadge.style.borderColor = '#2EC4B6';
          stampBadge.style.color = '#2EC4B6';
          stampBadge.style.background = 'rgba(46,196,182,0.14)';
        } else {
          stampBadge.innerHTML = '⏳ AWAITING CASHIER CONFIRMATION & PAYMENT';
          stampBadge.style.borderColor = 'var(--gold-primary)';
          stampBadge.style.color = 'var(--gold-light)';
          stampBadge.style.background = 'rgba(212,175,55,0.12)';
        }
      }

      const totalVal = parseFloat(r.totalAmount || _store.getItem('activeOrderTotal') || 0);
      const subtotalVal = parseFloat(r.subtotal || totalVal);
      const discountVal = parseFloat(r.discountAmount || 0);

      if (subtotalEl) subtotalEl.innerText = `₱\${Math.round(subtotalVal)}`;
      if (grandTotalEl) grandTotalEl.innerText = `₱\${Math.round(totalVal)}`;

      if (discountRow) {
        if (discountVal > 0) {
          discountRow.style.display = 'flex';
          if (discountLabel) {
            const pct = r.discountPercentage ? ` (\${r.discountPercentage}%)` : '';
            discountLabel.innerText = `Discount\${pct}:`;
          }
          if (discountAmountEl) discountAmountEl.innerText = `-₱\${Math.round(discountVal)}`;
        } else {
          discountRow.style.display = 'none';
        }
      }

      if (payDetails) {
        if (isPaid) {
          payDetails.style.display = 'block';
          if (payMethodEl) payMethodEl.innerText = (r.paymentMethod || 'Cash').toUpperCase();
          if (tenderedEl) tenderedEl.innerText = `₱\${Math.round(parseFloat(r.amountTendered || totalVal))}`;
          if (changeDueEl) changeDueEl.innerText = `₱\${Math.round(parseFloat(r.changeDue || 0))}`;
        } else {
          payDetails.style.display = 'none';
        }
      }

      renderTrackedItemsList(r.items || activeTrackedItems, totalVal);

      if (modal) modal.style.display = 'flex';
    }

    function updateTrackerUI(status) {
      const s = (status || '').toLowerCase();
      const step1 = document.getElementById('step1');
      const step2 = document.getElementById('step2');
      const step3 = document.getElementById('step3');
      const pendingNotice = document.getElementById('pendingPaymentNotice');
      const confirmedNotice = document.getElementById('confirmedPaymentNotice');
      const brewingNotice = document.getElementById('brewingNotice');
      const compNotice = document.getElementById('completedNotice');
      const headerTag = document.getElementById('trackerHeaderTag');
      const pendingActions = document.getElementById('pendingActionButtons');

      const orderAnotherBtn = document.getElementById('btnOrderAnotherItem');
      const btnOpenOrderModal = document.getElementById('btnOpenOrderModal');
      const isPaid = (s === 'confirmed' || s === 'inqueue' || s === 'queue' || s === 'preparing' || s === 'brewing' || s === 'kitchen' || s === 'ready' || s === 'completed');

      if (btnOpenOrderModal) {
        if (isPaid) {
          btnOpenOrderModal.style.display = 'flex';
          btnOpenOrderModal.innerHTML = `<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color: var(--emerald);"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg><span>View Official Receipt (<span style="color: var(--emerald); font-weight: 800;">Paid ✓</span>)</span>`;
          btnOpenOrderModal.style.borderColor = 'var(--emerald)';
          btnOpenOrderModal.style.boxShadow = '0 4px 14px rgba(46,196,182,0.25)';
        } else {
          // Do not display receipt if not settled by cashier
          btnOpenOrderModal.style.display = 'none';
        }
      }

      if (s === 'pending') {
        if (headerTag) headerTag.innerText = 'ORDER PLACED • AWAITING CASHIER';
        if (pendingNotice) pendingNotice.style.display = 'block';
        if (confirmedNotice) confirmedNotice.style.display = 'none';
        if (brewingNotice) brewingNotice.style.display = 'none';
        if (compNotice) compNotice.style.display = 'none';
        if (pendingActions) pendingActions.style.display = 'block';
        if (orderAnotherBtn) orderAnotherBtn.style.display = 'none';
        step1.className = 'status-step active';
        step2.className = 'status-step';
        step3.className = 'status-step';
      } else if (s === 'confirmed' || s === 'inqueue' || s === 'queue') {
        if (headerTag) headerTag.innerText = 'PAYMENT CONFIRMED • IN QUEUE';
        if (pendingNotice) pendingNotice.style.display = 'none';
        if (confirmedNotice) confirmedNotice.style.display = 'block';
        if (brewingNotice) brewingNotice.style.display = 'none';
        if (compNotice) compNotice.style.display = 'none';
        if (pendingActions) pendingActions.style.display = 'none';
        if (orderAnotherBtn) orderAnotherBtn.style.display = 'none';
        step1.className = 'status-step completed';
        step2.className = 'status-step'; // Awaiting barista to tap Start Brewing
        step3.className = 'status-step';
      } else if (s === 'preparing' || s === 'brewing' || s === 'kitchen') {
        if (headerTag) headerTag.innerText = 'NOW BREWING & PREPARING';
        if (pendingNotice) pendingNotice.style.display = 'none';
        if (confirmedNotice) confirmedNotice.style.display = 'none';
        if (brewingNotice) brewingNotice.style.display = 'block';
        if (compNotice) compNotice.style.display = 'none';
        if (pendingActions) pendingActions.style.display = 'none';
        if (orderAnotherBtn) orderAnotherBtn.style.display = 'none';
        step1.className = 'status-step completed';
        step2.className = 'status-step active'; // Step 2 lights up now!
        step3.className = 'status-step';

        if (prevTrackStatus === 'pending' || prevTrackStatus === 'confirmed') {
          try {
            const ctx = audioContext || new (window.AudioContext || window.webkitAudioContext)();
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(587.33, ctx.currentTime);
            osc.frequency.exponentialRampToValueAtTime(880, ctx.currentTime + 0.3);
            gain.gain.setValueAtTime(0.3, ctx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.4);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start();
            osc.stop(ctx.currentTime + 0.4);
          } catch(e) {}
        }
      } else if (s === 'ready') {
        if (headerTag) headerTag.innerText = 'ORDER READY FOR PICKUP!';
        if (pendingNotice) pendingNotice.style.display = 'none';
        if (confirmedNotice) confirmedNotice.style.display = 'none';
        if (brewingNotice) brewingNotice.style.display = 'none';
        const compNotice = document.getElementById('completedNotice');
        if (compNotice) compNotice.style.display = 'none';
        if (pendingActions) pendingActions.style.display = 'none';
        if (orderAnotherBtn) {
          orderAnotherBtn.style.display = 'inline-flex';
          orderAnotherBtn.innerText = '+ Order More / New Order';
        }
        step1.className = 'status-step completed';
        step2.className = 'status-step completed';
        step3.className = 'status-step active';

        // Trigger alarm if order is ready and not yet dismissed
        const orderKey = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '1';
        if (_store.getItem('alarmDismissed_' + orderKey) !== 'true') {
          startRepeatingAlarm();
        }
      } else if (s === 'completed') {
        if (headerTag) headerTag.innerText = 'ORDER COMPLETED • ENJOY!';
        if (pendingNotice) pendingNotice.style.display = 'none';
        if (confirmedNotice) confirmedNotice.style.display = 'none';
        if (brewingNotice) brewingNotice.style.display = 'none';
        const compNotice = document.getElementById('completedNotice');
        if (compNotice) compNotice.style.display = 'block';
        if (pendingActions) pendingActions.style.display = 'none';
        if (orderAnotherBtn) {
          orderAnotherBtn.style.display = 'inline-flex';
          orderAnotherBtn.innerText = '+ Order More / New Order';
        }
        step1.className = 'status-step completed';
        step2.className = 'status-step completed';
        step3.className = 'status-step completed';
        stopAlarm();

        if (pollInterval) {
          clearInterval(pollInterval);
          pollInterval = null;
        }

        // Pop-up celebratory completed modal with "Order Again" and "No Thanks"
        showOrderCompletedModal();

        try {
          _store.removeItem('activeOrderId');
          _store.removeItem('activeOrderNum');
          _store.removeItem('activeOrderTotal');
          _store.removeItem('activeOrderItems');
          _store.removeItem('pendingCart');
          _store.removeItem('orderCompleted');
        } catch(e) {}
      }
      prevTrackStatus = s;
    }

    let completedModalShown = false;
    function showOrderCompletedModal() {
      if (completedModalShown) return;
      const compModal = document.getElementById('orderCompletedModal');
      if (!compModal) return;

      const compNum = document.getElementById('completedModalOrderNum');
      const compTable = document.getElementById('completedModalTableInfo');
      const displayNum = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '#1';
      if (compNum) compNum.innerText = displayNum;
      const isTkComp = (currentOrderType === 'takeaway' || (activeReceiptData && (activeReceiptData.orderType === 'takeaway' || (activeReceiptData.tableNumber && activeReceiptData.tableNumber.toLowerCase().includes('take')))));
      if (compTable) compTable.innerText = isTkComp ? '🥡 Takeout / To-Go' : `\${currentTable} • Dine-In`;

      compModal.style.display = 'flex';
      compModal.style.zIndex = '99999';
      completedModalShown = true;
    }

    function dismissOrderCompleted() {
      closeModal('orderCompletedModal');
      // Customer clicked "No Thanks" - remove the redundant "Order Again" prompt and provide a subtle "Back to Menu"
      const orderAnotherBtn = document.getElementById('btnOrderAnotherItem');
      if (orderAnotherBtn) {
        orderAnotherBtn.style.display = 'inline-flex';
        orderAnotherBtn.innerText = 'Back to Menu';
        orderAnotherBtn.style.background = 'rgba(255,255,255,0.06)';
        orderAnotherBtn.style.border = '1px solid rgba(255,255,255,0.18)';
        orderAnotherBtn.style.color = 'var(--text-muted)';
        orderAnotherBtn.style.boxShadow = 'none';
      }
    }

    async function cancelCustomerOrder() {
      const targetId = activeTrackedOrderId || activeTrackedOrderNum || _store.getItem('activeOrderId') || _store.getItem('activeOrderNum');
      const orderNum = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '';
      if (!targetId) {
        newOrder();
        return;
      }

      showConfirmModal({
        title: `Cancel Order \${orderNum}?`,
        message: 'This will cancel your pending ticket at the cashier. Are you sure you want to cancel this order?',
        confirmText: 'Yes, Cancel Order',
        cancelText: 'Keep Order',
        isDestructive: true,
        onConfirm: async () => {
          const currentTargetId = activeTrackedOrderId || activeTrackedOrderNum || _store.getItem('activeOrderId') || _store.getItem('activeOrderNum');
          const currentOrderNum = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '';
          const btn = document.getElementById('btnCancelOrder');
          if (btn) {
            btn.innerHTML = '<span class="btn-spinner"></span><span>Cancelling Order...</span>';
            btn.disabled = true;
          }

          try {
            const payload = {
              orderId: currentTargetId,
              id: currentTargetId,
              orderNumber: currentOrderNum
            };

            const res = await fetch(`/api/customer/cancel-order?orderId=\${encodeURIComponent(currentTargetId)}`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(payload)
            });

            let data = null;
            try {
              data = await res.json();
            } catch (_) {}

            if (btn) {
              btn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg><span>Cancel Order</span>';
              btn.disabled = false;
            }

            if (data && data.success) {
              try {
                _store.removeItem('activeOrderId');
                _store.removeItem('activeOrderNum');
                _store.removeItem('activeOrderTotal');
                _store.removeItem('activeOrderItems');
                _store.removeItem('pendingCart');
                _store.removeItem('orderCompleted');
              } catch(e) {}
              showSuccessModal({
                title: 'Order Cancelled',
                message: `Order \${currentOrderNum || ''} has been cancelled successfully. You can now place a new order.`,
                buttonText: 'Return to Menu',
                onDismiss: () => newOrder(true)
              });
            } else {
              const errMsg = (data && data.error) ? data.error : 'Cannot cancel order at this time. Please speak with the cashier directly.';
              const isNotFound = errMsg.toLowerCase().includes('not found');
              showSuccessModal({
                title: isNotFound ? 'Order Notice' : 'Cancellation Notice',
                message: isNotFound ? 'Order not found in cafe records. Returning to menu.' : errMsg,
                buttonText: 'OK',
                onDismiss: () => {
                  if (isNotFound) {
                    newOrder(true);
                  } else if (btn) {
                    btn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg><span>Cancel Order</span>';
                    btn.disabled = false;
                  }
                }
              });
            }
          } catch (err) {
            if (btn) {
              btn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg><span>Cancel Order</span>';
              btn.disabled = false;
            }
            showSuccessModal({
              title: 'Order Cancelled',
              message: 'Your order has been cancelled.',
              buttonText: 'Return to Menu',
              onDismiss: () => newOrder()
            });
          }
        }
      });
    }

    function newOrder(force = false) {
      if (!force && activeTrackedOrderId && prevTrackStatus && prevTrackStatus !== 'completed' && prevTrackStatus !== 'cancelled') {
        showSuccessModal({
          title: 'Order In Progress',
          message: 'Your order (' + (activeTrackedOrderNum || '') + ') is currently in progress. You cannot place another order until it is completed or cancelled.',
          buttonText: 'View Active Order',
          onDismiss: () => {
            document.getElementById('controlsWrapper').style.display = 'none';
            document.getElementById('menuView').style.display = 'none';
            document.getElementById('cartBar').style.display = 'none';
            document.getElementById('trackerView').style.display = 'block';
            window.scrollTo({ top: 0, behavior: 'smooth' });
          }
        });
        return;
      }
      stopAlarm();
      if (pollInterval) {
        clearInterval(pollInterval);
        pollInterval = null;
      }
      activeTrackedOrderId = null;
      activeTrackedOrderNum = null;
      activeTrackedItems = [];
      prevTrackStatus = '';
      cart = [];

      try {
        // Clear order-related storage while keeping table assignment intact
        const keys = [];
        for (let i = 0; i < _store.length; i++) {
          const k = _store.key(i);
          if (k && k.startsWith('alarmDismissed_')) keys.push(k);
        }
        keys.forEach(k => _store.removeItem(k));
        _store.removeItem('activeOrderId');
        _store.removeItem('activeOrderNum');
        _store.removeItem('activeOrderTotal');
        _store.removeItem('activeOrderItems');
        _store.removeItem('activeReceiptData');
        activeReceiptData = null;
        _store.removeItem('orderCompleted');
        _store.removeItem('pendingCart');
      } catch(e) {}

      const btn = document.getElementById('btnSendOrder');
      if (btn) {
        btn.innerText = 'Submit Order to Cashier';
        btn.disabled = false;
      }

      const cancelBtn = document.getElementById('btnCancelOrder');
      if (cancelBtn) {
        cancelBtn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg><span>Cancel Order</span>';
        cancelBtn.disabled = false;
      }

      const breakdown = document.getElementById('trackedOrderBreakdown');
      if (breakdown) breakdown.style.display = 'none';

      // Reset all notice banners
      const compNotice = document.getElementById('completedNotice');
      if (compNotice) compNotice.style.display = 'none';
      const pendingNotice = document.getElementById('pendingPaymentNotice');
      if (pendingNotice) pendingNotice.style.display = 'none';
      const confirmedNotice = document.getElementById('confirmedPaymentNotice');
      if (confirmedNotice) confirmedNotice.style.display = 'none';
      const brewingNotice = document.getElementById('brewingNotice');
      if (brewingNotice) brewingNotice.style.display = 'none';

      completedModalShown = false;
      const orderAnotherBtn = document.getElementById('btnOrderAnotherItem');
      if (orderAnotherBtn) {
        orderAnotherBtn.style.display = 'none';
        orderAnotherBtn.style.background = '';
        orderAnotherBtn.style.border = '';
        orderAnotherBtn.style.color = '';
        orderAnotherBtn.style.boxShadow = '';
      }
      closeModal('trayModal');
      closeModal('customModal');
      closeModal('orderReceiptModal');
      closeModal('confirmModal');
      closeModal('successModal');
      closeModal('readyAlarmModal');
      closeModal('kitchenQueueModal');
      closeModal('orderCompletedModal');

      document.getElementById('trackerView').style.display = 'none';
      document.getElementById('controlsWrapper').style.display = 'block';
      document.getElementById('menuView').style.display = 'block';
      updateCartBar();
      window.scrollTo({ top: 0, behavior: 'smooth' });
      try {
        const url = new URL(window.location.href);
        url.searchParams.delete('id');
        url.searchParams.delete('orderId');
        url.searchParams.delete('order');
        window.history.replaceState({}, document.title, url.pathname + (url.searchParams.toString() ? '?' + url.searchParams.toString() : ''));
      } catch(e) {}
      try {
        sessionStorage.removeItem('celestial_dining_chosen');
      } catch(e) {}
      setTimeout(showDiningOptionModal, 250);
    }

    function restoreActiveOrderIfAny() {
      try {
        const savedId  = _store.getItem('activeOrderId');
        const savedNum = _store.getItem('activeOrderNum');
        const savedTotal = parseFloat(_store.getItem('activeOrderTotal') || '0');
        const savedTable = _store.getItem('activeTableNumber');
        if (savedTable) {
          currentTable = savedTable;
          const tableSel = document.getElementById('tableSelect');
          if (tableSel) tableSel.value = savedTable;
        }

        let savedItems = [];
        try { savedItems = JSON.parse(_store.getItem('activeOrderItems') || '[]'); } catch(e) {}

        // ── Path A0: Direct Order Tracking from URL (Scanned from Cashier Screen or Receipt) ──
        const trackUrlParams = new URLSearchParams(window.location.search);
        const urlOrderId = trackUrlParams.get('id') || trackUrlParams.get('orderId') || trackUrlParams.get('order');
        if (urlOrderId) {
          fetch(`/api/order-status?orderId=\${encodeURIComponent(urlOrderId)}`)
            .then(r => r.json())
            .then(data => {
              if (data && data.success && data.orderId) {
                activeReceiptData = data;
                try { _store.setItem('activeReceiptData', JSON.stringify(data)); } catch(e) {}
                startOrderTracking(data.orderId, data.orderNumber, data.totalAmount || 0, data.items || [], data.status || 'pending');
                renderLiveQueue(data.currentlyPreparing, data.currentlyInQueue, data.currentlyReady);

                // Prompt for notification & audio permissions
                try {
                  if ('Notification' in window && Notification.permission !== 'granted' && Notification.permission !== 'denied') {
                    Notification.requestPermission();
                  }
                } catch(_) {}
                initAudio();

                if (data.status === 'ready') {
                  startRepeatingAlarm();
                } else if (data.status === 'completed') {
                  showOrderCompletedModal();
                }
              } else if (!data || data.success === false || data.status === 'not_found' || (data.error && data.error.toLowerCase().includes('not found'))) {
                showSuccessModal({
                  title: 'Order Notice',
                  message: 'Order not found in cafe records. Please select your items from the menu.',
                  buttonText: 'OK',
                  onDismiss: () => newOrder(true)
                });
              }
            })
            .catch(err => {
              console.warn('Track URL recovery error:', err);
            });
          return;
        }

        if (savedId || savedNum) {
          // Verify with server FIRST before showing tracker view
          const qId = savedId || savedNum;
          fetch(`/api/order-status?orderId=\${encodeURIComponent(qId)}`)
            .then(r => r.json())
            .then(data => {
              if (data && data.status === 'completed') {
                const itemsToUse = (data.items && Array.isArray(data.items) && data.items.length > 0) ? data.items : savedItems;
                const totalToUse = (data.totalAmount !== undefined && data.totalAmount !== null) ? data.totalAmount : savedTotal;
                startOrderTracking(savedId || savedNum, savedNum || savedId, totalToUse, itemsToUse, 'completed');
                showOrderCompletedModal();
                return;
              }
              if (!data || data.success === false || data.status === 'cancelled' || data.status === 'not_found' || (data.error && data.error.toLowerCase().includes('not found'))) {
                // If cancelled or doesn't exist, reset to menu directly!
                newOrder(true);
                return;
              }
              if (data && data.status) {
                if (data.success) {
                  activeReceiptData = data;
                  try { _store.setItem('activeReceiptData', JSON.stringify(data)); } catch(e) {}
                }
                const itemsToUse = (data.items && Array.isArray(data.items) && data.items.length > 0) ? data.items : savedItems;
                const totalToUse = (data.totalAmount !== undefined && data.totalAmount !== null) ? data.totalAmount : savedTotal;
                startOrderTracking(savedId || savedNum, savedNum || savedId, totalToUse, itemsToUse, data.status);
                renderLiveQueue(data.currentlyPreparing, data.currentlyInQueue, data.currentlyReady);
              }
            })
            .catch(() => {
              // If offline or network error, stay locked to tracker view since active order was placed
              startOrderTracking(savedId || savedNum, savedNum || savedId, savedTotal, savedItems, 'pending');
            });
          return;
        }

        // ── Path B: No saved order — try cross-device recovery by table number ──
        const urlTable = (new URLSearchParams(window.location.search)).get('table');
        if (urlTable) {
          fetch(`/api/table-order?table=\${encodeURIComponent(urlTable)}`)
            .then(r => r.json())
            .then(data => {
              if (data && data.success && data.orderId && data.status &&
                  data.status !== 'completed' && data.status !== 'cancelled') {
                const items = (data.items && Array.isArray(data.items)) ? data.items : [];
                const total = (data.totalAmount !== undefined && data.totalAmount !== null) ? data.totalAmount : 0;
                startOrderTracking(data.orderId, data.orderNumber, total, items, data.status);
              } else {
                // ── Path C: No active order at all — restore pending cart if any ──
                _restorePendingCartIfAny();
              }
            })
            .catch(() => { _restorePendingCartIfAny(); });
        } else {
          _restorePendingCartIfAny();
        }
      } catch(e) {}
    }

    // Restore a cart the customer built before accidentally refreshing/closing.
    function _restorePendingCartIfAny() {
      try {
        const raw = _store.getItem('pendingCart');
        if (raw) {
          const saved = JSON.parse(raw);
          if (Array.isArray(saved) && saved.length > 0) {
            cart = saved;
            updateCartBar();
          }
        }
      } catch(e) {}
      _checkFirstAppearDiningPrompt();
    }

    function _checkFirstAppearDiningPrompt() {
      if (activeTrackedOrderId) return;
      const trackerEl = document.getElementById('trackerView');
      if (trackerEl && trackerEl.style.display === 'block') return;

      const urlParams = new URLSearchParams(window.location.search);
      const urlOrderId = urlParams.get('id') || urlParams.get('orderId') || urlParams.get('order');
      if (urlOrderId) return;

      const chosen = sessionStorage.getItem('celestial_dining_chosen');
      if (!chosen) {
        setTimeout(showDiningOptionModal, 320);
      }
    }

    // Instant local render with inlined menu
    renderMenu();
    connectCustomerWs();
    restoreActiveOrderIfAny();
  </script>
</body>
</html>
''';
}
