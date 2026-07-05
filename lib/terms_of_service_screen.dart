import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  final List<Map<String, dynamic>> _defaultTerms = const [
    {
      'heading': '1. User Eligibility',
      'body':
          'You must be of legal age to use Likeehit. By continuing, you agree to form a binding contract with us.',
      'order': 1,
    },
    {
      'heading': '2. Intellectual Property Rights',
      'body':
          'You retain ownership of the content you create, but grant Likeehit a broad license to distribute it across our platform.',
      'order': 2,
    },
    {
      'heading': '3. Acceptable Use Policy',
      'body':
          'Violating community standards or engaging in illegal acts will result in immediate account suspension or permanent termination.',
      'order': 3,
    },
    {
      'heading': '4. Limitation of Liability',
      'body':
          'Likeehit is provided "as is". We are not liable for user-generated content or service interruptions. Disputes are subject to binding arbitration.',
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
          'Terms of Service',
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
            .collection('terms_of_service')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          List<Map<String, dynamic>> terms = [];

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              terms.add({
                'heading': data['heading'] ?? '',
                'body': data['body'] ?? '',
                'order': data['order'] ?? 999,
              });
            }
            terms.sort(
              (a, b) => (a['order'] as num).compareTo(b['order'] as num),
            );
          } else {
            terms = List.from(_defaultTerms);
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
                    'Please read these Terms of Service carefully before using Likeehit. By using the app, you agree to comply with these rules.',
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: 14,
                      height: 1.5,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                ...terms.map((term) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          term['heading'],
                          style: TextStyle(
                            color: headingColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          term['body'],
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
