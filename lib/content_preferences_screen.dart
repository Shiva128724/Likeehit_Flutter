import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContentPreferencesScreen extends StatelessWidget {
  const ContentPreferencesScreen({super.key});

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
          title: const Text('Content preferences'),
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
          'Content preferences',
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
              data['content_preferences'] as Map<String, dynamic>? ?? {};
          final bool isRestrictedModeOn = prefs['restricted_mode'] == true;

          return ListView(
            children: [
              _buildListTile(
                icon: Icons.label_outline,
                title: 'Filter video keywords',
                trailingText: null,
                textColor: textColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FilterKeywordsScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.security,
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
    String? trailingText,
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
          if (trailingText != null)
            Text(
              trailingText,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          if (trailingText != null) const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

// Placeholder Screen for Filter Video Keywords
class FilterKeywordsScreen extends StatelessWidget {
  const FilterKeywordsScreen({super.key});

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
          'Filter video keywords',
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
          'Filter Keywords Configuration\n(Realtime block list goes here)',
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontFamily: 'Inter'),
        ),
      ),
    );
  }
}

// Placeholder Screen for Restricted Mode Setup
class RestrictedModeScreen extends StatelessWidget {
  const RestrictedModeScreen({super.key});

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
          'Restricted Mode',
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
          'Restricted Mode Setup\n(4-Digit PIN Logic goes here)',
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontFamily: 'Inter'),
        ),
      ),
    );
  }
}
