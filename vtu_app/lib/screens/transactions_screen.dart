import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/transaction_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_badge.dart';
import '../config/theme.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchCtrl = TextEditingController();
  TransactionType? _filterType;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TransactionModel> _filteredTransactions(List<TransactionModel> all) {
    return all.where((t) {
      final matchesType = _filterType == null || t.type == _filterType;
      final matchesSearch = _searchQuery.isEmpty ||
          t.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (t.recipient?.contains(_searchQuery) ?? false);
      return matchesType && matchesSearch;
    }).toList();
  }

  void _showDetail(BuildContext ctx, TransactionModel t) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Transaction Details',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 20),
            _detailRow(ctx, 'ID', t.id),
            _detailRow(ctx, 'Type', t.typeLabel),
            _detailRow(ctx, 'Amount', t.formattedAmount),
            _detailRow(ctx, 'Description', t.description),
            if (t.source != null) _detailRow(ctx, 'Source', t.source!),
            if (t.destination != null) _detailRow(ctx, 'Destination', t.destination!),
            if (t.recipient != null) _detailRow(ctx, 'Recipient', t.recipient!),
            if (t.provider != null) _detailRow(ctx, 'Provider', t.provider!),
            if (t.reference != null)
              _copyableRow(ctx, 'Reference', t.reference!),
            _detailRow(ctx, 'Date', _formatDate(t.createdAt)),
            const SizedBox(height: 16),
            StatusBadge(status: t.status),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _copyableRow(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    fontSize: 13)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: const Text('Reference copied to clipboard!'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(20),
                  ),
                );
              },
              child: Row(
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(width: 6),
                  Icon(Icons.copy_rounded,
                      size: 14,
                      color: Theme.of(ctx).colorScheme.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(TransactionType t) {
    switch (t) {
      case TransactionType.airtime:
        return Icons.phone_android_rounded;
      case TransactionType.data:
        return Icons.wifi_rounded;
      case TransactionType.transfer:
        return Icons.send_rounded;
      case TransactionType.deposit:
        return Icons.arrow_downward_rounded;
      case TransactionType.electricity:
        return Icons.flash_on_rounded;
      case TransactionType.cableTv:
        return Icons.tv_rounded;
      case TransactionType.water:
        return Icons.water_drop_rounded;
      case TransactionType.other:
        return Icons.receipt_rounded;
    }
  }

  Color _typeColor(TransactionType t) {
    switch (t) {
      case TransactionType.airtime:
        return AppTheme.secondaryEmerald;
      case TransactionType.data:
        return const Color(0xFF8B5CF6);
      case TransactionType.transfer:
        return AppTheme.primaryIndigo;
      case TransactionType.deposit:
        return AppTheme.secondaryEmerald;
      case TransactionType.electricity:
        return AppTheme.warningAmber;
      case TransactionType.cableTv:
        return const Color(0xFFEC4899);
      case TransactionType.water:
        return const Color(0xFF06B6D4);
      case TransactionType.other:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final filtered = _filteredTransactions(auth.transactions);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient:
              isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Transactions'),
                backgroundColor: Colors.transparent,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Column(
                  children: [
                    // Search bar
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () => setState(() {
                                  _searchCtrl.clear();
                                  _searchQuery = '';
                                }),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip(null, 'All'),
                          ...TransactionType.values.map((t) =>
                              _filterChip(t, t.name[0].toUpperCase() + t.name.substring(1))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No transactions found',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final t = filtered[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              borderRadius: 16,
                              onTap: () => _showDetail(ctx, t),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _typeColor(t.type)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(_typeIcon(t.type),
                                        color: _typeColor(t.type), size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(t.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w500)),
                                        const SizedBox(height: 2),
                                        Text(_formatDate(t.createdAt),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        t.formattedAmount,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: t.isCredit
                                              ? AppTheme.secondaryEmerald
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      StatusBadge(
                                          status: t.status, fontSize: 10),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(TransactionType? type, String label) {
    final selected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filterType = type),
        selectedColor: AppTheme.primaryIndigo,
        labelStyle: TextStyle(
          color: selected ? Colors.white : null,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
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
