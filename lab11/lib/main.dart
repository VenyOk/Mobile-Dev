import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSH Console',
      debugShowCheckedModeBanner: false,
      home: const Home(),
      theme: ThemeData(useMaterial3: true),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final hostC = TextEditingController(text: 'localhost');
  final portC = TextEditingController(text: '22');
  final userC = TextEditingController();
  final passC = TextEditingController();
  final cmdC = TextEditingController();

  SSHClient? client;
  bool connecting = false;
  bool connected = false;
  String log = '';

  Future<void> connect() async {
    if (connecting || connected) return;
    setState(() => connecting = true);
    try {
      final socket = await SSHSocket.connect(hostC.text.trim(), int.tryParse(portC.text.trim()) ?? 22);
      final c = SSHClient(socket, username: userC.text.trim(), onPasswordRequest: () => passC.text);
      await c.ping();
      setState(() {
        client = c;
        connected = true;
        log = 'CONNECTED ${hostC.text}:${portC.text}\n$log';
      });
    } catch (e) {
      setState(() {
        log = 'ERROR: $e\n$log';
      });
    } finally {
      setState(() => connecting = false);
    }
  }

  Future<void> disconnect() async {
    if (client == null) return;
    try {
      client!.close();
      await client!.done;
    } catch (_) {}
    setState(() {
      connected = false;
      client = null;
      log = 'DISCONNECTED\n$log';
    });
  }

  Future<void> runCommand() async {
    final c = client;
    final cmd = cmdC.text.trim();
    if (c == null || cmd.isEmpty) return;
    setState(() {
      log = '\$ $cmd\n$log';
      cmdC.clear();
    });
    try {
      final out = await c.run(cmd);
      final text = utf8.decode(out, allowMalformed: true);
      setState(() {
        log = '$text\n$log';
      });
    } catch (e) {
      setState(() {
        log = 'ERROR: $e\n$log';
      });
    }
  }

  @override
  void dispose() {
    hostC.dispose();
    portC.dispose();
    userC.dispose();
    passC.dispose();
    cmdC.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final canSend = connected && !connecting;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH Console'),
        actions: [
          TextButton(
            onPressed: canSend ? disconnect : connect,
            child: Text(
              connected ? 'Disconnect' : (connecting ? 'Connecting...' : 'Connect'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: hostC,
                      decoration: const InputDecoration(labelText: 'Host'),
                      enabled: !connected && !connecting,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: portC,
                      decoration: const InputDecoration(labelText: 'Port'),
                      keyboardType: TextInputType.number,
                      enabled: !connected && !connecting,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: userC,
                      decoration: const InputDecoration(labelText: 'Username'),
                      enabled: !connected && !connecting,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: passC,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      enabled: !connected && !connecting,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: SelectableText(
                      log,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cmdC,
                      decoration: const InputDecoration(hintText: 'Введите команду и нажмите Enter'),
                      onSubmitted: (_) => runCommand(),
                      enabled: canSend,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: canSend ? runCommand : null,
                    child: const Text('Send'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
