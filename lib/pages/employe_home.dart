import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/emploi_du_temps_employe.dart';
import 'package:whiskyshop_app/pages/historique_virements.dart';
import 'package:whiskyshop_app/pages/demande_service.dart';
import 'package:whiskyshop_app/pages/profil_page.dart';
import 'package:whiskyshop_app/pages/scanner_qr_presence.dart';
import 'package:whiskyshop_app/pages/suivi_gerant_page.dart';

class EmployeHome extends StatelessWidget {
  const EmployeHome({super.key});

  Stream<int> getUnreadNotificationsCount(String userUid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userUid)
        .collection('notifications')
        .where('seen', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    final String? userUid = FirebaseAuth.instance.currentUser?.uid;

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
              title: 'Emploi du Temps',
              icon: Icons.schedule,
              color: Colors.indigo,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => EmploiDuTempsEmploye(
                          employeUid: FirebaseAuth.instance.currentUser!.uid,
                        ),
                  ),
                );
              },
            ),
            _buildCard(
              context,
              title: 'Scanner Présence',
              icon: Icons.access_time,
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ScannerQrPresence()),
                );
              },
            ),
            _buildCard(
              context,
              title: 'Historique Paiements',
              icon: Icons.account_balance_wallet,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HistoriqueVirements()),
                );
              },
            ),
            _buildCard(
              context,
              title: 'Demander un Service',
              icon: Icons.request_page,
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DemandeService()),
                );
              },
            ),
            _buildCard(
              context,
              title: 'Mon Profil',
              icon: Icons.person,
              color: Colors.brown,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilPage(userId: userUid!),
                  ),
                );
              },
            ),

            _buildCard(
              context,
              title: 'Noter le Gérant',
              icon: Icons.note,
              color: Colors.deepPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SuiviGerantPage()),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardWithBadge(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Stream<int> stream,
    required VoidCallback onTap,
  }) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        int unreadCount = snapshot.data ?? 0;

        return Stack(
          children: [
            _buildCard(
              context,
              title: title,
              icon: icon,
              color: color,
              onTap: onTap,
            ),
            if (unreadCount > 0)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
