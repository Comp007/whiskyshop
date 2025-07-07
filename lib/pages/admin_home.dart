import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/admin_demande_service.dart';
import 'package:whiskyshop_app/pages/gestion_point_vente.dart';
import 'package:whiskyshop_app/pages/gestion_utilisateurs.dart';
import 'package:whiskyshop_app/pages/paiement_acceuil_page.dart';
import 'package:whiskyshop_app/pages/stats.dart';
import 'package:whiskyshop_app/pages/suivi_employes_page.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Adaptation dynamique en fonction de la largeur de l'écran
          final isDesktop = constraints.maxWidth > 800;
          final isTablet = constraints.maxWidth > 600 && !isDesktop;

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32.0 : 16.0,
              vertical: isDesktop ? 24.0 : 16.0,
            ),
            child: GridView.count(
              crossAxisCount: isDesktop
                  ? 4
                  : isTablet
                  ? 3
                  : 2,
              childAspectRatio: isDesktop ? 1.0 : 0.9,
              crossAxisSpacing: isDesktop ? 24.0 : 16.0,
              mainAxisSpacing: isDesktop ? 24.0 : 16.0,
              children: [
                _buildDashboardCard(
                  context,
                  title: 'Utilisateurs',
                  icon: Icons.people,
                  color: Colors.blue,
                  page: const GestionUtilisateurs(),
                  isDesktop: isDesktop,
                ),
                _buildDashboardCard(
                  context,
                  title: 'Points de Vente',
                  icon: Icons.store,
                  color: Colors.teal,
                  page: const GestionPointVente(),
                  isDesktop: isDesktop,
                ),
                _buildDashboardCard(
                  context,
                  title: 'Paiements',
                  icon: Icons.payment,
                  color: Colors.green,
                  page: const PaiementAccueilPage(),
                  isDesktop: isDesktop,
                ),
                _buildDashboardCard(
                  context,
                  title: 'Statistiques',
                  icon: Icons.bar_chart,
                  color: Colors.orange,
                  page: const Stats(),
                  isDesktop: isDesktop,
                ),
                _buildDashboardCard(
                  context,
                  title: 'Demandes Service',
                  icon: Icons.request_page,
                  color: Colors.purple,
                  page: const AdminDemandeService(),
                  isDesktop: isDesktop,
                ),
                _buildDashboardCard(
                  context,
                  title: 'Suivi Employés',
                  icon: Icons.badge,
                  color: Colors.redAccent,
                  page: const SuiviEmployesPage(),
                  isDesktop: isDesktop,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required Widget page,
        required bool isDesktop,
      }) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        child: Container(
          padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                radius: isDesktop ? 40 : 30,
                child: Icon(
                  icon,
                  color: color,
                  size: isDesktop ? 36 : 30,
                ),
              ),
              SizedBox(height: isDesktop ? 20 : 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}