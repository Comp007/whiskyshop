import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/admin_demande_service.dart';
import 'package:whiskyshop_app/pages/admin_home.dart';
import 'package:whiskyshop_app/pages/gestion_point_vente.dart';
import 'package:whiskyshop_app/pages/gestion_utilisateurs.dart';
import 'package:whiskyshop_app/pages/login.dart';
import 'package:whiskyshop_app/pages/paiement_acceuil_page.dart';
import 'package:whiskyshop_app/pages/stats.dart';
import 'package:whiskyshop_app/pages/suivi_employes_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Widget _currentScreen = const AdminHome(); // Page d'accueil

  void _changeScreen(Widget screen) {
    setState(() {
      _currentScreen = screen;
    });
    Navigator.pop(context); // Ferme le drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.deepPurple,
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
            child: Builder( // pour avoir accès à Scaffold.of(context)
              builder: (context) => Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Tableau de bord Admin",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // pour équilibrer la ligne
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.grey[100],
          child: Column(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(16),
                margin: EdgeInsets.zero,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.deepPurple,
                      child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Administrateur",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Espace sécurisé",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  children: [
                    _buildDrawerItem(Icons.dashboard, "Accueil", const AdminHome()),
                    _buildDrawerItem(Icons.people, "Gestion des Utilisateurs", const GestionUtilisateurs()),
                    _buildDrawerItem(Icons.store, "Points de Vente", const GestionPointVente()),
                    _buildDrawerItem(Icons.payment, "Paiements & Suivi", const PaiementAccueilPage()),
                    _buildDrawerItem(Icons.bar_chart, "Statistiques", const Stats()),
                    _buildDrawerItem(Icons.request_page, "Demandes de Service", const AdminDemandeService()),
                    _buildDrawerItem(Icons.badge, "Suivi des Employés", const SuiviEmployesPage()),
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
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentScreen,
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, Widget screen) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () => _changeScreen(screen),
    );
  }
}
