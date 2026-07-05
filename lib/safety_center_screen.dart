import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_a_problem_screen.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  final List<Map<String, dynamic>> _defaultPolicies = const [
    {
      'heading': '1. Safety Guidelines',
      'body':
          'Likeehit is committed to maintaining a safe environment. We do not tolerate hate speech, violence, or illegal activities.',
      'order': 1,
    },
    {
      'heading': '2. Anti-Bullying Tools',
      'body':
          'You can filter comments, restrict tags, and block abusive users easily from your Privacy settings.',
      'order': 2,
    },
    {
      'heading': '3. Suicide & Self-Harm Prevention',
      'body':
          'If you or someone you know is going through a tough time, please reach out. You are not alone. Contact emergency services or a crisis line immediately.',
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
          'Safety Center',
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
            .collection('safety_policies')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          List<Map<String, dynamic>> policies = [];

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              policies.add({
                'heading': data['heading'] ?? '',
                'body': data['body'] ?? '',
                'order': data['order'] ?? 999,
              });
            }
            policies.sort(
              (a, b) => (a['order'] as num).compareTo(b['order'] as num),
            );
          } else {
            policies = List.from(_defaultPolicies);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...policies.map((policy) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          policy['heading'],
                          style: TextStyle(
                            color: headingColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          policy['body'],
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReportAProblemScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.flag_outlined, color: Colors.white),
                    label: const Text(
                      'Report Misuse',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}
