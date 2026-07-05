import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PushNotificationsScreen extends StatelessWidget {
  const PushNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : const Color(0xFFFFFFFF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

    if (uid == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Push notifications'),
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
        ),
        body: const Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Push notifications',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final notifications =
              data['notification_settings'] as Map<String, dynamic>? ?? {};

          bool getVal(String key, {bool defaultValue = true}) {
            return notifications[key] as bool? ?? defaultValue;
          }

          void toggleVal(String key, bool value) {
            FirebaseFirestore.instance.collection('users').doc(uid).set({
              'notification_settings': {key: value},
            }, SetOptions(merge: true));
          }

          return ListView(
            children: [
              _buildSectionHeader('INTERACTIONS', subtitleColor),
              _buildSwitchTile(
                title: 'Likes',
                value: getVal('likes'),
                onChanged: (val) => toggleVal('likes', val),
                textColor: textColor,
              ),
              _buildSwitchTile(
                title: 'Comments',
                value: getVal('comments'),
                onChanged: (val) => toggleVal('comments', val),
                textColor: textColor,
              ),
              _buildSwitchTile(
                title: 'New followers',
                value: getVal('new_followers'),
                onChanged: (val) => toggleVal('new_followers', val),
                textColor: textColor,
              ),
              _buildSwitchTile(
                title: 'Mentions and tags',
                value: getVal('mentions_and_tags'),
                onChanged: (val) => toggleVal('mentions_and_tags', val),
                textColor: textColor,
              ),

              const SizedBox(height: 12),
              _buildSectionHeader('MESSAGES', subtitleColor),
              _buildSwitchTile(
                title: 'Direct messages',
                value: getVal('direct_messages'),
                onChanged: (val) => toggleVal('direct_messages', val),
                textColor: textColor,
              ),
              _buildSwitchTile(
                title: 'Direct message previews',
                value: getVal('direct_message_previews'),
                onChanged: (val) => toggleVal('direct_message_previews', val),
                textColor: textColor,
              ),

              const SizedBox(height: 12),
              _buildSectionHeader('LIVE', subtitleColor),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 4.0,
                ),
                title: Text(
                  'LIVE Notifications from accounts you follow',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontFamily: 'Inter',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  // Navigate to specific creator live notification frequencies
                },
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 24.0,
        bottom: 8.0,
      ),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 4.0,
      ),
      title: Text(
        title,
        style: TextStyle(color: textColor, fontSize: 15, fontFamily: 'Inter'),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: Colors.green,
      ),
      onTap: () => onChanged(!value),
    );
  }
}
