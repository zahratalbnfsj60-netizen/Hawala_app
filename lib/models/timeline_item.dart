import 'transfer.dart';
import 'debt.dart';

class TimelineItem {
  final DateTime date;
  final Transfer? transfer;
  final Debt? debt;

  TimelineItem.transfer(this.transfer) : date = transfer!.date, debt = null;
  TimelineItem.debt(this.debt) : date = debt!.date, transfer = null;
}
