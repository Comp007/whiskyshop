import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/signup.dart';
import 'edit_user_page.dart';

class GestionUtilisateurs extends StatefulWidget {
  const GestionUtilisateurs({super.key});

  @override
  _GestionUtilisateursState createState() => _GestionUtilisateursState();
}

class _GestionUtilisateursState extends State<GestionUtilisateurs> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _users = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('users').get();
      List<Map<String, dynamic>> usersList =
          snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'fullName': data['fullName'] ?? '',
              'phone': data['phone'] ?? '',
              'role': data['role'] ?? '',
              'taches': List<String>.from(data["taches"] ?? []),
              'isActive': data['isActive'] ?? true,
              'matrimoniale': data['maritalStatus'] ?? '',
              'startDate': data['startDate'] ?? '',
              'deactivatedAt': data['deactivatedAt'],
            };
          }).toList();

      setState(() {
        _users = usersList;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors du chargement : ${e.toString()}";
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _users;

    return _users.where((user) {
      return user['fullName'].toString().toLowerCase().contains(query) ||
          user['phone'].toString().toLowerCase().contains(query) ||
          user['role'].toString().toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _deleteUser(String userId) async {
    bool confirmDelete =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Confirmer la suppression"),
                content: const Text(
                  "Cette action est irréversible. Continuer ?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Annuler"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      "Supprimer",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (confirmDelete) {
      try {
        await _firestore.collection('users').doc(userId).delete();
        _fetchUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Utilisateur supprimé"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleUserStatus(String userId, bool isActive) async {
    bool confirm =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  isActive
                      ? "Désactiver l'utilisateur"
                      : "Activer l'utilisateur",
                ),
                content: Text(
                  isActive
                      ? "L'utilisateur ne pourra plus se connecter. Continuer ?"
                      : "L'utilisateur pourra à nouveau se connecter. Continuer ?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Annuler"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      isActive ? "Désactiver" : "Activer",
                      style: TextStyle(
                        color: isActive ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (confirm) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'isActive': !isActive,
          'deactivatedAt': isActive ? DateTime.now() : null,
        });
        _fetchUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isActive ? "Utilisateur désactivé" : "Utilisateur activé",
            ),
            backgroundColor: isActive ? Colors.orange : Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des Utilisateurs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage()),
                ).then((_) => _fetchUsers()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Rechercher un utilisateur...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                        : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            // <-- Utilisez Expanded pour le contenu scrollable
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage.isNotEmpty
                    ? Center(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                    : _filteredUsers.isEmpty
                    ? const Center(child: Text("Aucun utilisateur trouvé"))
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;
                        return GridView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          // <-- Ajustez le padding
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isWide ? 2 : 1,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio:
                                    isWide ? 2.2 : 1.8, // <-- Ajustez ce ratio
                              ),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            final isActive = user['isActive'] ?? true;
                            return Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                // <-- Réduisez le padding interne
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  // <-- Important pour éviter les débordements
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user['fullName'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              // <-- Réduisez légèrement la taille de police
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isActive
                                                    ? Colors.green
                                                    : Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            isActive ? "Actif" : "Inactif",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildCompactUserInfoRow(
                                      Icons.phone,
                                      user['phone'] ?? '',
                                    ),
                                    _buildCompactUserInfoRow(
                                      Icons.work,
                                      user['role'] ?? '',
                                    ),
                                    if (user['taches'] is List &&
                                        user['taches'].isNotEmpty)
                                      _buildCompactUserInfoRow(
                                        Icons.task,
                                        user['taches'].join(', '),
                                      ),
                                    const Spacer(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 20,
                                            color: Colors.blue,
                                          ),
                                          onPressed:
                                              () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) => EditUserPage(
                                                        userId: user['id'],
                                                      ),
                                                ),
                                              ).then((_) => _fetchUsers()),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 20,
                                            color: Colors.red,
                                          ),
                                          onPressed:
                                              () => _deleteUser(user['id']),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isActive
                                                ? Icons.toggle_on
                                                : Icons.toggle_off,
                                            size: 20,
                                            color:
                                                isActive
                                                    ? Colors.green
                                                    : Colors.orange,
                                          ),
                                          onPressed:
                                              () => _toggleUserStatus(
                                                user['id'],
                                                isActive,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactUserInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
