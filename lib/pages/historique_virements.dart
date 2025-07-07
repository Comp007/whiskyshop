import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HistoriqueVirements extends StatefulWidget {
  const HistoriqueVirements({super.key});

  @override
  State<HistoriqueVirements> createState() => _HistoriqueVirementsState();
}

class _HistoriqueVirementsState extends State<HistoriqueVirements> {
  List<Map<String, dynamic>> virements = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHistoriqueVirements();
  }

  Future<void> fetchHistoriqueVirements() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print("Utilisateur non connecté.");
        setState(() {
          isLoading = false;
        });
        return;
      }
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final CollectionReference paiementsCollection = firestore.collection('paiements');

      // 🔍 On récupère uniquement les virements "Effectué"
      final QuerySnapshot paiementsSnapshot = await paiementsCollection
          .where('statut', isEqualTo: 'Effectué')
          .where('beneficiaire', isEqualTo: userId)
          .get();

      final List<Map<String, dynamic>> paiements = [];

      for (final doc in paiementsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        paiements.add({
          'id': doc.id,
          'beneficiaire': data['beneficiaire'],
          'montant': data['montant'],
          'date': data['date'],
        });
      }

      setState(() {
        virements = paiements;
        isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement : $e');
      setState(() {
        isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des Virements"),
        backgroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : virements.isEmpty
          ? const Center(child: Text("Aucun virement trouvé."))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Table(
              border: TableBorder.all(color: Colors.black, width: 1),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Colors.black),
                  children: [
                    tableHeader("Date"),
                    tableHeader("Montant"),
                  ],
                ),
                ...virements.map((entry) => TableRow(
                  decoration: const BoxDecoration(color: Colors.white),
                  children: [
                    tableCell(formatDate(entry['date'])),
                    tableCell("${entry['montant']} FCFA"),
                  ],
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }

  String formatDate(dynamic date) {
    if (date is Timestamp) {
      final DateTime dt = date.toDate();
      return "${dt.day}/${dt.month}/${dt.year}";
    }
    return "Date invalide";
  }
}
