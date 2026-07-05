import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinTestersScreen extends StatefulWidget {
  const JoinTestersScreen({super.key});

  @override
  State<JoinTestersScreen> createState() => _JoinTestersScreenState();
}

class _JoinTestersScreenState extends State<JoinTestersScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  Future<void> _toggleBetaTester(bool isCurrentlyTester) async {
    if (_user == null) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate a brief loading visual before finishing the sync
    await Future.delayed(const Duration(milliseconds: 1200));

    try {
      await FirebaseFirestore.instance.collection('users').doc(_user.uid).set({
        'is_beta_tester': !isCurrentlyTester,
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildBenefitTile(
    IconData icon,
    String title,
    String subtitle,
    Color textColor,
    Color iconColor,
    Color subtitleColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                    height: 1.4,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white70 : const Color(0xFF333333);
    final brandColor = Colors.redAccent;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Join Likeehit Testers',
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Hero Section
                  const SizedBox(height: 10),
                  Icon(
                    Icons.rocket_launch_outlined,
                    color: brandColor,
                    size: 70,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Become a Likeehit Tester',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Get early access to upcoming features, test experimental UI layouts, and share your valuable feedback directly with our development team before the official release.',
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 14,
                      height: 1.5,
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Benefits Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'BENEFITS OF JOINING',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBenefitTile(
                    Icons.star_border_outlined,
                    'Early Access',
                    'Try new editing filters and tools first.',
                    textColor,
                    textColor,
                    subtitleColor,
                  ),
                  _buildBenefitTile(
                    Icons.rate_review_outlined,
                    'Direct Feedback',
                    'Report bugs directly from the app interface.',
                    textColor,
                    textColor,
                    subtitleColor,
                  ),
                  _buildBenefitTile(
                    Icons.verified_outlined,
                    'Exclusive Badge',
                    'Display a \'Beta\' badge on your profile.',
                    textColor,
                    textColor,
                    subtitleColor,
                  ),
                ],
              ),
            ),
          ),

          // Action Button Section
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.grey[900]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: _user == null
                  ? const SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: Center(child: Text('Please log in first.')),
                    )
                  : StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(_user.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        bool isBetaTester = false;

                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          isBetaTester = data?['is_beta_tester'] ?? false;
                        }

                        return SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: _isLoading
                              ? Center(
                                  child: CircularProgressIndicator.adaptive(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      brandColor,
                                    ),
                                  ),
                                )
                              : isBetaTester
                              ? OutlinedButton(
                                  onPressed: () => _toggleBetaTester(true),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: textColor,
                                    side: BorderSide(
                                      color: isDarkMode
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  child: const Text(
                                    'Leave Beta Program',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: () => _toggleBetaTester(false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: brandColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  child: const Text(
                                    'Join Beta Program',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
