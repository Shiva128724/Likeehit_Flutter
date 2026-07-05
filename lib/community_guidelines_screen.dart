import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  final List<Map<String, dynamic>> _defaultGuidelines = const [
    {
      'heading': '1. Harassment and Bullying',
      'body':
          'We do not tolerate members of our community being shamed, bullied, or harassed. Any such content will be removed immediately.',
      'order': 1,
    },
    {
      'heading': '2. Hate Speech Policy',
      'body':
          'Likeehit is a diverse community. We prohibit behavior or content that attacks or incites violence against individuals or groups.',
      'order': 2,
    },
    {
      'heading': '3. Violent & Graphic Content Restrictions',
      'body':
          'We do not allow content that is excessively gruesome or shocking, or that promotes violence or suffering.',
      'order': 3,
    },
    {
      'heading': '4. Minor Safety Standards',
      'body':
          'We are deeply committed to ensuring the safety of minors on Likeehit. Exploitative or harmful content involving minors is strictly forbidden.',
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
          'Community Guidelines',
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
            .collection('community_guidelines')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          List<Map<String, dynamic>> guidelines = [];

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              guidelines.add({
                'heading': data['heading'] ?? '',
                'body': data['body'] ?? '',
                'order': data['order'] ?? 999,
              });
            }
            guidelines.sort(
              (a, b) => (a['order'] as num).compareTo(b['order'] as num),
            );
          } else {
            guidelines = List.from(_defaultGuidelines);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Text(
                    'Our guidelines define the rules and standards for using Likeehit to keep our community safe and welcoming.',
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: 14,
                      height: 1.5,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                ...guidelines.map((guideline) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guideline['heading'],
                          style: TextStyle(
                            color: headingColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          guideline['body'],
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
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
