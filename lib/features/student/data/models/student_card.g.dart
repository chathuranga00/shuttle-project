// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_card.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StudentCard _$StudentCardFromJson(Map<String, dynamic> json) => StudentCard(
      cardId: json['cardId'] as String,
      cardStatus: json['cardStatus'] as String,
      monthlyPassStatus: json['monthlyPassStatus'] as String,
      wallet:
          WalletSummary.fromJson(json['wallet'] as Map<String, dynamic>),
      qrToken: json['qrToken'] as String,
    );

Map<String, dynamic> _$StudentCardToJson(StudentCard instance) =>
    <String, dynamic>{
      'cardId': instance.cardId,
      'cardStatus': instance.cardStatus,
      'monthlyPassStatus': instance.monthlyPassStatus,
      'wallet': instance.wallet.toJson(),
      'qrToken': instance.qrToken,
    };
