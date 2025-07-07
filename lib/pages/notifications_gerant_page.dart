import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsGerantPage extends StatefulWidget {
  final String employeId;

  const NotificationsGerantPage({super.key, required this.employeId});

  @override
  State<NotificationsGerantPage> createState() => _NotificationsGerantPageState();
}


class _NotificationsGerantPageState extends State<NotificationsGerantPage> {
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    marquerNotesCommeLues(widget.employeId); // Marquer les notes comme lues
  }

  Future<void> marquerNotesCommeLues(String employeId) async {
    final firestore = FirebaseFirestore.instance;

    // Requête directe dans la collection globale 'notes'
    final notesSnapshot = await firestore
        .collection('notes')
        .where('employeId', isEqualTo: employeId)
        .where('lu', isEqualTo: false)
        .get();

    // Mise à jour en parallèle des documents non lus
    final futures = notesSnapshot.docs.map((doc) => doc.reference.update({'lu': true}));

    await Future.wait(futures);
  }



  Future<List<Map<String, dynamic>>> fetchNotifications(String employeId) async {
    final firestore = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return [];

    List<Map<String, dynamic>> result = [];

    // 1. Récupérer les notes depuis la collection globale 'notes' filtrées par employeId
    final notesSnapshot = await firestore
        .collection('notes')
        .where('employeId', isEqualTo: employeId)
        .orderBy('timestamp', descending: true)
        .get();

    for (var doc in notesSnapshot.docs) {
      final data = doc.data();
      final noteValue = (data['note'] is num) ? (data['note'] as num).toDouble() : 0.0;
      final commentaire = (data['commentaire'] ?? '').toString();
      final fullName = (data['fullName'] ?? 'Employé').toString();
      final alreadyRead = data['lu'] ?? false;
      final timestamp = (data['timestamp'] as Timestamp).toDate();

      result.add({
        'type': 'note',
        'note': noteValue,
        'commentaire': commentaire,
        'fullName': fullName,
        'timestamp': timestamp,
        'lu': alreadyRead,
      });

      if (!alreadyRead) {
        triggerLocalNotification(
          title: 'Nouvelle note reçue',
          body: '$fullName vous a attribué une note.',
        );
      }
    }

    // 2. Récupérer les notifications classiques stockées dans sous-collection 'notifications' du user courant
    final notificationsSnapshot = await firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .get();

    for (var doc in notificationsSnapshot.docs) {
      final data = doc.data();
      final title = data['title'];
      final seen = data['seen'] ?? false;
      final timestamp = (data['timestamp'] as Timestamp).toDate();

      if (title == 'Profil incomplet') {
        result.add({
          'type': 'profil_incomplet',
          'userId': data['userId'],
          'message': data['message'],
          'timestamp': timestamp,
          'seen': seen,
          'link': data['link'],
        });

        if (!seen) {
          triggerLocalNotification(
            title: 'Profil incomplet',
            body: data['message'] ?? '',
          );
        }
      } else if (title == 'Document rejeté') {
        result.add({
          'type': 'rejet',
          'userId': data['userId'],
          'message': data['message'],
          'timestamp': timestamp,
          'seen': seen,
          'link': data['link'],
        });

        if (!seen) {
          triggerLocalNotification(
            title: 'Document rejeté',
            body: data['message'] ?? '',
          );
        }
      }
    }

    // 3. Trier toutes les notifications par date décroissante
    result.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    return result;
  }


  void triggerLocalNotification({
    required String title,
    required String body,
  }) {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'default_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchNotifications(widget.employeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Aucune notification pour le moment."));
          }

          final notations = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notations.length,
            itemBuilder: (context, index) {
              final item = notations[index];
              final type = item['type'];
              final timestamp = item['timestamp'] as DateTime;
              final formattedDate = DateFormat('dd MMM yyyy à HH:mm').format(timestamp);

              if (type == 'note') {
                final note = item['note'] ?? 0.0;
                final fullName = item['fullName'] ?? 'Employé';
                final commentaire = item['commentaire'] ?? '';
                final isRead = item['lu'] == true;
                if (!isRead) {
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Nouveau",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                }


              return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.grey[200] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: isRead ? Colors.grey : Colors.indigo,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isRead ? Colors.grey[700] : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < note ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 20,
                                );
                              }),
                            ),
                            if (commentaire.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                commentaire,
                                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              formattedDate,
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (type == 'profil_incomplet') {
                final isRead = item['seen'] == true;

                return GestureDetector(
                  onTap: isRead ? null : () async {
                    final firestore = FirebaseFirestore.instance;
                    final snapshot = await firestore
                        .collection('users')
                        .doc(currentUser!.uid)
                        .collection('notifications')
                        .where('userId', isEqualTo: item['userId'])
                        .where('title', isEqualTo: 'Profil incomplet')
                        .get();

                    for (var doc in snapshot.docs) {
                      await doc.reference.update({'seen': true});
                    }
                    if (item['link'] != null) {
                      Navigator.pushNamed(context, item['link']).then((_) {
                      });
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.grey[200] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isRead ? Colors.grey : Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning,
                            color: isRead ? Colors.grey : Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Profil incomplet",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isRead ? Colors.grey : Colors.black)),
                              Text(item['message']),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }

              if (type == 'rejet') {
                final isRead = item['seen'] == true;

                return GestureDetector(
                  onTap: isRead ? null : () async {
                    final firestore = FirebaseFirestore.instance;
                    final snapshot = await firestore
                        .collection('users')
                        .doc(currentUser!.uid)
                        .collection('notifications')
                        .where('userId', isEqualTo: item['userId'])
                        .where('title', isEqualTo: 'Document rejeté')
                        .get();

                    for (var doc in snapshot.docs) {
                      await doc.reference.update({'seen': true});
                    }

                    if (item['link'] != null) {
                      Navigator.pushNamed(context, item['link']).then((_) {
                      });
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.grey[200] : Colors.red[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isRead ? Colors.grey : Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber,
                            color: isRead ? Colors.grey : Colors.red, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Document rejeté",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isRead ? Colors.grey : Colors.red)),
                              Text(item['message']),
                              const SizedBox(height: 6),
                              Text(
                                formattedDate,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],

                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          );

        },
      ),
    );
  }
}
