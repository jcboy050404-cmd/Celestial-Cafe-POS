import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

typedef OrderStatusUpdateCallback = void Function(String orderId, String newStatus);
typedef CustomerOrderCallback = Map<String, dynamic> Function(Map<String, dynamic> rawOrder);
typedef CustomerChangeOrderCallback = Map<String, dynamic> Function(String orderId);
typedef CustomerCancelOrderCallback = Map<String, dynamic> Function(String orderId);
typedef ItemImageCallback = Uint8List? Function(String itemId);

class KdsServerService {
  HttpServer? _server;
  final Set<WebSocket> _clients = {};
  String _localIp = '192.168.43.1';
  int _port = 8080;
  bool _isRunning = false;

  OrderStatusUpdateCallback? onOrderStatusUpdate;
  List<Map<String, dynamic>> Function()? getActiveOrdersJson;
  List<Map<String, dynamic>> Function()? getMenuCallback;
  CustomerOrderCallback? onCustomerOrderSubmitted;
  CustomerChangeOrderCallback? onCustomerChangeOrder;
  CustomerCancelOrderCallback? onCustomerCancelOrder;
  dynamic Function(String orderId)? getOrderByIdCallback;
  ItemImageCallback? getItemImageCallback;

  bool get isRunning => _isRunning;
  String get serverUrl => 'http://$_localIp:$_port';
  String get localIp => _localIp;
  int get port => _port;
  int get clientCount => _clients.length;

  String getTableOrderUrl(String tableNumber) {
    final cleanTable = tableNumber.replaceAll('Table', '').trim();
    return 'http://$_localIp:$_port/order?table=$cleanTable';
  }

  Future<void> start({
    required List<Map<String, dynamic>> Function() getOrdersCallback,
    required OrderStatusUpdateCallback onStatusUpdate,
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
        print('☕ Celestial POS & KDS Server started on $serverUrl');
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
          print('☕ Celestial KDS Server started on fallback $serverUrl');
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

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            if (addr.address.startsWith('192.168.43.') ||
                addr.address.startsWith('172.20.10.') ||
                addr.address.startsWith('192.168.')) {
              _localIp = addr.address;
              return;
            }
            _localIp = addr.address;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error detecting local IP: $e');
      _localIp = '192.168.43.1';
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
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
  }

  void broadcastOrders() {
    if (getActiveOrdersJson == null) return;
    try {
      final ordersList = getActiveOrdersJson!();
      final payload = jsonEncode({
        'type': 'SYNC_ORDERS',
        'orders': ordersList,
      });

      for (var client in List<WebSocket>.from(_clients)) {
        if (client.readyState == WebSocket.open) {
          client.add(payload);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error broadcasting KDS orders: $e');
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

    if (path == '/ws') {
      _handleWebSocket(request);
    } else if (path == '/logo.png' || path == '/assets/images/logo.png') {
      _serveLogo(request);
    } else if (path.startsWith('/api/item-image') || path.startsWith('/item-image')) {
      _serveItemImage(request);
    } else if (path.startsWith('/order') || path.startsWith('/menu') || path.startsWith('/table')) {
      _serveCustomerOrderWebPage(request);
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
    } else if (path.startsWith('/api/orders')) {
      _handleOrdersApi(request);
    } else {
      _serveKdsWebPage(request);
    }
  }

  void _serveItemImage(HttpRequest request) {
    final itemId = request.uri.queryParameters['id'] ?? request.uri.queryParameters['itemId'] ?? '';
    if (getItemImageCallback != null && itemId.isNotEmpty) {
      final bytes = getItemImageCallback!(itemId);
      if (bytes != null) {
        request.response
          ..headers.contentType = ContentType.parse('image/png')
          ..headers.add('Cache-Control', 'public, max-age=3600')
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
      final file = File('assets/images/Logo.png');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        request.response
          ..headers.contentType = ContentType.parse('image/png')
          ..headers.add('Cache-Control', 'public, max-age=3600')
          ..statusCode = HttpStatus.ok
          ..add(bytes)
          ..close();
        return;
      }
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
    final orderId = request.uri.queryParameters['orderId'] ?? request.uri.queryParameters['id'] ?? '';
    final cleanId = orderId.trim().toLowerCase();

    final activeList = getActiveOrdersJson != null ? getActiveOrdersJson!() : <Map<String, dynamic>>[];
    final List<String> currentlyPreparing = [];
    final List<String> currentlyInQueue = [];
    final List<String> currentlyReady = [];

    for (var o in activeList) {
      final s = (o['status'] as String? ?? '').toLowerCase();
      final num = o['orderNumber'] as String? ?? '';
      if (num.isNotEmpty) {
        if (s == 'preparing' || s == 'brewing' || s == 'kitchen') {
          currentlyPreparing.add(num);
        } else if (s == 'confirmed' || s == 'inqueue' || s == 'queue') {
          currentlyInQueue.add(num);
        } else if (s == 'ready') {
          currentlyReady.add(num);
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
          final isPending = o['status'] == 'pending';
          request.response
            ..headers.contentType = ContentType.json
            ..statusCode = HttpStatus.ok
            ..write(jsonEncode({
              'success': true,
              'orderId': o['id'],
              'orderNumber': o['orderNumber'],
              'status': o['status'],
              'isPaid': !isPending,
              'tableNumber': o['tableNumber'],
              'totalAmount': o['totalAmount'],
              'items': o['items'] ?? [],
              'currentlyPreparing': currentlyPreparing,
              'currentlyInQueue': currentlyInQueue,
              'currentlyReady': currentlyReady,
            }))
            ..close();
          return;
        }
      }
    }

    if (matchedOrder != null) {
      final statusName = matchedOrder.status?.name?.toString() ?? matchedOrder.status?.toString() ?? '';
      final isPaid = statusName != 'pending' && statusName != 'cancelled';
      final dynamic orderItems = matchedOrder.items;
      List<Map<String, dynamic>> itemsJson = [];
      if (orderItems is List) {
        for (var i in orderItems) {
          final itemName = i.menuItem?.name ?? i.name ?? 'Item';
          final qty = i.quantity ?? 1;
          final price = i.totalPrice ?? i.price ?? 0.0;
          final uPrice = i.unitPrice ?? (price / (qty > 0 ? qty : 1));
          final note = i.notes ?? '';
          List<dynamic> customs = [];
          if (i.customizations is List) {
            customs = (i.customizations as List).map((c) => c.optionName ?? c.toString()).toList();
          }
          itemsJson.add({
            'name': itemName,
            'quantity': qty,
            'price': price,
            'unitPrice': uPrice,
            'notes': note,
            'customizations': customs,
          });
        }
      }

      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({
          'success': true,
          'orderId': matchedOrder.id,
          'orderNumber': matchedOrder.orderNumber,
          'status': matchedOrder.status.name,
          'isPaid': isPaid,
          'tableNumber': matchedOrder.tableNumber,
          'totalAmount': matchedOrder.totalAmount,
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
          'success': false,
          'status': 'pending',
          'isPaid': false,
          'error': 'Order not found in records',
          'currentlyPreparing': currentlyPreparing,
          'currentlyInQueue': currentlyInQueue,
          'currentlyReady': currentlyReady,
        }))
        ..close();
    }
  }

  void _handleCustomerOrderApi(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      final data = jsonDecode(content) as Map<String, dynamic>;

      if (onCustomerOrderSubmitted != null) {
        final result = onCustomerOrderSubmitted!(data);
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode(result))
          ..close();
      } else {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.internalServerError
          ..write(jsonEncode({'success': false, 'error': 'Server callback not initialized'}))
          ..close();
      }
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

  void _handleOrdersApi(HttpRequest request) {
    final ordersList = getActiveOrdersJson != null ? getActiveOrdersJson!() : [];
    request.response
      ..headers.contentType = ContentType.json
      ..statusCode = HttpStatus.ok
      ..write(jsonEncode({'orders': ordersList}))
      ..close();
  }

  void _handleUpdateStatusApi(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final orderId = data['orderId'] as String?;
      final status = data['status'] as String?;

      if (orderId != null && status != null) {
        onOrderStatusUpdate?.call(orderId, status);
      }

      await Future.delayed(const Duration(milliseconds: 40));

      final ordersList = getActiveOrdersJson != null ? getActiveOrdersJson!() : [];
      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'success': true, 'orders': ordersList}))
        ..close();
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write(jsonEncode({'error': e.toString()}))
        ..close();
    }
  }

