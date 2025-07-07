import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SuiviEmployesPage extends StatefulWidget {
  const SuiviEmployesPage({super.key});

  @override
  State<SuiviEmployesPage> createState() => _SuiviEmployesPageState();
}

class _SuiviEmployesPageState extends State<SuiviEmployesPage> {
  Future<List<Map<String, dynamic>>> getUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'fullName': data['fullName'] ?? '',
        'role': data['role'] ?? '',
        'taches': List<String>.from(data['taches'] ?? []),
        'sanction': data['sanction'] ?? false,
        'commentaireSanction': data['commentaireSanction'] ?? '',
        'note': data['note'] ?? 0,
      };
    }).toList();
  }

  void toggleSanction(String userId, bool currentStatus) async {
  if (!currentStatus) {
    // Sanctionner : demander un commentaire
    String commentaire = '';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Motif de la sanction"),
        content: TextField(
          onChanged: (value) => commentaire = value,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Saisir le motif de la sanction...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('users').doc(userId).update({
                'sanction': true,
                'commentaireSanction': commentaire,
              });
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Sanctionner"),
          ),
        ],
      ),
    );
  } else {
    // Lever la sanction
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'sanction': false,
      'commentaireSanction': "",
    });
    setState(() {});
  }
}


  void updateNote(String userId, double note) {
    FirebaseFirestore.instance.collection('users').doc(userId).update({
      'note': note,
    });
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> getPointages() async {
    final snapshot = await FirebaseFirestore.instance.collection('pointages').get();
    List<Map<String, dynamic>> pointages = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final uid = data['uid']?.toString();
      final entree = data['date'] != null ? (data['date'] as Timestamp).toDate() : null;
      final sortie = data['sortie'] != null ? (data['sortie'] as Timestamp).toDate() : null;
      String fullname = 'Inconnu';

      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
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

    return pointages;
  }

  Widget buildResponsiveTable({
    required BuildContext context,
    required List<DataColumn> columns,
    required List<DataRow> rows,
  }) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            columnSpacing: 20,
            columns: columns,
            rows: rows,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 80,
            headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
            dividerThickness: 0.5,
          ),
        ),
      );
    });
  }

  void showNoteDialog(String userId, double currentNote) {
    double selectedNote = currentNote;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attribuer une note'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: 0,
                max: 5,
                divisions: 5,
                label: selectedNote.toStringAsFixed(0),
                value: selectedNote,
                onChanged: (value) {
                  setStateDialog(() => selectedNote = value);
                },
              ),
              Text("Note : ${selectedNote.toStringAsFixed(0)} étoiles")
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Valider'),
            onPressed: () {
              updateNote(userId, selectedNote);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Suivi des employés"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth < 600 ? 8 : 16,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section Utilisateurs - Carte responsive
              Card(
                elevation: 2,
                margin: EdgeInsets.only(bottom: screenHeight * 0.02),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(screenWidth < 600 ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Liste des employés",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: screenWidth < 600 ? 18 : 22,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: getUsers(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(child: Text(
                              "Aucun employé trouvé",
                              style: TextStyle(fontSize: screenWidth < 600 ? 14 : 16),
                            ));
                          }
                          return _buildUsersTable(
                            context,
                            users: snapshot.data!,
                            isSmallScreen: screenWidth < 600,
                            isDarkMode: isDarkMode,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Section Pointages - Carte responsive
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(screenWidth < 600 ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Historique des pointages",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: screenWidth < 600 ? 18 : 22,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: getPointages(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(child: Text(
                              "Aucun pointage trouvé",
                              style: TextStyle(fontSize: screenWidth < 600 ? 14 : 16),
                            ));
                          }
                          return _buildPointagesTable(
                            context,
                            pointages: snapshot.data!,
                            isSmallScreen: screenWidth < 600,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersTable(
      BuildContext context, {
        required List<Map<String, dynamic>> users,
        required bool isSmallScreen,
        required bool isDarkMode,
      }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: isSmallScreen ? 12 : 24,
        horizontalMargin: isSmallScreen ? 12 : 24,
        columns: [
          DataColumn(label: _buildTableHeader("Nom complet")),
          DataColumn(label: _buildTableHeader("Rôle")),
          if (!isSmallScreen) DataColumn(label: _buildTableHeader("Tâches")),
          DataColumn(label: _buildTableHeader("Statut")),
          DataColumn(label: _buildTableHeader("Note")),
          DataColumn(label: _buildTableHeader("Actions")),
        ],
        rows: users.map((user) {
          final isSanctioned = user['sanction'] == true;
          return DataRow(
            cells: [
              DataCell(Text(
                user['fullName'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w500),
              )),
              DataCell(Text(user['role'] ?? '')),
              if (!isSmallScreen)
                DataCell(
                  Tooltip(
                    message: (user['taches'] as List<String>).join(', '),
                    child: Text(
                      (user['taches'] as List<String>).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              DataCell(
                Chip(
                  label: Text(
                    isSanctioned ? 'Sanctionné' : 'OK',
                    style: TextStyle(
                      color: isSanctioned ? Colors.white : Colors.green[800],
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: isSanctioned
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.2),
                  side: BorderSide(
                    color: isSanctioned ? Colors.red : Colors.green,
                    width: 1,
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${user['note']}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                  ],
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.gavel,
                        color: isSanctioned ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      tooltip: isSanctioned ? 'Lever sanction' : 'Sanctionner',
                      onPressed: () => toggleSanction(user['id'], isSanctioned),
                    ),
                    IconButton(
                      icon: const Icon(Icons.star_rate, color: Colors.amber),
                      tooltip: 'Modifier note',
                      onPressed: () => showNoteDialog(user['id'], (user['note'] ?? 0).toDouble()),
                    ),
                    if (isSanctioned && user['commentaireSanction'] != null && user['commentaireSanction'].isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.info, color: Colors.blue),
                        tooltip: user['commentaireSanction'],
                        onPressed: () => _showSanctionDetails(user['commentaireSanction']),
                      ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPointagesTable(
      BuildContext context, {
        required List<Map<String, dynamic>> pointages,
        required bool isSmallScreen,
      }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: isSmallScreen ? 12 : 24,
        horizontalMargin: isSmallScreen ? 12 : 24,
        columns: [
          DataColumn(label: _buildTableHeader("Employé")),
          DataColumn(label: _buildTableHeader("Date")),
          DataColumn(label: _buildTableHeader("Entrée")),
          DataColumn(label: _buildTableHeader("Sortie")),
          DataColumn(label: _buildTableHeader("Durée")),
        ],
        rows: pointages.map((p) {
          final entree = p['entree'] as DateTime?;
          final sortie = p['sortie'] as DateTime?;
          final duree = entree != null && sortie != null ? sortie.difference(entree) : null;

          return DataRow(
            cells: [
              DataCell(Text(
                p['fullName'] ?? 'Inconnu',
                style: const TextStyle(fontWeight: FontWeight.w500),
              )),
              DataCell(Text(entree != null ? DateFormat('dd/MM/yyyy').format(entree) : '-')),
              DataCell(Text(entree != null ? DateFormat('HH:mm').format(entree) : 'Non pointé')),
              DataCell(Text(sortie != null ? DateFormat('HH:mm').format(sortie) : 'En cours')),
              DataCell(Text(duree != null ? '${duree.inHours}h${duree.inMinutes.remainder(60)}m' : '-')),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  void _showSanctionDetails(String commentaire) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Détails de la sanction"),
        content: Text(commentaire),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }
}
