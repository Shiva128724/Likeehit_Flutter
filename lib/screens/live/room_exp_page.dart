import 'package:flutter/material.dart';

import '../../services/live_service.dart';

class RoomExpPage extends StatefulWidget {
  const RoomExpPage({super.key, required this.roomId});

  final String roomId;

  @override
  State<RoomExpPage> createState() => _RoomExpPageState();
}

class _RoomExpPageState extends State<RoomExpPage> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14051F),
      body: StreamBuilder<RoomExpState>(
        stream: LiveService.instance.watchRoomExp(widget.roomId),
        builder: (context, snapshot) {
          final exp = snapshot.data ?? LiveService.roomExpFromRoomData({});
          return Stack(
            fit: StackFit.expand,
            children: [
              const _RoomExpBackground(),
              SafeArea(
                child: Column(
                  children: [
                    _header(),
                    const SizedBox(height: 16),
                    _tabs(),
                    const SizedBox(height: 18),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _tabIndex == 0
                            ? _TodayExpTab(
                                key: const ValueKey('today'),
                                exp: exp,
                              )
                            : _RoomLevelTab(
                                key: const ValueKey('level'),
                                exp: exp,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Room EXP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: _showPrivilegeNotice,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFFFF3F7F),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              'NEW',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            _tabButton(0, 'EXP earned today'),
            _tabButton(1, 'Room Level'),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: double.infinity,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivilegeNotice() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notice on New Privileges',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF33313A),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Lv.4 Quick Upgrade Gift\n\n'
                  'Once the room reaches the required level, premium room gifts unlock in the gift panel. Sending them grants bonus Room EXP.\n\n'
                  'Lv.7 Free EXP Limit\n\n'
                  'Higher room levels increase daily EXP limits and room privileges for active hosts.\n\n'
                  'Lv.8 Gold EXP Limit\n\n'
                  'Higher monthly earning unlocks stronger room capacity, badge, and VIP profile effects.',
                  style: TextStyle(
                    color: Color(0xFF42404A),
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TodayExpTab extends StatelessWidget {
  const _TodayExpTab({super.key, required this.exp});

  final RoomExpState exp;

  @override
  Widget build(BuildContext context) {
    final dailyProgress = (exp.todayExp / 5000).clamp(0, 1).toDouble();
    final freeProgress = (exp.todayExp / 2000).clamp(0, 1).toDouble();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF3A155D).withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF8D49FF)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8D49FF).withValues(alpha: 0.22),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _glowLabel('EXP'),
                    const Spacer(),
                    Text(
                      '${exp.todayExp}/5000',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: dailyProgress,
                    backgroundColor: Colors.black.withValues(alpha: 0.28),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF4D8D),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reach 3000 and 5000 Room EXP each day to receive rewards. Room EXP grows from host star earnings.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                _sectionTitle('Free EXP (${exp.todayExp.clamp(0, 2000)}/2000)'),
                const SizedBox(height: 12),
                _emptyOrProgressBox(
                  value: freeProgress,
                  text: exp.todayExp == 0
                      ? 'No EXP earned'
                      : '+${exp.todayExp.clamp(0, 2000)} EXP from gifts today',
                  borderColor: const Color(0xFFDBF2F4),
                ),
                const SizedBox(height: 22),
                _sectionTitle('Gold EXP (${exp.todayExp.clamp(0, 5000)}/5000)'),
                const SizedBox(height: 12),
                _emptyOrProgressBox(
                  value: dailyProgress,
                  text: exp.todayExp == 0
                      ? 'No EXP earned'
                      : '+${exp.todayExp.clamp(0, 5000)} Gold EXP progress',
                  borderColor: const Color(0xFFF1E8CE),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomLevelTab extends StatelessWidget {
  const _RoomLevelTab({super.key, required this.exp});

  final RoomExpState exp;

  @override
  Widget build(BuildContext context) {
    final previous = (exp.level - 1).clamp(1, LiveService.roomExpMaxLevel);
    final next = (exp.level + 1).clamp(1, LiveService.roomExpMaxLevel);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        children: [
          SizedBox(
            height: 218,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _levelBadge(previous, false),
                      _levelBadge(exp.level, true),
                      _levelBadge(next, false),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 54),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: exp.levelProgress,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFC47BFF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                _sectionTitle('Level Privileges'),
                const SizedBox(height: 22),
                _privilegeGrid(exp.level),
                const SizedBox(height: 24),
                _taskCard(),
                const SizedBox(height: 22),
                _sectionTitle('Room Level EXP'),
                const SizedBox(height: 12),
                ...List.generate(LiveService.roomExpMaxLevel, (index) {
                  final level = index + 1;
                  final requiredExp = LiveService.roomExpForLevel(level);
                  final selected = level == exp.level;
                  return _levelRow(level, requiredExp, selected);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomExpBackground extends StatelessWidget {
  const _RoomExpBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF24005A), Color(0xFF160020), Color(0xFF08030D)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            left: -40,
            right: -40,
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB755FF).withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: 22,
            right: 22,
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _glowLabel(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF11D7FF), Color(0x0011D7FF)],
      ),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

Widget _sectionTitle(String title) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(
        width: 34,
        child: Divider(color: Color(0xFFC47BFF), thickness: 2),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF3A3740),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(
        width: 34,
        child: Divider(color: Color(0xFFC47BFF), thickness: 2),
      ),
    ],
  );
}

Widget _emptyOrProgressBox({
  required double value,
  required String text,
  required Color borderColor,
}) {
  return Container(
    width: double.infinity,
    height: 150,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: borderColor.withValues(alpha: 0.28),
      border: Border.all(color: borderColor),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF96949D),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: value,
            backgroundColor: Colors.white,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4D8D)),
          ),
        ),
      ],
    ),
  );
}

