import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/live_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _busy = false;

  static const List<_StarPack> _packs = [
    _StarPack(stars: 100, rupees: 10),
    _StarPack(stars: 1000, rupees: 100, title: '1k'),
    _StarPack(stars: 5015, rupees: 500, title: '5k +15', hot: true),
    _StarPack(stars: 10070, rupees: 1000, title: '10k +70', hot: true),
    _StarPack(stars: 50400, rupees: 5000, title: '50k +400', hot: true),
    _StarPack(stars: 101000, rupees: 10000, title: '100k +1000', hot: true),
  ];

  Future<void> _openPaymentSheet(_StarPack pack) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF251B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _PaymentMethodSheet(
        pack: pack,
        busy: _busy,
        onRazorpay: () => _startRazorpay(pack),
      ),
    );
  }

  Future<void> _startRazorpay(_StarPack pack) async {
    if (_busy) return;
    Navigator.pop(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final response = await LiveService.instance.createStarRechargePaymentLink(
        stars: pack.stars,
        amountPaise: pack.rupees * 100,
        packTitle: pack.displayTitle,
      );
      final url = response['shortUrl']?.toString() ?? '';
      final paymentLinkId = response['paymentLinkId']?.toString() ?? '';
      if (url.isEmpty || paymentLinkId.isEmpty) {
        throw StateError('Payment link was not created.');
      }
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('Unable to open Razorpay checkout.');
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Payment link opened. Tap Sync after payment.'),
          action: SnackBarAction(
            label: 'Sync',
            onPressed: () => _syncPayment(paymentLinkId),
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncPayment(String paymentLinkId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await LiveService.instance.syncStarRechargePayment(paymentLinkId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Payment synced. Stars updated.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _showRecords() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const _RechargeRecordsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF11121B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171820),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Wallet'),
        actions: [
          TextButton(
            onPressed: _showRecords,
            child: const Text('Record', style: TextStyle(color: Colors.white)),
          ),
        ],
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
          final diamonds = _asInt(data['diamonds']);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
            children: [
              const Text(
                'My Wallet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _BalanceCard(
                title: 'My Stars',
                value: stars,
                suffix: 'Stars',
                button: 'Get more',
                colors: const [Color(0xFFFF755F), Color(0xFFFFC04E)],
                onTap: () => _openPaymentSheet(_packs.first),
              ),
              const SizedBox(height: 16),
              _BalanceCard(
                title: 'Diamonds Balance',
                value: diamonds,
                suffix: 'Diamonds',
                button: 'Details',
                colors: const [Color(0xFF8258FF), Color(0xFFFF91F0)],
                onTap: _showRecords,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Stars Recharge',
                      style: TextStyle(color: Colors.white, fontSize: 22),
                    ),
                  ),
                  TextButton(
                    onPressed: _showRecords,
                    child: const Text('Recharge Record'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _packs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.18,
                ),
                itemBuilder: (context, index) => _StarPackTile(
                  pack: _packs[index],
                  selected: index == 0,
                  onTap: () => _openPaymentSheet(_packs[index]),
                ),
              ),
              const SizedBox(height: 18),
              const Text.rich(
                TextSpan(
                  text: 'Agree to ',
                  children: [
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(color: Color(0xFF4EA1FF)),
                    ),
                  ],
                ),
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 18),
              Container(
                height: 90,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3DB8), Color(0xFFFFB83B)],
                  ),
                ),
                child: const Text(
                  'Super Deluxe\nStar Pack',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Service',
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentMethodSheet extends StatelessWidget {
  const _PaymentMethodSheet({
    required this.pack,
    required this.busy,
    required this.onRazorpay,
  });

  final _StarPack pack;
  final bool busy;
  final VoidCallback onRazorpay;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Please select the payment method',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _PaymentRow(
                label: 'Paytm',
                icon: Icons.account_balance_wallet_rounded,
                onTap: () => Navigator.pop(context),
              ),
              _PaymentRow(
                label: busy ? 'Creating link...' : 'Razorpay',
                icon: Icons.near_me_rounded,
                onTap: busy ? null : onRazorpay,
              ),
              _PaymentRow(
                label: 'Google Pay',
                icon: Icons.payments_rounded,
                onTap: () => Navigator.pop(context),
              ),
              _PaymentRow(
                label: 'Official Recharge Service',
                icon: Icons.support_agent_rounded,
                onTap: () => Navigator.pop(context),
              ),
              _PaymentRow(
                label: 'Top-Up Agent',
                icon: Icons.person_pin_circle_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7D4DFF), Color(0xFFB055FF)],
                  ),
                ),
                child: Text(
                  '${pack.displayTitle} stars pack selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RechargeRecordsSheet extends StatelessWidget {
  const _RechargeRecordsSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: LiveService.instance.watchStarRechargeOrders(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Recharge Record',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: docs.isEmpty
                      ? const Center(
                          child: Text(
                            'No recharge record yet',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (context, index) =>
                              const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final status = data['status']?.toString() ?? '';
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFFC04E),
                                child: Icon(Icons.star, color: Colors.white),
                              ),
                              title: Text(
                                '${_asInt(data['stars'])} Stars',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                status,
                                style: const TextStyle(color: Colors.white54),
                              ),
                              trailing: Text(
                                'Rs ${_asInt(data['amountPaise']) ~/ 100}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.value,
    required this.suffix,
    required this.button,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final int value;
  final String suffix;
  final String button;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 116,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: colors),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    text: '$value ',
                    children: [
                      TextSpan(
                        text: suffix,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 30),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colors.first,
            ),
            onPressed: onTap,
            child: Text(button),
          ),
        ],
      ),
    );
  }
}

class _StarPackTile extends StatelessWidget {
  const _StarPackTile({
    required this.pack,
    required this.selected,
    required this.onTap,
  });

  final _StarPack pack;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E2449) : const Color(0xFF171B26),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF8E52FF) : Colors.white10,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFC04E),
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          pack.displayTitle,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs ${pack.rupees}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (pack.hot)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3D7A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Hot',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        tileColor: const Color(0xFF171B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(icon, color: const Color(0xFF365BFF)),
        ),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
      ),
    );
  }
}

class _StarPack {
  const _StarPack({
    required this.stars,
    required this.rupees,
    this.title,
    this.hot = false,
  });

  final int stars;
  final int rupees;
  final String? title;
  final bool hot;

  String get displayTitle => title ?? stars.toString();
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
