import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';




class EditUserPage extends StatefulWidget {
  final String userId;
  const EditUserPage({super.key, required this.userId});

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  String _errorMessage = '';

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();

  String? _identityDocUrl;
  String? _birthCertUrl;
  String? _diplomaUrl;
  bool _identityDocValidated = false;
  bool _birthCertValidated = false;
  bool _diplomaValidated = false;

  String? _selectedRole;
  String? _selectedEducationLevel;
  String? _selectedMaritalStatuses;
  bool _isRegisteredCnss = false;

  List<String> _rolesFromDb = [];
  List<String> _educationLevels = [];
  List<String> _maritalStatuses = [];

  @override
  void initState() {
    super.initState();
    _loadRoles().then((_) => _loadUser());
    _loadEducationLevels();
    _loadMaritalStatuses();
    _loadUserValidationStatus();
  }

  Future<void> _loadRoles() async {
    try {
      final snapshot = await _firestore.collection('roles').get();
      final roles = snapshot.docs.map((doc) => doc['name'].toString()).toList();
      setState(() {
        _rolesFromDb = roles;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors du chargement des rôles : $e";
      });
    }
  }
  Future<void> _loadEducationLevels() async {
    try {
      final doc = await _firestore.collection('settings').doc('education_levels').get();
      final levels = List<String>.from(doc['name']);
      setState(() {
        _educationLevels = levels;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors du chargement des niveaux d'études : $e";
      });
    }
  }

  Future<void> _loadMaritalStatuses() async {
    try {
      final doc = await _firestore.collection('settings').doc('marital_statuses').get();
      final statuses = List<String>.from(doc['name']);

      setState(() {
        _maritalStatuses = statuses;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors du chargement des statuts matrimoniaux : $e";
      });
    }
  }

