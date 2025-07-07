import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsEmployePage extends StatefulWidget {
  const NotificationsEmployePage({super.key});

  @override
  State<NotificationsEmployePage> createState() => _NotificationsEmployePageState();
}

class _NotificationsEmployePageState extends State<NotificationsEmployePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool loading = true;
  List<Map<String, dynamic>> notifications = [];
  Set<String> clickedNotifications = {};
  bool isNavigating = false;



  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    setState(() => loading = true);
    final fetched = await fetchNotifications();
    setState(() {
      notifications = fetched;
      loading = false;
    });
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      final List<Map<String, dynamic>> fetched = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        final notification = {
          'id': doc.id,
          'title': data['title'] ?? 'Notification',
          'message': data['message'] ?? '',
          'timestamp': data['timestamp'],
          'seen': data['seen'] ?? false,
          'link': data['link'],
        };

        fetched.add(notification);

        // 👉 Afficher une notification locale si elle n’a pas été vue
        if (!(data['seen'] ?? false)) {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
              channelKey: 'basic_channel',
              title: notification['title'],
              body: notification['message'],
              notificationLayout: NotificationLayout.Default,
            ),
          );

          // Marquer la notification comme lue
          await doc.reference.update({'seen': true});
        }
      }

      return fetched;
    } catch (e) {
      print('Erreur lors de la récupération des notifications : $e');
      return [];
    }
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy à HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes notifications'), centerTitle: true,),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
          ? const Center(child: Text("Aucune notification disponible."))
          : ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(
                Icons.notifications,
                color: notif['seen'] ? Colors.grey : Colors.red,
              ),
              title: Text(
                notif['title'],
                style: TextStyle(
                  fontWeight:
                  notif['seen'] ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif['message']),
                  const SizedBox(height: 4),
                  Text(
                    formatTimestamp(notif['timestamp']),
                    style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              onTap: () {
                final notifId = notif['id'];
                if (isNavigating || clickedNotifications.contains(notifId)) return;

                setState(() {
                  isNavigating = true;
                  clickedNotifications.add(notifId);
                });

                if (notif['link'] != null) {
                  Navigator.pushNamed(context, notif['link']).then((_) {
                    setState(() {
                      isNavigating = false;
                    });
                  });
                }

              },
            ),
          );
        },
      ),
    );
  }
}
