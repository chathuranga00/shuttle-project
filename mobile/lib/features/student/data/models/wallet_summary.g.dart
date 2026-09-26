// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WalletSummary _$WalletSummaryFromJson(Map<String, dynamic> json) =>
    WalletSummary(
      // balance arrives as a JSON number (BigDecimal) — convert to string
      balance: json['balance'].toString(),
      status: json['status'] as String,
    );

Map<String, dynamic> _$WalletSummaryToJson(WalletSummary instance) =>
    <String, dynamic>{
      'balance': instance.balance,
      'status': instance.status,
    };
