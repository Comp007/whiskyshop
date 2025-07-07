import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ListeEmployes extends StatefulWidget {
  const ListeEmployes({super.key});

  @override
  _ListeEmployesState createState() => _ListeEmployesState();
}

class _ListeEmployesState extends State<ListeEmployes> {
  List<Map<String, dynamic>> employes = [];
  List<Map<String, dynamic>> filteredEmployes = [];
  List<String> taches = [];
  String? pointVenteId;
  String searchText = "";
  bool isLoading = true;


  @override
  void initState() {
    super.initState();
    listeEmployes();
  }

  Future<void> listeEmployes() async {
    setState(() {
      isLoading = true;
    });
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final pointVenteSnapshot = await FirebaseFirestore.instance
          .collection('points_vente')
          .where('gerant', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (pointVenteSnapshot.docs.isNotEmpty) {
        final pointVenteDoc = pointVenteSnapshot.docs.first;
        pointVenteId = pointVenteDoc.id;
        final pointVenteData = pointVenteDoc.data();

        taches = List<String>.from(pointVenteData['taches'] ?? []);
        final List<dynamic> employeUIDs = pointVenteData['employes'] ?? [];

        if (employeUIDs.isNotEmpty) {
          final usersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: employeUIDs)
              .get();

          setState(() {
            employes = usersSnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                "id": doc.id,
                "nom": data["fullName"] ?? "",
                "poste": data["poste"] ?? "N/A",
                "sanction": data["sanction"] ?? false,
                "commentaireSanction": data["commentaireSanction"] ?? "",
                "note": data["note"] ?? 0,
                "taches": List<String>.from(data["taches"] ?? []),
              };
            }).toList();
            filteredEmployes = employes;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du chargement des employés : $e");
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _filtrerEmployes(String query) {
    setState(() {
      searchText = query;
      filteredEmployes = employes
          .where((e) => e["nom"].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _addNotification(String employeId, String message) async {
    final notifRef = FirebaseFirestore.instance
        .collection('users')
        .doc(employeId)
        .collection('notifications');

    await notifRef.add({
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
    });
  }

  void _showEmployeOptions(BuildContext context, int index) {
    int note = filteredEmployes[index]['note'] ?? 0;
    TextEditingController commentaireController = TextEditingController(
        text: filteredEmployes[index]['commentaireSanction'] ?? "");

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text("Options pour ${filteredEmployes[index]['nom']}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  icon: Icon(
                    filteredEmployes[index]['sanction'] ? Icons.undo : Icons
                        .gavel, color: Colors.white,),
                  label: Text(filteredEmployes[index]['sanction']
                      ? "Retirer la sanction"
                      : "Sanctionner", style: TextStyle(color: Colors.white),),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: filteredEmployes[index]['sanction']
                        ? Colors.green
                        : Colors.redAccent,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  onPressed: () async {
                    final employeId = filteredEmployes[index]['id'];
                    final newSanction = !filteredEmployes[index]['sanction'];

                    if (newSanction) {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            title: const Text("Commentaire de sanction"),
                            content: TextField(
                              controller: commentaireController,
                              decoration: const InputDecoration(
                                hintText: "Motif ou commentaire...",
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Annuler"),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final commentaire = commentaireController.text
                                      .trim();

                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(employeId)
                                      .update({
                                    "sanction": true,
                                    "commentaireSanction": commentaire,
                                  });

                                  await _addNotification(
                                    employeId,
                                    "Vous avez été sanctionné. Motif : $commentaire",
                                  );

                                  setState(() {
                                    filteredEmployes[index]['sanction'] = true;
                                    filteredEmployes[index]['commentaireSanction'] =
                                        commentaire;
                                  });

                                  Navigator.pop(
                                      context); // Fermer le dialog commentaire
                                  Navigator.pop(
                                      context); // Fermer le dialog options
                                },
                                child: const Text("Valider"),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(employeId)
                          .update({
                        "sanction": false,
                        "commentaireSanction": null,
                      });

                      await _addNotification(
                        employeId,
                        "Votre sanction a été retirée.",
                      );

                      setState(() {
                        filteredEmployes[index]['sanction'] = false;
                        filteredEmployes[index]['commentaireSanction'] = "";
                      });

                      Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text("Note actuelle :",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return IconButton(
                      icon: Icon(
                        i < note ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setStateDialog(() {
                          note = i + 1;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send, color: Colors.white,),
                  label: const Text(
                    "Donner une note", style: TextStyle(color: Colors.white),),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    backgroundColor: Colors.deepOrange,
                  ),
                  onPressed: () async {
                    final employeId = filteredEmployes[index]['id'];
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(employeId)
                        .update({"note": note});

                    await _addNotification(
                      employeId,
                      "Vous avez reçu une nouvelle note : $note étoiles.",
                    );

                    setState(() {
                      filteredEmployes[index]['note'] = note;
                    });
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.task_alt, color: Colors.white,),
                  label: const Text("Assigner des tâches",
                    style: TextStyle(color: Colors.white),),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    backgroundColor: Colors.blueGrey,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _assignTasks(context, index);
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _assignTasks(BuildContext context, int index) {
    List<String> selectedTaches = List.from(filteredEmployes[index]['taches']);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(
                "Assigner des tâches à ${filteredEmployes[index]['nom']}"),
            content: SingleChildScrollView(
              child: Column(
                children: taches.map((tache) {
                  return CheckboxListTile(
                    title: Text(tache),
                    value: selectedTaches.contains(tache),
                    activeColor: Colors.deepOrange,
                    onChanged: (bool? value) {
                      setStateDialog(() {
                        if (value == true) {
                          selectedTaches.add(tache);
                        } else {
                          selectedTaches.remove(tache);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange),
                onPressed: () async {
                  final employeId = filteredEmployes[index]['id'];
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(employeId)
                      .update({"taches": selectedTaches});

                  await _addNotification(
                    employeId,
                    "De nouvelles tâches vous ont été assignées : ${selectedTaches
                        .join(', ')}",
                  );

                  setState(() {
                    filteredEmployes[index]['taches'] = selectedTaches;
                  });
                  Navigator.pop(context);
                },
                child: const Text(
                  "Assigner", style: TextStyle(color: Colors.white),),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final deepBlue = Colors.blue.shade900;
    final deepBlueLight = Colors.blue.shade100;
    final deepBlueMid = Colors.blue.shade700;

    return Scaffold(
      backgroundColor: deepBlueLight, // fond clair bleu pâle
      appBar: AppBar(
        title: const Text("Liste des Employés"),
        backgroundColor: deepBlue,
        // bleu profond
        centerTitle: true,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        toolbarHeight: 70,
        titleTextStyle: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: deepBlue))
            : Column(
          children: [
            TextField(
              style: TextStyle(color: deepBlue),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: deepBlue),
                hintText: "Rechercher un employé...",
                hintStyle: TextStyle(color: deepBlueMid.withValues(alpha: 0.6)),
                filled: true,
                fillColor: deepBlueLight,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide(color: deepBlueMid, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide(color: deepBlue, width: 2),
                ),
              ),
              onChanged: _filtrerEmployes,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: filteredEmployes.isEmpty
                  ? Center(
                child: Text(
                  "Aucun employé trouvé.",
                  style: TextStyle(
                      color: deepBlueMid.withValues(alpha: 0.6), fontSize: 18),
                ),
              )
                  : ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: filteredEmployes.length,
                itemBuilder: (context, index) {
                  final employe = filteredEmployes[index];
                  final nom = employe['nom'];
                  final sanction = employe['sanction'] ?? false;
                  final note = employe['note'] ?? 0;
                  final tachesList =
                  List<String>.from(employe['taches'] ?? []);

                  return Padding(
                    padding:
                    const EdgeInsets.symmetric(vertical: 8),
                    child: Material(
                      color: sanction
                          ? deepBlueLight.withValues(alpha: 0.5)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      elevation: 5,
                      shadowColor: deepBlueLight.withValues(alpha: 0.5),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        splashColor: deepBlue.withValues(alpha: 0.15),
                        onTap: () => _showEmployeOptions(context, index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 20),
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: deepBlue,
                                child: Text(
                                  nom.isNotEmpty
                                      ? nom[0].toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    fontSize: 28,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nom,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: sanction
                                            ? deepBlueMid
                                            : deepBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: tachesList
                                          .map((t) =>
                                          Chip(
                                            label: Text(t,
                                                style: const TextStyle(
                                                    color:
                                                    Colors.white,
                                                    fontWeight:
                                                    FontWeight
                                                        .w600)),
                                            backgroundColor:
                                            deepBlueMid,
                                            elevation: 2,
                                            shadowColor:
                                            deepBlueLight,
                                          ))
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                children: [
                                  Row(
                                    children: List.generate(
                                      5,
                                          (i) =>
                                          Icon(
                                            i < note
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 22,
                                            color: Colors.amber.shade600,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  sanction
                                      ? const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.redAccent,
                                    size: 30,
                                  )
                                      : const SizedBox.shrink(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
