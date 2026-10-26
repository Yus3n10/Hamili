import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/category_visuals.dart';
import '../../domain/category.dart';
import '../../domain/transaction.dart';
import '../../../../shared/widgets/confirm_delete.dart';

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
    final amountColor = isExpense ? context.expenseText : context.incomeText;
    final sign = isExpense ? '-' : '+';


    final isOthersWithLabel = category?.name.toLowerCase() == 'others' && (transaction.note?.isNotEmpty ?? false);
    final title = isOthersWithLabel ? transaction.note! : (category?.name ?? 'Uncategorized');
    // The year only adds noise for this year's rows, and it was what got
    // cut off when a note was long.
    final date = transaction.transactionDate;
    final dateLabel =
        (date.year == DateTime.now().year ? DateFormat.MMMd() : DateFormat.yMMMd()).format(date);
    final subtitle = isOthersWithLabel
        ? dateLabel
        : (transaction.note?.isNotEmpty == true ? '${transaction.note} · $dateLabel' : dateLabel);

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
        final confirmed = await confirmDelete(
          context,
          title: 'Delete transaction?',
          message: '$title, $sign${CurrencyFormatter.format(transaction.amount)} on $dateLabel.',
        );
        if (confirmed) onDelete();
        return confirmed;
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
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: amountColor, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