  void _handleWebSocket(HttpRequest request) async {
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      _clients.add(socket);

      if (getActiveOrdersJson != null) {
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

            if (action == 'update_status' && orderId != null && status != null) {
              onOrderStatusUpdate?.call(orderId, status);
            }
          } catch (e) {
            if (kDebugMode) print('Error parsing KDS WS message: $e');
          }
        },
        onDone: () {
          _clients.remove(socket);
        },
        onError: (err) {
          _clients.remove(socket);
        },
      );
    } catch (e) {
      if (kDebugMode) print('WebSocket upgrade failed: $e');
    }
  }

  void _serveKdsWebPage(HttpRequest request) {
    final ordersJson = jsonEncode(getActiveOrdersJson != null ? getActiveOrdersJson!() : []);
    final html = _kdsHtmlTemplate.replaceFirst(
      '/*__INITIAL_KDS_ORDERS__*/',
      'window.INITIAL_ORDERS = $ordersJson;',
    );
    request.response
      ..headers.contentType = ContentType.html
      ..headers.add('Cache-Control', 'no-cache')
      ..statusCode = HttpStatus.ok
      ..write(html)
      ..close();
  }

  void _serveCustomerOrderWebPage(HttpRequest request) {
    final menuJson = jsonEncode(getMenuCallback != null ? getMenuCallback!() : []);
    final html = _customerOrderHtmlTemplate.replaceFirst(
      '/*__INITIAL_MENU_DATA__*/',
      'window.INITIAL_MENU = $menuJson;',
    );
    request.response
      ..headers.contentType = ContentType.html
      ..headers.add('Cache-Control', 'no-cache')
      ..statusCode = HttpStatus.ok
      ..write(html)
      ..close();
  }

  // 1:1 Matched Fast Local KDS HTML Template (0s load, no external fonts)
  static const String _kdsHtmlTemplate = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Celestial Cafe — Barista KDS</title>
  <style>
    :root {
      --bg-dark: #0B080D;
      --bg-surface: #17131B;
      --bg-card: #1E1720;
      --gold-primary: #D4AF37;
      --gold-light: #F3D079;
      --brown-warm: #432C1D;
      --emerald-ready: #2EC4B6;
      --amber-brewing: #FF9F1C;
      --rose-alert: #E71D36;
      --blue-info: #4CC9F0;
      --text-light: #F7EFE8;
      --text-muted: #AFA399;
      --text-subtle: #6E645D;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
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
      padding: 12px 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      position: sticky;
      top: 0;
      z-index: 100;
      box-shadow: 0 4px 12px rgba(0,0,0,0.5);
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
      background: var(--bg-card);
      border-radius: 18px;
      border: 1.2px solid rgba(255, 255, 255, 0.08);
      overflow: hidden;
      display: flex;
      flex-direction: column;
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.45);
      transition: border-color 0.2s ease, transform 0.15s ease;
    }
    .ticket.pending { border-color: rgba(212, 175, 55, 0.35); }
    .ticket.preparing { border-color: rgba(255, 159, 28, 0.6); box-shadow: 0 8px 28px rgba(255, 159, 28, 0.15); }
    .ticket.ready { border-color: rgba(46, 196, 182, 0.6); box-shadow: 0 8px 28px rgba(46, 196, 182, 0.15); }

    .ticket-header {
      padding: 14px 16px 10px 16px;
      background: var(--bg-surface);
      border-bottom: 1px solid rgba(255, 255, 255, 0.06);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .ticket-title-group { display: flex; align-items: center; gap: 8px; }
    .ticket-number { font-size: 19px; font-weight: 800; color: var(--gold-light); letter-spacing: 0.5px; }
    .order-type-badge {
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 700;
      background: rgba(67, 44, 29, 0.4);
      color: var(--gold-light);
      border: 1px solid rgba(212, 175, 55, 0.25);
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
      margin-bottom: 12px;
      padding-bottom: 10px;
      border-bottom: 1px dashed rgba(255, 255, 255, 0.07);
      cursor: pointer;
      user-select: none;
      transition: opacity 0.2s;
    }
    .item-row:last-child { margin-bottom: 0; padding-bottom: 0; border-bottom: none; }
    .item-row.item-done { opacity: 0.35; text-decoration: line-through; }
    
    .item-title-row { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
    .item-qty {
      padding: 2px 6px;
      border-radius: 6px;
      background: var(--gold-primary);
      color: var(--bg-dark);
      font-size: 12px;
      font-weight: 800;
      min-width: 24px;
      text-align: center;
    }
    .item-name { font-weight: 700; font-size: 14px; color: var(--text-light); flex: 1; }

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
      padding: 12px 8px;
      border-radius: 10px;
      border: none;
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      transition: transform 0.1s, opacity 0.15s;
    }
    .action-btn:active { opacity: 0.75; transform: scale(0.98); }
    .btn-brew { background: var(--amber-brewing); color: var(--bg-dark); }
    .btn-ready { background: var(--emerald-ready); color: var(--bg-dark); }
    .btn-done { background: #22c55e; color: #ffffff; font-weight: 800; box-shadow: 0 4px 14px rgba(34, 197, 94, 0.4); }

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
    <div id="statusBadge" class="status-badge">
      <div class="dot"></div>
      <span id="statusText">Live Sync</span>
    </div>
  </header>

  <div class="filter-bar">
    <button class="tab-btn active" onclick="setFilter('all', this)">Active Queue <span class="tab-count" id="countAll">0</span></button>
    <button class="tab-btn" onclick="setFilter('preparing', this)">Brewing / Prep <span class="tab-count" id="countBrewing">0</span></button>
    <button class="tab-btn" onclick="setFilter('ready', this)">Ready for Pickup <span class="tab-count" id="countReady">0</span></button>
  </div>

  <main id="ticketsContainer">
    <div class="empty-state">
      <div class="empty-icon">☕</div>
      <h3>No Active Kitchen Tickets</h3>
      <p style="font-size: 13px; margin-top: 4px;">Orders approved & confirmed at the POS will appear here live.</p>
    </div>
  </main>

  <script>
    /*__INITIAL_KDS_ORDERS__*/
    let currentOrders = window.INITIAL_ORDERS || [];
    let ws;
    let audioContext;
    let activeFilter = 'all';

    function playChime() {
      try {
        if (!audioContext) audioContext = new (window.AudioContext || window.webkitAudioContext)();
        if (audioContext.state === 'suspended') audioContext.resume();
        const osc = audioContext.createOscillator();
        const gain = audioContext.createGain();
        osc.type = 'triangle';
        osc.connect(gain);
        gain.connect(audioContext.destination);
        osc.frequency.setValueAtTime(659.25, audioContext.currentTime);
        osc.frequency.setValueAtTime(1046.5, audioContext.currentTime + 0.12);
        gain.gain.setValueAtTime(0.6, audioContext.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.55);
        osc.start();
        osc.stop(audioContext.currentTime + 0.55);

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
      const loc = window.location;
      const wsUrl = (loc.protocol === 'https:' ? 'wss://' : 'ws://') + loc.host + '/ws';
      
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
      fetch('/api/orders')
        .then(res => res.json())
        .then(data => {
          if (data && data.orders) {
            currentOrders = data.orders;
            renderOrders(currentOrders);
          }
        })
        .catch(err => console.warn('Poll err:', err));
    }

    let prevCount = 0;
    function renderOrders(orders) {
      currentOrders = orders;
      const active = orders.filter(o => o.status === 'preparing' || o.status === 'ready');
      
      document.getElementById('countAll').innerText = active.length;
      document.getElementById('countBrewing').innerText = active.filter(o => o.status === 'preparing').length;
      document.getElementById('countReady').innerText = active.filter(o => o.status === 'ready').length;

      if (active.length > prevCount) {
        playChime();
      }
      prevCount = active.length;

      const filtered = activeFilter === 'all'
        ? active
        : active.filter(o => o.status === activeFilter);

      const container = document.getElementById('ticketsContainer');

      if (filtered.length === 0) {
        container.innerHTML = `
          <div class="empty-state">
            <div class="empty-icon">☕</div>
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

        const itemsHtml = (order.items || []).map(item => {
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

          const noteHtml = item.notes ? `<div class="note-box">Note: \${item.notes}</div>` : '';

          return `
            <div class="item-row" onclick="this.classList.toggle('item-done')">
              <div class="item-title-row">
                <span class="item-qty">\${item.quantity}x</span>
                <span class="item-name">\${item.name || item.menuItem?.name || ''}</span>
                \${sizeHtml}
              </div>
              \${customsListHtml}
              \${noteHtml}
            </div>
          `;
        }).join('');

        let actionBtn = '';
        let pendingBadge = '';
        if (order.status === 'confirmed') {
          actionBtn = `<button class="action-btn btn-brew" onclick="updateStatus('\${order.id}', 'preparing')">Start Brewing / Prep</button>`;
        } else if (order.status === 'pending') {
          pendingBadge = `<div style="background: rgba(255,159,28,0.15); border: 1px solid rgba(255,159,28,0.4); border-radius: 6px; padding: 4px 8px; font-size: 11px; font-weight: bold; color: var(--amber-brewing); margin-bottom: 8px; text-align: center;">Awaiting Cashier Payment</div>`;
          actionBtn = `<button class="action-btn btn-brew" onclick="updateStatus('\${order.id}', 'preparing')">Start Brewing / Confirm</button>`;
        } else if (order.status === 'preparing') {
          actionBtn = `<button class="action-btn btn-ready" onclick="updateStatus('\${order.id}', 'ready')">Mark Ready for Pickup</button>`;
        } else if (order.status === 'ready') {
          actionBtn = `<button class="action-btn btn-done" onclick="updateStatus('\${order.id}', 'completed')">Complete & Hand Over</button>`;
        }

        const tableInfo = order.tableNumber ? ` • \${order.tableNumber}` : '';
        const orderTypeLabel = order.orderType === 'dineIn' ? 'Dine-In' : 'Takeaway';
        const totalItems = (order.items || []).reduce((sum, i) => sum + (i.quantity || 1), 0);

        return `
          <div class="ticket \${order.status}">
            <div class="ticket-header">
              <div class="ticket-title-group">
                <div class="ticket-number">\${order.orderNumber}</div>
                <div class="order-type-badge">\${orderTypeLabel}\${tableInfo}</div>
              </div>
              <div class="ticket-header-right">
                <div class="timer-badge \${timerClass}">\${elapsedMins}m ago</div>
                <button class="void-btn" onclick="voidOrder('\${order.id}', '\${order.orderNumber}')" title="Void / Cancel Ticket">✕</button>
              </div>
            </div>
            <div class="ticket-sub">
              <span class="guest-name">Guest: \${order.customerName || 'Guest Patron'}</span>
              <span class="item-count-text">\${totalItems} items</span>
            </div>
            <div class="ticket-body">
              \${pendingBadge}
              \${itemsHtml}
            </div>
            \${order.orderNotes ? `<div class="order-memo-box">Memo: \${order.orderNotes}</div>` : ''}
            <div class="ticket-footer">
              \${actionBtn}
            </div>
          </div>
        `;
      }).join('');
    }

    function voidOrder(orderId, orderNumber) {
      if (confirm('Void / Cancel order ' + orderNumber + '?\\nAll items will be returned to stock.')) {
        updateStatus(orderId, 'cancelled');
      }
    }

    function updateStatus(orderId, newStatus) {
      const idx = currentOrders.findIndex(o => o.id === orderId);
      if (idx >= 0) {
        if (newStatus === 'completed' || newStatus === 'cancelled') {
          currentOrders.splice(idx, 1);
        } else {
          currentOrders[idx].status = newStatus;
        }
        renderOrders(currentOrders);
      }

      if (ws && ws.readyState === WebSocket.OPEN) {
        try {
          ws.send(JSON.stringify({
            action: 'update_status',
            orderId: orderId,
            status: newStatus
          }));
        } catch (e) {}
      }

      fetch('/api/orders/update-status', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ orderId: orderId, status: newStatus })
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

    renderOrders(currentOrders);
    connectWs();
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
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700;800;900&family=Outfit:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
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
      font-family: 'Outfit', -apple-system, BlinkMacSystemFont, sans-serif;
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
      font-family: 'Cinzel', serif;
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
      border: 1px solid var(--gold-primary);
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
      font-family: 'Cinzel', serif;
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

    /* Menu Grid Container */
    .menu-container {
      padding: 6px 18px 24px 18px;
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(165px, 1fr));
      gap: 14px;
    }

    /* Item Card */
    .item-card {
      background: var(--bg-card);
      border-radius: var(--radius-lg);
      border: 1px solid var(--border-subtle);
      padding: 12px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
      cursor: pointer;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
      position: relative;
      overflow: hidden;
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
      height: 115px;
      border-radius: var(--radius-md);
      overflow: hidden;
      margin-bottom: 10px;
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
      font-size: 10px;
      font-weight: 700;
      color: var(--gold-light);
      text-transform: uppercase;
      letter-spacing: 0.8px;
      margin-bottom: 4px;
      display: inline-block;
    }
    .item-card-name {
      font-weight: 700;
      font-size: 14px;
      color: var(--text-light);
      line-height: 1.3;
      margin-bottom: 4px;
    }
    .item-card-desc {
      font-size: 11px;
      color: var(--text-muted);
      line-height: 1.35;
      max-height: 36px;
      overflow: hidden;
      text-overflow: ellipsis;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
    }

    .item-card-bottom {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 10px;
      padding-top: 10px;
      border-top: 1px dashed rgba(255, 255, 255, 0.08);
    }
    .item-price {
      font-size: 16px;
      font-weight: 800;
      color: var(--gold-light);
      letter-spacing: 0.3px;
    }
    .btn-add-pill {
      background: linear-gradient(135deg, var(--gold-primary) 0%, #B89025 100%);
      color: #0D0A0F;
      border: none;
      border-radius: 10px;
      padding: 7px 14px;
      font-weight: 800;
      font-size: 12px;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 4px;
      box-shadow: 0 2px 8px rgba(212, 175, 55, 0.25);
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

    /* READY ALARM BANNER & SILENT-MODE STROBE */
    body.alarm-active {
      animation: screenStrobe 0.8s infinite alternate !important;
    }
    @keyframes screenStrobe {
      0% { background-color: #0D0A0F; }
      50% { background-color: #173832; }
      100% { background-color: #2D2314; }
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
        <div class="brand-sub">Artisanal Cafe & Espresso</div>
      </div>
    </div>
    <div class="header-right">
      <div class="live-dot-pulse" title="Connected to Cafe Hotspot"></div>
      <div id="tablePill" class="table-pill">Table 1</div>
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
        ⚠️ Wi-Fi Disconnected! Please reconnect to Cafe Wi-Fi to continue tracking your order live.
      </div>

      <!-- Slow Connection / Loading Banner -->
      <div id="slowConnectionBanner" style="display: none; text-align: center; margin-bottom: 12px;">
        <span style="width: 13px; height: 13px; border: 2px solid var(--amber-brewing); border-top-color: transparent; border-radius: 50%; display: inline-block; animation: spin 0.8s linear infinite;"></span>
      </div>

      <!-- Wi-Fi Keep Connected Notice Pill -->
      <div id="wifiStatusPill" style="display: inline-flex; align-items: center; justify-content: center; gap: 7px; background: rgba(46,196,182,0.12); border: 1px solid rgba(46,196,182,0.35); color: var(--emerald); border-radius: 20px; padding: 6px 14px; font-size: 11.5px; font-weight: 700; margin-bottom: 12px;">
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

      <!-- View Order Receipt Pop-up Modal Button -->
      <div style="margin-top: 14px;">
        <button onclick="openOrderModal()" id="btnOpenOrderModal" style="width: 100%; background: linear-gradient(135deg, rgba(212,175,55,0.18) 0%, rgba(212,175,55,0.06) 100%); border: 1.5px solid var(--gold-primary); color: var(--gold-light); border-radius: var(--radius-md); padding: 13px 16px; font-weight: 800; font-size: 13.5px; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px; box-shadow: 0 4px 14px rgba(212,175,55,0.15); transition: all 0.15s;">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
          <span>View Order Receipt (<span id="trackedItemsCount">0</span> items)</span>
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
        <button onclick="testAlarm()" style="background: rgba(46, 196, 182, 0.14); border: 1px solid var(--emerald); color: var(--emerald); border-radius: var(--radius-md); padding: 12px 18px; font-weight: 700; font-size: 12.5px; cursor: pointer; display: flex; align-items: center; gap: 6px;">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path><path d="M13.73 21a2 2 0 0 1-3.46 0"></path></svg>
          <span>Test Ready Alarm</span>
        </button>
        <button onclick="newOrder()" id="btnOrderAnotherItem" style="display: none; background: linear-gradient(135deg, rgba(212,175,55,0.2) 0%, rgba(212,175,55,0.08) 100%); border: 1.5px solid var(--gold-primary); color: var(--gold-light); border-radius: var(--radius-md); padding: 12px 20px; font-weight: 800; font-size: 13px; cursor: pointer; align-items: center; gap: 6px; box-shadow: 0 4px 14px rgba(212,175,55,0.18);">
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

  <!-- Customization Modal (Bottom Sheet) -->
  <div class="modal-overlay" id="customModal">
    <div class="modal-content">
      <div class="modal-drag-pill"></div>
      <div id="modalImageContainer"></div>
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <div class="modal-title" id="modalItemName">Item Name</div>
          <div class="modal-desc" id="modalItemDesc">Description</div>
        </div>
        <button onclick="closeModal('customModal')" style="background: rgba(255,255,255,0.08); border: none; border-radius: 50%; width: 32px; height: 32px; font-size: 14px; color: var(--text-muted); cursor: pointer; display: flex; align-items: center; justify-content: center;">✕</button>
      </div>

      <div id="customGroupContainer"></div>

      <!-- Quantity Stepper inside Customization Modal -->
      <div class="qty-stepper-row">
        <span style="font-weight: 700; font-size: 13px; color: var(--text-light);">Quantity</span>
        <div class="qty-controls">
          <button class="btn-qty" onclick="changeModalQty(-1)">−</button>
          <span class="qty-display" id="modalQtyDisplay">1</span>
          <button class="btn-qty" onclick="changeModalQty(1)">+</button>
        </div>
      </div>

      <div class="opt-group-title">Special Instructions (Optional)</div>
      <input type="text" id="modalItemNotes" placeholder="e.g. Less sweet, extra hot, no sauce..." style="width: 100%; background: var(--bg-card); border: 1px solid var(--border-subtle); border-radius: var(--radius-md); padding: 12px 14px; color: var(--text-light); font-size: 13px; margin-bottom: 18px; outline: none;">

      <button id="btnAddItemToCart" onclick="confirmAddToCart()" style="width: 100%; background: linear-gradient(135deg, var(--gold-primary) 0%, #B89025 100%); color: #0D0A0F; border: none; border-radius: var(--radius-md); padding: 15px; font-weight: 800; font-size: 15px; cursor: pointer; box-shadow: 0 4px 16px rgba(212, 175, 55, 0.35);">
        Add to Tray (₱0)
      </button>
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

      <div class="opt-group-title">Guest Name</div>
      <input type="text" id="custNameInput" placeholder="Enter your name (e.g. Maria, John)" style="width: 100%; background: var(--bg-card); border: 1px solid var(--border-subtle); border-radius: var(--radius-md); padding: 12px 14px; color: var(--text-light); font-size: 13.5px; margin-bottom: 14px; outline: none;">

      <div class="opt-group-title">Payment Method</div>
      <div class="opt-grid">
        <div class="opt-chip selected" onclick="selectPayment('cash', this)">Pay Cash at Counter</div>
        <div class="opt-chip" onclick="selectPayment('gcash', this)">Pay GCash / Maya at Counter</div>
        <div class="opt-chip" onclick="selectPayment('creditCard', this)">Pay Card at Counter</div>
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

  <!-- View Order Receipt Pop-up Modal -->
  <div class="modal-overlay" id="orderReceiptModal" onclick="if(event.target===this) closeModal('orderReceiptModal')">
    <div class="modal-content" style="max-width: 520px; margin: 0 auto;">
      <div class="modal-drag-pill"></div>
      <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 14px;">
        <div>
          <div class="modal-title" style="display: flex; align-items: center; gap: 8px; font-size: 18px;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: var(--gold-light);"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
            <span>Order Receipt</span>
          </div>
          <div class="modal-desc" id="modalReceiptSub" style="margin-bottom: 0; color: var(--text-muted); font-size: 12px; margin-top: 2px;">Ticket #1 • Table 1 • Dine-In</div>
        </div>
        <button onclick="closeModal('orderReceiptModal')" style="background: rgba(255,255,255,0.08); border: none; border-radius: 50%; width: 32px; height: 32px; font-size: 14px; color: var(--text-muted); cursor: pointer; display: flex; align-items: center; justify-content: center;">✕</button>
      </div>

      <!-- Items List -->
      <div id="modalOrderItemsList" style="max-height: 46vh; overflow-y: auto; margin-bottom: 16px; background: rgba(0,0,0,0.35); border: 1px solid rgba(255,255,255,0.08); border-radius: var(--radius-md); padding: 14px;">
        <!-- Dynamically rendered items -->
      </div>

      <!-- Summary Info & Total -->
      <div style="background: var(--bg-card); border: 1px solid var(--border-gold); border-radius: var(--radius-md); padding: 12px 14px; margin-bottom: 16px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
          <span style="font-size: 12px; color: var(--text-muted);">Current Status</span>
          <span id="modalReceiptStatus" style="font-size: 11.5px; font-weight: 800; color: var(--gold-light); text-transform: uppercase;">Awaiting Cashier</span>
        </div>
        <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px dashed rgba(255,255,255,0.1); padding-top: 8px;">
          <span style="font-weight: 700; font-size: 13.5px; color: var(--text-light);">Total Payable Amount</span>
          <span style="font-weight: 900; font-size: 20px; color: var(--gold-light);" id="modalReceiptTotal">₱0</span>
        </div>
      </div>

      <button onclick="closeModal('orderReceiptModal')" style="width: 100%; background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.18); color: var(--text-light); border-radius: var(--radius-md); padding: 13px; font-weight: 700; font-size: 13.5px; cursor: pointer;">
        Close Receipt
      </button>
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
  <div class="modal-overlay" id="successModal" style="align-items: center; justify-content: center; padding: 20px;" onclick="if(event.target===this) closeModal('successModal')">
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

  <!-- Live Kitchen Activity Pop-Up Modal -->
  <div class="modal-overlay" id="kitchenQueueModal" onclick="if(event.target===this) closeModal('kitchenQueueModal')">
    <div class="modal-content" style="max-width: 480px; margin: 0 auto; border-top: 2px solid var(--amber-brewing);">
      <div class="modal-drag-pill"></div>
      
      <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 14px;">
        <div>
          <div class="modal-title" style="display: flex; align-items: center; gap: 8px; font-size: 18px;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: var(--amber-brewing);"><path d="M18 8h1a4 4 0 0 1 0 8h-1"></path><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path><line x1="6" y1="1" x2="6" y2="4"></line><line x1="10" y1="1" x2="10" y2="4"></line><line x1="14" y1="1" x2="14" y2="4"></line></svg>
            <span>Live Kitchen Activity</span>
          </div>
          <div class="modal-desc" style="margin-bottom: 0; color: var(--text-muted); font-size: 12px; margin-top: 2px;">Real-time preparation queue from the barista bar</div>
        </div>
        <div style="display: flex; align-items: center; gap: 8px;">
          <div style="display: flex; align-items: center; gap: 5px; background: rgba(46,196,182,0.15); border: 1px solid rgba(46,196,182,0.4); border-radius: 12px; padding: 3px 8px; font-size: 10px; font-weight: 700; color: var(--emerald);">
            <span style="width: 6px; height: 6px; border-radius: 50%; background: var(--emerald); display: inline-block; animation: pulse 1.5s infinite;"></span>
            <span>Live Sync</span>
          </div>
          <button onclick="closeModal('kitchenQueueModal')" style="background: rgba(255,255,255,0.08); border: none; border-radius: 50%; width: 30px; height: 30px; font-size: 13px; color: var(--text-muted); cursor: pointer; display: flex; align-items: center; justify-content: center;">✕</button>
        </div>
      </div>

      <!-- Now Brewing / Preparing Section -->
      <div style="background: rgba(255,159,28,0.1); border: 1.5px solid rgba(255,159,28,0.35); border-radius: var(--radius-md); padding: 14px; margin-bottom: 12px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
          <div style="font-size: 11.5px; font-weight: 800; color: var(--amber-brewing); text-transform: uppercase; letter-spacing: 0.5px; display: flex; align-items: center; gap: 6px;">
            <span>🔥 Now Brewing / Preparing</span>
          </div>
          <span id="modalNowPrepCount" style="font-size: 11px; font-weight: 700; color: var(--gold-light);">0 orders</span>
        </div>
        <div id="modalNowPreparingChips" style="display: flex; flex-wrap: wrap; gap: 8px; align-items: center; min-height: 32px;">
          <span style="font-size: 12px; color: var(--text-muted); font-style: italic;">No orders currently on bar</span>
        </div>
      </div>

      <!-- Orders in Queue Section -->
      <div style="background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.09); border-radius: var(--radius-md); padding: 14px; margin-bottom: 12px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
          <div style="font-size: 11.5px; font-weight: 800; color: var(--text-light); text-transform: uppercase; letter-spacing: 0.5px; display: flex; align-items: center; gap: 6px;">
            <span>📋 Orders In Queue</span>
          </div>
          <span id="modalInQueueCount" style="font-size: 11px; font-weight: 700; color: var(--text-muted);">0 in queue</span>
        </div>
        <div id="modalInQueueChips" style="display: flex; flex-wrap: wrap; gap: 7px; align-items: center; min-height: 32px;">
          <span style="font-size: 12px; color: var(--text-muted);">Queue is currently clear</span>
        </div>
      </div>

      <!-- Ready for Pickup Section -->
      <div style="background: rgba(46,196,182,0.08); border: 1px solid rgba(46,196,182,0.25); border-radius: var(--radius-md); padding: 14px; margin-bottom: 16px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
          <div style="font-size: 11.5px; font-weight: 800; color: var(--emerald); text-transform: uppercase; letter-spacing: 0.5px; display: flex; align-items: center; gap: 6px;">
            <span>✨ Ready For Pickup</span>
          </div>
          <span id="modalReadyCount" style="font-size: 11px; font-weight: 700; color: var(--emerald);">0 ready</span>
        </div>
        <div id="modalReadyChips" style="display: flex; flex-wrap: wrap; gap: 7px; align-items: center; min-height: 28px;">
          <span style="font-size: 12px; color: var(--text-muted);">No orders at pickup counter</span>
        </div>
      </div>

      <button onclick="closeModal('kitchenQueueModal')" style="width: 100%; background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.18); color: var(--text-light); border-radius: var(--radius-md); padding: 13px; font-weight: 800; font-size: 13.5px; cursor: pointer;">
        Close Kitchen Queue
      </button>
    </div>
  </div>

  <script>
    /*__INITIAL_MENU_DATA__*/
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

    const urlParams = new URLSearchParams(window.location.search);
    const tableParam = urlParams.get('table');
    if (tableParam) {
      currentTable = tableParam.toLowerCase().startsWith('table') ? tableParam : 'Table ' + tableParam;
    }
    document.getElementById('tablePill').innerText = currentTable;

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

    function initAudio() {
      try {
        if (!audioContext) audioContext = new (window.AudioContext || window.webkitAudioContext)();
        if (audioContext && audioContext.state === 'suspended') {
          audioContext.resume();
        }
      } catch(e) {}
    }
    document.addEventListener('click', initAudio);
    document.addEventListener('touchstart', initAudio);

    function playAlarmSound() {
      try {
        initAudio();
        if (audioContext && audioContext.state === 'suspended') audioContext.resume();

        if (audioContext) {
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
        }
      } catch (e) {
        console.warn('Audio play err:', e);
      }
      doVibrate();
    }

    function startRepeatingAlarm() {
      const orderKey = activeTrackedOrderNum || localStorage.getItem('activeOrderNum') || '1';
      if (localStorage.getItem('alarmDismissed_' + orderKey) === 'true') {
        return;
      }
      if (prevTrackStatus === 'completed' || localStorage.getItem('orderCompleted') === 'true') {
        return;
      }

      document.body.classList.add('alarm-active');
      const numEl = document.getElementById('alarmModalOrderNum');
      const tableEl = document.getElementById('alarmModalTableInfo');
      if (numEl) numEl.innerText = activeTrackedOrderNum || localStorage.getItem('activeOrderNum') || '#1';
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
    }

    function stopAlarm() {
      const orderKey = activeTrackedOrderNum || localStorage.getItem('activeOrderNum') || '1';
      try {
        localStorage.setItem('alarmDismissed_' + orderKey, 'true');
      } catch(e) {}

      if (alarmInterval) {
        clearInterval(alarmInterval);
        alarmInterval = null;
      }
      stopVibrationLoop();
      document.body.classList.remove('alarm-active');
      const modal = document.getElementById('readyAlarmModal');
      if (modal) modal.style.display = 'none';
      const box = document.getElementById('readyAlarmBox');
      if (box) box.style.display = 'none';
    }

    function testAlarm() {
      const orderKey = activeTrackedOrderNum || localStorage.getItem('activeOrderNum') || '1';
      try {
        localStorage.removeItem('alarmDismissed_' + orderKey);
        localStorage.removeItem('orderCompleted');
      } catch(e) {}
      startRepeatingAlarm();
    }

    function connectCustomerWs() {
      const loc = window.location;
      const wsUrl = (loc.protocol === 'https:' ? 'wss://' : 'ws://') + loc.host + '/ws';
      try {
        custWs = new WebSocket(wsUrl);
        custWs.onmessage = (e) => {
          try {
            const data = JSON.parse(e.data);
            if (data.type === 'SYNC_ORDERS' && (activeTrackedOrderId || activeTrackedOrderNum)) {
              const cleanId = (activeTrackedOrderId || '').toLowerCase();
              const cleanNum = (activeTrackedOrderNum || '').toLowerCase();
              const found = (data.orders || []).find(o => {
                const oid = (o.id || '').toLowerCase();
                const onum = (o.orderNumber || '').toLowerCase();
                return oid === cleanId || onum === cleanNum || onum === cleanId;
              });
              if (found && found.status) {
                updateTrackerUI(found.status);
              }
              // Also update live queue from the broadcast order list
              const orders = data.orders || [];
              const nowPreparing = orders.filter(o => ['preparing','brewing','kitchen'].includes((o.status||'').toLowerCase())).map(o => o.orderNumber || '');
              const inQueue = orders.filter(o => ['confirmed','inqueue','queue'].includes((o.status||'').toLowerCase())).map(o => o.orderNumber || '');
              const nowReady = orders.filter(o => (o.status||'').toLowerCase() === 'ready').map(o => o.orderNumber || '');
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
              <span class="item-cat-badge">\${item.categoryLabel || item.category}</span>
              <div class="item-card-name">\${item.name}</div>
              <div class="item-card-desc">\${item.description || ''}</div>
            </div>
            <div class="item-card-bottom">
              <span class="item-price">₱\${Math.round(item.price)}</span>
              <button class="btn-add-pill" onclick="event.stopPropagation(); openCustomModal('\${item.id}')">
                + Add
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
      
      const imgUrl = selectedItem.imageBase64 ? ('data:image/png;base64,' + selectedItem.imageBase64) : (selectedItem.imageUrl || (selectedItem.imagePath ? `/api/item-image?id=\${selectedItem.id}` : ''));
      document.getElementById('modalImageContainer').innerHTML = imgUrl ? `
        <div style="width: 100%; height: 150px; border-radius: var(--radius-md); overflow: hidden; margin-bottom: 14px; background: rgba(0,0,0,0.4); border: 1px solid var(--border-gold);">
          <img src="\${imgUrl}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.parentElement.style.display='none'">
        </div>
      ` : '';

      document.getElementById('modalItemName').innerText = selectedItem.name;
      document.getElementById('modalItemDesc').innerText = selectedItem.description || '';
      document.getElementById('modalItemNotes').value = '';

      const container = document.getElementById('customGroupContainer');
      const groups = selectedItem.customizations || [];

      container.innerHTML = groups.map((g, gIdx) => {
        return `
          <div class="opt-group-title">\${g.groupTitle}</div>
          <div class="opt-grid">
            \${g.options.map((opt, oIdx) => {
              const isDefault = opt.isDefault || (!g.isMultiSelect && oIdx === 0);
              const extraText = opt.priceAdjustment > 0 ? ` (+₱\${Math.round(opt.priceAdjustment)})` : '';
              if (isDefault) {
                selectedCustomizations.push({
                  groupTitle: g.groupTitle,
                  optionName: opt.name,
                  extraPrice: opt.priceAdjustment || 0,
                  isMulti: g.isMultiSelect
                });
              }
              return `
                <div class="opt-chip \${isDefault ? 'selected' : ''}" onclick="toggleCustomOption(\${gIdx}, \${oIdx}, this)">
                  \${opt.name}\${extraText}
                </div>
              `;
            }).join('')}
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
        el.parentElement.querySelectorAll('.opt-chip').forEach(c => c.classList.remove('selected'));
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
        if (el.classList.contains('selected')) {
          selectedCustomizations.push({
            groupTitle: group.groupTitle,
            optionName: opt.name,
            extraPrice: opt.priceAdjustment || 0,
            isMulti: true
          });
        } else {
          selectedCustomizations = selectedCustomizations.filter(c => !(c.groupTitle === group.groupTitle && c.optionName === opt.name));
        }
      }
      updateModalAddButtonPrice();
    }

    function updateModalAddButtonPrice() {
      const extraTotal = selectedCustomizations.reduce((sum, c) => sum + (c.extraPrice || 0), 0);
      const unitTotal = selectedItem.price + extraTotal;
      const grandTotal = unitTotal * modalItemQty;
      document.getElementById('btnAddItemToCart').innerText = `Add to Tray (₱\${Math.round(grandTotal)})`;
    }

    function confirmAddToCart() {
      const notes = document.getElementById('modalItemNotes').value.trim();
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

      closeModal('customModal');
      updateCartBar();
    }

    function updateCartBar() {
      const count = cart.reduce((sum, i) => sum + i.quantity, 0);
      const total = cart.reduce((sum, i) => sum + (i.unitPrice * i.quantity), 0);

      if (count > 0) {
        document.getElementById('cartBar').style.display = 'flex';
        document.getElementById('cartCountText').innerText = `\${count} item\${count > 1 ? 's' : ''}`;
        document.getElementById('cartTotalText').innerText = `₱\${Math.round(total)}`;
      } else {
        document.getElementById('cartBar').style.display = 'none';
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
        return `
          <div style="background: var(--bg-card); border-radius: var(--radius-md); border: 1px solid var(--border-subtle); padding: 12px; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center;">
            <div style="flex: 1; padding-right: 8px;">
              <div style="font-weight: 700; font-size: 14px; color: var(--text-light);">\${item.name}</div>
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
        const custName = (custNameEl && custNameEl.value.trim()) ? custNameEl.value.trim() : `Guest (\${currentTable})`;

        const payload = {
          tableNumber: currentTable,
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
        submitTimeout = setTimeout(() => controller.abort(), 10000);

        const res = await fetch('/api/customer/order', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
          signal: controller.signal
        });
        if (submitTimeout) clearTimeout(submitTimeout);

        let data = null;
        try {
          data = await res.json();
        } catch (_) {}

        if (data && data.success && data.orderId) {
          const submittedItems = cart.slice();
          cart = [];
          updateCartBar();
          closeModal('trayModal');
          startOrderTracking(data.orderId, data.orderNumber, data.totalAmount, (data.items && data.items.length > 0) ? data.items : submittedItems);
        } else {
          showSuccessModal({
            title: 'Order Notice',
            message: (data && data.error) ? data.error : 'Could not submit order. Please try again.',
            buttonText: 'OK'
          });
        }
      } catch (err) {
        if (submitTimeout) clearTimeout(submitTimeout);
        showSuccessModal({
          title: 'Connection Notice',
          message: 'Could not connect to Cafe server or request timed out. Please ensure you are connected to the Cafe hotspot and try again.',
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

    function startOrderTracking(orderId, orderNumber, total, items) {
      activeTrackedOrderId = orderId;
      activeTrackedOrderNum = orderNumber;
      prevTrackStatus = 'pending';
      if (items && Array.isArray(items)) {
        activeTrackedItems = items;
      }

      try {
        localStorage.setItem('activeOrderId', orderId);
        localStorage.setItem('activeOrderNum', orderNumber);
        localStorage.setItem('activeOrderTotal', total);
        localStorage.setItem('activeTableNumber', currentTable);
        if (items && items.length > 0) {
          localStorage.setItem('activeOrderItems', JSON.stringify(items));
        }
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
      updateTrackerUI('pending');

      if (pollInterval) clearInterval(pollInterval);
      checkOrderStatus();
      pollInterval = setInterval(checkOrderStatus, 1500);
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

          // Order gone from server (deleted/cancelled/purged)
          if (!data || data.success === false) {
            if (pollInterval) { clearInterval(pollInterval); pollInterval = null; }
            newOrder();
            return;
          }

          if (data && data.status) {
            if (data.status === 'cancelled' && prevTrackStatus !== 'cancelled') {
              if (pollInterval) { clearInterval(pollInterval); pollInterval = null; }
              showSuccessModal({
                title: 'Order Cancelled',
                message: 'Your order was cancelled by the cashier.',
                buttonText: 'Return to Menu',
                onDismiss: () => newOrder()
              });
              return;
            }
            updateTrackerUI(data.status);
            if (data.items && Array.isArray(data.items) && data.items.length > 0) {
              activeTrackedItems = data.items;
              try { localStorage.setItem('activeOrderItems', JSON.stringify(data.items)); } catch(e) {}
              renderTrackedItemsList(data.items, data.totalAmount);
            }
            renderLiveQueue(data.currentlyPreparing, data.currentlyInQueue, data.currentlyReady);
          }
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

    function openKitchenQueueModal() {
      const modal = document.getElementById('kitchenQueueModal');
      if (modal) modal.style.display = 'flex';
    }

    function renderLiveQueue(preparingList, queueList, readyList) {
      const nowPrepContainer = document.getElementById('modalNowPreparingChips');
      const inQueueContainer = document.getElementById('modalInQueueChips');
      const readyContainer = document.getElementById('modalReadyChips');
      const nowPrepCount = document.getElementById('modalNowPrepCount');
      const inQueueCount = document.getElementById('modalInQueueCount');
      const readyCount = document.getElementById('modalReadyCount');
      const summaryBadge = document.getElementById('trackerQueueSummaryBadge');

      const currentNum = (activeTrackedOrderNum || localStorage.getItem('activeOrderNum') || '').trim();
      const preps = Array.isArray(preparingList) ? preparingList : [];
      const queue = Array.isArray(queueList) ? queueList : [];
      const ready = Array.isArray(readyList) ? readyList : [];

      if (summaryBadge) {
        summaryBadge.innerText = `\${preps.length} brewing • \${queue.length} in queue`;
      }
      if (nowPrepCount) nowPrepCount.innerText = `\${preps.length} order\${preps.length !== 1 ? 's' : ''}`;
      if (inQueueCount) inQueueCount.innerText = `\${queue.length} in queue`;
      if (readyCount) readyCount.innerText = `\${ready.length} ready`;

      if (nowPrepContainer) {
        if (preps.length === 0) {
          nowPrepContainer.innerHTML = '<span style="font-size: 12px; color: var(--text-muted); font-style: italic;">No orders currently on bar</span>';
        } else {
          nowPrepContainer.innerHTML = preps.map(num => {
            const isMine = currentNum && (num.toLowerCase() === currentNum.toLowerCase() || num.replaceAll('#','').trim() === currentNum.replaceAll('#','').trim());
            if (isMine) {
              return `<span style="background: linear-gradient(135deg, var(--gold-primary) 0%, #B89025 100%); color: #0D0A0F; padding: 6px 12px; border-radius: 14px; font-weight: 800; font-size: 12.5px; box-shadow: 0 0 14px rgba(212,175,55,0.7); display: inline-flex; align-items: center; gap: 5px;"><span>☕ \${num}</span> <span style="font-size: 10px; background: rgba(0,0,0,0.3); color: #fff; padding: 1px 6px; border-radius: 6px;">Your Order!</span></span>`;
            }
            return `<span style="background: rgba(255,159,28,0.2); border: 1.2px solid var(--amber-brewing); color: var(--amber-brewing); padding: 5px 10px; border-radius: 10px; font-weight: 700; font-size: 12px;">☕ \${num}</span>`;
          }).join('');
        }
      }

      if (inQueueContainer) {
        if (queue.length === 0) {
          inQueueContainer.innerHTML = '<span style="font-size: 12px; color: var(--text-muted);">Queue is currently clear</span>';
        } else {
          inQueueContainer.innerHTML = queue.map(num => {
            const isMine = currentNum && (num.toLowerCase() === currentNum.toLowerCase() || num.replaceAll('#','').trim() === currentNum.replaceAll('#','').trim());
            if (isMine) {
              return `<span style="background: rgba(46,196,182,0.25); border: 1.2px solid var(--emerald); color: var(--emerald); padding: 5px 11px; border-radius: 10px; font-weight: 800; font-size: 12px; display: inline-flex; align-items: center; gap: 5px;"><span>📋 \${num}</span> <span style="font-size: 9.5px; background: rgba(46,196,182,0.35); padding: 1px 5px; border-radius: 4px;">Your Ticket</span></span>`;
            }
            return `<span style="background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.14); color: var(--text-light); padding: 4px 9px; border-radius: 8px; font-weight: 600; font-size: 11.5px;">\${num}</span>`;
          }).join('');
        }
      }

      if (readyContainer) {
        if (ready.length === 0) {
          readyContainer.innerHTML = '<span style="font-size: 12px; color: var(--text-muted);">No orders at pickup counter</span>';
        } else {
          readyContainer.innerHTML = ready.map(num => {
            const isMine = currentNum && (num.toLowerCase() === currentNum.toLowerCase() || num.replaceAll('#','').trim() === currentNum.replaceAll('#','').trim());
            if (isMine) {
              return `<span style="background: linear-gradient(135deg, var(--emerald) 0%, #1FA295 100%); color: #000; padding: 5px 11px; border-radius: 10px; font-weight: 900; font-size: 12px; box-shadow: 0 0 12px var(--emerald-glow); display: inline-flex; align-items: center; gap: 5px;"><span>✨ \${num}</span> <span style="font-size: 9.5px; background: rgba(0,0,0,0.3); color: #fff; padding: 1px 5px; border-radius: 4px;">Ready Now!</span></span>`;
            }
            return `<span style="background: rgba(46,196,182,0.18); border: 1px solid var(--emerald); color: var(--emerald); padding: 4px 9px; border-radius: 8px; font-weight: 700; font-size: 11.5px;">✨ \${num}</span>`;
          }).join('');
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
                <span style="font-weight:700;color:var(--text-light);font-size:13.5px;">\${i.name || i.menuItem?.name || 'Item'}</span>
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
      const modal = document.getElementById('orderReceiptModal');
      const subEl = document.getElementById('modalReceiptSub');
      const statusEl = document.getElementById('modalReceiptStatus');
      const totalEl = document.getElementById('modalReceiptTotal');

      if (subEl) subEl.innerText = `Ticket \${activeTrackedOrderNum || '#1'} • \${currentTable} • Dine-In`;

      const s = (prevTrackStatus || 'pending').toLowerCase();
      let statusLabel = 'Awaiting Cashier Confirmation';
      if (s === 'confirmed' || s === 'inqueue') statusLabel = 'Paid • In Kitchen Queue';
      else if (s === 'preparing' || s === 'brewing' || s === 'kitchen') statusLabel = 'Brewing / Preparing in Kitchen';
      else if (s === 'ready') statusLabel = 'Ready for Pickup';
      else if (s === 'completed') statusLabel = 'Completed';
      if (statusEl) statusEl.innerText = statusLabel;

      const savedTotal = localStorage.getItem('activeOrderTotal') || '0';
      renderTrackedItemsList(activeTrackedItems, parseFloat(savedTotal) || 0);

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
      const headerTag = document.getElementById('trackerHeaderTag');
      const pendingActions = document.getElementById('pendingActionButtons');

      const orderAnotherBtn = document.getElementById('btnOrderAnotherItem');

      if (s === 'pending') {
        if (headerTag) headerTag.innerText = 'ORDER PLACED • AWAITING CASHIER';
        if (pendingNotice) pendingNotice.style.display = 'block';
        if (confirmedNotice) confirmedNotice.style.display = 'none';
        if (brewingNotice) brewingNotice.style.display = 'none';
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
        if (orderAnotherBtn) orderAnotherBtn.style.display = 'inline-flex';
        step1.className = 'status-step completed';
        step2.className = 'status-step completed';
        step3.className = 'status-step active';

        // Only start repeating alarm if live transitioning from kitchen into ready
        if (prevTrackStatus === 'preparing' || prevTrackStatus === 'brewing' || prevTrackStatus === 'confirmed' || prevTrackStatus === 'inqueue') {
          const orderKey = activeTrackedOrderNum || localStorage.getItem('activeOrderNum') || '1';
          if (localStorage.getItem('alarmDismissed_' + orderKey) !== 'true') {
            startRepeatingAlarm();
          }
        }
      } else if (s === 'completed') {
        if (headerTag) headerTag.innerText = 'ORDER COMPLETED • ENJOY!';
        if (pendingNotice) pendingNotice.style.display = 'none';
        if (confirmedNotice) confirmedNotice.style.display = 'none';
        if (brewingNotice) brewingNotice.style.display = 'none';
        const compNotice = document.getElementById('completedNotice');
        if (compNotice) compNotice.style.display = 'block';
        if (pendingActions) pendingActions.style.display = 'none';
        if (orderAnotherBtn) orderAnotherBtn.style.display = 'inline-flex';
        step1.className = 'status-step completed';
        step2.className = 'status-step completed';
        step3.className = 'status-step completed';
        stopAlarm();

        try {
          localStorage.removeItem('activeOrderId');
          localStorage.removeItem('activeOrderNum');
          localStorage.removeItem('activeOrderTotal');
          localStorage.removeItem('activeOrderItems');
          localStorage.setItem('orderCompleted', 'true');
        } catch(e) {}
      }
      prevTrackStatus = s;
    }

    async function cancelCustomerOrder() {
      const targetId = activeTrackedOrderId || activeTrackedOrderNum || localStorage.getItem('activeOrderId') || localStorage.getItem('activeOrderNum');
      const orderNum = activeTrackedOrderNum || localStorage.getItem('activeOrderNum') || '';
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
          const currentTargetId = activeTrackedOrderId || activeTrackedOrderNum || localStorage.getItem('activeOrderId') || localStorage.getItem('activeOrderNum');
          const currentOrderNum = activeTrackedOrderNum || localStorage.getItem('activeOrderNum') || '';
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
                localStorage.removeItem('activeOrderId');
                localStorage.removeItem('activeOrderNum');
                localStorage.removeItem('activeOrderTotal');
                localStorage.removeItem('activeOrderItems');
                localStorage.removeItem('orderCompleted');
              } catch(e) {}
              showSuccessModal({
                title: 'Order Cancelled',
                message: `Order \${currentOrderNum || ''} has been cancelled successfully. You can now place a new order.`,
                buttonText: 'Return to Menu',
                onDismiss: () => newOrder()
              });
            } else {
              const errMsg = (data && data.error) ? data.error : 'Cannot cancel order at this time. Please speak with the cashier directly.';
              showSuccessModal({
                title: 'Cancellation Notice',
                message: errMsg,
                buttonText: 'OK',
                onDismiss: () => {
                  if (btn) {
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

    function newOrder() {
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
        // Clear all order-related localStorage including stale alarm flags
        const keys = [];
        for (let i = 0; i < localStorage.length; i++) {
          const k = localStorage.key(i);
          if (k && k.startsWith('alarmDismissed_')) keys.push(k);
        }
        keys.forEach(k => localStorage.removeItem(k));
        localStorage.removeItem('activeOrderId');
        localStorage.removeItem('activeOrderNum');
        localStorage.removeItem('activeOrderTotal');
        localStorage.removeItem('activeOrderItems');
        localStorage.removeItem('activeTableNumber');
        localStorage.removeItem('orderCompleted');
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

      closeModal('trayModal');
      closeModal('customModal');
      closeModal('orderReceiptModal');
      closeModal('confirmModal');
      closeModal('successModal');
      closeModal('readyAlarmModal');
      closeModal('kitchenQueueModal');

      document.getElementById('trackerView').style.display = 'none';
      document.getElementById('controlsWrapper').style.display = 'block';
      document.getElementById('menuView').style.display = 'block';
      updateCartBar();
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    function restoreActiveOrderIfAny() {
      try {
        if (localStorage.getItem('orderCompleted') === 'true') {
          newOrder();
          return;
        }

        const savedId = localStorage.getItem('activeOrderId');
        const savedNum = localStorage.getItem('activeOrderNum');
        const savedTotal = parseFloat(localStorage.getItem('activeOrderTotal') || '0');
        const savedTable = localStorage.getItem('activeTableNumber');
        if (savedTable) {
          currentTable = savedTable;
          const tableSel = document.getElementById('tableSelect');
          if (tableSel) tableSel.value = savedTable;
        }

        let savedItems = [];
        try {
          savedItems = JSON.parse(localStorage.getItem('activeOrderItems') || '[]');
        } catch(e) {}

        if (savedId || savedNum) {
          // 1. Immediately restore tracking view synchronously
          startOrderTracking(savedId || savedNum, savedNum || savedId, savedTotal, savedItems);

          // 2. Fetch latest status from server in background
          const qId = savedId || savedNum;
          fetch(`/api/order-status?orderId=\${encodeURIComponent(qId)}`)
            .then(r => r.json())
            .then(data => {
              // Order not found on server (cancelled, purged, or never existed)
              if (!data || data.success === false) {
                newOrder();
                return;
              }
              if (data && data.status) {
                if (data.status === 'cancelled') {
                  newOrder();
                } else if (data.status === 'completed') {
                  updateTrackerUI('completed');
                } else {
                  const itemsToUse = (data.items && Array.isArray(data.items) && data.items.length > 0) ? data.items : savedItems;
                  const totalToUse = (data.totalAmount !== undefined && data.totalAmount !== null) ? data.totalAmount : savedTotal;
                  startOrderTracking(savedId || savedNum, savedNum || savedId, totalToUse, itemsToUse);
                  updateTrackerUI(data.status);
                  renderLiveQueue(data.currentlyPreparing, data.currentlyInQueue, data.currentlyReady);
                }
              }
            })
            .catch(() => {});
        }
      } catch(e) {}
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
