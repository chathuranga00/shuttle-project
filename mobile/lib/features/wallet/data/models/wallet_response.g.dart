// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'wallet_response.dart';

WalletResponse _$WalletResponseFromJson(Map<String, dynamic> json) =>
    WalletResponse(
      id: (json['id'] as num).toInt(),
      balance: (json['balance'] as num).toDouble(),
      status: json['status'] as String,
    );

Map<String, dynamic> _$WalletResponseToJson(WalletResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'balance': instance.balance,
      'status': instance.status,
    };
