import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';

class ScannerQrPresence extends StatefulWidget {
  const ScannerQrPresence({super.key});

  @override
  State<ScannerQrPresence> createState() => _ScannerQrPresenceState();
}

class _ScannerQrPresenceState extends State<ScannerQrPresence> {
  bool scanned = false;
  bool geolocationActive = false;
  bool showSortieButton = false;
  String? pointageDocId;

  MobileScannerController cameraController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _checkLocationPermissionAndService();
  }

  Future<void> _checkLocationPermissionAndService() async {
    Location location = Location();
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
    }

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
    }

    setState(() {
      geolocationActive = status.isGranted && serviceEnabled;
    });

    if (!geolocationActive) {
      _showMessage("Veuillez activer la géolocalisation pour scanner.");
      return;
    }

    // Vérifie si une entrée sans sortie existe
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      try { final snapshot = await FirebaseFirestore.instance
          .collection('pointages')
          .where('uid', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('sortie', isNull: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          showSortieButton = true;
          pointageDocId = snapshot.docs.first.id;
        });
      }
      } catch (e, stack) {
        debugPrint("🔥 ERREUR FIRESTORE : $e");
        debugPrint("📌 STACK : $stack");
      }
    }
  }

  double calculateDistanceInMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000; // rayon de la Terre en mètres
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  void _handleScan(String data) async {
    if (scanned || !geolocationActive) return;
    scanned = true;

    try {
      final pointDeVenteIdQR = data.trim(); // juste l'ID scanné
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userPointDeVente = userDoc['pointDeVenteId'];
      if (pointDeVenteIdQR != userPointDeVente) {
        _showMessage("QR Code invalide !");
        return;
      }

      // 📍 Vérifier la localisation
      final location = Location();
      final currentLocation = await location.getLocation();

      final pointDeVenteDoc = await FirebaseFirestore.instance
          .collection('points_vente')
          .doc(pointDeVenteIdQR)
          .get();

      if (!pointDeVenteDoc.exists) {
        _showMessage("Point de vente introuvable.");
        return;
      }

      final pointData = pointDeVenteDoc.data();
      final double latitudePV = pointData?['latitude'] ?? 0.0;
      final double longitudePV = pointData?['longitude'] ?? 0.0;

      final distance = calculateDistanceInMeters(
        currentLocation.latitude ?? 0.0,
        currentLocation.longitude ?? 0.0,
        latitudePV,
        longitudePV,
      );

      if (distance > 100) {
        _showMessage("Vous êtes trop loin du point de vente (${distance.toStringAsFixed(1)} m).");
        return;
      }

      // Vérifie la présence du jour
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final snapshot = await FirebaseFirestore.instance
          .collection('pointages')
          .where('uid', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('sortie', isNull: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _showMessage("Vous avez déjà marqué votre présence !");
        return;
      }

      await FirebaseFirestore.instance.collection('pointages').add({
        'uid': user.uid,
        'pointDeVenteId': pointDeVenteIdQR,
        'date': Timestamp.now(),
        'sortie': null,
      });

      _showMessage("Présence marquée avec succès !");
      setState(() {
        showSortieButton = true;
      });
    } catch (e) {
      _showMessage("Erreur : ${e.toString()}");
    }

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) Navigator.pop(context);
  }





  Future<void> _marquerSortie() async {
    if (pointageDocId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmation"),
        content: const Text("Voulez-vous vraiment marquer votre sortie ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('pointages')
          .doc(pointageDocId)
          .update({'sortie': Timestamp.now()});

      _showMessage("Sortie marquée avec succès !");
      setState(() {
        showSortieButton = false;
        pointageDocId = null;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showMessage("Erreur lors de la sortie : ${e.toString()}");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: geolocationActive
          ? Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    final barcode = capture.barcodes.first;
                    final data = barcode.rawValue;
                    if (data != null) {
                      _handleScan(data);
                    }
                  },
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 50),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "Scannez le QR Code de pointage",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                if (showSortieButton)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onPressed: _marquerSortie,
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text("Marquer la sortie"),
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text(
                    "La géolocalisation est désactivée.",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _checkLocationPermissionAndService,
                    child: const Text("Activer la géolocalisation"),
                  ),
                ],
              ),
            ),
    );
  }
}
