import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:url_launcher/url_launcher.dart';

class GestionPaiementsPage extends StatefulWidget {
  const GestionPaiementsPage({super.key});

  @override
  State<GestionPaiementsPage> createState() => _GestionPaiementsPageState();
}

class _GestionPaiementsPageState extends State<GestionPaiementsPage> {
  bool paiementInitie = false;
  bool isListeFloue = false;
  bool afficherConfirmation = false;
  bool isLoading = false;
  List<Map<String, dynamic>> paiementsList = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredPaiements {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return paiementsList;
    return paiementsList
        .where((p) => (p['nom'] as String? ?? '').toLowerCase().contains(query))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchEmployes() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .where('role', whereIn: ['employe', 'gerant'])
            .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'nom': data['fullName'],
        'numero': data['phone'],
        'role': data['role'],
        'salaire': data['salaire'],
        'pretActif': data['pretActif'] ?? false,
      };
    }).toList();
  }

  Future<double> calculerMensualite(String userId) async {
    final query =
        await FirebaseFirestore.instance
            .collection('demandedeservice')
            .where('userId', isEqualTo: userId)
            .where('typeDemande', isEqualTo: 'pret')
            .where('statut', isEqualTo: 'validée')
            .where(
              'pretActif',
              isEqualTo: true,
            ) // Cible uniquement le prêt en cours
            .limit(1)
            .get();

    if (query.docs.isEmpty) return 0;

    final pret = query.docs.first.data();
    final montant = pret['montantPret'] ?? 0;
    final duree = pret['periodeRemboursement'] ?? 1;
    return montant / duree;
  }

  Future<List<Map<String, dynamic>>> calculerPaiements() async {
    final employes = await fetchEmployes();
    List<Map<String, dynamic>> paiements = [];

    for (final e in employes) {
      final estDejaPaye = await dejaPayeCeMois(e['id']);
      if (estDejaPaye) continue;

      final salaire = e['salaire'] ?? 0;
      final mensualite = e['pretActif'] ? await calculerMensualite(e['id']) : 0;
      final montantFinal = (salaire - mensualite).round();

      paiements.add({
        'nom': e['nom'],
        'numero': e['numero'],
        'salaire': salaire,
        'montant': montantFinal,
        'userId': e['id'],
      });
    }

    return paiements;
  }

  Future<bool> dejaPayeCeMois(String userId) async {
    final debutMois = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final finMois = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

    final paiementQuery =
        await FirebaseFirestore.instance
            .collection('paiement')
            .where('userId', isEqualTo: userId)
            .where('date', isGreaterThanOrEqualTo: debutMois)
            .where('date', isLessThanOrEqualTo: finMois)
            .limit(1)
            .get();

    return paiementQuery.docs.isNotEmpty;
  }

  Future<void> mettreAJourPret(String userId) async {
    final query =
        await FirebaseFirestore.instance
            .collection('demandedeservice')
            .where('userId', isEqualTo: userId)
            .where('typeDemande', isEqualTo: 'pret')
            .where('statut', isEqualTo: 'validée')
            .where(
              'pretActif',
              isEqualTo: true,
            ) // Cible uniquement le prêt en cours
            .limit(1)
            .get();

    if (query.docs.isEmpty) return;

    final docPret = query.docs.first;
    final data = docPret.data();

    int moisRestants =
        data['moisRestants'] ?? data['periodeRemboursement'] ?? 0;

    if (moisRestants > 0) {
      moisRestants--;

      if (moisRestants <= 0) {
        // Prêt terminé
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {'pretActif': false},
        );

        await FirebaseFirestore.instance
            .collection('demandedeservice')
            .doc(docPret.id)
            .update({
              'pretActif': false,
              'moisRestants': 0,
              'statut': 'remboursé',
            });
      } else {
        // Mise à jour du nombre de mois restants
        await FirebaseFirestore.instance
            .collection('demandedeservice')
            .doc(docPret.id)
            .update({'moisRestants': moisRestants});
      }
    }
  }

  Future<void> enregistrerPaiements(
    List<Map<String, dynamic>> paiements,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final p in paiements) {
      final docRef = FirebaseFirestore.instance.collection('paiement').doc();
      batch.set(docRef, {
        'nom': p['nom'],
        'numero': p['numero'],
        'salaire': p['salaire'],
        'montant': p['montant'],
        'userId': p['userId'],
        'date': DateTime.now(),
      });
    }
    await batch.commit();

    for (final p in paiements) {
      await mettreAJourPret(p['userId']);
    }
  }

  Future<void> exporterExcel(List<Map<String, dynamic>> paiements) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];

    sheet.getRangeByName('A1').setText('Nom');
    sheet.getRangeByName('B1').setText('Numéro');
    sheet.getRangeByName('C1').setText('Montant à recevoir');

    for (int i = 0; i < paiements.length; i++) {
      final ligne = i + 2;
      sheet.getRangeByName('A$ligne').setText(paiements[i]['nom']);
      sheet
          .getRangeByName('B$ligne')
          .setText(paiements[i]['numero'].toString());
      sheet
          .getRangeByName('C$ligne')
          .setNumber(paiements[i]['montant'].toDouble());
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/paiements.xlsx');
    await file.writeAsBytes(bytes, flush: true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Exportation réussie : fichier paiements.xlsx enregistré.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> envoyerNotificationPaiement() async {
    final users = await FirebaseFirestore.instance.collection('users').get();
    for (final user in users.docs) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': user.id,
        'titre': 'Paiement du mois effectué',
        'message': 'Votre salaire de ce mois a été payé.',
        'timestamp': FieldValue.serverTimestamp(),
        'lu': false,
      });
    }
  }

  Future<void> toutPayer() async {
    setState(() => isLoading = true);
    final paiements = await calculerPaiements();
    await exporterExcel(paiements);
    setState(() {
      paiementsList = paiements;
      isListeFloue = true;
      afficherConfirmation = true;
      isLoading = false;
    });
  }

  Future<void> confirmerPaiementEffectue() async {
    await enregistrerPaiements(paiementsList);
    await envoyerNotificationPaiement();
    setState(() {
      paiementsList.clear();
      afficherConfirmation = false;
      paiementInitie = false;
      isListeFloue = false;
    });
  }

  double calculerMontantTotal() {
    return _filteredPaiements.fold(
      0.0,
      (total, p) => total + (p['montant'] ?? 0),
    );
  }

  Future<void> _modifierSalaire(BuildContext context, String userId) async {
    final controller = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Modifier le salaire'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nouveau salaire'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () {
                  final salaire = double.tryParse(controller.text);
                  if (salaire != null) {
                    Navigator.pop(context, salaire);
                  }
                },
                child: const Text('Valider'),
              ),
            ],
          ),
    );

    if (result != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'salaire': result,
      });

      final updatedPaiements = await calculerPaiements();
      setState(() {
        paiementsList = updatedPaiements;
      });
    }
  }

  Future<void> _payerIndividuellement(Map<String, dynamic> paiement) async {
    final tel = paiement['numero'] ?? '';
    final montant = (paiement['montant'] ?? 0).toDouble();
    final montantStr = montant.toStringAsFixed(0);

    final uri = Uri.parse(
      'tel:${Uri.encodeComponent("*144*2*$tel*$montantStr#")}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);

      if (!mounted) return;

      // Confirmation manuelle après l'appel USSD
      final confirme = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Confirmation'),
              content: Text(
                'Le paiement de ${paiement['nom']} a-t-il été effectué avec succès ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Oui, confirmé'),
                ),
              ],
            ),
      );

      if (confirme == true) {
        await enregistrerPaiements([paiement]);

        setState(() {
          paiementsList.removeWhere((p) => p['userId'] == paiement['userId']);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Paiement enregistré pour ${paiement['nom']}'),
            ),
          );
        }
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lancer l’application téléphone'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Gestion des paiements'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.playlist_add),
                    label: const Text("Initier Paiement"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      setState(() {
                        isLoading = true;
                        paiementInitie = true;
                      });

                      final paiements = await calculerPaiements();

                      setState(() {
                        paiementsList = paiements;
                        isLoading = false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon:
                        isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : Icon(
                              Icons.file_download,
                              color:
                                  paiementInitie ? Colors.white : Colors.grey,
                            ),
                    label: Text(
                      "Tout payer",
                      style: TextStyle(
                        color: paiementInitie ? Colors.white : Colors.grey,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          paiementInitie ? Colors.green : Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: paiementInitie && !isLoading ? toutPayer : null,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          if (paiementInitie)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Rechercher un employé par nom...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                          : null,
                ),
              ),
            ),
          if (!paiementInitie)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.wallet, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      "Appuyez sur 'Initier Paiement'\npour afficher la liste des employés.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          if (paiementInitie)
            Expanded(
              child: Stack(
                children: [
                  Opacity(
                    opacity: isListeFloue ? 0.3 : 1,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      children: [
                        // 💳 Carte de résumé des paiements
                        Card(
                          color: Colors.teal[50],
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.payments,
                                  color: Colors.teal,
                                  size: 32,
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Montant total à payer",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "${calculerMontantTotal().toStringAsFixed(0)} FCFA",
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 📄 Liste des paiements
                        ..._filteredPaiements.map(
                          (p) => Card(
                            elevation: 3,
                            color: Colors.white,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: Colors.deepPurple.shade100,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              title: Text(
                                p['nom'] ?? 'Nom inconnu',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Salaire : ${p['salaire'] ?? 0} FCFA'),
                                  Text('À recevoir : ${p['montant']} FCFA'),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'modifier') {
                                    _modifierSalaire(context, p['userId']);
                                  } else if (value == 'payer') {
                                    _payerIndividuellement(p);
                                  }
                                },
                                itemBuilder:
                                    (context) => [
                                      const PopupMenuItem(
                                        value: 'modifier',
                                        child: Text('Modifier le salaire'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'payer',
                                        child: Text('Payer individuellement'),
                                      ),
                                    ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ✅ Boutons de confirmation
                  if (afficherConfirmation)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Annuler",
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 24,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  afficherConfirmation = false;
                                  isListeFloue = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Paiement annulé. Aucun changement enregistré.",
                                    ),
                                  ),
                                );
                              },
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Paiement effectué",
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 24,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: confirmerPaiementEffectue,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
