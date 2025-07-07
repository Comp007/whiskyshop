import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class HistoriquePaiementsPage extends StatefulWidget {
  const HistoriquePaiementsPage({super.key});

  @override
  State<HistoriquePaiementsPage> createState() => _HistoriquePaiementsPageState();
}

class _HistoriquePaiementsPageState extends State<HistoriquePaiementsPage> {
  late int selectedMonth;
  late int selectedYear;
  List<Map<String, dynamic>> paiements = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    selectedMonth = now.month;
    selectedYear = now.year;
    chargerPaiements();
  }

  Future<void> chargerPaiements() async {
    setState(() => isLoading = true);
    paiements = await fetchPaiementsDuMois(selectedMonth, selectedYear);
    setState(() => isLoading = false);
  }

  Future<List<Map<String, dynamic>>> fetchPaiementsDuMois(int mois, int annee) async {
    final debut = DateTime(annee, mois, 1);
    final fin = DateTime(annee, mois + 1, 1).subtract(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('paiement')
        .where('date', isGreaterThanOrEqualTo: debut)
        .where('date', isLessThanOrEqualTo: fin)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'nom': data['nom'] ?? 'Inconnu',
        'montant': data['montant'] ?? 0,
        'date': (data['date'] as Timestamp).toDate(),
        'mode': 'Orange Money' // À améliorer si tu veux distinguer plus tard
      };
    }).toList();
  }

  Future<List<DropdownMenuItem<int>>> getMoisItems() async {
    await initializeDateFormatting('fr_FR', null);
    return List.generate(12, (index) {
      final monthNum = index + 1;
      final nomMois = DateFormat.MMMM('fr_FR').format(DateTime(0, monthNum));
      return DropdownMenuItem(value: monthNum, child: Text(nomMois));
    });
  }

  List<DropdownMenuItem<int>> get anneeItems {
    final anneeActuelle = DateTime.now().year;
    return List.generate(5, (i) {
      int annee = anneeActuelle - i;
      return DropdownMenuItem(value: annee, child: Text('$annee'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Historique des paiements"),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<DropdownMenuItem<int>>>(
                    future: getMoisItems(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      return DropdownButtonFormField<int>(
                        value: selectedMonth,
                        items: snapshot.data!,
                        onChanged: (value) async {
                          setState(() => selectedMonth = value!);
                          await chargerPaiements();
                        },
                        decoration: const InputDecoration(labelText: "Mois"),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedYear,
                    items: anneeItems,
                    onChanged: (value) async {
                      setState(() => selectedYear = value!);
                      await chargerPaiements();
                    },
                    decoration: const InputDecoration(labelText: "Année"),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : paiements.isEmpty
                ? const Center(child: Text("Aucun paiement trouvé pour cette période."))
                : ListView.builder(
              itemCount: paiements.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final paiement = paiements[index];
                final nom = paiement['nom'];
                final montant = paiement['montant'];
                final date = paiement['date'] as DateTime;
                final mode = paiement['mode'];

                return Card(
                  color: Colors.white,
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                    title: Text(
                      nom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      "Montant: ${montant.toString()} FCFA\nMode: $mode",
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: Text(
                      DateFormat('dd MMM yyyy', 'fr_FR').format(date),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
