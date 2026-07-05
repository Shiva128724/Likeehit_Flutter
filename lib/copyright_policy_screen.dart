import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CopyrightPolicyScreen extends StatelessWidget {
  const CopyrightPolicyScreen({super.key});

  final List<Map<String, dynamic>> _defaultSections = const [
    {
      'heading': '1. Intellectual Property Protection',
      'body':
          'Likeehit respects the intellectual property rights of others and expects users to do the same. We are committed to protecting copyrights and ensuring a fair creative ecosystem.',
      'order': 1,
    },
    {
      'heading': '2. Digital Millennium Copyright Act (DMCA) Notice',
      'body':
          'If you believe your copyright-protected work was posted on Likeehit without authorization, you may submit a copyright infringement notification. These requests should only be submitted by the copyright owner or an agent authorized to act on the owner\'s behalf.',
      'order': 2,
    },
    {
      'heading': '3. Counter-Notification Procedures',
      'body':
          'If your content was removed due to a copyright claim that you believe was made in error, you may submit a counter-notification. Misuse of the DMCA process may result in legal consequences or account termination.',
      'order': 3,
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
          'Copyright Policy',
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
            .collection('copyright_policy')
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
                          height: 1.5,
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
