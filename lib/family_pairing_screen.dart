import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FamilyPairingScreen extends StatefulWidget {
  const FamilyPairingScreen({super.key});

  @override
  State<FamilyPairingScreen> createState() => _FamilyPairingScreenState();
}

class _FamilyPairingScreenState extends State<FamilyPairingScreen> {
  String? _selectedRole;

  void _onRoleSelected(String role) {
    setState(() {
      _selectedRole = role;
    });
  }

  Future<void> _onContinuePressed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _selectedRole == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'family_pairing_role': _selectedRole,
    }, SetOptions(merge: true));

    if (!mounted) return;

    if (_selectedRole == 'Parent') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QrGeneratorScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QrScannerScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

    final isContinueEnabled = _selectedRole != null;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Family Pairing',
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
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.supervised_user_circle_outlined,
                    size: 80,
                    color: textColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Family Pairing',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Link your Likeehit account with your teen\'s to manage their screen time, restrict inappropriate content, and customize privacy settings remotely.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 14,
                      fontFamily: 'Inter',
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildRoleCard(
                    title: 'Parent',
                    description:
                        'Manage screen time limits and safety features for your teen.',
                    roleKey: 'Parent',
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 16),
                  _buildRoleCard(
                    title: 'Teen',
                    description:
                        'Link with your parent to enable tailored safety preferences.',
                    roleKey: 'Teen',
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isContinueEnabled ? _onContinuePressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  disabledBackgroundColor: isDarkMode
                      ? Colors.grey[800]
                      : Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Continue',
                  style: TextStyle(
                    color: isContinueEnabled
                        ? Colors.white
                        : (isDarkMode ? Colors.grey[500] : Colors.grey[600]),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String description,
    required String roleKey,
    required bool isDarkMode,
  }) {
    final isSelected = _selectedRole == roleKey;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.grey[50];
    final borderColor = isSelected
        ? Colors.redAccent
        : (isDarkMode ? Colors.grey[800]! : Colors.grey[300]!);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

    return GestureDetector(
      onTap: () => _onRoleSelected(roleKey),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.0),
          borderRadius: BorderRadius.circular(12.0),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 13,
                      fontFamily: 'Inter',
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? Colors.redAccent : Colors.grey,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder Screen for QR Generator (Parent flow)
class QrGeneratorScreen extends StatelessWidget {
  const QrGeneratorScreen({super.key});

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
          'Generate QR Code',
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
          'Parent QR Generator\n(Display pairing QR code here)',
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontFamily: 'Inter'),
        ),
      ),
    );
  }
}

// Placeholder Screen for QR Scanner (Teen flow)
class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key});

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
          'Scan QR Code',
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
          'Teen QR Scanner\n(Camera scan interface here)',
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontFamily: 'Inter'),
        ),
      ),
    );
  }
}
