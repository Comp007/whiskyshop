import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/gerant_retard_page.dart';
import 'package:whiskyshop_app/pages/liste_employes.dart';
import 'package:whiskyshop_app/pages/historique_pointages.dart';
import 'package:whiskyshop_app/pages/liste_employes_gestion_temps.dart';
import 'package:whiskyshop_app/pages/notifications_gerant_page.dart';
import 'package:whiskyshop_app/pages/profil_page.dart';
import 'package:whiskyshop_app/pages/scanner_qr_presence.dart';

class GerardHome extends StatelessWidget {
  const GerardHome({super.key});

  Stream<int> getUnreadNotificationsCount(String userUid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userUid)
        .collection('notifications')
        .where('seen', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getUnreadRetardRequestsCount(String pointDeVenteId) {
    return FirebaseFirestore.instance
        .collection('demandedeservice')
        .where('typeDemande', isEqualTo: 'retard')
        .where('pointDeVenteId', isEqualTo: pointDeVenteId)
        .where('statut', isEqualTo: 'en attente')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    final String? userUid = FirebaseAuth.instance.currentUser?.uid;
    String? pointDeVenteId;

    // Récupérer le pointDeVenteId du gérant
    if (userUid != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .get()
          .then((doc) {
        if (doc.exists) {
          pointDeVenteId = doc.data()?['pointDeVenteId'];
        }
      });
    }

    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildCard(
              context,
              title: 'Liste des Employés',
              icon: Icons.people,
              color: Colors.blue,
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ListeEmployes()));
              },
            ),
            _buildCard(
              context,
              title: 'Gestion Emplois du Temps',
              icon: Icons.schedule,
              color: Colors.teal,
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ListeEmployesGestion()));
              },
            ),
            _buildCard(
              context,
              title: 'Historique des Pointages',
              icon: Icons.history,
              color: Colors.orange,
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => HistoriquePointages()));
              },
            ),

            _buildCard(
              context,
              title: 'Scanner Présence',
              icon: Icons.access_time,
              color: Colors.indigo,
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ScannerQrPresence()));
              },
            ),

            if (pointDeVenteId != null)
            StreamBuilder<int>(
              stream: getUnreadRetardRequestsCount(pointDeVenteId!),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return _buildCard(
                  context,
                  title: 'Demandes de retard',
                  icon: Icons.access_time,
                  color: Colors.indigo,
                  badgeCount: unreadCount,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GerantRetardPage()),
                    );
                  },
                );
              },
            )
            else
              _buildCard(
                context,
                title: 'Demandes de retard',
                icon: Icons.access_time,
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GerantRetardPage()),
                  );
                },
              ),

            _buildCard(
              context,
              title: 'Notifications',
              icon: Icons.notifications,
              color: Colors.red,
              // Ne pas passer de badgeCount pour cette carte
              onTap: () async {
                try {
                  final notesSnapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userUid)
                      .collection('notes')
                      .get();

                  if (notesSnapshot.docs.isNotEmpty) {
                    final data = notesSnapshot.docs.first.data();
                    if (data.containsKey('employeId')) {
                      String employeId = data['employeId'];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationsGerantPage(employeId: employeId),
                        ),
                      );
                    } else {
                      throw Exception("Le champ 'employeId' est manquant.");
                    }
                  } else {
                    throw Exception("Aucune note trouvée.");
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erreur : ${e.toString()}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            _buildCard(
              context,
              title: 'Mon Profil',
              icon: Icons.person,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ProfilPage(
                                userId: FirebaseAuth.instance.currentUser!
                                    .uid)
                    )
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        int? badgeCount,
        required VoidCallback onTap,
      }) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.42, // Largeur uniforme
          height: 180, // Hauteur fixe pour toutes les cartes
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.1),
                      radius: 30,
                      child: Icon(icon, color: color, size: 30),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      child: Text(
                        badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