  Future<void> _loadUser() async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(widget.userId).get();
      if (!doc.exists) {
        setState(() {
          _errorMessage = "Utilisateur non trouvé";
          _loading = false;
        });
        return;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      _fullNameController.text = data['fullName'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _startDateController.text = data['startDate'] ?? '';
      _selectedMaritalStatuses = data['maritalStatus'];
      _identityDocUrl = data['pieceIdentite'];
      _birthCertUrl = data['acte_de_naissance'];
      _diplomaUrl = data['diplomes'];
      _identityDocValidated = data['pieceIdentiteValidated'] ?? false;
      _birthCertValidated = data['acte_de_naissanceValidated'] ?? false;
      _diplomaValidated = data['diplomesValidated'] ?? false;
      _selectedRole = data['role'];
      _selectedEducationLevel = data['educationLevel'];
      _isRegisteredCnss = data['registeredCnss'] ?? false;
      _addressController.text = data['adresse'] ?? '';
      _emergencyContactController.text = data['emergencyContact'] ?? '';

      //print("Statuts matrimoniaux chargés : $data['maritalStatus']");

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors du chargement de l'utilisateur : $e";
        _loading = false;
      });
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner un rôle.")),
      );
      return;
    }

    try {
      await _firestore.collection('users').doc(widget.userId).update({
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
        'educationLevel': _selectedEducationLevel,
        'registeredCnss': _isRegisteredCnss,
        'startDate': _startDateController.text.trim(),
        'maritalStatus': _selectedMaritalStatuses,
        'adresse': _addressController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Utilisateur mis à jour avec succès")),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la mise à jour : $e")),
      );
    }
  }

  Future<void> _rejectDocument(String docType) async {
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rejeter le document"),
        content: const Text(
            "Voulez-vous vraiment rejeter ce document ? Une notification sera envoyée à l'utilisateur."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Annuler")),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Rejeter", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ??
        false;

    if (!confirm) return;

    try {
      await _firestore.collection('users').doc(widget.userId).update({
        docType: FieldValue.delete(),
        '${docType}Validated': false,
      });

      String nomDuDocument = docType == 'pieceIdentite'
          ? 'la pièce d\'identité'
          : docType == 'acte_de_naissance'
          ? 'l\'acte de naissance'
          : 'le diplome';

      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('notifications')
          .add({
        'title': "Document rejeté",
        'message': "Votre $nomDuDocument a été rejeté. Veuillez le soumettre à nouveau.",
        'timestamp': Timestamp.now(),
        'seen': false,
        'type': 'rejet',
        'link': '/profile/${widget.userId}',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Document rejeté et notification envoyée.")),
      );

      setState(() {
        if (docType == 'pieceIdentite') {
          _identityDocUrl = null;
          _identityDocValidated = false;
        }
        if (docType == 'acte_de_naissance') {
          _birthCertUrl = null;
          _birthCertValidated = false;
        }
        if (docType == 'diplomes') {
          _diplomaUrl = null;
          _diplomaValidated = false;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors du rejet : $e")),
      );
    }
  }

  Future<void> _loadUserValidationStatus() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.userId).get();
      final data = doc.data();

      if (data != null) {
        setState(() {
          _identityDocValidated = data['pieceIdentiteValidated'] == true;
          _birthCertValidated = data['acte_de_naissanceValidated'] == true;
          _diplomaValidated = data['diplomesValidated'] == true;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur chargement des statuts de validation : $e");
      }
    }
  }


  Future<void> _validateDocument(String docType) async {
    try {
      await _firestore.collection('users').doc(widget.userId).update({
        '${docType}Validated': true,
      });


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$docType validé.")),
      );

      setState(() {
        if (docType == 'pieceIdentite') {
          _identityDocValidated = true;
        }
        if (docType == 'acte_de_naissance') {
          _birthCertValidated = true;
        }
        if (docType == 'diplomes') {
          _diplomaValidated = true;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la validation : $e")),
      );
    }
  }

  void openDocumentFromUrl(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text("Aperçu du document")),
          body: SfPdfViewer.network(url),
        ),
      ),
    );
  }




  Widget _buildDocumentCard({
    required String docType,
    required String title,
    required String? docUrl, // Firebase Storage URL
    required bool validated,
  }) {
    if (docUrl == null) {
      return Card(
        child: ListTile(
          title: Text(title),
          subtitle: const Text("Aucun document soumis"),
        ),
      );
    }

    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(validated ? "Validé" : "Non validé"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.visibility, color: Colors.blue),
              onPressed: () async {
                try {
                  final ref = FirebaseStorage.instance.refFromURL(docUrl);
                  final downloadUrl = await ref.getDownloadURL();
                  openDocumentFromUrl(context, downloadUrl);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Impossible d’ouvrir le document : $e")),
                  );
                }
              },

              tooltip: "Voir le document",
            ),

            if (!validated) ...[
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => _validateDocument(docType),
                tooltip: "Valider",
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _rejectDocument(docType),
                tooltip: "Rejeter",
              ),

            ]
          ],
        ),
      ),
    );
  }


  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _startDateController.dispose();
    //_maritalStatusController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Modifier utilisateur")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Modifier utilisateur")),
        body: Center(
          child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Modifier utilisateur"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.green),
            onPressed: _saveUser,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: "Nom complet",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? "Nom requis" : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: "Téléphone",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                value == null || value.isEmpty ? "Téléphone requis" : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: _rolesFromDb
                    .map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(role),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedRole = val),
                decoration: const InputDecoration(
                  labelText: "Rôle",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                validator: (val) => val == null ? "Rôle requis" : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedEducationLevel,
                items: _educationLevels
                    .map((level) => DropdownMenuItem(
                  value: level,
                  child: Text(level),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedEducationLevel = val),
                decoration: const InputDecoration(
                  labelText: "Niveau d'études",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text("Inscrit à la CNSS"),
                value: _isRegisteredCnss,
                onChanged: (val) => setState(() => _isRegisteredCnss = val),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _startDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Date de début",
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _startDateController.text =
                      "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedMaritalStatuses,
                items: _maritalStatuses
                    .map((level) => DropdownMenuItem(
                  value: level,
                  child: Text(level),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedMaritalStatuses = val),
                decoration: const InputDecoration(
                  labelText: "Situation matrimoniale",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: "Adresse",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(
                  labelText: "Contact d'urgence",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Documents justificatifs",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),

              _buildDocumentCard(
                docType: 'pieceIdentite',
                title: "Pièce d'identité",
                docUrl: _identityDocUrl,
                validated: _identityDocValidated,
              ),


              _buildDocumentCard(
                docType: 'acte_de_naissance',
                title: "Acte de naissance",
                docUrl: _birthCertUrl,
                validated: _birthCertValidated,
              ),

              _buildDocumentCard(
                docType: 'diplomes',
                title: "Diplômes",
                docUrl: _diplomaUrl,
                validated: _diplomaValidated,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
