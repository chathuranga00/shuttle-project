import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/payment_history_item.dart';
import '../../data/models/transaction_item.dart';
import '../../data/models/wallet_response.dart';
import '../../data/wallet_repository.dart';

final walletProvider = FutureProvider<WalletResponse>((ref) {
  return ref.watch(walletRepositoryProvider).getWallet();
});

final walletTransactionsProvider =
    FutureProvider<List<TransactionItem>>((ref) {
  return ref.watch(walletRepositoryProvider).getTransactions();
});

final paymentHistoryProvider =
    FutureProvider<List<PaymentHistoryItem>>((ref) {
  return ref.watch(walletRepositoryProvider).getPaymentHistory();
});
