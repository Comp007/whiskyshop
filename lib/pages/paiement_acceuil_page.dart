import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PaiementAccueilPage extends StatelessWidget {
  const PaiementAccueilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Centre de Paiements", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildOptionCard(
              context,
              icon: LucideIcons.wallet,
              color: Colors.green,
              title: "Gérer Paiements",
              description: "Initier et effectuer les paiements mensuels",
              onTap: () => Navigator.pushNamed(context, '/gestionPaiements'),
            ),
            const SizedBox(height: 20),
            _buildOptionCard(
              context,
              icon: LucideIcons.history,
              color: Colors.indigo,
              title: "Historique des paiements",
              description: "Voir tous les paiements précédents",
              onTap: () => Navigator.pushNamed(context, '/historiquePaiements'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String title,
        required String description,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 6),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
