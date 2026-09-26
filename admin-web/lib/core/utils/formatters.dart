import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'LKR ',
    decimalDigits: 2,
  );

  static String formatCurrency(dynamic amount) {
    if (amount == null) return 'LKR 0.00';
    if (amount is num) return _currencyFormat.format(amount);
    final parsed = double.tryParse(amount.toString());
    return parsed != null ? _currencyFormat.format(parsed) : 'LKR 0.00';
  }

  static String formatDate(dynamic dateTime) {
    if (dateTime == null) return '-';
    try {
      DateTime dt;
      if (dateTime is DateTime) {
        dt = dateTime;
      } else {
        dt = DateTime.parse(dateTime.toString());
      }
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {
      return dateTime.toString();
    }
  }

  static String formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '-';
    try {
      DateTime dt;
      if (dateTime is DateTime) {
        dt = dateTime;
      } else {
        dt = DateTime.parse(dateTime.toString());
      }
      return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
    } catch (_) {
      return dateTime.toString();
    }
  }

  static Widget statusBadge(String status) {
    Color bg;
    Color text;
    final upper = status.toUpperCase();

    switch (upper) {
      case 'ACTIVE':
      case 'SUCCESS':
      case 'COMPLETED':
        bg = AppTheme.successLight;
        text = AppTheme.success;
        break;
      case 'SCHEDULED':
      case 'PENDING':
      case 'IN_PROGRESS':
        bg = AppTheme.infoLight;
        text = AppTheme.info;
        break;
      case 'SUSPENDED':
      case 'INACTIVE':
      case 'MAINTENANCE':
        bg = AppTheme.warningLight;
        text = AppTheme.warning;
        break;
      case 'CANCELLED':
      case 'FAILED':
      case 'RETIRED':
        bg = AppTheme.dangerLight;
        text = AppTheme.danger;
        break;
      default:
        bg = AppTheme.surfaceMuted;
        text = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        upper,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
