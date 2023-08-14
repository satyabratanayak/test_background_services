import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PermissionStatus status = await Permission.location.request();
  if (status == PermissionStatus.granted) {
    await initializeService();
    runApp(const MyApp());
  } else {
    debugPrint('Location permission denied');
    status = await Permission.location.request();
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  // Service Configuration
  if (await Permission.location.isGranted) {
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        initialNotificationTitle: 'LOCATION SERVICE',
        initialNotificationContent: 'Initializing...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Timer of 1 second
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Custom Notification
        service.setForegroundNotificationInfo(
          title: "LOCATION SERVICE",
          content: "lat: ${position.latitude} \nlon: ${position.longitude}",
        );
      }
    }
    service.invoke(
      'location_service_info',
      {
        "latitude": position.latitude,
        "longitude": position.longitude,
      },
    );
  });
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String text = "Start Service";
  String latitude = "17.0000000";
  String longitude = "78.0000000";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Service App'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            // crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StreamBuilder<Map<String, dynamic>?>(
                stream: FlutterBackgroundService().on('location_service_info'),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text("Error"));
                  } else if (!snapshot.hasData) {
                    return const Center(child: Text("Start Location Service"));
                  } else {
                    final data = snapshot.data!;
                    String? latitude = data["latitude"].toString();
                    String? longitude = data["longitude"].toString();
                    return Column(
                      children: [Text("latitude: $latitude \nlongitude: $longitude")],
                    );
                  }
                },
              ),
              ElevatedButton(
                child: Text(text),
                onPressed: () async {
                  final service = FlutterBackgroundService();
                  var isRunning = await service.isRunning();
                  if (isRunning) {
                    service.invoke("stopService");
                    text = "Start service";
                  } else {
                    service.startService();
                    text = "Stop service";
                  }
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
