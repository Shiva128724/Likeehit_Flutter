import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void showLikeehitShareSheet(
  BuildContext context, {
  String shareUrl = 'https://likeehit.com/@username',
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFFFFF),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return LikeehitShareSheetLayout(shareUrl: shareUrl);
    },
  );
}

class LikeehitShareSheetLayout extends StatelessWidget {
  final String shareUrl;

  const LikeehitShareSheetLayout({super.key, required this.shareUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // SECTION 1: Send to (Realtime Firestore Friends)
          _buildSendToSection(),

          const SizedBox(height: 16),
          Divider(color: Colors.grey[200], height: 1),
          const SizedBox(height: 16),

          // SECTION 2: Share to (Social Media)
          _buildShareToSection(context),

          const SizedBox(height: 16),
          Divider(color: Colors.grey[200], height: 1),
          const SizedBox(height: 16),

          // SECTION 3: Actions
          _buildActionsSection(context),
        ],
      ),
    );
  }

  Widget _buildSendToSection() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'me';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Send to',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: StreamBuilder<QuerySnapshot>(
            // Listening to a mock 'friends' subcollection for real-time updates
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('friends')
                .snapshots(),
            builder: (context, snapshot) {
              List<Map<String, dynamic>> friends = [];
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                friends = snapshot.data!.docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();
              } else {
                // Mock fallback data if database is empty for visual layout
                friends = [
                  {'name': 'Alex', 'photo': ''},
                  {'name': 'Sarah', 'photo': ''},
                  {'name': 'Mike', 'photo': ''},
                ];
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                itemCount: friends.length + 1, // +1 for the search icon
                itemBuilder: (context, index) {
                  if (index == friends.length) {
                    return _buildShareIcon(
                      icon: Icons.search,
                      label: 'More',
                      bgColor: Colors.grey[100]!,
                      iconColor: Colors.black87,
                      onTap: () {},
                    );
                  }

                  final friend = friends[index];
                  final String name = friend['name'] ?? 'User';
                  final String photo = friend['photo'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: photo.isNotEmpty
                              ? NetworkImage(photo)
                              : null,
                          child: photo.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 28,
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShareToSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Share to',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            children: [
              _buildShareIcon(
                icon: Icons.chat_bubble,
                label: 'WhatsApp',
                bgColor: Colors.green,
                iconColor: Colors.white,
                onTap: () async {
                  Navigator.pop(context);
                  await Clipboard.setData(
                    ClipboardData(
                      text: 'Check this out on Likeehit! $shareUrl',
                    ),
                  );
                },
              ),
              _buildShareIcon(
                icon: Icons.camera_alt,
                label: 'Insta Stories',
                bgColor: Colors.pinkAccent,
                iconColor: Colors.white,
                onTap: () => Navigator.pop(context),
              ),
              _buildShareIcon(
                icon: Icons.send,
                label: 'Insta DM',
                bgColor: Colors.pink,
                iconColor: Colors.white,
                onTap: () => Navigator.pop(context),
              ),
              _buildShareIcon(
                icon: Icons.facebook,
                label: 'Facebook',
                bgColor: Colors.blue[700]!,
                iconColor: Colors.white,
                onTap: () => Navigator.pop(context),
              ),
              _buildShareIcon(
                icon: Icons.snapchat,
                label: 'Snapchat',
                bgColor: Colors.yellow[700]!,
                iconColor: Colors.white,
                onTap: () => Navigator.pop(context),
              ),
              _buildShareIcon(
                icon: Icons.alternate_email,
                label: 'X (Twitter)',
                bgColor: Colors.black,
                iconColor: Colors.white,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        children: [
          _buildShareIcon(
            icon: Icons.link,
            label: 'Copy Link',
            bgColor: Colors.grey[100]!,
            iconColor: Colors.black87,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: shareUrl));
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link Copied!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          _buildShareIcon(
            icon: Icons.download_rounded,
            label: 'Save Video',
            bgColor: Colors.grey[100]!,
            iconColor: Colors.black87,
            onTap: () => Navigator.pop(context),
          ),
          _buildShareIcon(
            icon: Icons.qr_code,
            label: 'QR Code',
            bgColor: Colors.grey[100]!,
            iconColor: Colors.black87,
            onTap: () => Navigator.pop(context),
          ),
          _buildShareIcon(
            icon: Icons.report_problem_outlined,
            label: 'Report',
            bgColor: Colors.grey[100]!,
            iconColor: Colors.black87,
            onTap: () => Navigator.pop(context),
          ),
          _buildShareIcon(
            icon: Icons.heart_broken,
            label: 'Not Interested',
            bgColor: Colors.grey[100]!,
            iconColor: Colors.black87,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildShareIcon({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 11,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
