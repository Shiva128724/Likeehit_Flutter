import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportAProblemScreen extends StatefulWidget {
  const ReportAProblemScreen({super.key});

  @override
  State<ReportAProblemScreen> createState() => _ReportAProblemScreenState();
}

class _ReportAProblemScreenState extends State<ReportAProblemScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  String? _selectedTopic;

  @override
  void initState() {
    super.initState();
    _feedbackController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'user_id': uid,
        'description': text,
        'topic': _selectedTopic ?? 'General',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your feedback!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: $e'),
          backgroundColor: Colors.red,
        ),
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
    final hintColor = isDarkMode ? Colors.white30 : Colors.black38;
    final headerColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final borderColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;

    final bool isSubmitEnabled =
        _feedbackController.text.trim().isNotEmpty && !_isSubmitting;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Report a problem',
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
      body: Stack(
        children: [
          ListView(
            children: [
              _buildSectionHeader('SELECT A TOPIC', headerColor),
              _buildTopicTile(
                icon: Icons.person_outline,
                title: 'Account and Profile',
                textColor: textColor,
                isDarkMode: isDarkMode,
              ),
              _buildTopicTile(
                icon: Icons.movie_creation_outlined,
                title: 'Feed, Search, and Share',
                textColor: textColor,
                isDarkMode: isDarkMode,
              ),
              _buildTopicTile(
                icon: Icons.favorite_border,
                title: 'Follow, Like, and Comment',
                textColor: textColor,
                isDarkMode: isDarkMode,
              ),
              _buildTopicTile(
                icon: Icons.videocam_outlined,
                title: 'LIVE and Monetization',
                textColor: textColor,
                isDarkMode: isDarkMode,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(color: borderColor, height: 1),
              ),
              _buildSectionHeader('TELL US MORE', headerColor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _feedbackController,
                  maxLines: 8,
                  minLines: 4,
                  style: TextStyle(color: textColor, fontFamily: 'Inter'),
                  decoration: InputDecoration(
                    hintText: 'Please describe your problem in detail...',
                    hintStyle: TextStyle(color: hintColor, fontFamily: 'Inter'),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.white54 : Colors.grey[400]!,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () {
                      // Simulate picking image
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
                        border: Border.all(
                          color: borderColor,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: headerColor,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 100), // padding for bottom button
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitEnabled ? _submitFeedback : null,
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
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Submit',
                          style: TextStyle(
                            color: isSubmitEnabled
                                ? Colors.white
                                : (isDarkMode
                                      ? Colors.grey[500]
                                      : Colors.grey[600]),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color headerColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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

  Widget _buildTopicTile({
    required IconData icon,
    required String title,
    required Color textColor,
    required bool isDarkMode,
  }) {
    final iconColor = isDarkMode ? Colors.white70 : Colors.black87;
    final chevronColor = isDarkMode ? Colors.grey[600]! : Colors.grey[400]!;
    final isSelected = _selectedTopic == title;

    return ListTile(
      onTap: () {
        setState(() {
          _selectedTopic = title;
        });
      },
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 4.0,
      ),
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.redAccent : textColor,
          fontSize: 15,
          fontFamily: 'Inter',
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Icon(
        isSelected ? Icons.check_circle : Icons.chevron_right,
        color: isSelected ? Colors.redAccent : chevronColor,
        size: 20,
      ),
    );
  }
}
