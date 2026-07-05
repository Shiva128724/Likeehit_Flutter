import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HostCenterScreen extends StatefulWidget {
  const HostCenterScreen({super.key});

  @override
  State<HostCenterScreen> createState() => _HostCenterScreenState();
}

enum _HostRange { thisMonth, lastMonth, custom }

class _HostCenterScreenState extends State<HostCenterScreen> {
  _HostRange _range = _HostRange.thisMonth;
  DateTimeRange? _customRange;
  int _tab = 0;
  int? _selectedDayIdx;

  DateTimeRange _activeRange() {
    final now = DateTime.now();
    if (_range == _HostRange.custom && _customRange != null) return _customRange!;
    if (_range == _HostRange.lastMonth) {
      final firstThis = DateTime(now.year, now.month, 1);
      final firstLast = DateTime(now.year, now.month - 1, 1);
      return DateTimeRange(start: firstLast, end: firstThis.subtract(const Duration(milliseconds: 1)));
    }
    final firstThis = DateTime(now.year, now.month, 1);
    final next = DateTime(now.year, now.month + 1, 1);
    return DateTimeRange(start: firstThis, end: next.subtract(const Duration(milliseconds: 1)));
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange,
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _range = _HostRange.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }
    final range = _activeRange();
    return Scaffold(
      backgroundColor: const Color(0xFF181A30),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181A30),
        title: const Text('Host Center', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('liveRooms')
            .where('hostId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(400)
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? const [];
          final stats = _HostStats.fromRooms(docs, range);
          return Column(
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _tabBtn('Data', _tab == 0, () => setState(() => _tab = 0)),
                  const SizedBox(width: 24),
                  _tabBtn('Task', _tab == 1, () => setState(() => _tab = 1)),
                  const SizedBox(width: 24),
                  _tabBtn('Top Fans', _tab == 2, () => setState(() => _tab = 2)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _tab == 2
                    ? _TopFansView(hostId: uid)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Live Data', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _rangeBtn(
                                    'This Month',
                                    _range == _HostRange.thisMonth,
                                    () => setState(() => _range = _HostRange.thisMonth),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _rangeBtn(
                                    'Last Month',
                                    _range == _HostRange.lastMonth,
                                    () => setState(() => _range = _HostRange.lastMonth),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _rangeBtn('Custom', _range == _HostRange.custom, _pickCustom),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (_tab == 0) _validLiveChart(docs, range),
                            if (_tab == 1) _taskView(stats),
                            const SizedBox(height: 16),
                            _metricGrid(stats),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metricGrid(_HostStats s) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.45,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _metric('Valid Live Time', s.validLiveTime),
        _metric('Sum Live Time', s.sumLiveTime),
        _metric('Live Time', '${s.liveSessions}'),
        _metric('Live Diamonds', '${s.liveDiamonds}'),
        _metric('Redeem', '${s.redeem}'),
        _metric('Valid Live Day', '${s.validLiveDay}'),
        _metric('Cumulative Releases', '${s.cumulativeReleases}'),
      ],
    );
  }

  Widget _taskView(_HostStats s) {
    final tasks = <_TaskItem>[
      _TaskItem('Go Live 30 mins/day', s.sumLiveTime, _secToText(30 * 60), s.totalSec >= 30 * 60),
      _TaskItem('Get 100 Diamonds', '${s.liveDiamonds}', '100', s.liveDiamonds >= 100),
      _TaskItem('Valid Live Day 7', '${s.validLiveDay}', '7', s.validLiveDay >= 7),
      _TaskItem('Top Fans 3+', '${s.topFansCount}', '3', s.topFansCount >= 3),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF23253B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tasks.map((t) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  t.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: t.done ? const Color(0xFF54E28A) : Colors.white54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                Text(
                  '${t.current}/${t.target}',
                  style: const TextStyle(color: Color(0xFFFFD66B), fontWeight: FontWeight.w800),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _metric(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2C40),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _rangeBtn(String label, bool active, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? const Color(0xFF8E4DFF) : Colors.transparent,
        side: BorderSide(color: active ? Colors.transparent : Colors.white38),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.white70,
          fontWeight: FontWeight.w800,
          fontSize: 24,
        ),
      ),
    );
  }

  Widget _validLiveChart(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DateTimeRange range,
  ) {
    final days = range.end.difference(range.start).inDays + 1;
    final clampedDays = days.clamp(1, 31);
    final perDay = List<int>.filled(clampedDays, 0);
    for (final doc in docs) {
      final data = doc.data();
      final created = data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null;
      if (created == null) continue;
      if (created.isBefore(range.start) || created.isAfter(range.end)) continue;
      final ended = data['endedAt'] is Timestamp
          ? (data['endedAt'] as Timestamp).toDate()
          : DateTime.now();
      final sec = ended.difference(created).inSeconds.clamp(0, 60 * 60 * 24 * 2);
      final index = created.difference(DateTime(range.start.year, range.start.month, range.start.day)).inDays;
      if (index >= 0 && index < perDay.length) {
        perDay[index] += sec;
      }
    }
    final maxSec = perDay.fold<int>(1, (a, b) => b > a ? b : a);
    final labels = {
      0,
      (clampedDays * 0.16).floor(),
      (clampedDays * 0.32).floor(),
      (clampedDays * 0.48).floor(),
      (clampedDays * 0.64).floor(),
      (clampedDays * 0.80).floor(),
      clampedDays - 1,
    }.toList()
      ..sort();
    final today = DateTime.now();
    final todayIdx = today.isBefore(range.start) || today.isAfter(range.end)
        ? null
        : today
              .difference(DateTime(range.start.year, range.start.month, range.start.day))
              .inDays;
    final todaySec = (todayIdx != null && todayIdx >= 0 && todayIdx < perDay.length)
        ? perDay[todayIdx]
        : 0;
    final avgSec = perDay.isEmpty ? 0 : (perDay.reduce((a, b) => a + b) ~/ perDay.length);
    int bestIdx = 0;
    int bestSec = 0;
    for (int i = 0; i < perDay.length; i++) {
      if (perDay[i] > bestSec) {
        bestSec = perDay[i];
        bestIdx = i;
      }
    }
    final bestDay = range.start.add(Duration(days: bestIdx));

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0x16FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Valid Live Time',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (context, glow, child) {
              return SizedBox(
                height: 220,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final h = c.maxHeight - 26;
                    final points = List<Offset>.generate(clampedDays, (i) {
                      final dx = clampedDays <= 1 ? 0.0 : (w * i / (clampedDays - 1));
                      final ratio = perDay[i] / maxSec;
                      final base = h - 14;
                      final dy = base - (ratio * (h - 26));
                      return Offset(dx, dy);
                    });

                    final sel = _selectedDayIdx != null &&
                            _selectedDayIdx! >= 0 &&
                            _selectedDayIdx! < points.length
                        ? points[_selectedDayIdx!]
                        : null;

                    return GestureDetector(
                      onTapDown: (d) {
                        final i = ((d.localPosition.dx / w) * (clampedDays - 1))
                            .round()
                            .clamp(0, clampedDays - 1);
                        setState(() => _selectedDayIdx = i);
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _LiveChartPainter(
                                points: points,
                                glow: glow,
                                showGuides: true,
                              ),
                            ),
                          ),
                          if (sel != null)
                            Positioned(
                              left: (sel.dx - 66).clamp(6, w - 132),
                              top: (sel.dy - 56).clamp(2, h - 64),
                              child: Container(
                                width: 132,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xEE2A2D4D),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0x66FF7CCF)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_mon(range.start.add(Duration(days: _selectedDayIdx!)).month)} ${range.start.add(Duration(days: _selectedDayIdx!)).day}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _fmt(perDay[_selectedDayIdx!]),
                                      style: const TextStyle(color: Color(0xFFFF7CCF), fontWeight: FontWeight.w900, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.map((i) {
              final day = range.start.add(Duration(days: i));
              return Text(
                '${_mon(day.month)} ${day.day}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryChip(
                  'Today Live',
                  _fmt(todaySec),
                  const Color(0xFF67A9FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryChip(
                  'Avg/Day',
                  _fmt(avgSec),
                  const Color(0xFFB072FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryChip(
                  'Best Day',
                  '${_mon(bestDay.month)} ${bestDay.day}',
                  const Color(0xFFFF7CCF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveChartPainter extends CustomPainter {
  const _LiveChartPainter({
    required this.points,
    required this.glow,
    required this.showGuides,
  });

  final List<Offset> points;
  final double glow;
  final bool showGuides;

  @override
  void paint(Canvas canvas, Size size) {
    if (showGuides) {
      final guide = Paint()
        ..color = const Color(0x55FFFFFF)
        ..strokeWidth = 1;
      for (int i = 0; i < 7; i++) {
        final x = size.width * i / 6;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), guide);
      }
    }
    if (points.isEmpty) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final cx = (p0.dx + p1.dx) / 2;
      path.quadraticBezierTo(cx, p0.dy, p1.dx, p1.dy);
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = const Color(0x66FF7CCF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFFFF7CCF);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    final point = Paint()..color = const Color(0xFFFF7CCF);
    final pointGlow = Paint()
      ..color = const Color(0x66FF7CCF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (final p in points) {
      canvas.drawCircle(p, 4.5 * glow, pointGlow);
      canvas.drawCircle(p, 3.7, point);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveChartPainter oldDelegate) {
    return oldDelegate.glow != glow || oldDelegate.points != points;
  }
}

class _TopFansView extends StatelessWidget {
  const _TopFansView({required this.hostId});
  final String hostId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('roomGiftLeaders')
          .where('hostId', isEqualTo: hostId)
          .snapshots(),
      builder: (context, snap) {
        final map = <String, _Fan>{};
        for (final doc in snap.data?.docs ?? const []) {
          final d = doc.data();
          final uid = d['uid']?.toString() ?? doc.id;
          final fan = map[uid] ?? _Fan(uid: uid, name: d['name']?.toString() ?? 'Fan', photoUrl: d['photoUrl']?.toString() ?? '', stars: 0);
          map[uid] = fan.copyWith(stars: fan.stars + _toInt(d['totalStars']));
        }
        final fans = map.values.toList()..sort((a, b) => b.stars.compareTo(a.stars));
        if (fans.isEmpty) return const Center(child: Text('No fan gifts yet', style: TextStyle(color: Colors.white70)));
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (fans.isNotEmpty)
              _topFanCard(1, fans[0], const [Color(0xFFFFD66B), Color(0xFFFFA63D)]),
            if (fans.length > 1)
              _topFanCard(2, fans[1], const [Color(0xFFB9C9FF), Color(0xFF8EA1E5)]),
            if (fans.length > 2)
              _topFanCard(3, fans[2], const [Color(0xFFE0B08A), Color(0xFFB67B56)]),
            const SizedBox(height: 8),
            ...List.generate(fans.length, (i) {
              final fan = fans[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  SizedBox(width: 28, child: Text('#${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                  CircleAvatar(backgroundImage: fan.photoUrl.isNotEmpty ? NetworkImage(fan.photoUrl) : null, child: fan.photoUrl.isEmpty ? const Icon(Icons.person) : null),
                  const SizedBox(width: 10),
                  Expanded(child: Text(fan.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  Text('${fan.stars}★', style: const TextStyle(color: Color(0xFFFFD66B), fontWeight: FontWeight.w800)),
                ]),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _topFanCard(int rank, _Fan fan, List<Color> colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors.map((c) => c.withValues(alpha: 0.22)).toList()),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.first.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: fan.photoUrl.isNotEmpty ? NetworkImage(fan.photoUrl) : null,
            child: fan.photoUrl.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top $rank', style: TextStyle(color: colors.first, fontWeight: FontWeight.w900)),
                Text(fan.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Text('${fan.stars}★', style: const TextStyle(color: Color(0xFFFFD66B), fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }
}

class _Fan {
  const _Fan({required this.uid, required this.name, required this.photoUrl, required this.stars});
  final String uid;
  final String name;
  final String photoUrl;
  final int stars;

  _Fan copyWith({int? stars}) => _Fan(uid: uid, name: name, photoUrl: photoUrl, stars: stars ?? this.stars);
}

class _HostStats {
  const _HostStats({
    required this.validLiveTime,
    required this.sumLiveTime,
    required this.liveSessions,
    required this.liveDiamonds,
    required this.redeem,
    required this.validLiveDay,
    required this.cumulativeReleases,
    required this.totalSec,
    required this.topFansCount,
  });

  final String validLiveTime;
  final String sumLiveTime;
  final int liveSessions;
  final int liveDiamonds;
  final int redeem;
  final int validLiveDay;
  final int cumulativeReleases;
  final int totalSec;
  final int topFansCount;

  factory _HostStats.fromRooms(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, DateTimeRange range) {
    var totalSec = 0;
    var sessions = 0;
    var diamonds = 0;
    final days = <String>{};
    for (final doc in docs) {
      final d = doc.data();
      final c = d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null;
      if (c == null) continue;
      if (c.isBefore(range.start) || c.isAfter(range.end)) continue;
      final e = d['endedAt'] is Timestamp ? (d['endedAt'] as Timestamp).toDate() : DateTime.now();
      final sec = e.difference(c).inSeconds.clamp(0, 60 * 60 * 24 * 2);
      totalSec += sec;
      sessions += 1;
      diamonds += _toInt(d['totalGiftStars']);
      days.add('${c.year}-${c.month}-${c.day}');
    }
    final formatted = _fmt(totalSec);
    return _HostStats(
      validLiveTime: formatted,
      sumLiveTime: formatted,
      liveSessions: sessions,
      liveDiamonds: diamonds,
      redeem: 0,
      validLiveDay: days.length,
      cumulativeReleases: diamonds,
      totalSec: totalSec,
      topFansCount: 0,
    );
  }
}

String _fmt(int sec) {
  final h = (sec ~/ 3600).toString().padLeft(2, '0');
  final m = ((sec % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (sec % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

String _secToText(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  return '${h}h ${m}m';
}

class _TaskItem {
  const _TaskItem(this.title, this.current, this.target, this.done);
  final String title;
  final String current;
  final String target;
  final bool done;
}

String _mon(int m) {
  const months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[m];
}
