import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecurityAndLoginScreen extends StatefulWidget {
  const SecurityAndLoginScreen({super.key});

  @override
  State<SecurityAndLoginScreen> createState() => _SecurityAndLoginScreenState();
}

class _SecurityAndLoginScreenState extends State<SecurityAndLoginScreen> {
  Future<void> _updateSecuritySetting(String key, dynamic value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'security_settings': {key: value},
      }, SetOptions(merge: true));
    }
  }

  void _showMockMfaSheet(String currentValue) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '2-step verification',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  'On',
                  style: TextStyle(
                    color: currentValue == 'On'
                        ? Colors.redAccent
                        : Colors.white,
                  ),
                ),
                trailing: currentValue == 'On'
                    ? const Icon(Icons.check, color: Colors.redAccent)
                    : null,
                onTap: () {
                  _updateSecuritySetting('mfa_enabled', true);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(
                  'Off',
                  style: TextStyle(
                    color: currentValue == 'Off'
                        ? Colors.redAccent
                        : Colors.white,
                  ),
                ),
                trailing: currentValue == 'Off'
                    ? const Icon(Icons.check, color: Colors.redAccent)
                    : null,
                onTap: () {
                  _updateSecuritySetting('mfa_enabled', false);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'me';
    // The user explicitly requested pure white #FFFFFF for this screen
    const Color bgColor = Color(0xFFFFFFFF);
    const Color textColor = Colors.black87;
    const Color iconColor = Colors.black54;
    const Color chevronColor = Colors.black38;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Security and login',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          Map<String, dynamic> securitySettings = {};

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            securitySettings =
                data['security_settings'] as Map<String, dynamic>? ?? {};
          }

          // Defaults
          final bool hasAlerts = securitySettings['has_alerts'] ?? false;
          final bool mfaEnabled = securitySettings['mfa_enabled'] ?? false;
          final bool saveLoginInfo =
              securitySettings['save_login_info'] ?? true;

          return ListView(
            children: [
              const SizedBox(height: 16),
              _buildListTile(
                icon: Icons.shield_outlined,
                title: 'Security alerts',
                trailingWidget: hasAlerts
                    ? const Text(
                        '1 warning',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      )
                    : const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () {
                  // Clear alerts mock action
                  if (hasAlerts) {
                    _updateSecuritySetting('has_alerts', false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alerts cleared')),
                    );
                  }
                },
              ),
              _buildListTile(
                icon: Icons.devices_outlined,
                title: 'Manage devices',
                trailingWidget: null, // Just the chevron
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MockManageDevicesScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.lock_outline,
                title: '2-step verification',
                trailingText: mfaEnabled ? 'On' : 'Off',
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () => _showMockMfaSheet(mfaEnabled ? 'On' : 'Off'),
              ),
              _buildSwitchTile(
                icon: Icons.fingerprint_outlined,
                title: 'Save login info',
                value: saveLoginInfo,
                textColor: textColor,
                iconColor: iconColor,
                onChanged: (val) =>
                    _updateSecuritySetting('save_login_info', val),
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
    Widget? trailingWidget,
    required Color textColor,
    required Color iconColor,
    required Color chevronColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: TextStyle(
                  color: chevronColor,
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (trailingWidget != null) ...[
              trailingWidget,
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, color: chevronColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required Color textColor,
    required Color iconColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: Colors.redAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class MockManageDevicesScreen extends StatelessWidget {
  const MockManageDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFFFFFFFF);
    const Color textColor = Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage devices',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: Center(
        child: Text(
          'Active Login Sessions Stream...',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }
}
