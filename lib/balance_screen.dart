import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BalanceScreen extends StatelessWidget {
  const BalanceScreen({super.key});

  void _showRechargeSheet(BuildContext context, bool isDark) {
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Recharge Coins',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildMockPackageTile(context, '65', '\$0.99', textColor),
              _buildMockPackageTile(context, '330', '\$4.99', textColor),
              _buildMockPackageTile(context, '660', '\$9.99', textColor),
              _buildMockPackageTile(context, '3300', '\$49.99', textColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMockPackageTile(
    BuildContext context,
    String coins,
    String price,
    Color textColor,
  ) {
    return ListTile(
      leading: const Icon(Icons.monetization_on, color: Colors.amber),
      title: Text('$coins Coins', style: TextStyle(color: textColor)),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: () {
          // Mock adding coins directly into Firestore
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            FirebaseFirestore.instance.collection('users').doc(uid).set({
              'coins_balance': FieldValue.increment(int.parse(coins)),
            }, SetOptions(merge: true));
          }
          Navigator.pop(context);
        },
        child: Text(
          price,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'me';
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF8F8F8);
    final Color cardColor = isDark ? Colors.black : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;
    final Color chevronColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
    final Color dividerColor = isDark ? Colors.grey[900]! : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 1,
        shadowColor: Colors.black12,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Balance',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.receipt_long_outlined, color: textColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransactionHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          int coinsBalance = 0;
          int diamondsBalance = 0;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            coinsBalance = data['coins_balance'] ?? 0;
            diamondsBalance = data['diamonds_balance'] ?? 0;
          }

          return ListView(
            children: [
              const SizedBox(height: 16),
              // COIN BALANCE SUMMARY CARD
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Coins',
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 16,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$coinsBalance',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _showRechargeSheet(context, isDark),
                          child: const Text(
                            'Recharge',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // LIVE REWARDS SECTION
              Container(
                color: cardColor,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LiveRewardsScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 16.0,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.diamond_outlined,
                          color: Colors.pinkAccent,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LIVE Rewards',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$diamondsBalance Diamonds',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: chevronColor,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Divider(color: dividerColor, height: 1),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// PLACEHOLDER SCREENS
// ---------------------------------------------------------

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      _buildPlaceholder(context, 'Transaction History');
}

class LiveRewardsScreen extends StatelessWidget {
  const LiveRewardsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      _buildPlaceholder(context, 'LIVE Rewards');
}

Widget _buildPlaceholder(BuildContext context, String title) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final Color bgColor = isDark ? Colors.black : Colors.white;
  final Color textColor = isDark ? Colors.white : Colors.black;

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
        title,
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
        '$title Stream...',
        style: TextStyle(color: Colors.grey[600]),
      ),
    ),
  );
}
