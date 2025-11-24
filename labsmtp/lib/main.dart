import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

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

class Recipient {
  String name;
  String email;
  
  Recipient({required this.name, required this.email});
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
  
  final List<Recipient> _recipients = [];
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Поля для SMTP настроек
  final _smtpHostController = TextEditingController(text: 'smtp.yandex.ru');
  final _smtpPortController = TextEditingController(text: '465');
  final _smtpUserController = TextEditingController(text: 'shemyakinveniamin@yandex.ru');
  final _smtpPasswordController = TextEditingController(text: 'tfotiwnnspxypcqc');
  
  // Для хранения выбранной картинки
  File? _selectedImage;
  final _imageAltController = TextEditingController(text: 'Прикрепленное изображение');
  
  bool _isSending = false;
  int _currentProgress = 0;
  int _totalProgress = 0;
  bool _showSmtpSettings = false;
  bool _includeImage = false;
  bool _useImageUrl = true;
  final _imageUrlController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUserController.dispose();
    _smtpPasswordController.dispose();
    _imageAltController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Ошибка при выборе изображения: $e');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _addRecipient() {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      _showError('Заполните имя и email');
      return;
    }

    if (!_emailController.text.contains('@')) {
      _showError('Введите корректный email');
      return;
    }

    setState(() {
      _recipients.add(Recipient(
        name: _nameController.text,
        email: _emailController.text,
      ));
      _nameController.clear();
      _emailController.clear();
    });
  }

  void _removeRecipient(int index) {
    setState(() {
      _recipients.removeAt(index);
    });
  }

  void _clearAllRecipients() {
    setState(() {
      _recipients.clear();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _sendEmails() async {
    if (_recipients.isEmpty) {
      _showError('Добавьте хотя бы одного получателя');
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    
    // Валидация SMTP настроек
    if (_smtpHostController.text.isEmpty || 
        _smtpUserController.text.isEmpty || 
        _smtpPasswordController.text.isEmpty) {
      _showError('Заполните SMTP настройки');
      return;
    }

    // Валидация картинки если включена опция
    if (_includeImage && _selectedImage == null) {
      _showError('Выберите картинку или отключите вставку изображения');
      return;
    }

    setState(() {
      _isSending = true;
      _currentProgress = 0;
      _totalProgress = _recipients.length;
    });

    try {
      final port = int.tryParse(_smtpPortController.text) ?? 465;
      
      final smtpServer = SmtpServer(
        _smtpHostController.text,
        port: port,
        ssl: true,
        username: _smtpUserController.text,
        password: _smtpPasswordController.text,
      );

      int successCount = 0;
      
      for (int i = 0; i < _recipients.length; i++) {
        final recipient = _recipients[i];
        
        try {
          final subject = 'Привет, ${recipient.name}! ${_subjectController.text}';
          
          final message = Message()
            ..from = Address(_smtpUserController.text)
            ..recipients.add(recipient.email)
            ..subject = subject
            ..html = _buildHtmlTemplate(
              recipient.name, 
              _bodyController.text,
              includeImage: _includeImage,
              imageAlt: _imageAltController.text,
            );

          // Добавляем картинку как attachment если она выбрана
          if (_includeImage && _selectedImage != null) {
            // Создаем уникальное имя для картинки
            final imageName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
            message.attachments = [
              FileAttachment(_selectedImage!)
                ..fileName = imageName
                ..location = Location.inline
                ..cid = '<image_cid>'
            ];
          }

          await send(message, smtpServer);
          successCount++;
          
        } catch (e) {
          print('Ошибка отправки для ${recipient.email}: $e');
          // Продолжаем отправку другим получателям
        }
        
        setState(() {
          _currentProgress = i + 1;
        });

        // Кулдаун 1 секунда между отправками
        if (i < _recipients.length - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (!mounted) return;
      
      if (successCount == _recipients.length) {
        _showSuccess('Все сообщения отправлены ($successCount писем)');
      } else {
        _showSuccess('Отправлено $successCount из ${_recipients.length} писем');
      }
      
    } on MailerException catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Ошибка отправки: ${e.toString()}';
      if (e.toString().contains('535')) {
        errorMessage = '''
Ошибка аутентификации (535). Возможные причины:
1. Неправильный логин или пароль
2. Нужно включить двухфакторную аутентификацию
3. Использовать пароль приложения вместо обычного пароля
4. Проверить настройки почтового ящика
''';
      } else if (e.toString().contains('550')) {
        errorMessage = 'Ошибка: Неверный адрес получателя';
      }
      
      _showError(errorMessage);
    } catch (e) {
      if (!mounted) return;
      _showError('Неизвестная ошибка: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }
  }

  String _buildHtmlTemplate(
    String name, 
    String bodyText, {
    bool includeImage = false,
    String imageAlt = 'Image',
  }) {
    String imageSection = '';
    
    if (includeImage) {
      imageSection = '''
      <div class="image-section">
        <img 
          src="cid:image_cid" 
          alt="$imageAlt" 
          style="max-width: 100%; height: auto; border-radius: 8px; margin: 20px 0;"
        >
        <p style="text-align: center; color: #666; font-size: 14px; margin-top: 8px;">$imageAlt</p>
      </div>
      ''';
    }

    return '''
<html>
  <head>
    <meta charset="utf-8">
    <style>
      body { 
        font-family: Arial, sans-serif; 
        line-height: 1.6; 
        color: #333; 
        max-width: 600px; 
        margin: 0 auto; 
        padding: 20px;
        background-color: #f5f5f5;
      }
      .container {
        background: white;
        border-radius: 10px;
        overflow: hidden;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
      }
      .header { 
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 30px 20px;
        text-align: center;
      }
      .header h1 {
        margin: 0;
        font-size: 28px;
        font-weight: 300;
      }
      .content { 
        padding: 30px; 
      }
      .greeting {
        font-size: 20px;
        font-weight: 600;
        color: #2c3e50;
        margin-bottom: 20px;
      }
      .message {
        background: #f8f9fa;
        padding: 20px;
        border-radius: 8px;
        border-left: 4px solid #667eea;
        font-size: 16px;
        line-height: 1.7;
      }
      .image-section {
        text-align: center;
        margin: 25px 0;
        padding: 15px;
        background: #f8f9fa;
        border-radius: 8px;
      }
      .footer { 
        text-align: center; 
        color: #666; 
        font-size: 14px; 
        margin-top: 30px;
        padding-top: 20px;
        border-top: 1px solid #eee;
      }
      .signature {
        font-style: italic;
        color: #7f8c8d;
        margin-top: 10px;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <h1>Привет, $name!</h1>
      </div>
      <div class="content">
        <div class="message">
          ${bodyText.replaceAll('\n', '<br>')}
        </div>
        $imageSection
      </div>
    </div>
  </body>
</html>
''';
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      border: const OutlineInputBorder(),
      labelText: label,
      filled: _isSending,
      fillColor: _isSending ? Colors.grey[100] : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMTP Mass Sender'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_recipients.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllRecipients,
              tooltip: 'Очистить всех получателей',
            ),
          IconButton(
            icon: Icon(_showSmtpSettings ? Icons.settings : Icons.settings_outlined),
            onPressed: () {
              setState(() {
                _showSmtpSettings = !_showSmtpSettings;
              });
            },
            tooltip: 'Настройки SMTP',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Настройки SMTP
                if (_showSmtpSettings) ...[
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Настройки SMTP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _smtpHostController,
                            decoration: const InputDecoration(
                              labelText: 'SMTP сервер',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _smtpPortController,
                                  decoration: const InputDecoration(
                                    labelText: 'Порт',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _smtpUserController,
                                  decoration: const InputDecoration(
                                    labelText: 'Логин/Email',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _smtpPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'Пароль',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Для Yandex: используйте пароль приложения из настроек безопасности',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Секция добавления получателей
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Добавить получателя',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Имя',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _addRecipient,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              child: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Список получателей
                Card(
                  elevation: 2,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.3,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Text(
                                'Список получателей',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Всего: ${_recipients.length}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _recipients.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text(
                                        'Нет получателей',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _recipients.length,
                                  itemBuilder: (context, index) {
                                    final recipient = _recipients[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blue.shade100,
                                        child: Text(
                                          recipient.name.isNotEmpty 
                                              ? recipient.name[0].toUpperCase() 
                                              : '?',
                                        ),
                                      ),
                                      title: Text(recipient.name),
                                      subtitle: Text(recipient.email),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _removeRecipient(index),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Поля для письма
                // ЗАМЕНИТЕ ЭТУ ЧАСТЬ КОДА (поля для письма):

// Поля для письма - УБРАТЬ Expanded и ConstrainedBox
Card(
  elevation: 2,
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        const Text(
          'Сообщение',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _subjectController,
          decoration: _dec('Дополнительная тема (необязательно)'),
          enabled: !_isSending,
        ),
        const SizedBox(height: 12),
        
        // Настройки картинки
        Card(
          color: Colors.grey[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.image, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Добавить картинку',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Switch(
                      value: _includeImage,
                      onChanged: _isSending ? null : (value) {
                        setState(() {
                          _includeImage = value;
                        });
                      },
                    ),
                  ],
                ),
                if (_includeImage) ...[
                  const SizedBox(height: 12),
                  
                  // Превью картинки
                  if (_selectedImage != null) ...[
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.delete),
                            label: const Text('Удалить картинку'),
                            onPressed: _removeImage,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Выбрать картинку из галереи'),
                      onPressed: _pickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 8),
                  TextField(
                    controller: _imageAltController,
                    decoration: const InputDecoration(
                      labelText: 'Описание картинки',
                      border: OutlineInputBorder(),
                      hintText: 'Описание для ALT тега',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Картинка будет встроена в письмо и отображена в тексте',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Текстовое поле для сообщения - ФИКСИРОВАННАЯ ВЫСОТА вместо Expanded
        Container(
          height: 200, // Фиксированная высота
          child: TextFormField(
            controller: _bodyController,
            decoration: _dec('Текст сообщения для вставки в HTML'),
            maxLines: null,
            expands: true,
            validator: (v) => (v == null || v.isEmpty) ? 'Введите текст' : null,
            enabled: !_isSending,
          ),
        ),
      ],
    ),
  ),
),

                const SizedBox(height: 16),

                if (_isSending) ...[
                  LinearProgressIndicator(
                    value: _totalProgress > 0 ? _currentProgress / _totalProgress : 0,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Отправлено $_currentProgress из $_totalProgress писем',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendEmails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _recipients.isEmpty ? Colors.grey : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSending
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Отправка...'),
                            ],
                          )
                        : Text(
                            _recipients.isEmpty 
                                ? 'Добавьте получателей' 
                                : 'Отправить всем (${_recipients.length})',
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(const SmtpApp());
}