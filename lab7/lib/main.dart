import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:yandex_mapkit/yandex_mapkit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Lab6App());
}

/// Приложение на Cupertino, чтобы стилистика экрана списка/карты совпадала.
class Lab6App extends StatelessWidget {
  const Lab6App({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'ЛР6 — Яндекс.Карта',
      home: Lab6YandexScreen(),
    );
  }
}

class Lab6YandexScreen extends StatefulWidget {
  const Lab6YandexScreen({super.key});
  @override
  State<Lab6YandexScreen> createState() => _Lab6YandexScreenState();
}

class _Lab6YandexScreenState extends State<Lab6YandexScreen> {
  static const String kDefaultEndpoint =
      'http://pstgu.yss.su/iu9/mobiledev/lab4_yandex_map/2023.php?x=var15';

  final _urlCtrl = TextEditingController(text: kDefaultEndpoint);

  bool _loading = false;
  String? _error;
  final List<_Org> _orgs = [];

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _orgs.clear();
    });

    try {
      // Пробуем напрямую...
      final body = await _fetchBody(url);
      await _parseAndSet(body);
    } on SocketException catch (_) {
      // Если DNS/host lookup упал — резерв через https-прокси (обходной путь)
      final proxy = _wrapWithProxy(url);
      try {
        final body = await _fetchBody(proxy);
        await _parseAndSet(body);
        _toast('Основной хост недоступен. Загрузил через прокси.');
      } catch (e2) {
        _error = 'Ошибка загрузки: $e2';
      }
    } catch (e) {
      _error = 'Ошибка загрузки: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _fetchBody(String url) async {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}');
    }
    return const Utf8Decoder(allowMalformed: true).convert(r.bodyBytes);
  }

  Future<void> _parseAndSet(String body) async {
    final jsonArrayString = _firstJsonArray(body);
    if (jsonArrayString == null) {
      throw Exception('Невозможно извлечь JSON-массив из ответа');
    }
    final rawList = jsonDecode(jsonArrayString);
    if (rawList is! List) {
      throw Exception('Ответ не является списком');
    }
    for (final raw in rawList) {
      if (raw is Map) {
        final org = _Org.tryParse(raw);
        if (org != null) _orgs.add(org);
      }
    }
    if (_orgs.isEmpty) {
      throw Exception('Список объектов пуст');
    }
    setState(() {}); // обновим UI
  }

  String _wrapWithProxy(String src) {
    if (src.startsWith('https://')) return src;
    return 'https://r.jina.ai/$src'; // отдаёт http-контент по https
  }

  String? _firstJsonArray(String s) {
    final start = s.indexOf('[');
    if (start < 0) return null;
    var level = 0;
    for (var i = start; i < s.length; i++) {
      final ch = s[i];
      if (ch == '[') level++;
      if (ch == ']') {
        level--;
        if (level == 0) return s.substring(start, i + 1);
      }
    }
    return null;
  }

  void _openMap({int? focusIndex}) {
    if (_orgs.isEmpty) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => Lab6MapScreen(
          orgs: List<_Org>.from(_orgs),
          focusIndex: focusIndex,
        ),
      ),
    );
  }

  void _toast(String msg) {
    // простой тост через диалог
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('ЛР6 — Яндекс.Карты'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Источник данных',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _urlCtrl,
                    placeholder: 'http://.../2023.php?x=var15',
                    keyboardType: TextInputType.url,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    onSubmitted: (_) => _load(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton.filled(
                          onPressed: _loading ? null : _load,
                          child: Text(_loading ? '...' : 'Загрузить'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CupertinoButton(
                          onPressed: _orgs.isEmpty ? null : () => _openMap(),
                          child: const Text('Показать все на карте'),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style:
                            const TextStyle(color: CupertinoColors.systemRed)),
                  ],
                ],
              ),
            ),
            if (_loading)
              const Center(child: CupertinoActivityIndicator())
            else if (_orgs.isNotEmpty)
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Объекты',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...List.generate(_orgs.length, (i) {
                      final o = _orgs[i];
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: CupertinoColors.separator
                                  .resolveFrom(context),
                              width: i == _orgs.length - 1 ? 0 : 0.5,
                            ),
                          ),
                        ),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 0),
                          onPressed: () => _openMap(focusIndex: i),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                if ((o.address ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      o.address!,
                                      style: const TextStyle(
                                        color:
                                            CupertinoColors.secondaryLabel,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Экран с картой
class Lab6MapScreen extends StatefulWidget {
  final List<_Org> orgs;
  final int? focusIndex; // если не null — приблизиться к выбранному

  const Lab6MapScreen({
    super.key,
    required this.orgs,
    this.focusIndex,
  });

  @override
  State<Lab6MapScreen> createState() => _Lab6MapScreenState();
}

class _Lab6MapScreenState extends State<Lab6MapScreen> {
  YandexMapController? _map;
  late final List<MapObject> _objects;

  @override
  void initState() {
    super.initState();
    _objects = List.generate(widget.orgs.length, (i) {
      final org = widget.orgs[i];
      return CircleMapObject(
        mapId: MapObjectId('org_$i'),
        circle: Circle(
          center: Point(latitude: org.lat, longitude: org.lon),
          radius: 14,
        ),
        fillColor: Colors.red.withOpacity(0.85),
        strokeColor: Colors.white,
        strokeWidth: 1.0,
        onTap: (_, __) => _showOrg(org),
      );
    });
  }

  Future<void> _onMapCreated(YandexMapController c) async {
    _map = c;
    await _map!.moveCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: Point(latitude: 55.751244, longitude: 37.618423),
          zoom: 9.5,
        ),
      ),
      animation:
          const MapAnimation(type: MapAnimationType.smooth, duration: 0.3),
    );

    if (widget.orgs.isEmpty) return;

    if (widget.focusIndex == null) {
      await _fitAll();
    } else {
      final org =
          widget.orgs[widget.focusIndex!.clamp(0, widget.orgs.length - 1)];
      await _focusOn(org);
      _showOrg(org);
    }
  }

  Future<void> _fitAll() async {
    if (_map == null || widget.orgs.isEmpty) return;

    final lats = widget.orgs.map((e) => e.lat);
    final lons = widget.orgs.map((e) => e.lon);
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLon = lons.reduce((a, b) => a < b ? a : b);
    final maxLon = lons.reduce((a, b) => a > b ? a : b);

    final center = Point(
      latitude: (minLat + maxLat) / 2,
      longitude: (minLon + maxLon) / 2,
    );

    final dLat = (maxLat - minLat).abs();
    final dLon = (maxLon - minLon).abs();
    final spread = (dLat > dLon ? dLat : dLon);

    double zoom;
    if (spread < 0.005) zoom = 16;
    else if (spread < 0.02) zoom = 14;
    else if (spread < 0.1) zoom = 12;
    else if (spread < 0.5) zoom = 10;
    else zoom = 8;

    await _map!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: center, zoom: zoom),
      ),
      animation:
          const MapAnimation(type: MapAnimationType.smooth, duration: 0.7),
    );
  }

  Future<void> _focusOn(_Org org) async {
    if (_map == null) return;
    await _map!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(latitude: org.lat, longitude: org.lon),
          zoom: 16,
        ),
      ),
      animation:
          const MapAnimation(type: MapAnimationType.smooth, duration: 0.6),
    );
  }

  void _showOrg(_Org org) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(org.title, textAlign: TextAlign.center),
        message: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((org.address ?? '').isNotEmpty) Text('Адрес: ${org.address}'),
            if ((org.info ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(org.info!),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Координаты: ${org.lat.toStringAsFixed(6)}, ${org.lon.toStringAsFixed(6)}',
                style: const TextStyle(
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('ЛР6 — Я.Карты (карта)'),
      ),
      child: SafeArea(
        child: YandexMap(
          onMapCreated: _onMapCreated,
          mapObjects: _objects,
        ),
      ),
    );
  }
}

