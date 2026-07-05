import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageAccountScreen extends StatefulWidget {
  const ManageAccountScreen({super.key});

  @override
  State<ManageAccountScreen> createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends State<ManageAccountScreen> {
  String _maskPhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'Add phone number';
    if (phone.length <= 4) return phone;
    // e.g., +91 9876543210 -> +91 ******3210
    final prefix = phone.substring(0, 3);
    final suffix = phone.substring(phone.length - 4);
    return '$prefix ******$suffix';
  }

  String _maskEmail(String? email) {
    if (email == null || email.isEmpty) return 'Add email';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 1) return email;
    return '${name.substring(0, 1)}***@$domain';
  }

  void _showMockUpdateSheet(String field, String title, String currentValue) {
    final TextEditingController controller = TextEditingController(
      text: currentValue,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update $title',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter new $title',
                  hintStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.redAccent),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null && controller.text.isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .set({
                            field: controller.text.trim(),
                          }, SetOptions(merge: true));
                    }
                    nav.pop();
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _switchToBusinessAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Business Account',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Upgrade to a Business Account to access advanced analytics and creator tools. Do you want to proceed?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Upgrade',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'accountType': 'business',
        }, SetOptions(merge: true));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account upgraded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete account',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete your Likeehit account? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Optional: Delete user document from firestore first
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .delete();
          await user.delete();
        }
        // Deletion will trigger AuthState changes -> goes to login screen
        nav.popUntil((route) => route.isFirst);
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'me';
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? Colors.black : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color headerColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final Color iconColor = isDark ? Colors.white70 : Colors.black87;
    final Color chevronColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
    final Color dividerColor = isDark ? Colors.grey[900]! : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manage account',
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
          String? phone;
          String? email;
          String accountType = 'personal';

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            phone = data['phone'] as String?;
            email = data['email'] as String?;
            accountType = data['accountType'] as String? ?? 'personal';
          }

          return ListView(
            children: [
              // SECTION 1: ACCOUNT INFORMATION
              _buildSectionHeader('Account Information', headerColor),
              _buildListTile(
                icon: Icons.phone_android,
                title: 'Phone number',
                trailingText: _maskPhone(phone),
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () =>
                    _showMockUpdateSheet('phone', 'Phone number', phone ?? ''),
              ),
              _buildListTile(
                icon: Icons.mail_outline,
                title: 'Email',
                trailingText: _maskEmail(email),
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () =>
                    _showMockUpdateSheet('email', 'Email', email ?? ''),
              ),
              _buildListTile(
                icon: Icons.lock_outline,
                title: 'Password',
                trailingText:
                    'Set password', // Could read from auth provider data
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () => _showMockUpdateSheet('password', 'Password', ''),
              ),
              Divider(color: dividerColor, height: 1),

              // SECTION 2: ACCOUNT CONTROL
              _buildSectionHeader('Account Control', headerColor),
              _buildListTile(
                icon: Icons.business_center_outlined,
                title: accountType == 'business'
                    ? 'Switch to Personal Account'
                    : 'Switch to Business Account',
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: _switchToBusinessAccount,
              ),
              _buildListTile(
                icon: Icons.delete_outline,
                title: 'Delete account',
                textColor: textColor, // Standard text color as requested
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: _deleteAccount,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color headerColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: headerColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? trailingText,
    required Color textColor,
    required Color iconColor,
    required Color chevronColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
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
            Icon(Icons.chevron_right, color: chevronColor, size: 20),
          ],
        ),
      ),
    );
  }
}
