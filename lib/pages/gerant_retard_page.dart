import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GerantRetardPage extends StatefulWidget {
  const GerantRetardPage({super.key});

  @override
  State<GerantRetardPage> createState() => _GerantRetardPageState();
}

class _GerantRetardPageState extends State<GerantRetardPage> {
  String? _pointDeVenteId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerPointDeVente();
  }

  Future<void> _chargerPointDeVente() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _pointDeVenteId = doc.data()?['pointDeVenteId'];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pointDeVenteId == null) {
      return const Center(child: Text("Aucun point de vente assigné"));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Demandes de retard"),
        centerTitle: true,
        elevation: 0,
      ),
      body: _buildListeRetards(),
    );
  }

  Widget _buildListeRetards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('demandedeservice')
          .where('typeDemande', isEqualTo: 'retard')
          .where('pointDeVenteId', isEqualTo: _pointDeVenteId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "Aucune demande de retard",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return _buildCarteRetard(data, doc.id);
          },
        );
      },
    );
  }

  Widget _buildCarteRetard(Map<String, dynamic> data, String docId) {
    final nom = data['nom'] ?? 'Inconnu';
    final poste = data['poste'] ?? '---';
    final statut = data['statut'] ?? 'en attente';
    final motif = data['sousType'] ?? 'non spécifié';
    final texte = data['texte'] ?? '';

    final Timestamp? timestamp = data['timestamp'];
    final date = timestamp?.toDate() ?? DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy à HH:mm').format(date);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        poste,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    statut.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(statut),
                    ),
                  ),
                  backgroundColor: _getStatusColor(statut).withValues(alpha: 0.1),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: _getStatusColor(statut).withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (motif.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      "Motif: ${motif.isNotEmpty ? motif[0].toUpperCase() + motif.substring(1) : motif}",
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),

            if (texte.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  texte,
                  style: const TextStyle(fontSize: 14),
                ),
              ),

            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (statut == 'en attente')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _changerStatut(docId, "validée"),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Valider", style: TextStyle(color: Colors.green)),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => _changerStatut(docId, "refusée"),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Refuser", style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changerStatut(String docId, String statut) async {
    try {
      await FirebaseFirestore.instance
          .collection('demandedeservice')
          .doc(docId)
          .update({'statut': statut});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Demande ${statut == 'validée' ? 'validée' : 'refusée'}"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la mise à jour")),
      );
    }
  }

  Color _getStatusColor(String statut) {
    switch (statut.toLowerCase()) {
      case 'validée':
        return Colors.green;
      case 'refusée':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}