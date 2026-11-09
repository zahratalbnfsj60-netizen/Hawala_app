import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class NumberTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final int newTextValue = int.parse(newValue.text.replaceAll(',', ''));
    final String newText = NumberFormat.decimalPattern('en').format(newTextValue);
    return TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}
