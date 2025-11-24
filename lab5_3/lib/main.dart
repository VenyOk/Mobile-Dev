import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Счётчик слов (WS)',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _kSavedTextKey = 'saved_input_text';
  final _textController = TextEditingController();
  final _serverController = TextEditingController(text: 'ws://127.0.0.1:8765');
  SharedPreferences? _prefs;
  WebSocketChannel? _channel;
  int? _wordCount;
  List<String> _words = [];
  String? _error;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _initPrefsAndRestore();
    _textController.addListener(_persistText);
  }

  Future<void> _initPrefsAndRestore() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs!.getString(_kSavedTextKey);
    if (saved != null && saved.isNotEmpty) {
      _textController.value = TextEditingValue(
        text: saved,
        selection: TextSelection.collapsed(offset: saved.length),
      );
    }
  }

  void _persistText() {
    final p = _prefs;
    if (p != null) {
      p.setString(_kSavedTextKey, _textController.text);
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_persistText);
    _textController.dispose();
    _serverController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  void _connect() {
    _channel?.sink.close();
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_serverController.text));
      _channel!.stream.listen((event) async {
        final data = jsonDecode(event);
        void _applyResultLike(Map<String, dynamic> data) {
          final original = (data['original'] as String?) ?? '';
          final words = original.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
          final count = data['word_count'] is int ? data['word_count'] as int : words.length;
          setState(() {
            _wordCount = count;
            _words = words;
            _error = null;
          });
          if (_textController.text.trim().isEmpty && original.isNotEmpty) {
            _textController.value = TextEditingValue(
              text: original,
              selection: TextSelection.collapsed(offset: original.length),
            );
          }
        }
        if (data['type'] == 'result') {
          _applyResultLike(data);
          final p = _prefs;
          if (p != null) {
            await p.setString(_kSavedTextKey, data['original'] ?? '');
          }
        } else if (data['type'] == 'restore') {
          _applyResultLike(data);
          final p = _prefs;
          if (p != null) {
            await p.setString(_kSavedTextKey, data['original'] ?? '');
          }
        } else if (data['type'] == 'error') {
          setState(() {
            _error = data['message']?.toString();
          });
        }
      }, onError: (e) {
        setState(() {
          _error = e.toString();
        });
      }, onDone: () {
        setState(() {
          _error ??= 'Соединение закрыто';
        });
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _connecting = false;
      });
    }
  }

  void _send() {
    final ch = _channel;
    if (ch == null) {
      setState(() {
        _error = 'Нет соединения с сервером';
      });
      return;
    }
    final payload = jsonEncode({'text': _text_controller_text});
    ch.sink.add(payload);
    _persistText();
  }

  String get _text_controller_text => _textController.text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подсчёт слов по WebSocket')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serverController,
                  decoration: const InputDecoration(
                    labelText: 'WS сервер',
                    hintText: 'ws://185.102.139.168:8765',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _connecting ? null : _connect,
                icon: const Icon(Icons.link),
                label: Text(_channel == null ? 'Подключиться' : 'Переподкл.'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Введите предложение',
              hintText: 'Например:   Привет   мир   это   тест',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _send,
                icon: const Icon(Icons.send),
                label: const Text('Отправить'),
              ),
              const SizedBox(width: 12),
              if (_error != null)
                Flexible(
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: _wordCount == null
                ? const Text('Результат будет здесь')
                : TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
                    tween: Tween(begin: 0, end: _wordCount!.toDouble()),
                    builder: (context, value, _) => Column(
                      children: [
                        Text('Всего слов', style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          value.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (_words.isNotEmpty) ...[
            Text('Слова', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _words.map((w) {
                return Chip(
                  label: Text(w),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _words.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final w = _words[i];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(w),
                    subtitle: Text('длина: ${w.length}'),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
