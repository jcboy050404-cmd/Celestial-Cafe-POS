import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/order.dart';
import 'web_templates/customer_web_template.dart';
import 'web_templates/kds_web_template.dart';

typedef OrderStatusUpdateCallback = void Function(String orderId, String newStatus);
typedef OrderItemPreparedCallback = void Function(String orderId, int itemIndex, bool isPrepared);
typedef CustomerOrderCallback = Map<String, dynamic> Function(Map<String, dynamic> rawOrder);
typedef CustomerChangeOrderCallback = Map<String, dynamic> Function(String orderId);
typedef CustomerCancelOrderCallback = Map<String, dynamic> Function(String orderId);
typedef CustomerFeedbackCallback = Map<String, dynamic> Function(Map<String, dynamic> rawFeedback);
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
  CustomerFeedbackCallback? onCustomerFeedbackSubmitted;
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

  static const String _tableSecretSalt = 'Celestial_Cafe_Table_Sign_2026_SecureKey';

  static String getTableToken(String tableNumber) {
    final cleanTable = tableNumber.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (cleanTable.isEmpty) return '';
    final bytes = utf8.encode('table:$cleanTable:$_tableSecretSalt');
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8).toUpperCase();
  }

  static ({String tableNumber, String? token}) parseTableAndToken(String? rawTable, String? rawToken) {
    if (rawTable == null || rawTable.trim().isEmpty) {
      return (tableNumber: '', token: null);
    }
    final cleaned = rawTable.trim();
    String? token = (rawToken != null && rawToken.trim().isNotEmpty) ? rawToken.trim() : null;

    if (cleaned.contains('-') || cleaned.contains('_')) {
      final parts = cleaned.split(RegExp(r'[-_]'));
      if (parts.length >= 2) {
        final tablePart = parts[0].replaceAll(RegExp(r'[^0-9]'), '').trim();
        final tokenPart = parts.sublist(1).join('-').trim();
        return (tableNumber: tablePart, token: token ?? tokenPart);
      }
    }

    final tablePart = cleaned.replaceAll(RegExp(r'[^0-9]'), '').trim();
    return (tableNumber: tablePart, token: token);
  }

  static bool isValidTableToken(String tableNumber, String? token) {
    final parsed = parseTableAndToken(tableNumber, token);
    if (parsed.tableNumber.isEmpty || parsed.token == null || parsed.token!.trim().isEmpty) {
      return false;
    }
    final expected = getTableToken(parsed.tableNumber);
    return parsed.token!.trim().toLowerCase() == expected.toLowerCase();
  }

  String getTableOrderUrl(String tableNumber) {
    final cleanTable = tableNumber.replaceAll(RegExp(r'[^0-9]'), '').trim();
    final token = getTableToken(cleanTable);
    return 'http://$_localIp:$_port/order?table=T$cleanTable-$token';
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
    CustomerFeedbackCallback? onCustomerFeedbackSubmitted,
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
    this.onCustomerFeedbackSubmitted = onCustomerFeedbackSubmitted;
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

  void _broadcastToSockets(Iterable<WebSocket> targetClients, String payload) {
    final deadClients = <WebSocket>[];
    for (var client in List<WebSocket>.from(targetClients)) {
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
  }

  void _doBroadcastOrders() {
    if (getActiveOrdersJson == null) return;
    try {
      final ordersList = getActiveOrdersJson!();
      final payload = jsonEncode({
        'type': 'SYNC_ORDERS',
        'orders': ordersList,
      });
      _broadcastToSockets(_baristaClients, payload);
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
      _broadcastToSockets(_baristaClients, payload);
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
      _broadcastToSockets(_clients, payload);
    } catch (e) {
      if (kDebugMode) print('Error broadcasting order status update: $e');
    }
  }

  void broadcastMenu(List<Map<String, dynamic>> menuList) {
    try {
      final payload = jsonEncode({
        'type': 'SYNC_MENU',
        'menu': menuList,
      });
      _broadcastToSockets(_clients, payload);
    } catch (e) {
      if (kDebugMode) print('Error broadcasting menu update: $e');
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
    } else if (path.startsWith('/assets/images/') || path.startsWith('/images/')) {
      _serveAssetImage(request);
    } else if (path == '/audio/order-ready.wav' || path == '/order-ready.wav') {
      _serveOrderReadyAudio(request);
    } else if (path.startsWith('/api/item-image') || path.startsWith('/item-image')) {
      _serveItemImage(request);
    } else if (path == '/api/qr' || path.startsWith('/api/qr')) {
      _serveQrSvg(request);
    } else if (path.startsWith('/order') || path.startsWith('/menu') || path.startsWith('/table') || path.startsWith('/track') || path.startsWith('/claim') || path.startsWith('/status')) {
      _serveCustomerOrderWebPage(request);
    } else if (path.startsWith('/api/barista/verify-pin') || path.startsWith('/api/verify-pin')) {
      _handleBaristaVerifyPinApi(request);
    } else if (path.startsWith('/api/verify-table')) {
      _handleVerifyTableApi(request);
    } else if (path.startsWith('/api/menu')) {
      _handleMenuApi(request);
    } else if (path.startsWith('/api/customer/order')) {
      _handleCustomerOrderApi(request);
    } else if (path.startsWith('/api/customer/change-order')) {
      _handleCustomerChangeOrderApi(request);
    } else if (path.startsWith('/api/customer/cancel-order') || path.startsWith('/api/cancel-order')) {
      _handleCustomerCancelOrderApi(request);
    } else if (path.startsWith('/api/customer/feedback') || path.startsWith('/api/feedback')) {
      _handleCustomerFeedbackApi(request);
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

  void _serveQrSvg(HttpRequest request) {
    try {
      final data = request.uri.queryParameters['data'] ?? '';
      final cleanData = data.trim().isEmpty ? 'CELESTIAL-CAFE-ORDER' : data.trim();
      final qrCode = QrCode.fromData(
        data: cleanData,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final qrImage = QrImage(qrCode);
      final count = qrImage.moduleCount;
      final buf = StringBuffer();
      buf.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \$count \$count" width="100%" height="100%" shape-rendering="crispEdges">');
      buf.write('<rect width="100%" height="100%" fill="#FFFFFF"/>');
      for (int r = 0; r < count; r++) {
        for (int c = 0; c < count; c++) {
          if (qrImage.isDark(r, c)) {
            buf.write('<rect x="\$c" y="\$r" width="1" height="1" fill="#000000"/>');
          }
        }
      }
      buf.write('</svg>');
      final bytes = utf8.encode(buf.toString());
      request.response
        ..headers.contentType = ContentType('image', 'svg+xml')
        ..headers.add('Cache-Control', 'public, max-age=86400')
        ..statusCode = HttpStatus.ok
        ..add(bytes)
        ..close();
    } catch (_) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..close();
    }
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

  void _serveAssetImage(HttpRequest request) async {
    try {
      String rawPath = request.uri.path;
      if (rawPath.startsWith('/')) rawPath = rawPath.substring(1);
      if (!rawPath.startsWith('assets/')) {
        rawPath = 'assets/$rawPath';
      }
      Uint8List? bytes;
      try {
        final byteData = await rootBundle.load(rawPath);
        bytes = byteData.buffer.asUint8List();
      } catch (_) {
        final f = File(rawPath);
        if (f.existsSync()) {
          bytes = f.readAsBytesSync();
        }
      }
      if (bytes != null && bytes.isNotEmpty) {
        final isJpg = rawPath.endsWith('.jpg') || rawPath.endsWith('.jpeg');
        request.response
          ..headers.contentType = isJpg ? ContentType('image', 'jpeg') : ContentType('image', 'png')
          ..headers.add('Cache-Control', 'public, max-age=86400, immutable')
          ..headers.add('Access-Control-Allow-Origin', '*')
          ..statusCode = HttpStatus.ok
          ..add(bytes)
          ..close();
        return;
      }
    } catch (_) {}
    request.response.statusCode = HttpStatus.notFound;
    request.response.close();
  }

  Uint8List? _cachedOrderReadyAudioBytes;

  void _serveOrderReadyAudio(HttpRequest request) async {
    try {
      if (_cachedOrderReadyAudioBytes == null) {
        try {
          final byteData = await rootBundle.load('assets/audio/order_ready.wav');
          _cachedOrderReadyAudioBytes = byteData.buffer.asUint8List();
        } catch (_) {
          final f = File('assets/audio/order_ready.wav');
          if (f.existsSync()) {
            _cachedOrderReadyAudioBytes = f.readAsBytesSync();
          }
        }
      }
      if (_cachedOrderReadyAudioBytes != null && _cachedOrderReadyAudioBytes!.isNotEmpty) {
        request.response
          ..headers.contentType = ContentType('audio', 'wav')
          ..headers.add('Cache-Control', 'public, max-age=86400, immutable')
          ..headers.add('Access-Control-Allow-Origin', '*')
          ..statusCode = HttpStatus.ok
          ..add(_cachedOrderReadyAudioBytes!)
          ..close();
        return;
      }
    } catch (_) {}
    request.response.statusCode = HttpStatus.notFound;
    request.response.close();
  }

  void _handleVerifyTableApi(HttpRequest request) {
    final tableParam = request.uri.queryParameters['table'] ?? request.uri.queryParameters['t'] ?? '';
    final tokenParam = request.uri.queryParameters['token'] ?? request.uri.queryParameters['key'] ?? request.uri.queryParameters['code'] ?? '';
    final parsed = parseTableAndToken(tableParam, tokenParam);
    final valid = parsed.tableNumber.isNotEmpty && isValidTableToken(parsed.tableNumber, parsed.token);

    request.response
      ..headers.contentType = ContentType.json
      ..statusCode = HttpStatus.ok
      ..write(jsonEncode({
        'success': valid,
        'verified': valid,
        'table': parsed.tableNumber.isNotEmpty ? 'Table ${parsed.tableNumber}' : null,
        'token': valid ? parsed.token : null,
        'fullCode': valid ? 'T${parsed.tableNumber}-${parsed.token}' : null,
        if (!valid) 'error': 'Invalid or missing table QR verification token. Please scan the physical QR code on your table.'
      }))
      ..close();
  }

  void _handleMenuApi(HttpRequest request) {
    final tableParam = request.uri.queryParameters['table'] ?? request.uri.queryParameters['t'];
    final tokenParam = request.uri.queryParameters['token'] ?? request.uri.queryParameters['key'] ?? request.uri.queryParameters['code'];
    if (tableParam != null && tableParam.trim().isNotEmpty) {
      final parsed = parseTableAndToken(tableParam, tokenParam);
      if (parsed.tableNumber.isNotEmpty && !isValidTableToken(parsed.tableNumber, parsed.token)) {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.forbidden
          ..write(jsonEncode({
            'success': false,
            'menu': [],
            'error': 'Menu access blocked. Please scan the physical table QR code to access the menu.'
          }))
          ..close();
        return;
      }
    }

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
          request.uri.queryParameters['order'] ??
          request.uri.queryParameters['num'] ??
          '';
      final cleanId = orderId.trim().toLowerCase().replaceAll('#', '');

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

      if (matchedOrder == null && cleanId.isEmpty) {
        final tableParam = (request.uri.queryParameters['table'] ?? request.uri.queryParameters['t'] ?? '')
            .replaceAll(RegExp(r'table\s*', caseSensitive: false), '')
            .trim();
        if (tableParam.isNotEmpty && activeList.isNotEmpty) {
          for (var o in activeList.reversed) {
            final t = (o['tableNumber'] as String? ?? '').replaceAll(RegExp(r'table\s*', caseSensitive: false), '').trim();
            final s = (o['status'] as String? ?? '').toLowerCase();
            if (t == tableParam && s != 'completed' && s != 'cancelled') {
              matchedOrder = o;
              break;
            }
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
          ..write(jsonEncode(result));
        await request.response.close();
      } else {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.badRequest
          ..write(jsonEncode({'success': false, 'error': 'Missing order ID or change handler not initialized'}));
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
          ..write(jsonEncode(result));
        await request.response.close();
      } else {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({'success': false, 'error': 'Missing order ID or order not found'}));
        await request.response.close();
      }
    } catch (e) {
      try {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({'success': false, 'error': e.toString()}));
        await request.response.close();
      } catch (_) {}
    }
  }

  void _handleCustomerFeedbackApi(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join().timeout(const Duration(seconds: 10));
      final data = (content.trim().isNotEmpty) ? jsonDecode(content) as Map<String, dynamic> : <String, dynamic>{};

      Map<String, dynamic> result = {'success': true, 'message': 'Feedback accepted'};
      if (onCustomerFeedbackSubmitted != null && data.isNotEmpty) {
        result = onCustomerFeedbackSubmitted!(data);
      }

      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode(result));
      await request.response.close();
    } catch (e, stack) {
      if (kDebugMode) print('Error in _handleCustomerFeedbackApi: $e\n$stack');
      try {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({'success': false, 'error': e.toString()}));
        await request.response.close();
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
    final tokenParam = request.uri.queryParameters['token'] ?? request.uri.queryParameters['key'] ?? request.uri.queryParameters['code'];
    final parsed = parseTableAndToken(raw, tokenParam);
    final tableNum = parsed.tableNumber;
    if (tableNum.isEmpty || !isValidTableToken(tableNum, parsed.token)) {
      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'success': false, 'error': 'Table QR verification required'}))
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
      _gzippedKdsHtml ??= gzip.encode(utf8.encode(kdsHtmlTemplate));
      request.response
        ..headers.add(HttpHeaders.contentEncodingHeader, 'gzip')
        ..statusCode = HttpStatus.ok
        ..add(_gzippedKdsHtml!)
        ..close();
    } else {
      request.response
        ..statusCode = HttpStatus.ok
        ..write(kdsHtmlTemplate)
        ..close();
    }
  }

  static String? _cachedMenuJson;
  static String? _cachedCustomerHtml;

  void _serveCustomerOrderWebPage(HttpRequest request) {
    final menuJson = jsonEncode(getMenuCallback != null ? getMenuCallback!() : []);

    String? rawTable = request.uri.queryParameters['table'] ?? request.uri.queryParameters['t'];
    if (rawTable == null) {
      final segments = request.uri.pathSegments;
      for (int i = 0; i < segments.length; i++) {
        final s = segments[i].toLowerCase();
        if ((s == 'table' || s == 't') && i + 1 < segments.length) {
          rawTable = segments[i + 1];
          break;
        } else if (s.startsWith('table') && s.length > 5) {
          rawTable = s.substring(5);
          break;
        }
      }
    }

    final token = request.uri.queryParameters['token'] ?? request.uri.queryParameters['key'] ?? request.uri.queryParameters['code'];
    final parsed = parseTableAndToken(rawTable, token);
    final cleanTable = parsed.tableNumber;
    final validToken = parsed.token;

    final bool hasTableAttempt = cleanTable.isNotEmpty;
    final bool isVerified = hasTableAttempt && isValidTableToken(cleanTable, validToken);

    final tableAuthJson = jsonEncode({
      'hasTableAttempt': hasTableAttempt,
      'isVerified': isVerified,
      'tableNumber': isVerified ? 'Table $cleanTable' : (hasTableAttempt ? 'Table $cleanTable' : null),
      'cleanTable': isVerified ? cleanTable : null,
      'token': isVerified ? validToken : null,
      'fullCode': isVerified ? 'T$cleanTable-$validToken' : null,
      'error': (hasTableAttempt && !isVerified)
          ? 'Physical QR code scan required. Table cannot be accessed by manually editing the link.'
          : null,
    });

    final bool isBlocked = hasTableAttempt && !isVerified;
    final String effectiveMenuJson = isBlocked ? '[]' : menuJson;

    String baseHtml;
    if (_cachedMenuJson == effectiveMenuJson && _cachedCustomerHtml != null) {
      baseHtml = _cachedCustomerHtml!;
    } else {
      baseHtml = customerOrderHtmlTemplate.replaceFirst(
        '/*__INITIAL_MENU_DATA__*/',
        'window.INITIAL_MENU = $effectiveMenuJson;',
      );
      _cachedMenuJson = effectiveMenuJson;
      _cachedCustomerHtml = baseHtml;
    }

    final html = baseHtml.replaceFirst(
      '/*__TABLE_AUTH_DATA__*/',
      'window.TABLE_AUTH = $tableAuthJson;',
    );

    final acceptEncoding = request.headers.value(HttpHeaders.acceptEncodingHeader) ?? '';
    final canGzip = acceptEncoding.contains('gzip');

    request.response
      ..headers.contentType = ContentType.html
      ..headers.add('Cache-Control', 'no-cache, no-store, must-revalidate');

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
}