import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whiskyshop_app/pages/signup.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  String _errorMessage = '';

  void _login() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    try {
      // Authentification
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Récupération de l'utilisateur Firestore
      DocumentSnapshot userDoc =
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData['isActive'] == false) {
          await _auth.signOut(); // déconnecter si inactif
          setState(() {
            _errorMessage =
            "Votre compte a été désactivé. Veuillez contacter l'administrateur.";
            _loading = false;
          });
        } else {
          // Vérifie les documents AVANT redirection
          await checkUserDocuments();

          // Redirection selon le rôle par exemple
          String role = userData['role'] ?? 'employé';
          Navigator.pushReplacementNamed(context, '/${role}_dashboard');
        }
      } else {
        setState(() {
          _errorMessage = "Utilisateur introuvable.";
          _loading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Erreur de connexion.";
        _loading = false;
      });
    }
  }

  Future<void> checkUserDocuments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data();

    final role = data?['role'] ?? '';
    if (role == 'admin') return;

    final docId = data?['pieceIdentite'];
    final acteNaissance = data?['acte_de_naissance'];

    final notifCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications');

    final notifSnapshot =
    await notifCollection
        .where('type', isEqualTo: 'profil_incomplet')
        .limit(1)
        .get();

    final hasMissingDocs =
    (docId == null ||
        docId.isEmpty ||
        acteNaissance == null ||
        acteNaissance.isEmpty);

    if (hasMissingDocs) {
      if (notifSnapshot.docs.isNotEmpty) {
        final docIdNotif = notifSnapshot.docs.first.id;
        await notifCollection.doc(docIdNotif).update({
          'seen': false,
          'timestamp': Timestamp.now(),
        });
      } else {
        await notifCollection.add({
          'title': 'Profil incomplet',
          'message':
          'Veuillez compléter votre profil en ajoutant vos documents justificatifs.',
          'timestamp': Timestamp.now(),
          'seen': false,
          'type': 'profil_incomplet',
          'link': '/profile/${user.uid}',
        });
      }
    } else {
      // ✅ Tous les documents sont fournis → supprimer notification si elle existe
      if (notifSnapshot.docs.isNotEmpty) {
        await notifCollection.doc(notifSnapshot.docs.first.id).delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logowhisky.png', width: 120, height: 120),
                  const SizedBox(height: 16),
                  Text(
                    "Connexion",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.email),
                      labelText: 'Email',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock),
                      labelText: 'Mot de passe',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius
                            .circular(12)),
                        backgroundColor: Colors.brown[700],
                      ),
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white,
                            strokeWidth: 2),
                      )
                          : Text(
                          "Se connecter", style: TextStyle(fontSize: 16, color: Colors.white),),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.red[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignUpPage()),
                      );
                    },
                    child: Text(
                      "Pas encore de compte ? S'inscrire",
                      style: TextStyle(color: Colors.brown[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}