import 'package:flutter/material.dart';
import '../models/transaction_model.dart';

class StatusBadge extends StatelessWidget {
  final TransactionStatus status;
  final double fontSize;

  const StatusBadge({super.key, required this.status, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    switch (status) {
      case TransactionStatus.success:
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        text = const Color(0xFF10B981);
        label = 'Success';
        icon = Icons.check_circle_rounded;
      case TransactionStatus.pending:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        text = const Color(0xFFF59E0B);
        label = 'Pending';
        icon = Icons.schedule_rounded;
      case TransactionStatus.failed:
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        text = const Color(0xFFEF4444);
        label = 'Failed';
        icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: text, size: fontSize + 2),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
