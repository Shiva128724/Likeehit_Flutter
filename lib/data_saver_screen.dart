import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DataSaverScreen extends StatelessWidget {
  const DataSaverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    if (uid == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Data Saver'),
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
          'Data Saver',
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
          final bool isDataSaverEnabled = data['data_saver_enabled'] == true;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                title: Text(
                  'Data Saver',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                trailing: Switch.adaptive(
                  value: isDataSaverEnabled,
                  activeThumbColor: Colors.white,
                  activeTrackColor:
                      Colors.green, // Standard successful toggle color
                  onChanged: (val) {
                    FirebaseFirestore.instance.collection('users').doc(uid).set(
                      {'data_saver_enabled': val},
                      SetOptions(merge: true),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  "Data Saver will reduce your cellular data usage. Videos may be at a lower resolution or take longer to load. This won't apply when you're on Wi-Fi.",
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
