import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const ArithApp());
}

class ArithApp extends StatelessWidget {
  const ArithApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WS Arithmetic',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const ArithPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ArithPage extends StatefulWidget {
  const ArithPage({super.key});

  @override
  State<ArithPage> createState() => _ArithPageState();
}

class _ArithPageState extends State<ArithPage> {
  late final TextEditingController _aCtrl;
  late final TextEditingController _bCtrl;

  WebSocketChannel? _channel;
  String? _status;
  String _resultText = '—';

  // Слайдеры
  static const double _min = -100.0;
  static const double _max = 100.0;
  double _aVal = 0;
  double _bVal = 0;
  Timer? _debounce;

  // URL WS для Python-сервера ниже (без пути /ws)
  // Android эмулятор: ws://10.0.2.2:8080
  // iOS Simulator:    ws://127.0.0.1:8080
  // Реальное устройство: ws://<IP_ПК>:8080
  String wsUrl = 'ws://127.0.0.1:8080';

  @override
  void initState() {
    super.initState();
    _aCtrl = TextEditingController();
    _bCtrl = TextEditingController();

    // Синхронизация из текстовых полей -> слайдеры + отправка
    _aCtrl.addListener(() => _onTextChanged(isA: true));
    _bCtrl.addListener(() => _onTextChanged(isA: false));

    _connect();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _aCtrl.dispose();
    _bCtrl.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  void _connect() {
    try {
      final ch = WebSocketChannel.connect(Uri.parse(wsUrl));
      setState(() {
        _channel = ch;
        _status = 'Connected';
      });

      ch.stream.listen(
        (msg) {
          final text = msg.toString();
          // Пытаемся разобрать наш протокол
          try {
            final data = jsonDecode(text);
            if (data is Map<String, dynamic>) {
              switch (data['type']) {
                case 'state': // сервер прислал сохранённые a,b
                  final a = (data['a'] as num?)?.toDouble() ?? 0.0;
                  final b = (data['b'] as num?)?.toDouble() ?? 0.0;
                  setState(() {
                    _aVal = a.clamp(_min, _max);
                    _bVal = b.clamp(_min, _max);
                    _aCtrl.text = _aVal.toStringAsFixed(2);
                    _bCtrl.text = _bVal.toStringAsFixed(2);
                  });
                  break;
                case 'calculation_result':
                  setState(() => _resultText = 'Результат: ${data['result']}');
                  break;
                case 'calculation_error':
                  setState(() => _resultText = 'Ошибка: ${data['message']}');
                  break;
              }
              return;
            }
          } catch (_) {}

          // Fallback: текст/другое
          setState(() {
            _resultText = _formatServerMessage(text);
          });
        },
        onError: (e) {
          setState(() {
            _status = 'Error: $e';
            _resultText = 'Ошибка соединения';
          });
        },
        onDone: () {
          setState(() {
            _status = 'Disconnected';
          });
        },
      );

      // Сразу попросим состояние
      _sendJson({'type': 'get_state'});

    } catch (e) {
      setState(() {
        _status = 'Failed to connect: $e';
        _resultText = 'Не удалось подключиться';
      });
    }
  }

  void _sendJson(Map<String, dynamic> map) {
    try {
      _channel?.sink.add(jsonEncode(map));
    } catch (_) {}
  }

  // Текстовые поля -> обновляем слайдеры + отправляем set_ab с дебаунсом
  void _onTextChanged({required bool isA}) {
    final v = _parse(isA ? _aCtrl.text : _bCtrl.text);
    if (v == null) return;
    setState(() {
      if (isA) _aVal = v.clamp(_min, _max);
      else _bVal = v.clamp(_min, _max);
    });
    _scheduleSendSetAB();
  }

  // Слайдеры -> обновляем поля + отправляем set_ab с дебаунсом
  void _onSliderChanged({required bool isA, required double value}) {
    setState(() {
      if (isA) {
        _aVal = value;
        _aCtrl.text = value.toStringAsFixed(2);
      } else {
        _bVal = value;
        _bCtrl.text = value.toStringAsFixed(2);
      }
    });
    _scheduleSendSetAB();
  }

  void _scheduleSendSetAB() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _sendJson({'type': 'set_ab', 'a': _aVal, 'b': _bVal});
    });
  }

  String _formatServerMessage(String msg) {
    try {
      final data = jsonDecode(msg);
      if (data is Map<String, dynamic>) {
        switch (data['type']) {
          case 'calculation_result':
            return 'Результат: ${data['result']}';
          case 'calculation_error':
            return 'Ошибка: ${data['message']}';
          case 'state':
            return 'Служебное состояние получено';
          case 'error':
            return 'Ошибка: ${data['message']}';
        }
      }
    } catch (_) {}
    final low = msg.toLowerCase().trim();
    if (low.startsWith('error:')) return 'Ошибка: ${msg.substring(6).trim()}';
    return 'Результат: $msg';
  }

  double? _parse(String s) {
    if (s.trim().isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  void _sendOp(String op) {
    // Можно считать по текущим полям, но сервер и так хранит их —
    // всё равно передадим на всякий случай.
    final a = _parse(_aCtrl.text);
    final b = _parse(_bCtrl.text);
    if (a == null || b == null) {
      setState(() => _resultText = 'Ошибка: введите корректные числа в a и b');
      return;
    }
    _sendJson({
      'type': 'calculate',
      'a': a,
      'b': b,
      'operation': op,
    });
    setState(() => _resultText = 'Вычисление…');
  }

  @override
  Widget build(BuildContext context) {
    final connected = _status == 'Connected';
    return Scaffold(
      appBar: AppBar(
        title: const Text('WS Arithmetic'),
        actions: [
          IconButton(
            tooltip: 'Reconnect',
            onPressed: _connect,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Server: $wsUrl • ${_status ?? '—'}'),
            const SizedBox(height: 12),

            // Поля ввода
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _aCtrl,
                    decoration: const InputDecoration(
                      labelText: 'a',
                      hintText: 'Число, например 12.5',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _bCtrl,
                    decoration: const InputDecoration(
                      labelText: 'b',
                      hintText: 'Число, например 3',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Слайдер A
            Row(
              children: [
                const SizedBox(width: 28, child: Text('a', textAlign: TextAlign.center)),
                Expanded(
                  child: Slider(
                    value: _aVal.clamp(_min, _max),
                    min: _min,
                    max: _max,
                    divisions: 400,
                    label: _aVal.toStringAsFixed(2),
                    onChanged: (v) => _onSliderChanged(isA: true, value: v),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(_aVal.toStringAsFixed(2), textAlign: TextAlign.right),
                ),
              ],
            ),

            // Слайдер B
            Row(
              children: [
                const SizedBox(width: 28, child: Text('b', textAlign: TextAlign.center)),
                Expanded(
                  child: Slider(
                    value: _bVal.clamp(_min, _max),
                    min: _min,
                    max: _max,
                    divisions: 400,
                    label: _bVal.toStringAsFixed(2),
                    onChanged: (v) => _onSliderChanged(isA: false, value: v),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(_bVal.toStringAsFixed(2), textAlign: TextAlign.right),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Кнопки операций
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: connected ? () => _sendOp('+') : null,
                  child: const Text('+'),
                ),
                ElevatedButton(
                  onPressed: connected ? () => _sendOp('-') : null,
                  child: const Text('-'),
                ),
                ElevatedButton(
                  onPressed: connected ? () => _sendOp('*') : null,
                  child: const Text('×'),
                ),
                ElevatedButton(
                  onPressed: connected ? () => _sendOp('/') : null,
                  child: const Text('÷'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Результат
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Результат:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_resultText),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
