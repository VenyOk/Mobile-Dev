import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

const String smtpHost = 'smtp.yandex.ru';
const int smtpPort = 465;
const String smtpUser = 'shemyakinveniamin@yandex.ru';
const String smtpPassword = 'tfotiwnnspxypcqc';
const String recipient = 'veniaminshemyakin@yandex.ru';

void main() {
  runApp(const SmtpApp());
}

class SmtpApp extends StatelessWidget {
  const SmtpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SmtpScreen(),
    );
  }
}

class SmtpScreen extends StatefulWidget {
  const SmtpScreen({super.key});

  @override
  State<SmtpScreen> createState() => _SmtpScreenState();
}

class _SmtpScreenState extends State<SmtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSending = true;
    });

    try {
      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        ssl: true,
        username: smtpUser,
        password: smtpPassword,
      );

      final message = Message()
        ..from = Address(smtpUser)
        ..recipients.add(recipient)
        ..subject = _subjectController.text
        ..text = _bodyController.text;

      await send(message, smtpServer);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сообщение отправлено')),
      );
    } on MailerException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка отправки: ${e.toString()}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Неизвестная ошибка: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }
  }

  InputDecoration _dec(String label) {
    return InputDecoration(border: const OutlineInputBorder(), labelText: label);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SMTP Yandex Sender')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _subjectController,
                  decoration: _dec('Тема'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Введите тему' : null,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextFormField(
                    controller: _bodyController,
                    decoration: _dec('Текст сообщения'),
                    maxLines: null,
                    expands: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'Введите текст' : null,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendEmail,
                    child: _isSending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Отправить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
