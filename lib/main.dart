import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const GuardianXApp());
}

class GuardianXApp extends StatelessWidget {
  const GuardianXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GuardianX',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LatLng currentLocation = LatLng(16.5062, 80.6480);
  LatLng? destination;
  List<LatLng> routePoints = [];

  final MapController mapController = MapController();
  final stt.SpeechToText speech = stt.SpeechToText();

  Timer? sosTimer;
  bool isSOSActive = false;

  // 🔐 PUT YOUR TWILIO CREDENTIALS HERE
  final String accountSid = "AC66dd9d0e3452090a5d0540ac782c9e85";
  final String authToken = "8ada4e3ec15f2318d6462cb63492381d";

  @override
  void initState() {
    super.initState();
    initApp();
  }

  // ✅ FIXED PERMISSION HANDLING
  Future<void> initApp() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      showSnack("Location permission permanently denied ❌");
      return;
    }

    await getLocation();
    liveLocation();
  }

  // 📍 GET LOCATION
  Future<void> getLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      showSnack("Location error ❌");
    }
  }

  // 📡 LIVE LOCATION
  void liveLocation() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      final newLoc = LatLng(position.latitude, position.longitude);

      setState(() {
        currentLocation = newLoc;

        if (destination != null) {
          routePoints = [currentLocation, destination!];
        }
      });

      mapController.move(newLoc, mapController.camera.zoom);
    });
  }

  // 🚀 TWILIO WHATSAPP
  Future<void> sendWhatsApp() async {
    if (accountSid.contains("PUT_")) {
      showSnack("Add Twilio credentials ❗");
      return;
    }

    final url = Uri.parse(
        "https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json");

    final auth =
        'Basic ' + base64Encode(utf8.encode('$accountSid:$authToken'));

    try {
      final response = await http.post(
        url,
        headers: {"Authorization": auth},
        body: {
          "From": "whatsapp:+14155238886",
          "To": "whatsapp:+919876543210",
          "Body":
          "🚨 EMERGENCY!\nhttps://maps.google.com/?q=${currentLocation.latitude},${currentLocation.longitude}"
        },
      );

      if (response.statusCode == 201) {
        showSnack("WhatsApp Sent 🚀");
      } else {
        showSnack("Failed ❌");
        print(response.body);
      }
    } catch (e) {
      showSnack("Network error ❌");
    }
  }

  // 🔁 START SOS
  void startSOS() async {
    if (isSOSActive) return;

    isSOSActive = true;

    await sendWhatsApp();

    sosTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      sendWhatsApp();
    });

    showSnack("SOS Activated 🚨");
  }

  // 🛑 STOP SOS
  void stopSOS() {
    sosTimer?.cancel();
    isSOSActive = false;
    showSnack("SOS Stopped ❌");
  }

  // 📱 BACKUP WHATSAPP
  Future<void> openWhatsApp() async {
    String phone = "919876543210";

    String msg =
        "🚨 HELP!\nhttps://maps.google.com/?q=${currentLocation.latitude},${currentLocation.longitude}";

    final url =
    Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(msg)}");

    await launchUrl(url);
  }

  // 🎤 VOICE SOS
  void startListening() async {
    bool available = await speech.initialize();

    if (!available) {
      showSnack("Mic not available ❌");
      return;
    }

    showSnack("Say 'help' 🎤");

    speech.listen(onResult: (result) {
      if (result.recognizedWords.toLowerCase().contains("help")) {
        startSOS();
      }
    });
  }

  void showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text("GuardianX")),

      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: currentLocation,
                initialZoom: 15,
                onTap: (tap, point) {
                  setState(() {
                    destination = point;
                    routePoints = [currentLocation, point];
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation,
                      width: 60,
                      height: 60,
                      child: const Icon(Icons.my_location,
                          color: Colors.blue),
                    ),
                    if (destination != null)
                      Marker(
                        point: destination!,
                        width: 60,
                        height: 60,
                        child: const Icon(Icons.location_pin,
                            color: Colors.red),
                      ),
                  ],
                ),
                if (routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 4,
                        color: Colors.green,
                      ),
                    ],
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              children: [
                buildCard("Panic SOS", Colors.red, Icons.warning, startSOS),
                buildCard("Stop SOS", Colors.grey, Icons.stop, stopSOS),
                buildCard("Open WhatsApp", Colors.green, Icons.message, openWhatsApp),
                buildCard("Voice SOS", Colors.blue, Icons.mic, startListening),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget buildCard(
      String title, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.6)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 35, color: Colors.white),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}