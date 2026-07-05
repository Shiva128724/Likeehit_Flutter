import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  final List<Map<String, dynamic>> _defaultSections = const [
    {
      'heading': '1. Information We Collect',
      'body':
          'We collect information you provide when creating an account on Likeehit, including your name, email address, phone number, and birth date. We also collect usage data regarding your interactions with our platform.',
      'order': 1,
    },
    {
      'heading': '2. How We Use Your Information',
      'body':
          'We use the information we collect to provide, maintain, and improve our services. This includes personalizing your experience, troubleshooting issues, and protecting the community against fraudulent activity.',
      'order': 2,
    },
    {
      'heading': '3. Sharing of Information',
      'body':
          'We may share your information with third-party service providers who assist us in operating Likeehit. We do not sell your personal data to third parties for their direct marketing purposes without your consent.',
      'order': 3,
    },
    {
      'heading': '4. Data Security and Retention',
      'body':
          'We implement robust security measures to protect your personal information from unauthorized access. We retain your data only as long as necessary to provide our services or as required by law.',
      'order': 4,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final headingColor = isDarkMode ? Colors.white : Colors.black;
    final bodyColor = isDarkMode ? Colors.grey[300] : const Color(0xFF333333);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: headingColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('privacy_policy')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          List<Map<String, dynamic>> sections = [];

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              sections.add({
                'heading': data['heading'] ?? '',
                'body': data['body'] ?? '',
                'order': data['order'] ?? 999,
              });
            }
            // Sort by order locally so we don't require an explicit index in Firestore
            sections.sort(
              (a, b) => (a['order'] as num).compareTo(b['order'] as num),
            );
          } else {
            sections = List.from(_defaultSections);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections.map((section) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section['heading'],
                        style: TextStyle(
                          color: headingColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        section['body'],
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: 14,
                          height: 1.5, // proper line height for readability
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
