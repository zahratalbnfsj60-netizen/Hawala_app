import 'package:intl/intl.dart';
final _num = NumberFormat('#,##0.##', 'ar');
final _date = DateFormat('yyyy/MM/dd', 'ar');
String fmtNum(num v) => _num.format(v);
String fmtDate(DateTime d) => _date.format(d);
