import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HistoriquePointages extends StatefulWidget {
  const HistoriquePointages({super.key});

  @override
  State<HistoriquePointages> createState() => _HistoriquePointagesState();
}

class _HistoriquePointagesState extends State<HistoriquePointages> {
  String? selectedEmploye;
  DateTime? selectedDate;

  String? currentUserPointDeVenteId;

  Future<void> getCurrentUserPointDeVenteId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          currentUserPointDeVenteId = userDoc['pointDeVenteId'];
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPointages() async {
    if (currentUserPointDeVenteId == null) {
      await getCurrentUserPointDeVenteId();
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('pointages')
        .where('pointDeVenteId', isEqualTo: currentUserPointDeVenteId)
        .get();

    List<Map<String, dynamic>> pointages = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final uid = data['uid']?.toString();
      final entree = data['date'] != null ? (data['date'] as Timestamp).toDate() : null;
      final sortie = data['sortie'] != null ? (data['sortie'] as Timestamp).toDate() : null;

      String fullname = 'Inconnu';
      if (uid != null) {
        final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          fullname = userDoc.data()!['fullName']?.toString() ?? 'Sans nom';
        }
      }

      pointages.add({
        'fullName': fullname,
        'entree': entree,
        'sortie': sortie,
      });
    }

    // Appliquer les filtres
    if (selectedEmploye != null) {
      pointages = pointages.where((p) => p['fullName'] == selectedEmploye).toList();
    }
    if (selectedDate != null) {
      pointages = pointages.where((p) {
        final date = p['entree'] ?? p['sortie'];
        return date != null &&
            DateUtils.dateOnly(date) == DateUtils.dateOnly(selectedDate!);
      }).toList();
    }

    return pointages;
  }

  @override
  void initState() {
    super.initState();
    getCurrentUserPointDeVenteId();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des Pointages"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: getPointages(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final pointages = snapshot.data!;
            final nomsUniquepointes = pointages.map((p) => p['fullName']).toSet().toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Colors.blue[50],
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        DropdownButton<String>(
                          value: selectedEmploye,
                          hint: const Text("Filtrer par employé"),
                          items: nomsUniquepointes
                              .map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(e),
                          ))
                              .toList(),

                          onChanged: (val) => setState(() => selectedEmploye = val),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2022),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => selectedDate = date);
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            selectedDate != null
                                ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                                : "Filtrer par date",
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              selectedDate = null;
                              selectedEmploye = null;
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text("Réinitialiser"),
                        )
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: pointages.isEmpty
                      ? const Center(child: Text("Aucun pointage trouvé."))
                      : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columnSpacing: 20,
                        headingRowColor:
                        WidgetStateProperty.all(Colors.blue.withValues(alpha: 0.2)),
                        columns: const [
                          DataColumn(label: Text("Nom employé")),
                          DataColumn(label: Text("Entrée")),
                          DataColumn(label: Text("Sortie")),
                        ],
                        rows: pointages.map((p) {
                          return DataRow(
                            cells: [
                              DataCell(Text(p['fullName'] ?? '')),
                              DataCell(Text(p['entree'] != null
                                  ? DateFormat('dd/MM/yyyy – HH:mm').format(p['entree'])
                                  : 'Non pointé')),
                              DataCell(Text(p['sortie'] != null
                                  ? DateFormat('dd/MM/yyyy – HH:mm').format(p['sortie'])
                                  : 'Pas encore sorti')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
