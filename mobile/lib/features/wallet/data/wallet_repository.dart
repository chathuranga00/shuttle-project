import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_client.dart';
import 'models/payment_history_item.dart';
import 'models/payment_status_response.dart';
import 'models/top_up_response.dart';
import 'models/transaction_item.dart';
import 'models/wallet_response.dart';

class WalletRepository {
  WalletRepository(this._dio);
  final Dio _dio;

  Future<WalletResponse> getWallet() async {
    try {
      final r = await _dio.get('/api/wallet');
      return WalletResponse.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  Future<List<TransactionItem>> getTransactions() async {
    try {
      final r = await _dio.get('/api/wallet/transactions');
      return (r.data as List)
          .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  /// Initiates a top-up. Returns checkout URL — never credits wallet directly.
  Future<TopUpResponse> topUp(double amount) async {
    try {
      final r = await _dio.post('/api/wallet/top-up',
          data: {'amount': amount});
      return TopUpResponse.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  /// Polls the server for payment status after returning from checkout.
  /// The app must NOT mark a payment successful based solely on this call —
  /// the webhook has to have fired first.
  Future<PaymentStatusResponse> pollPaymentStatus(int paymentId) async {
    try {
      final r = await _dio.get('/api/payment/status/$paymentId');
      return PaymentStatusResponse.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }

  Future<List<PaymentHistoryItem>> getPaymentHistory() async {
    try {
      final r = await _dio.get('/api/students/me/payments');
      return (r.data as List)
          .map((e) => PaymentHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException
          : ApiException(message: ApiException.friendlyMessage(null));
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(dioClientProvider));
});