Widget _levelBadge(int level, bool selected) {
  final requiredExp = LiveService.roomExpForLevel(level);
  final size = selected ? 116.0 : 82.0;
  final accent = _levelAccent(level);
  return Opacity(
    opacity: selected ? 1 : 0.62,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [accent.withValues(alpha: 0.95), const Color(0xFF381066)],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: selected ? 0.62 : 0.25),
                blurRadius: selected ? 34 : 18,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white.withValues(alpha: 0.92),
                size: selected ? 72 : 48,
              ),
              Positioned(
                bottom: selected ? 18 : 12,
                child: Text(
                  'Lv.$level',
                  style: TextStyle(
                    color: const Color(0xFF27142E),
                    fontSize: selected ? 20 : 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          selected
              ? '${_formatNumber(requiredExp)} EXP'
              : level == 1
              ? '0 EXP\nCurrent EXP'
              : '${_formatNumber(requiredExp)} EXP',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: selected ? 0.9 : 0.72),
            fontSize: selected ? 14 : 11,
            height: 1.25,
          ),
        ),
      ],
    ),
  );
}

Widget _privilegeGrid(int level) {
  final capacity = 40 + (level * 10);
  final admin = (level * 2).clamp(5, 60);
  final leadSinger = (level * 2).clamp(5, 60);
  final coOwner = (level / 4).ceil().clamp(1, 8);
  final items = <_PrivilegeItem>[
    const _PrivilegeItem(
      Icons.diamond_outlined,
      'Room Diamond\nEarnings',
      'Sharing 20%',
    ),
    const _PrivilegeItem(
      Icons.workspace_premium_outlined,
      'Room Badge',
      'VIP ring',
    ),
    _PrivilegeItem(Icons.badge_outlined, 'Room Capacity', '$capacity people'),
    _PrivilegeItem(Icons.person_pin_rounded, 'Admin', '$admin people'),
    _PrivilegeItem(Icons.key_rounded, 'Lead Singer', '$leadSinger people'),
    _PrivilegeItem(Icons.groups_rounded, 'Co-owner', '$coOwner people'),
  ];

  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 22,
      childAspectRatio: 0.88,
    ),
    itemCount: items.length,
    itemBuilder: (context, index) {
      final item = items[index];
      return Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFF4EEFF),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: const Color(0xFF7A42F4), size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF33313A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9996A0),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    },
  );
}

Widget _taskCard() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete Room Owner tasks to get additional EXP',
                style: TextStyle(
                  color: Color(0xFF3A3740),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Tasks change periodically and may grant extra rewards.',
                style: TextStyle(color: Color(0xFF9B98A2), fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3F7F),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Go',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _levelRow(int level, int requiredExp, bool selected) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: selected ? const Color(0xFFFFEDF5) : const Color(0xFFF8F7FB),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: selected ? const Color(0xFFFF4D8D) : const Color(0xFFE8E5EF),
      ),
    ),
    child: Row(
      children: [
        Icon(
          Icons.workspace_premium_rounded,
          color: _levelAccent(level),
          size: 28,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Lv.$level',
            style: const TextStyle(
              color: Color(0xFF33313A),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          level == 1
              ? '0 EXP Current EXP'
              : '${_formatNumber(requiredExp)} EXP',
          style: const TextStyle(
            color: Color(0xFF77727F),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Color _levelAccent(int level) {
  if (level >= 40) return const Color(0xFFFFD36B);
  if (level >= 25) return const Color(0xFFFF8B36);
  if (level >= 10) return const Color(0xFFC47BFF);
  if (level >= 4) return const Color(0xFF62C7FF);
  return const Color(0xFF77F2CC);
}

String _formatNumber(int value) {
  if (value >= 1000000) {
    final compact = value / 1000000;
    return '${compact.toStringAsFixed(compact.truncateToDouble() == compact ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final compact = value / 1000;
    return '${compact.toStringAsFixed(compact.truncateToDouble() == compact ? 0 : 1)}K';
  }
  return value.toString();
}

class _PrivilegeItem {
  const _PrivilegeItem(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}
