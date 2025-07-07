import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ProfilPage extends StatefulWidget {
  final String userId;

  const ProfilPage({required this.userId, super.key});

  @override
  State<ProfilPage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilPage> {
  final _firestore = FirebaseFirestore.instance;

  bool _isUploading = false;
  final _fullNameController = TextEditingController();
  final _roleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _startDateController = TextEditingController();
  //final _maritalStatusController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  bool _isFullNameEditable = true;
  bool _isPhoneEditable = true;
  bool _isEducationLevelEditable = true;
  bool _isStartDateEditable = true;
  bool _isMaritalStatusEditable = true;
  bool _isAddressEditable = true;
  bool _isEmergencyContactEditable = true;


  String? _selectedRole;
  String? _selectedEducationLevel;
  String? _selectedMaritalStatuses;
  bool _isRegisteredCnss = false;

  String? _acteDeNaissanceUrl;
  String? _pieceIdentiteUrl;
  String? _diplomeUrl;

  File? _selectedFile;
  String? _selectedFileType;
  List<String> _educationLevels = [];

  List<String> _maritalStatuses = [];
  String? _profilePhotoUrl;



  Future<void> _loadEducationLevels() async {
    try {
      final doc = await _firestore.collection('settings').doc('education_levels').get();
      final levels = List<String>.from(doc['name']);
      setState(() {
        _educationLevels = levels;
      });
    } catch (e) {
      setState(() {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"Erreur lors du chargement des niveaux d\'études : $e')),
        );
      });
    }
  }

  Future<void> _loadMaritalStatuses() async {
    try {
      final doc = await _firestore.collection('settings').doc('marital_statuses').get();
      final statuses = List<String>.from(doc['name']);

      if (kDebugMode) {
        print("Statuts matrimoniaux chargés : $statuses");
      } // 👈 DEBUG ici
      setState(() {
        _maritalStatuses = statuses;
      });
    } catch (e) {
      setState(() {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement des statuts matrimoniaux : $e')),
        );
      });
    }
  }

  Widget _buildDropdownField({
    required String label,
    required List<String> items,
    required String? selectedValue,
    required bool enabled,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        onChanged: enabled ? onChanged : null,
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }


  Widget _buildTextField(String label, TextEditingController controller, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  void ouvrirDocument(BuildContext context, String url) {
    final isPdf = url.toLowerCase().endsWith('.pdf');
    final isImage = url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.png');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text("Aperçu du document")),
          body: isPdf
              ? SfPdfViewer.network(url)
              : isImage
              ? InteractiveViewer(child: Center(child: Image.network(url)))
              : Center(child: Text("Format de document non supporté")),
        ),
      ),
    );
  }

  Widget _buildUploadSection(String label, String type, String? url) {
    final isSelected = _selectedFile != null && _selectedFileType == type;

    // LOGIQUE STRICTE APPLIQUÉE
    if (url != null && url.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text("Document disponible : ${Uri.parse(url).pathSegments.last}"),
              const SizedBox(height: 4),
              TextButton.icon(
                icon: Icon(Icons.visibility),
                label: Text("Voir le document"),
                onPressed: () => ouvrirDocument(context, url),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (!isSelected)
              ElevatedButton(
                onPressed: () => _pickDocument(type),
                child: Text("Choisir un fichier", style: TextStyle(color: Colors.blue),),
              ),
            if (isSelected) ...[
              Text("Fichier sélectionné : ${_selectedFile!.path.split('/').last}"),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _confirmUpload,
                    icon: _isUploading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                    )
                        : Icon(Icons.upload),
                    label: Text(
                      _isUploading ? "Chargement..." : "Confirmer",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedFile = null;
                      _selectedFileType = null;
                    }),
                    child: Text("Annuler", style: TextStyle(color: Colors.blue),),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: Icon(Icons.visibility),
                label: Text("Prévisualiser", style: TextStyle(color: Colors.blue),),
                onPressed: () async {
                  if (_selectedFile != null && await _selectedFile!.exists()) {
                    await OpenFile.open(_selectedFile!.path);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Fichier local introuvable pour prévisualisation."),
                      backgroundColor: Colors.red,
                    ));
                  }
                },
              ),

            ]
          ],
        ),
      ),
    );
  }



  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {

      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('users/${widget.userId}/profile_photo.jpg');


        await ref.putFile(File(picked.path)); // Uploader le fichier d'abord
        final downloadUrl = await ref.getDownloadURL(); // Ensuite obtenir l'URL


        await _firestore.collection('users').doc(widget.userId).update({
          'profilePhoto': downloadUrl,
        });

        setState(() {
          _profilePhotoUrl = downloadUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Photo de profil mise à jour")),
        );
      } catch (e) {
        if (kDebugMode) {
          print("Erreur upload profil : $e");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Échec de l'envoi de la photo")),
        );
      }
    }
  }
  Widget _buildProfilePhoto() {
    final imageProvider = _profilePhotoUrl != null
        ? NetworkImage(_profilePhotoUrl!)
        : AssetImage('assets/avatar.jpeg') as ImageProvider;

    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              if (_profilePhotoUrl != null) {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: Image.network(_profilePhotoUrl!),
                  ),
                );
              }
            },
            child: CircleAvatar(
              radius: 60,
              backgroundImage: imageProvider,
              backgroundColor: Colors.grey[200],
            ),
          ),
          Positioned(
            bottom: 0,
            right: 4,
            child: GestureDetector(
              onTap: _pickProfilePhoto,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue,
                child: Icon(Icons.edit, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDocument(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);

      setState(() {
        _selectedFile = file;
        _selectedFileType = type;
      });
    }
  }



  Future<void> _confirmUpload() async {
    if (_selectedFile == null || _selectedFileType == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final fileName = _selectedFile!.path.split('/').last;
      final ref = FirebaseStorage.instance
          .ref()
          .child('users/${widget.userId}/$_selectedFileType/$fileName');

      await ref.putFile(_selectedFile!);
      final downloadUrl = await ref.getDownloadURL();


      // Mise à jour du lien dans Firestore
      await _firestore.collection('users').doc(widget.userId).update({
        _selectedFileType!: downloadUrl,
      });

      setState(() {
        if (_selectedFileType == 'acte_de_naissance') {
          _acteDeNaissanceUrl = downloadUrl;
        } else if (_selectedFileType == 'pieceIdentite') {
          _pieceIdentiteUrl = downloadUrl;
        } else {
          _diplomeUrl = downloadUrl;
        }

        _selectedFile = null;
        _selectedFileType = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Document stocké avec succès dans le cloud.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (kDebugMode) {
        print("Erreur stockage : $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur lors de l’envoi du document.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }


  Future<void> _loadUserData() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.userId).get();
      if (!doc.exists) return;
      final data = doc.data();
      setState(() {
        _fullNameController.text = data?['fullName'] ?? '';
        _phoneController.text = data?['phone'] ?? '';
        _selectedRole = data?['role'];
        _roleController.text = _selectedRole ?? '';
        _selectedEducationLevel = data?['educationLevel'];
        _isRegisteredCnss = data?['cnssDeclared'] ?? false;
        _startDateController.text = data?['startDate'] ?? '';
        _selectedMaritalStatuses = data?['maritalStatus'];
        _addressController.text = data?['adresse'] ?? '';
        _emergencyContactController.text = data?['emergencyContact'] ?? '';
        _pieceIdentiteUrl = data?['pieceIdentite'];
        _acteDeNaissanceUrl = data?['acte_de_naissance'];
        _diplomeUrl = data?['diplomes'];

        _isFullNameEditable = _fullNameController.text.trim().isEmpty;
        _isPhoneEditable = _phoneController.text.trim().isEmpty;
        _isEducationLevelEditable = (_selectedEducationLevel == null || _selectedEducationLevel!.isEmpty);
        _isMaritalStatusEditable = (_selectedMaritalStatuses == null || _selectedMaritalStatuses!.isEmpty);

        _isStartDateEditable = _startDateController.text.isEmpty;
        _isAddressEditable = _addressController.text.isEmpty;
        _isEmergencyContactEditable = _emergencyContactController.text.isEmpty;
        _profilePhotoUrl = data?['profilePhoto'];

      });
    } catch (e) {
      if (kDebugMode) {
        print("Erreur chargement données : $e");
      }
    }
  }

  Future<void> _saveUserProfile() async {
    try {
      await _firestore.collection('users').doc(widget.userId).update({
        if (_fullNameController.text.isNotEmpty && _isFullNameEditable)
          'fullName': _fullNameController.text,
        if (_phoneController.text.isNotEmpty && _isPhoneEditable)
          'phone': _phoneController.text,
        if (_selectedEducationLevel != null && _isEducationLevelEditable)
          'educationLevel': _selectedEducationLevel,
        if (_startDateController.text.isNotEmpty && _isStartDateEditable)
          'startDate': _startDateController.text,
        if (_selectedMaritalStatuses != null && _isMaritalStatusEditable)
          'maritalStatus': _selectedMaritalStatuses,
        if (_addressController.text.isNotEmpty && _isAddressEditable)
          'adresse': _addressController.text,
        if (_emergencyContactController.text.isNotEmpty && _isEmergencyContactEditable)
          'emergencyContact': _emergencyContactController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Profil mis à jour."), backgroundColor: Colors.green),
      );

      setState(() {
        _isFullNameEditable = false;
        _isPhoneEditable = false;
        _isEducationLevelEditable = false;
        _isStartDateEditable = false;
        _isMaritalStatusEditable = false;
        _isAddressEditable = false;
        _isEmergencyContactEditable = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Erreur mise à jour profil : $e");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la mise à jour du profil."), backgroundColor: Colors.red),
      );
    }
  }

  bool _documentsCompletementValides() {
    return (_fullNameController.text.isEmpty && _phoneController.text.isEmpty && _selectedEducationLevel != null && _startDateController.text.isNotEmpty &&
        _selectedMaritalStatuses != null && _addressController.text.isNotEmpty &&
        _emergencyContactController.text.isNotEmpty );
  }




  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadEducationLevels();
    _loadMaritalStatuses();
  }


  @override
  void dispose() {
    _fullNameController.dispose();
    _roleController.dispose();
    _phoneController.dispose();
    _startDateController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mon Profil"), centerTitle: true,),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfilePhoto(),
            const SizedBox(height: 16),
            _buildTextField("Nom complet", _fullNameController, enabled: _isFullNameEditable),
            _buildTextField("Téléphone", _phoneController, enabled: _isPhoneEditable),
            _buildTextField("Rôle", _roleController, enabled: false),
            Row(
              children: [
                Checkbox(value: _isRegisteredCnss, onChanged: null),
                Text("Déclaré à la CNSS")
              ],
            ),

            TextFormField(
              controller: _startDateController,
              readOnly: true,
              enabled: _isStartDateEditable,
              decoration: InputDecoration(
                labelText: "Date de début",
                border: OutlineInputBorder(),
              ),
              onTap: () async {
                if (!_isStartDateEditable) return;
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
            _buildDropdownField(
              label: "Niveau d'étude",
              items: _educationLevels,
              selectedValue: _selectedEducationLevel,
              enabled: _isEducationLevelEditable,
              onChanged: (value) {
                setState(() {
                  _selectedEducationLevel = value;
                });
              },
            ),
            _buildDropdownField(
              label: "Statut matrimonial",
              items: _maritalStatuses,
              selectedValue: _selectedMaritalStatuses,
              enabled: _isMaritalStatusEditable,
              onChanged: (value) {
                setState(() {
                  _selectedMaritalStatuses = value;
                });
              },
            ),
            _buildTextField("Adresse", _addressController, enabled: _isAddressEditable),
            _buildTextField("Contact d'urgence", _emergencyContactController, enabled: _isEmergencyContactEditable),

            const SizedBox(height: 16),
            if (_pieceIdentiteUrl == null || _pieceIdentiteUrl == 'UPLOADED')
              _buildUploadSection("Pièce d'identité", "pieceIdentite", _pieceIdentiteUrl),

            if (_acteDeNaissanceUrl == null || _acteDeNaissanceUrl == 'UPLOADED')
              _buildUploadSection("Acte de naissance", "acte_de_naissance", _acteDeNaissanceUrl),

            if (_diplomeUrl == null || _diplomeUrl == 'UPLOADED')
              _buildUploadSection("Diplômes", "diplomes", _diplomeUrl),


            const SizedBox(height: 20),
            if (!_documentsCompletementValides())
              ElevatedButton.icon(
                onPressed: _saveUserProfile,
                icon: Icon(Icons.save, color: Colors.white),
                label: Text("Enregistrer", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.green,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
