import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/gerant_home.dart';
import 'package:whiskyshop_app/pages/gerant_retard_page.dart';
import 'package:whiskyshop_app/pages/liste_employes_gestion_temps.dart';
import 'package:whiskyshop_app/pages/login.dart';
import 'package:whiskyshop_app/pages/notifications_gerant_page.dart';
import 'package:whiskyshop_app/pages/scanner_qr_presence.dart';
import 'historique_pointages.dart';
import 'liste_employes.dart';

class GerantDashboard extends StatefulWidget {
  const GerantDashboard({super.key});

  @override
  State<GerantDashboard> createState() => _GerantDashboardState();
}

class _GerantDashboardState extends State<GerantDashboard> {
  Widget _currentScreen = const GerardHome();
  String? employeId;

  @override
  void initState() {
    super.initState();
    _fetchEmployeId();
  }

  void _changeScreen(Widget screen) {
    setState(() {
      _currentScreen = screen;
    });
    Navigator.pop(context); // Ferme le drawer
  }

  Future<void> _fetchEmployeId() async {
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid != null) {
      final notesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .collection('notes')
          .get();

      if (notesSnapshot.docs.isNotEmpty) {
        final data = notesSnapshot.docs.first.data();
        if (data.containsKey('employeId')) {
          setState(() {
            employeId = data['employeId'];
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
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
                final userUid = FirebaseAuth.instance.currentUser?.uid;
                final Stream<int> unreadCountStream = (userUid != null)
                    ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(userUid)
                    .collection('notifications')
                    .where('seen', isEqualTo: false)
                    .snapshots()
                    .map((snapshot) => snapshot.docs.length)
                    : Stream.value(0);

                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          "Tableau de bord Gérant",
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
                              onPressed: () async {
                                if (userUid != null) {
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
                                }
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
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.supervisor_account, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Gérant", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        SizedBox(height: 4),
                        Text("Espace professionnel", style: TextStyle(fontSize: 14, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _buildDrawerItem(Icons.dashboard, "Accueil", const GerardHome()),
                  _buildDrawerItem(Icons.people, "Liste des Employés", const ListeEmployes()),
                  _buildDrawerItem(Icons.schedule, "Gérer les Emplois du Temps", const ListeEmployesGestion()),
                  _buildDrawerItem(Icons.history, "Historique des Pointages", const HistoriquePointages()),
                  _buildDrawerItem(Icons.qr_code_scanner, "Marquer ma présence", const ScannerQrPresence()),
                  _buildDrawerItem(Icons.request_page, "Gerer demande de retard", const GerantRetardPage()),

                  ListTile(
                    leading: Icon(Icons.notifications, color: Colors.blueAccent),
                    title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.w500)),
                    onTap: () {
                      if (employeId != null) {
                        _changeScreen(NotificationsGerantPage(employeId: employeId!));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Employé ID introuvable."),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
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
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () => _changeScreen(screen),
    );
  }
}
