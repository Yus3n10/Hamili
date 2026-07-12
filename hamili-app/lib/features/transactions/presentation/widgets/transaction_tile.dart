import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/category_visuals.dart';
import '../../domain/category.dart';
import '../../domain/transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.category,
    required this.onTap,
    required this.onDelete,
  });

  final AppTransaction transaction;
  final AppCategory? category;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == 'expense';
    final amountColor = isExpense ? AppColors.expense : AppColors.income;
    final sign = isExpense ? '-' : '+';

    // "Others" is a catch-all category — the note field doubles as a
    // user-typed specific label in that case, so show it as the title
    // instead of the generic "Others" text.
    final isOthersWithLabel = category?.name.toLowerCase() == 'others' && (transaction.note?.isNotEmpty ?? false);
    final title = isOthersWithLabel ? transaction.note! : (category?.name ?? 'Uncategorized');
    final subtitle = isOthersWithLabel
        ? DateFormat.yMMMd().format(transaction.transactionDate)
        : (transaction.note?.isNotEmpty == true
            ? '${transaction.note} · ${DateFormat.yMMMd().format(transaction.transactionDate)}'
            : DateFormat.yMMMd().format(transaction.transactionDate));

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.expense,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return true;
      },
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: amountColor.withValues(alpha: 0.15),
          child: Icon(CategoryVisuals.iconFor(category?.icon), color: amountColor, size: 20),
        ),
        title: Text(title),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          '$sign${CurrencyFormatter.format(transaction.amount)}',
          style: TextStyle(color: amountColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
