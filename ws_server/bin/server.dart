import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const String HOST = '0.0.0.0';
const int PORT = 8080;

double sliderValue = 50.0;
double slider2Value = 25.0;

void main() async {
  final wsHandler = webSocketHandler((WebSocketChannel webSocket) {
    print('Новое WebSocket подключение установлено');
    
    webSocket.sink.add(jsonEncode({
      'type': 'slider_value',
      'value': sliderValue
    }));
    
    webSocket.sink.add(jsonEncode({
      'type': 'slider2_value',
      'value': slider2Value
    }));
    
    webSocket.stream.listen(
      (message) {
        print('Получено сообщение: $message');
        
        try {
          final data = jsonDecode(message);
          final response = _handleMessage(data);
          if (response != null) {
            webSocket.sink.add(jsonEncode(response));
          }
        } catch (e) {
          print('Ошибка обработки сообщения: $e');
          webSocket.sink.add(jsonEncode({
            'type': 'error',
            'message': 'Неверный формат сообщения'
          }));
        }
      },
      onDone: () {
        print('WebSocket подключение закрыто');
      },
      onError: (error) {
        print('Ошибка WebSocket: $error');
      },
    );
  });

  final handler = (Request request) {
    if (request.url.path == 'ws') {
      return wsHandler(request);
    }
    return Response.notFound('WebSocket endpoint: /ws');
  };

  final server = await serve(handler, HOST, PORT);
  
  print('WebSocket сервер запущен на http://$HOST:$PORT');
  print('WebSocket endpoint: ws://$HOST:$PORT/ws');
  print('Нажмите Ctrl+C для остановки сервера');
}


Map<String, dynamic>? _handleMessage(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  
  switch (type) {
    case 'calculate':
      return _handleCalculation(data);
    case 'slider_update':
      return _handleSliderUpdate(data);
    case 'get_slider_value':
      return _getSliderValue();
    default:
      return {
        'type': 'error',
        'message': 'Неизвестный тип сообщения: $type'
      };
  }
}

Map<String, dynamic> _handleCalculation(Map<String, dynamic> data) {
  try {
    final a = (data['a'] as num).toDouble();
    final b = (data['b'] as num).toDouble();
    final operation = data['operation'] as String;
    
    double result;
    
    switch (operation) {
      case '+':
        result = a + b;
        break;
      case '-':
        result = a - b;
        break;
      case '*':
        result = a * b;
        break;
      case '/':
        if (b == 0) {
          return {
            'type': 'calculation_error',
            'message': 'Деление на ноль невозможно'
          };
        }
        result = a / b;
        break;
      default:
        return {
          'type': 'calculation_error',
          'message': 'Неизвестная операция: $operation'
        };
    }
    
    print('Вычисление: $a $operation $b = $result');
    
    return {
      'type': 'calculation_result',
      'result': result,
      'operation': operation,
      'a': a,
      'b': b
    };
  } catch (e) {
    return {
      'type': 'calculation_error',
      'message': 'Ошибка в данных для вычисления: $e'
    };
  }
}

Map<String, dynamic> _handleSliderUpdate(Map<String, dynamic> data) {
  try {
    final value = (data['value'] as num).toDouble();
    
    if (value < 0 || value > 100) {
      return {
        'type': 'slider_error',
        'message': 'Значение ползунка должно быть от 0 до 100'
      };
    }
    
    sliderValue = value;
    print('Обновлено значение ползунка: $sliderValue');
    
    return {
      'type': 'slider_updated',
      'value': sliderValue
    };
  } catch (e) {
    return {
      'type': 'slider_error',
      'message': 'Ошибка обновления ползунка: $e'
    };
  }
}

Map<String, dynamic> _getSliderValue() {
  return {
    'type': 'slider_value',
    'value': sliderValue
  };
}