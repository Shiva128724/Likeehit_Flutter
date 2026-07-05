import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdsScreen extends StatelessWidget {
  const AdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

    if (uid == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Ads'),
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
          'Ads',
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
          final bool isPersonalizedAdsEnabled =
              data['personalized_ads_enabled'] == true;

          return ListView(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                title: Text(
                  'Personalized ads',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontFamily: 'Inter',
                  ),
                ),
                subtitle: Text(
                  'Control whether you see ads based on your off-Likeehit activity. Your data helps us show more relevant ads.',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    fontFamily: 'Inter',
                    height: 1.3,
                  ),
                ),
                trailing: Switch.adaptive(
                  value: isPersonalizedAdsEnabled,
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.green,
                  onChanged: (val) {
                    FirebaseFirestore.instance.collection('users').doc(uid).set(
                      {'personalized_ads_enabled': val},
                      SetOptions(merge: true),
                    );
                  },
                ),
              ),
              _buildListTile(
                icon: Icons.bar_chart,
                title: 'Your ad activity',
                textColor: textColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdActivityScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.info_outline,
                title: 'About ads and your privacy',
                textColor: textColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutAdsPrivacyScreen(),
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
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}

// Placeholder Screen for Ad Activity
class AdActivityScreen extends StatelessWidget {
  const AdActivityScreen({super.key});

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
          'Your ad activity',
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
          'Historical Ad Interactions Graph',
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontFamily: 'Inter'),
        ),
      ),
    );
  }
}

// Placeholder Screen for About Ads Privacy
class AboutAdsPrivacyScreen extends StatelessWidget {
  const AboutAdsPrivacyScreen({super.key});

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
          'About ads',
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
          'Privacy Policy & Details',
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontFamily: 'Inter'),
        ),
      ),
    );
  }
}
