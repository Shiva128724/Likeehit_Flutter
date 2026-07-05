import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'content_preferences_screen.dart'; // To access RestrictedModeScreen

class DigitalWellbeingScreen extends StatelessWidget {
  const DigitalWellbeingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    if (uid == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Digital Wellbeing'),
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
          'Digital Wellbeing',
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
          final prefs =
              data['wellbeing_settings'] as Map<String, dynamic>? ?? {};
          final contentPrefs =
              data['content_preferences'] as Map<String, dynamic>? ?? {};

          final screenTimeLimit = prefs['screen_time_limit'];
          final String screenTimeText =
              screenTimeLimit == null || screenTimeLimit == 0
              ? 'Off'
              : '${screenTimeLimit}m';

          // Use content_preferences logic to determine Restricted Mode, assuming it shares the same boolean
          final bool isRestrictedModeOn =
              contentPrefs['restricted_mode'] == true ||
              prefs['restricted_mode'] == true;

          return ListView(
            children: [
              _buildListTile(
                icon: Icons.timer_outlined,
                title: 'Screen Time Management',
                trailingText: screenTimeText,
                textColor: textColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ScreenTimeManagementScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.shield_outlined,
                title: 'Restricted Mode',
                trailingText: isRestrictedModeOn ? 'On' : 'Off',
                textColor: textColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RestrictedModeScreen(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String trailingText,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 4.0,
      ),
      leading: Icon(icon, color: textColor, size: 24),
      title: Text(
        title,
        style: TextStyle(color: textColor, fontSize: 15, fontFamily: 'Inter'),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trailingText,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

// Placeholder Screen for Screen Time Management
class ScreenTimeManagementScreen extends StatelessWidget {
  const ScreenTimeManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Screen Time Management',
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
      body: Center(
        child: Text(
          'Screen Time PIN Setup\n(Daily limit configuration goes here)',
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontFamily: 'Inter'),
        ),
      ),
    );
  }
}
