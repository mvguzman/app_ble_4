import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothConnectionPage extends StatefulWidget {
  @override
  _BluetoothConnectionPageState createState() =>
      _BluetoothConnectionPageState();
}

class _BluetoothConnectionPageState extends State<BluetoothConnectionPage> {
  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  List<BluetoothDevice> devices = [];
  BluetoothDevice? connectedDevice;
  List<BluetoothService> services = [];
  List<BluetoothCharacteristic> characteristics = [];
  Stream<List<int>>? dataStream;
  String receivedData = '';

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() {
    flutterBlue.startScan(timeout: Duration(seconds: 4));

    flutterBlue.scanResults.listen((results) {
      setState(() {
        devices = results.map((result) => result.device).toList();
      });
    });
  }

  void _stopScan() {
    flutterBlue.stopScan();
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        connectedDevice = device;
      });
      _discoverServices(device);
    } catch (e) {
      print(e);
    }
  }

  void _disconnectDevice() {
    if (connectedDevice != null) {
      connectedDevice!.disconnect();
      setState(() {
        connectedDevice = null;
        services.clear();
        characteristics.clear();
        dataStream = null;
      });
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> deviceServices = await device.discoverServices();

    setState(() {
      services = deviceServices;
    });

    for (var service in deviceServices) {
      List<BluetoothCharacteristic> chars = service.characteristics;
      for (var characteristic in chars) {
        if (characteristic.properties.read) {
          characteristics.add(characteristic);
          if (characteristic.uuid.toString().toLowerCase() ==
              '6e400003-b5a3-f393-e0a9-e50e24dcca9e') {
            await characteristic.setNotifyValue(true);
            dataStream = characteristic.value;
            _startDataStreaming();
          }
        }
      }
    }
  }

  void _startDataStreaming() {
    if (dataStream != null) {
      dataStream!.listen((value) {
        setState(() {
          receivedData = utf8.decode(value);
        });
        _displayReceivedDataDialog(); // Display popup dialog
      });
    }
  }

  void _displayReceivedDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Received Data'),
          content: Text(receivedData),
          actions: [
            OutlinedButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Connection'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            child: Text('Connect to Bluetooth Device'),
            onPressed: () {
              _startScan();
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  title: Text(device.name),
                  subtitle: Text(device.id.toString()),
                  trailing: connectedDevice == device
                      ? Icon(Icons.bluetooth_connected)
                      : null,
                  onTap: () {
                    if (connectedDevice == device) {
                      _disconnectDevice();
                    } else {
                      _connectToDevice(device);
                    }
                  },
                );
              },
            ),
          ),
          if (services.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];
                  return ExpansionTile(
                    title: Text(service.uuid.toString()),
                    subtitle: Text('Service'),
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: ClampingScrollPhysics(),
                        itemCount: characteristics.length,
                        itemBuilder: (context, index) {
                          final characteristic = characteristics[index];
                          return ListTile(
                            title: Text(characteristic.uuid.toString()),
                            subtitle: Text('Characteristic'),
                            onTap: () async {
                              List value = await characteristic.read();
                              setState(() {
                                receivedData = value.join(',');
                                //receivedData = utf8.decode(value);
                              });
                              _displayReceivedDataDialog();
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          if (receivedData.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Received Data: $receivedData',
                style: TextStyle(fontSize: 18.0),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }
}

void main() {
  runApp(MaterialApp(
    home: BluetoothConnectionPage(),
  ));
}
