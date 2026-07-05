import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services/live_service.dart';
import 'widgets/svip_badge.dart';

class SvipScreen extends StatefulWidget {
  const SvipScreen({super.key});

  @override
  State<SvipScreen> createState() => _SvipScreenState();
}

class _SvipScreenState extends State<SvipScreen> {
  bool _busy = false;

  static const List<_SvipPlan> _plans = [
    _SvipPlan(
      id: 'lite',
      label: 'SVIP1',
      title: 'SVIP Lite',
      tier: 1,
      level: 1,
      days: 7,
      priceStars: 99,
      colors: [Color(0xFF775BFF), Color(0xFFFF6AB3)],
    ),
    _SvipPlan(
      id: 'pro',
      label: 'SVIP2',
      title: 'SVIP Pro',
      tier: 2,
      level: 3,
      days: 30,
      priceStars: 299,
      colors: [Color(0xFF30D7BE), Color(0xFF55A8FF)],
    ),
    _SvipPlan(
      id: 'royal',
      label: 'SVIP3',
      title: 'SVIP Royal',
      tier: 3,
      level: 7,
      days: 90,
      priceStars: 999,
      colors: [Color(0xFFFFC857), Color(0xFFFF4D88)],
    ),
  ];

  Future<void> _buy(_SvipPlan plan) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final response = await LiveService.instance.purchaseSvipPlan(plan.id);
      final alreadyActive = response['alreadyActive'] == true;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            alreadyActive
                ? '${plan.label} already active'
                : '${plan.label} activated',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF090A12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('SVIP'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: uid == null
            ? const Stream.empty()
            : FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final stars = _asInt(data['stars']);
          final activeTier = _activeSvipTierFromData(data);
          final activePlan = _planForTier(activeTier);
          final until = _formatUntil(data['svipUntil']);

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF24103D), Color(0xFF101729)],
                  ),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x662E1F8F),
                      blurRadius: 28,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFD66E), Color(0xFFFF4FA3)],
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LikeeHit SVIP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  SvipBadge(tier: activeTier),
                                  Text(
                                    activePlan == null
                                        ? 'Unlock premium identity and room boosts'
                                        : '${activePlan.title} active until $until',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _MiniBenefit(
                          icon: Icons.workspace_premium_rounded,
                          label: 'VIP Badge',
                          active: activeTier >= 1,
                        ),
                        _MiniBenefit(
                          icon: Icons.photo_filter_rounded,
                          label: 'Frame',
                          active: activeTier >= 2,
                        ),
                        _MiniBenefit(
                          icon: Icons.rocket_launch_rounded,
                          label: 'Entry FX',
                          active: activeTier >= 3,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Choose Plan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2030),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFFD95B)),
                        const SizedBox(width: 5),
                        Text(
                          stars.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final plan in _plans) ...[
                _SvipPlanCard(
                  plan: plan,
                  stars: stars,
                  activeTier: activeTier,
                  busy: _busy,
                  onTap: () => _buy(plan),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 8),
              Text(
                activePlan == null
                    ? 'Activate a plan to show SVIP1, SVIP2 or SVIP3 on profile, live rooms and party entries.'
                    : '${activePlan.label} is active. Your premium badge appears in profile, live rooms and party entries.',
                style: const TextStyle(color: Colors.white54, height: 1.35),
              ),
            ],
          );
        },
      ),
    );
  }

  static _SvipPlan? _planForTier(int tier) {
    for (final plan in _plans) {
      if (plan.tier == tier) return plan;
    }
    return null;
  }
}

class _SvipPlanCard extends StatelessWidget {
  const _SvipPlanCard({
    required this.plan,
    required this.stars,
    required this.activeTier,
    required this.busy,
    required this.onTap,
  });

  final _SvipPlan plan;
  final int stars;
  final int activeTier;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = activeTier == plan.tier;
    final included = activeTier > plan.tier;
    final canBuy = !busy && activeTier < plan.tier && stars >= plan.priceStars;
    final buttonText = current
        ? 'Active'
        : included
        ? 'Included'
        : activeTier > 0
        ? 'Upgrade'
        : '${plan.priceStars} stars';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: current || included ? plan.colors.first : Colors.white10,
          width: current ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: plan.colors),
              boxShadow: [
                BoxShadow(
                  color: plan.colors.last.withValues(alpha: 0.35),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(Icons.diamond_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      plan.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SvipBadge(tier: plan.tier, compact: true),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Lv.${plan.level} - ${plan.days} days - Entry badge + profile glow',
                  style: const TextStyle(color: Colors.white60, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: canBuy ? onTap : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3D84),
              foregroundColor: Colors.white,
              disabledBackgroundColor: current
                  ? plan.colors.first.withValues(alpha: 0.55)
                  : Colors.white12,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(86, 44),
            ),
            child: Text(
              buttonText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBenefit extends StatelessWidget {
  const _MiniBenefit({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.12) : Colors.white10,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFFFFD95B) : Colors.white54,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(color: active ? Colors.white : Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _SvipPlan {
  const _SvipPlan({
    required this.id,
    required this.label,
    required this.title,
    required this.tier,
    required this.level,
    required this.days,
    required this.priceStars,
    required this.colors,
  });

  final String id;
  final String label;
  final String title;
  final int tier;
  final int level;
  final int days;
  final int priceStars;
  final List<Color> colors;
}

String _formatUntil(dynamic value) {
  if (value is! Timestamp) return 'active';
  final date = value.toDate();
  return '${date.day}/${date.month}/${date.year}';
}

int _activeSvipTierFromData(Map<String, dynamic> data) {
  final until = data['svipUntil'];
  if (until is Timestamp && !until.toDate().isAfter(DateTime.now())) return 0;

  final tier = _asInt(data['svipTier']);
  if (tier > 0) return tier.clamp(1, 3);

  final plan = data['svipPlan']?.toString().toLowerCase() ?? '';
  if (plan == 'royal') return 3;
  if (plan == 'pro') return 2;
  if (plan == 'lite') return 1;

  final level = _asInt(data['svipLevel']);
  if (level >= 7) return 3;
  if (level >= 3) return 2;
  if (level >= 1) return 1;
  return 0;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
