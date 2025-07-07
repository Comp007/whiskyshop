import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/emploi_du_temps_employe.dart';
import 'package:whiskyshop_app/pages/employe_home.dart';
import 'package:whiskyshop_app/pages/login.dart';
import 'package:whiskyshop_app/pages/notification_employe_page_page.dart';
import 'package:whiskyshop_app/pages/profil_page.dart';
import 'package:whiskyshop_app/pages/scanner_qr_presence.dart';
import 'package:whiskyshop_app/pages/suivi_gerant_page.dart';
import 'demande_service.dart';
import 'historique_virements.dart';

class EmployeDashboard extends StatefulWidget {
  const EmployeDashboard({super.key});

  @override
  State<EmployeDashboard> createState() => _EmployeDashboardState();
}

class _EmployeDashboardState extends State<EmployeDashboard> {
  Widget _currentScreen = const EmployeHome();
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _changeScreen(Widget screen) {
    setState(() {
      _currentScreen = screen;
    });
    Navigator.pop(context); // Ferme le Drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green[700],
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Builder(
              builder: (context) {
                // Stream des notifications non lues
                final Stream<int> unreadCountStream = FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('notifications')
                    .where('seen', isEqualTo: false)
                    .snapshots()
                    .map((snapshot) => snapshot.docs.length);

                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          "Tableau de bord Employé",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    StreamBuilder<int>(
                      stream: unreadCountStream,
                      builder: (context, snapshot) {
                        int count = snapshot.data ?? 0;
                        return Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications, color: Colors.white),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const NotificationsEmployePage()),
                                );
                              },
                            ),
                            if (count > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  child: Text(
                                    count.toString(),
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
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.white),
              padding: const EdgeInsets.all(16),
              margin: EdgeInsets.zero,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.green,
                    child: Icon(Icons.work, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Employé", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        SizedBox(height: 4),
                        Text("Espace personnel", style: TextStyle(fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _buildDrawerItem(Icons.dashboard, "Accueil", const EmployeHome()),
                  _buildDrawerItem(Icons.schedule, "Mon Emploi du Temps", EmploiDuTempsEmploye(employeUid: uid)),
                  _buildDrawerItem(Icons.qr_code_scanner, "Marquer ma présence", const ScannerQrPresence()),
                  _buildDrawerItem(Icons.attach_money, "Mes Paiements", const HistoriqueVirements()),
                  _buildDrawerItem(Icons.request_page, "Demander un Service", const DemandeService()),
                  _buildDrawerItem(Icons.person, "Mon Profil", ProfilPage(userId: uid)),
                  _buildDrawerItem(Icons.notifications, "Notifications", const NotificationsEmployePage()),
                  _buildDrawerItem(Icons.note_alt, "Noter votre gérant", const SuiviGerantPage()),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Déconnexion", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentScreen,
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, Widget screen) {
    return ListTile(
      leading: Icon(icon, color: Colors.green[700]),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () => _changeScreen(screen),
    );
  }
}
