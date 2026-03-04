import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/transaction_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_badge.dart';
import '../config/theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _balanceVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => auth.refreshProfile(),
            color: AppTheme.primaryIndigo,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  AppTheme.primaryIndigo.withValues(alpha: 0.15),
                              child: Text(
                                user != null
                                    ? user.firstName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryIndigo,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Good day 👋',
                                    style: Theme.of(context).textTheme.bodySmall),
                                Text(
                                  user?.firstName ?? 'User',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.notifications_rounded),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Balance card
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Total Balance',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => _balanceVisible = !_balanceVisible),
                                    child: Icon(
                                      _balanceVisible
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                      size: 20,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  _balanceVisible
                                      ? (user?.formattedBalance ?? '₦0.00')
                                      : '₦ ••••••',
                                  key: ValueKey(_balanceVisible),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(
                                        color: AppTheme.primaryIndigo,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Builder(builder: (context) {
                                final txns = auth.transactions;
                                final income = txns
                                    .where((t) => t.isCredit)
                                    .fold(0.0, (sum, t) => sum + t.amount);
                                final expense = txns
                                    .where((t) => !t.isCredit)
                                    .fold(0.0, (sum, t) => sum + t.amount);
                                String fmt(double v) => '₦${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'; 
                                return Row(
                                  children: [
                                    _balanceChip(
                                        Icons.arrow_downward_rounded,
                                        'Income',
                                        fmt(income),
                                        AppTheme.secondaryEmerald),
                                    const SizedBox(width: 16),
                                    _balanceChip(
                                        Icons.arrow_upward_rounded,
                                        'Expense',
                                        fmt(expense),
                                        AppTheme.errorRed),
                                  ],
                                );
                              }),
                              const SizedBox(height: 16),
                              // Add / Send money buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: _balanceAction(
                                      context,
                                      icon: Icons.add_circle_rounded,
                                      label: 'Add Money',
                                      color: AppTheme.secondaryEmerald,
                                      onTap: () => Navigator.pushNamed(
                                          context, '/fund-wallet'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _balanceAction(
                                      context,
                                      icon: Icons.send_rounded,
                                      label: 'Send Money',
                                      color: AppTheme.primaryIndigo,
                                      onTap: () => Navigator.pushNamed(
                                          context, '/transfer'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Quick actions
                        Text('Quick Actions',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _actionButton(
                                context,
                                Icons.send_rounded,
                                'Transfer',
                                AppTheme.primaryIndigo,
                                () => Navigator.pushNamed(context, '/transfer')),
                            _actionButton(
                                context,
                                Icons.phone_android_rounded,
                                'Airtime',
                                AppTheme.secondaryEmerald,
                                () => Navigator.pushNamed(context, '/airtime')),
                            _actionButton(
                                context,
                                Icons.wifi_rounded,
                                'Data',
                                const Color(0xFF8B5CF6),
                                () => Navigator.pushNamed(context, '/data')),
                            _actionButton(
                                context,
                                Icons.flash_on_rounded,
                                'Bills',
                                AppTheme.warningAmber,
                                () => Navigator.pushNamed(context, '/bills')),
                          ],
                        ),
                        const SizedBox(height: 28),
                        // Transactions header
                        Row(
                          children: [
                            Text('Recent Transactions',
                                style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/transactions'),
                              child: const Text('See All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                // Transaction list
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: auth.transactions.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 64,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.2),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No transactions yet',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TransactionTile(
                                  transaction: auth.transactions[index]),
                            ),
                            childCount: auth.transactions.length > 5
                                ? 5
                                : auth.transactions.length,
                          ),
                        ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _balanceChip(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12, color: color),
            ),
          ],
        ),
      ],
    );
  }

  Widget _balanceAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isCredit
                  ? AppTheme.secondaryEmerald.withValues(alpha: 0.12)
                  : AppTheme.primaryIndigo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isCredit
                  ? AppTheme.secondaryEmerald
                  : AppTheme.primaryIndigo,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(transaction.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                transaction.formattedAmount,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isCredit ? AppTheme.secondaryEmerald : null,
                ),
              ),
              const SizedBox(height: 4),
              StatusBadge(status: transaction.status, fontSize: 10),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
