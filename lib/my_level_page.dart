import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'services/level_service.dart';

class MyLevelPage extends StatelessWidget {
  const MyLevelPage({
    super.key,
    required this.uid,
    required this.displayName,
    required this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF171821),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171821),
        foregroundColor: Colors.white,
        title: const Text('My level'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final level = LevelService.userLevelFromUserData(data);
          final name = data['name']?.toString().trim().isNotEmpty == true
              ? data['name'].toString().trim()
              : displayName;
          final avatar =
              data['photoURL']?.toString() ??
              data['photoUrl']?.toString() ??
              photoUrl;
          return SingleChildScrollView(
            child: Column(
              children: [
                _levelHero(name, avatar, level),
                const SizedBox(height: 18),
                _upgradeCard(),
                const SizedBox(height: 28),
                const Text(
                  'Privileges',
                  style: TextStyle(
                    color: Color(0xFFF2D8FF),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _privilegeTabs(),
                const SizedBox(height: 18),
                _privilegeGrid(),
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _levelHero(String name, String avatar, UserLevelState level) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF62A8), Color(0xFF8E7CFF)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 58,
                backgroundColor: Colors.black,
                backgroundImage: avatar.isNotEmpty
                    ? NetworkImage(avatar)
                    : null,
                child: avatar.isEmpty
                    ? const Icon(Icons.person, color: Colors.white70, size: 56)
                    : null,
              ),
              Positioned(bottom: -10, child: _levelPill(level.level)),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: level.progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.42),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: -34,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${level.expInLevel}',
                      style: const TextStyle(
                        color: Color(0xFFFF5E9F),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                level.isMaxLevel ? 'MAX Level' : 'Next:  Lv.${level.level + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                level.isMaxLevel
                    ? 'Exp ${level.totalExp}'
                    : 'Exp  ${level.expInLevel}/${level.expNeededForNextLevel}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _upgradeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF3B3B61),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF9073FF)),
        ),
        child: const Column(
          children: [
            Text(
              '>>   How to upgrade   <<',
              style: TextStyle(
                color: Color(0xFFFFD8F1),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 20),
            _UpgradeRow(
              icon: Icons.local_florist_rounded,
              title: 'Send Flowers',
              subtitle: 'You can get 3 exp for every flower you send.',
            ),
            SizedBox(height: 18),
            _UpgradeRow(
              icon: Icons.workspace_premium_rounded,
              title: 'Send Gifts',
              subtitle: 'Every 1 star sent gives +1 EXP.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _privilegeTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        _PrivilegeTab(label: 'Flower', selected: true),
        _PrivilegeTab(label: 'Avatar\nFrame'),
        _PrivilegeTab(label: 'Personalize\nBackground'),
      ],
    );
  }

  Widget _privilegeGrid() {
    final items = const [
      ('3 flowers/day', 'Lv.0'),
      ('5 flowers/day', 'Lv.1'),
      ('10 flowers/day', 'Lv.5'),
      ('Avatar frame', 'Lv.10'),
      ('Profile glow', 'Lv.20'),
      ('VIP entry', 'Lv.30'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2938),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFF403044),
                  child: Icon(
                    Icons.local_florist_rounded,
                    color: Color(0xFFFF5E9F),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.$1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _levelPill(int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5F79FF), Color(0xFFC493FF)],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9073FF).withValues(alpha: 0.45),
            blurRadius: 12,
          ),
        ],
      ),
      child: Text(
        'Lv.$level',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF5E9F), size: 34),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivilegeTab extends StatelessWidget {
  const _PrivilegeTab({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 62,
          height: 4,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF5E9F) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}
