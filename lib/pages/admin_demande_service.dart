import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminDemandeService extends StatefulWidget {
  const AdminDemandeService({super.key});

  @override
  State<AdminDemandeService> createState() => _AdminDemandeServiceState();
}

class _AdminDemandeServiceState extends State<AdminDemandeService> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  String _playingId = '';

  @override
  void initState() {
    super.initState();
    _player.openPlayer();
  }

  @override
  void dispose() {
    _player.closePlayer();
    super.dispose();
  }

  Future<void> _playAudio(String docId, String base64Audio) async {
    if (_playingId == docId) {
      await _player.stopPlayer();
      setState(() => _playingId = '');
    } else {
      final Uint8List audioBytes = base64Decode(base64Audio);
      await _player.startPlayer(
        fromDataBuffer: audioBytes,
        codec: Codec.aacADTS,
        whenFinished: () => setState(() => _playingId = ''),
      );
      setState(() => _playingId = docId);
    }
  }

  Future<void> _decaisserPret(String docId, Map<String, dynamic> data) async {
    final tel = data['phoneNumber'] ?? '';
    final montant = (data['montantPret'] ?? 0).toDouble();
    final nom = data['nom'] ?? 'Inconnu';
    final userId = data['userId'] ?? '';

    if (tel.isEmpty || montant <= 0 || userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Données de prêt invalides pour le décaissement."),
          ),
        );
      }
      return;
    }

    final montantStr = montant.toStringAsFixed(0);
    final uri = Uri.parse(
      'tel:${Uri.encodeComponent("*144*2*$tel*$montantStr#")}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);

      if (!mounted) return;

      // Demander la confirmation manuelle après la tentative d'appel USSD
      final confirme = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Confirmation du Décaissement'),
              content: Text(
                'Le prêt de $montantStr XAF pour $nom a-t-il été décaissé avec succès ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Non / Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Oui, Confirmé'),
                ),
              ],
            ),
      );

      if (confirme == true) {
        final batch = FirebaseFirestore.instance.batch();

        final demandeRef = FirebaseFirestore.instance
            .collection('demandedeservice')
            .doc(docId);
        batch.update(demandeRef, {
          'pretActif': true,
          'statut': 'décaissé',
          'dateDecaissement': FieldValue.serverTimestamp(),
        });

        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId);
        batch.update(userRef, {'pretActif': true});

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Décaissement pour $nom enregistré.'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
        }
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lancer l\'application téléphone'),
        ),
      );
    }
  }

  Future<void> _changerStatut(
    String docId,
    String statut,
    Map<String, dynamic> data,
  ) async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              "Confirmation",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              "Es-tu sûr de vouloir ${statut == 'validée' ? 'valider' : 'refuser'} cette demande ?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  "Annuler",
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      statut == 'validée' ? Colors.green : Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  statut == 'validée' ? "Valider" : "Refuser",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmation == true) {
      final docRef = FirebaseFirestore.instance
          .collection('demandedeservice')
          .doc(docId);

      await docRef.update({'statut': statut});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Demande ${statut == 'validée' ? 'validée' : 'refusée'}",
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        setState(() {});
      }
    }
  }

  Future<String> _getNomPointVente(String pointDeVenteId) async {
    if (pointDeVenteId.isEmpty) return '---';
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('points_vente')
              .doc(pointDeVenteId)
              .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final nom = data['nom'];
          if (nom is String && nom.isNotEmpty) {
            return nom;
          }
        }
      }
      return '---';
    } catch (e) {
      debugPrint("Erreur récupération point de vente: $e");
      return '---';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Demandes des employés",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;
          final isMediumScreen =
              constraints.maxWidth >= 600 && constraints.maxWidth < 1200;

          return Container(
            decoration: BoxDecoration(
              gradient:
                  isDarkMode
                      ? LinearGradient(
                        colors: [Colors.grey[900]!, Colors.grey[850]!],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                      : LinearGradient(
                        colors: [Colors.grey[50]!, Colors.grey[100]!],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('demandedeservice')
                      .where('typeDemande', isNotEqualTo: 'retard')
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
                        Icon(Icons.inbox, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "Aucune demande pour le moment",
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: isSmallScreen ? 8 : 16,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return _buildDemandeCard(
                      context: context,
                      data: data,
                      docId: doc.id,
                      isSmallScreen: isSmallScreen,
                      isDarkMode: isDarkMode,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDemandeCard({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String docId,
    required bool isSmallScreen,
    required bool isDarkMode,
  }) {
    final texte = data['texte'] ?? '';
    final audioBase64 = data['audioBase64'];
    final nom = data['nom'] ?? 'Inconnu';
    final poste = data['poste'] ?? '---';
    final pointDeVenteId = data['pointDeVenteId'] ?? '';
    final statut = data['statut'] ?? 'en attente';
    final type = data['typeDemande'] ?? '';
    final montantPret = data['montantPret'];
    final periodeRemboursement = data['periodeRemboursement'];
    final Timestamp? timestamp = data['timestamp'];
    final date = timestamp?.toDate() ?? DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy à HH:mm').format(date);

    return FutureBuilder<String>(
      future: _getNomPointVente(pointDeVenteId),
      builder: (context, snapshot) {
        final nomPointVente = snapshot.data ?? '---';

        return Card(
          margin: EdgeInsets.symmetric(
            vertical: 6,
            horizontal: isSmallScreen ? 4 : 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: isSmallScreen ? 16 : 20,
                      backgroundColor: _getStatusColor(statut).withOpacity(0.2),
                      child: Icon(
                        _getTypeIcon(type),
                        size: isSmallScreen ? 14 : 18,
                        color: _getStatusColor(statut),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nom,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            poste,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: isSmallScreen ? 11 : 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      labelPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 4 : 8,
                      ),
                      label: Text(
                        statut.toUpperCase(),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 11,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(statut),
                        ),
                      ),
                      backgroundColor: _getStatusColor(statut).withOpacity(0.1),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: _getStatusColor(statut).withOpacity(0.3),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isSmallScreen ? 8 : 12),

                // Request content
                if (texte.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      texte,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
                      ),
                    ),
                  ),

                // Loan info
                if (type.trim().toLowerCase() == 'pret' && montantPret != null)
                  Container(
                    margin: EdgeInsets.only(top: isSmallScreen ? 6 : 8),
                    padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.money,
                          color: Colors.blue,
                          size: isSmallScreen ? 18 : 20,
                        ),
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        Flexible(
                          child: Text(
                            "Prêt: ${montantPret.toString()} FCFA ($periodeRemboursement mois)",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                              fontSize: isSmallScreen ? 13 : 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: isSmallScreen ? 8 : 12),

                // Metadata row
                Wrap(
                  spacing: isSmallScreen ? 8 : 16,
                  runSpacing: isSmallScreen ? 4 : 8,
                  children: [
                    _buildMetaItem(
                      Icons.store,
                      nomPointVente,
                      isDarkMode,
                      isSmallScreen,
                    ),
                    _buildMetaItem(
                      Icons.access_time,
                      formattedDate,
                      isDarkMode,
                      isSmallScreen,
                    ),
                    if (type.isNotEmpty)
                      _buildMetaItem(
                        _getTypeIcon(type),
                        _getTypeLabel(type),
                        isDarkMode,
                        isSmallScreen,
                      ),
                  ],
                ),

                if (audioBase64 != null) ...[
                  SizedBox(height: isSmallScreen ? 8 : 16),
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _playingId == docId ? Icons.stop : Icons.play_arrow,
                            color: Colors.blue,
                            size: isSmallScreen ? 20 : 24,
                          ),
                          onPressed: () => _playAudio(docId, audioBase64),
                        ),
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: _playingId == docId ? null : 0,
                            backgroundColor: Colors.grey[300],
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        Text(
                          _playingId == docId ? "En cours..." : "Message vocal",
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color:
                                isDarkMode
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: isSmallScreen ? 12 : 16),

                // Action buttons
                if (statut == 'en attente')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _changerStatut(docId, "refusée", data),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text("Refuser"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _changerStatut(docId, "validée", data),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text("Valider"),
                      ),
                    ],
                  ),
                if (statut == 'validée' && type == 'pret')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _changerStatut(docId, "refusée", data),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text("Annuler"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _decaisserPret(docId, data),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.send_to_mobile, size: 18),
                        label: const Text("Décaisser le Prêt"),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetaItem(
    IconData icon,
    String text,
    bool isDarkMode,
    bool isSmallScreen,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: isSmallScreen ? 14 : 16, color: Colors.grey[500]),
        SizedBox(width: isSmallScreen ? 4 : 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String statut) {
    switch (statut.toLowerCase()) {
      case 'validée':
        return Colors.green;
      case 'refusée':
        return Colors.red;
      case 'décaissé':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pret':
        return Icons.money;
      case 'absence':
        return Icons.person_off;
      case 'conge':
        return Icons.beach_access;
      default:
        return Icons.request_page;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'pret':
        return 'Prêt';
      case 'absence':
        return 'Absence';
      case 'conge':
        return 'Congé';
      default:
        return type;
    }
  }
}