// ─── Модель/парсер под ваш JSON ──────────────────────────────────────────────

class _Org {
  final String title;
  final String? address;
  final String? info; // сюда кладём телефон, если есть
  final double lat;
  final double lon;

  _Org({
    required this.title,
    this.address,
    this.info,
    required this.lat,
    required this.lon,
  });

  static double? _toD(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  /// Поддерживает JSON вида:
  /// [{"name": "...", "gps": "55.78, 38.43", "address": "...", "tel": "..."}]
  static _Org? tryParse(Map raw) {
    final title = (raw['name'] ?? raw['title'] ?? '').toString().trim();
    final addr = raw['address']?.toString();

    final tel = raw['tel']?.toString();
    final info = (tel != null && tel.isNotEmpty) ? 'Телефон: $tel' : null;

    double? lat, lon;

    // gps: "55.780359, 38.434721"
    final gps = raw['gps'];
    if (gps != null) {
      final nums = RegExp(r'-?\d+(?:[.,]\d+)?')
          .allMatches(gps.toString())
          .map((m) => m.group(0)!.replaceAll(',', '.'))
          .toList();
      if (nums.length >= 2) {
        lat = double.tryParse(nums[0]);
        lon = double.tryParse(nums[1]);
      }
    }

    lat ??= _toD(raw['lat'] ?? raw['latitude'] ?? raw['y']);
    lon ??= _toD(raw['lon'] ?? raw['lng'] ?? raw['longitude'] ?? raw['x']);

    if (lat == null || lon == null) return null;

    return _Org(
      title: title.isEmpty ? 'Объект' : title,
      address: addr,
      info: info,
      lat: lat,
      lon: lon,
    );
  }
}

// ─── Простая карточка-секция под iOS стиль ───────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}
