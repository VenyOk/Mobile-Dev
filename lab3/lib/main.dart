import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wheel Control',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Wheel Control Panel'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _leftValue = 0;
  int _rightValue = 0;
  bool _serviceEnabled = true;
  bool _isLoading = false;
  String _lastUpdate = '';
  String _directionStatus = '';

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
  }

  void _checkServiceStatus() async {
    try {
      final uri = Uri.parse('http://iocontrol.ru/api/readData/BoardVenya2/TestVar2');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final bool check = jsonResponse['check'] ?? false;

        if (check) {
          final statusValue = jsonResponse['value'] ?? "0";
          setState(() {
            _serviceEnabled = statusValue == "1";
          });

          if (_serviceEnabled) {
            _loadWheelsValues();
          }
        }
      }
    } catch (error) {
      print("Error checking service status: $error");
    }
  }

  void _loadWheelsValues() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load left value
      final leftUri = Uri.parse('http://iocontrol.ru/api/readData/BoardVenya2/left');
      final leftResponse = await http.get(leftUri);

      if (leftResponse.statusCode == 200) {
        final jsonResponse = json.decode(leftResponse.body);
        final bool check = jsonResponse['check'] ?? false;

        if (check) {
          final leftValue = int.tryParse(jsonResponse['value'] ?? '0') ?? 0;
          setState(() {
            _leftValue = leftValue;
          });
        }
      }

      // Load right value
      final rightUri = Uri.parse('http://iocontrol.ru/api/readData/BoardVenya2/right');
      final rightResponse = await http.get(rightUri);

      if (rightResponse.statusCode == 200) {
        final jsonResponse = json.decode(rightResponse.body);
        final bool check = jsonResponse['check'] ?? false;

        if (check) {
          final rightValue = int.tryParse(jsonResponse['value'] ?? '0') ?? 0;
          setState(() {
            _rightValue = rightValue;
          });
        }
      }
    } catch (error) {
      print("Error loading wheels values: $error");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _incrementLeft() {
    if (!_serviceEnabled) return;

    setState(() {
      _leftValue++;
    });
    _updateValuesOnServer();
  }

  void _decrementLeft() {
    if (!_serviceEnabled) return;

    setState(() {
      _leftValue--;
    });
    _updateValuesOnServer();
  }

  void _incrementRight() {
    if (!_serviceEnabled) return;

    setState(() {
      _rightValue++;
    });
    _updateValuesOnServer();
  }

  void _decrementRight() {
    if (!_serviceEnabled) return;

    setState(() {
      _rightValue--;
    });
    _updateValuesOnServer();
  }

  void _resetValues() {
    if (!_serviceEnabled) return;

    setState(() {
      _leftValue = 0;
      _rightValue = 0;
      _directionStatus = '';
    });
    _updateValuesOnServer();
  }

  void _updateValuesOnServer() async {
    try {
      // Update left value
      final leftUri = Uri.parse('http://iocontrol.ru/api/sendData/BoardVenya2/left/$_leftValue');
      final leftResponse = await http.get(leftUri);

      // Update right value
      final rightUri = Uri.parse('http://iocontrol.ru/api/sendData/BoardVenya2/right/$_rightValue');
      final rightResponse = await http.get(rightUri);

      if (leftResponse.statusCode == 200 && rightResponse.statusCode == 200) {
        print("Values updated successfully: Left=$_leftValue, Right=$_rightValue");

        // Update last update time
        setState(() {
          _lastUpdate = DateTime.now().toString();
        });
      }
    } catch (error) {
      print("Error updating values: $error");
    }
  }

  void _getDeviceStatus() {
    if (!_serviceEnabled) return;

    setState(() {
      if (_rightValue > _leftValue) {
        _directionStatus = 'Движение влево';
      } else if (_leftValue > _rightValue) {
        _directionStatus = 'Движение вправо';
      } else if (_leftValue == _rightValue && _leftValue == 0){
        _directionStatus = 'Колеса не вращаются';
      } else {
        _directionStatus = 'Движение вперед';
      }
    });
  }

  void _getBitovkaLampRequestON() {
    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse('http://iocontrol.ru/api/sendData/BoardVenya2/TestVar2/1');
    http.get(uri).then((response) {
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      setState(() {
        _serviceEnabled = true;
      });

      // Load current values after turning on
      _loadWheelsValues();
    }).catchError((error){
      setState(() {
        _isLoading = false;
      });
      print("Error turning on service: $error");
    });
  }

  void _getBitovkaLampRequestOFF() {
    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse('http://iocontrol.ru/api/sendData/BoardVenya2/TestVar2/0');
    http.get(uri).then((response) {
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");
      setState(() {
        _serviceEnabled = false;
        _isLoading = false;
      });
    }).catchError((error){
      setState(() {
        _isLoading = false;
      });
      print("Error turning off service: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _serviceEnabled ? _loadWheelsValues : null,
            tooltip: 'Refresh values',
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading...'),
          ],
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Service Status
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Service Status:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _serviceEnabled ? 'ENABLED' : 'DISABLED',
                        style: TextStyle(
                          color: _serviceEnabled ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Left Wheel Control
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Left Wheel:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_leftValue',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(60, 60),
                              shape: const CircleBorder(),
                            ),
                            onPressed: _serviceEnabled ? _decrementLeft : null,
                            child: const Icon(Icons.remove, size: 30),
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(60, 60),
                              shape: const CircleBorder(),
                            ),
                            onPressed: _serviceEnabled ? _incrementLeft : null,
                            child: const Icon(Icons.add, size: 30),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Right Wheel Control
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Right Wheel:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_rightValue',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(60, 60),
                              shape: const CircleBorder(),
                            ),
                            onPressed: _serviceEnabled ? _decrementRight : null,
                            child: const Icon(Icons.remove, size: 30),
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(60, 60),
                              shape: const CircleBorder(),
                            ),
                            onPressed: _serviceEnabled ? _incrementRight : null,
                            child: const Icon(Icons.add, size: 30),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Device Status
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Device Status:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _directionStatus.isEmpty ? 'Press "Get Status" to check' : _directionStatus,
                        style: TextStyle(
                          color: _directionStatus.isEmpty ? Colors.grey : Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(200, 50),
                        ),
                        onPressed: _serviceEnabled ? _getDeviceStatus : null,
                        child: const Text('GET DEVICE STATUS'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _getBitovkaLampRequestON,
                    child: const Text('TURN ON SERVICE'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _getBitovkaLampRequestOFF,
                    child: const Text('TURN OFF SERVICE'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 50),
                ),
                onPressed: _serviceEnabled ? _resetValues : null,
                child: const Text('RESET VALUES TO 0'),
              ),

              const SizedBox(height: 10),
              Text(
                'Range: -100 to 100',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),

              if (_lastUpdate.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Last update: $_lastUpdate',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}