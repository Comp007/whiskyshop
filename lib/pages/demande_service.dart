// ... [Imports inchangés]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DemandeService extends StatefulWidget {
  const DemandeService({super.key});

  @override
  State<DemandeService> createState() => _DemandeServiceState();
}

class _DemandeServiceState extends State<DemandeService> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final RecorderController _recorderController = RecorderController();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _filePath;
  String? _audioBase64;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _montantPretController = TextEditingController();
  final TextEditingController _periodeRemboursementController =
      TextEditingController();

  String? nomUtilisateur;
  String? posteUtilisateur;
  String? pointDeVenteId;
  String? phoneNumber;
  double? _salaire;
  double? _salaireRestant;
  String? _errorMessagePret;

  String _typeDemande = 'absence';
  String? _sousType; // urgence, manifestation, maladie, etc.

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _player.openPlayer();
    _chargerInfosUtilisateur();
    _montantPretController.addListener(_calculerEtValiderPret);
    _periodeRemboursementController.addListener(_calculerEtValiderPret);
  }

  Future<void> _initRecorder() async {
    final micStatus = await Permission.microphone.request();
    if (!mounted) return;
    if (!micStatus.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Microphone non autorisé")));
      return;
    }

    await _recorder.openRecorder();
    _recorderController
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 16000;
  }

  Future<void> _chargerInfosUtilisateur() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          nomUtilisateur = data?['fullName'] ?? '';
          posteUtilisateur = data?['poste'] ?? '';
          pointDeVenteId = data?['pointDeVenteId'] ?? '';
          phoneNumber = data?['phone'] ?? '';
          _salaire = (data?['salaire'] as num?)?.toDouble();
        });
      }
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    _textController.dispose();
    _montantPretController.dispose();
    _periodeRemboursementController.dispose();
    _timer?.cancel();
    _montantPretController.removeListener(_calculerEtValiderPret);
    _periodeRemboursementController.removeListener(_calculerEtValiderPret);
    super.dispose();
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    final uniqueFileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    _filePath = '${dir.path}/$uniqueFileName';

    await _recorder.startRecorder(toFile: _filePath, codec: Codec.aacADTS);
    _recorderController.record();

    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(
        () =>
            _recordDuration = Duration(seconds: _recordDuration.inSeconds + 1),
      );
    });

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    await _recorderController.stop();
    _timer?.cancel();
    setState(() => _isRecording = false);

    if (_filePath != null) {
      final file = File(_filePath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        setState(() {
          _audioBase64 = base64Encode(bytes);
        });
      }
    }
  }

  Future<void> _playAudio() async {
    if (_filePath == null || !(await File(_filePath!).exists())) return;

    if (_isPlaying) {
      await _player.stopPlayer();
    } else {
      await _player.startPlayer(
        fromURI: _filePath,
        codec: Codec.aacADTS,
        whenFinished: () => setState(() => _isPlaying = false),
      );
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _resetAudio() {
    if (_filePath != null) File(_filePath!).delete();
    setState(() {
      _audioBase64 = null;
      _filePath = null;
      _recordDuration = Duration.zero;
    });
  }

  void _calculerEtValiderPret() {
    if (_typeDemande != 'pret' || _salaire == null || _salaire! <= 0) {
      if (mounted) {
        setState(() {
          _salaireRestant = null;
          _errorMessagePret = null;
        });
      }
      return;
    }

    final montant = double.tryParse(_montantPretController.text);
    final periode = int.tryParse(_periodeRemboursementController.text);

    if (montant == null || periode == null || montant <= 0 || periode <= 0) {
      if (mounted) {
        setState(() {
          _salaireRestant = null;
          _errorMessagePret = null;
        });
      }
      return;
    }

    final mensualite = montant / periode;

    if (mensualite >= _salaire!) {
      if (mounted) {
        setState(() {
          _salaireRestant = null;
          _errorMessagePret =
              "La mensualité (${mensualite.toStringAsFixed(0)} XAF) ne peut pas dépasser votre salaire. Veuillez réduire le montant ou augmenter la période.";
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _salaireRestant = _salaire! - mensualite;
          _errorMessagePret = null;
        });
      }
    }
  }

  Future<void> _envoyerDemande() async {
    if ((_audioBase64 == null || _audioBase64!.isEmpty) &&
        _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez enregistrer un audio ou écrire un message."),
        ),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Utilisateur non connecté.")),
      );
      return;
    }

    // Si la demande est un prêt, vérifier s'il y a déjà un prêt actif
    if (_typeDemande == 'pret') {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      final pretActif = userDoc.data()?['pretActif'] ?? false;

      if (pretActif == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Vous avez déjà un prêt actif en cours."),
          ),
        );
        return; // Ne pas continuer l'envoi
      }

      double? montantPret = double.tryParse(_montantPretController.text);
      int? periode = int.tryParse(_periodeRemboursementController.text);

      if (montantPret == null ||
          periode == null ||
          periode <= 0 ||
          montantPret <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez entrer un montant et une période valides."),
          ),
        );
        return;
      }

      // Nouvelle validation par rapport au salaire
      if (_salaire == null || _salaire! <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Votre salaire n'est pas défini. Impossible de demander un prêt.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final mensualite = montantPret / periode;
      if (mensualite >= _salaire!) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "La mensualité du prêt ne peut pas être supérieure ou égale à votre salaire.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Tu peux continuer avec montantPret et periode...
    }

    // Envoi de la demande
    await FirebaseFirestore.instance.collection('demandedeservice').add({
      'texte':
          _textController.text.trim().isNotEmpty
              ? _textController.text.trim()
              : null,
      'audioBase64': _audioBase64,
      'statut': 'en attente',
      'timestamp': FieldValue.serverTimestamp(),
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'heure': DateFormat('HH:mm:ss').format(DateTime.now()),
      'nom': nomUtilisateur ?? '',
      'poste': posteUtilisateur ?? '',
      'pointDeVenteId': pointDeVenteId ?? '',
      'typeDemande': _typeDemande,
      'sousType': _sousType,
      'montantPret':
          _typeDemande == 'pret'
              ? double.parse(_montantPretController.text)
              : null,
      'periodeRemboursement':
          _typeDemande == 'pret'
              ? int.parse(_periodeRemboursementController.text)
              : null,
      'dateDemandePret':
          _typeDemande == 'pret'
              ? DateFormat('yyyy-MM-dd').format(DateTime.now())
              : null,
      'phoneNumber': phoneNumber,
      'userId': userId,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Demande envoyée avec succès.")),
    );

    _resetAudio();
    _textController.clear();
    _montantPretController.clear();
    _periodeRemboursementController.clear();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Nouvelle Demande",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Type de demande",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _typeDemande,
                      isExpanded: true,
                      items: [
                        _buildDropdownItem(
                          'absence',
                          'Absence',
                          Icons.person_off,
                        ),
                        _buildDropdownItem(
                          'conge',
                          'Congé',
                          Icons.beach_access,
                        ),
                        _buildDropdownItem('pret', 'Prêt', Icons.money),
                        _buildDropdownItem(
                          'retard',
                          'Retard',
                          Icons.access_time,
                        ),
                      ],
                      onChanged:
                          (val) => setState(() {
                            _typeDemande = val!;
                            _sousType = null;
                            _calculerEtValiderPret();
                          }),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        filled: true,
                        fillColor:
                            isDarkMode ? Colors.grey[900] : Colors.grey[50],
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_typeDemande == 'absence' ||
                _typeDemande == 'conge' ||
                _typeDemande == 'retard')
              _buildMotifCard(theme, isDarkMode),

            if (_typeDemande == 'pret') _buildPretCard(theme, isDarkMode),

            const SizedBox(height: 20),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Détails de la demande",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: "Expliquez votre demande...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor:
                            isDarkMode ? Colors.grey[900] : Colors.grey[50],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Enregistrement vocal",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isRecording)
                      Column(
                        children: [
                          AudioWaveforms(
                            enableGesture: true,
                            size: Size(
                              MediaQuery.of(context).size.width - 64,
                              100.0,
                            ),
                            recorderController: _recorderController,
                            waveStyle: WaveStyle(
                              waveColor: theme.colorScheme.primary,
                              extendWaveform: true,
                              showMiddleLine: false,
                              gradient: ui.Gradient.linear(
                                const Offset(0, 0),
                                Offset(
                                  MediaQuery.of(context).size.width - 64,
                                  0,
                                ),
                                [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Durée: ${_formatDuration(_recordDuration)}",
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildIconButton(
                          icon: _isRecording ? Icons.stop : Icons.mic,
                          label: _isRecording ? "Arrêter" : "Enregistrer",
                          color:
                              _isRecording
                                  ? Colors.red
                                  : theme.colorScheme.primary,
                          onPressed:
                              _isRecording ? _stopRecording : _startRecording,
                        ),
                        if (_audioBase64 != null) ...[
                          _buildIconButton(
                            icon: _isPlaying ? Icons.stop : Icons.play_arrow,
                            label: _isPlaying ? "Arrêter" : "Écouter",
                            color: theme.colorScheme.secondary,
                            onPressed: _playAudio,
                          ),
                          _buildIconButton(
                            icon: Icons.delete,
                            label: "Supprimer",
                            color: Colors.orange,
                            onPressed: _resetAudio,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _envoyerDemande,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                "Envoyer la demande",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(
    String value,
    String text,
    IconData icon,
  ) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(text)],
      ),
    );
  }

  Widget _buildMotifCard(ThemeData theme, bool isDarkMode) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Motif",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _sousType,
              isExpanded: true,
              items:
                  (_typeDemande == 'absence'
                          ? ['urgence', 'manifestation']
                          : _typeDemande == 'conge'
                          ? ['maladie', 'grossesse', 'opération']
                          : ['transport', 'problème familial', 'autre'])
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.capitalize()),
                        ),
                      )
                      .toList(),
              onChanged: (val) => setState(() => _sousType = val),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
                hintText: "Sélectionnez un motif",
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPretCard(ThemeData theme, bool isDarkMode) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Détails du prêt",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _montantPretController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Montant du prêt",
                prefixText: "XAF ",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _periodeRemboursementController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Période de remboursement (mois)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessagePret != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  _errorMessagePret!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            if (_salaireRestant != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Text(
                  "Salaire mensuel après déduction : ${_salaireRestant!.toStringAsFixed(0)} XAF",
                  style: TextStyle(
                    color: Colors.green[800],
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, size: 28),
          color: color,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.2),
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : '';
}
