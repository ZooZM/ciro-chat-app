import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../entities/wallet_entities.dart';
import '../wallet_mock_data.dart';
import '../widgets/wallet_balance_card.dart';
import '../widgets/wallet_quick_action_button.dart';
import '../widgets/wallet_transaction_tile.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  late WalletBalance _currentBalance;

  @override
  void initState() {
    super.initState();
    _currentBalance = WalletMockData.balance;
  }

  void _toggleBalanceVisibility() {
    setState(() {
      _currentBalance = WalletBalance(
        totalBalance: _currentBalance.totalBalance,
        currentBalance: _currentBalance.currentBalance,
        currency: _currentBalance.currency,
        isVisible: !_currentBalance.isVisible,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(context),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GestureDetector(
                  onTap: () {
                    const result = PaymentResult(
                      status: PaymentResultStatus.success,
                      amount: 150.0,
                      currency: 'SAR',
                      recipientName: 'Ahmed',
                      referenceId: 'CIRO-938475',
                    );
                    context.push(AppRouterName.walletPaymentStatus, extra: result);
                  },
                  child: WalletBalanceCard(
                    balance: _currentBalance,
                    onToggleVisibility: _toggleBalanceVisibility,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    WalletQuickActionButton(
                      label: 'wallet.addMoney'.tr(),
                      icon: Icons.add_circle,
                      onTap: () => context.push(AppRouterName.walletAddAmount),
                    ),
                    WalletQuickActionButton(
                      label: 'wallet.send'.tr(),
                      icon: Icons.arrow_upward,
                      onTap: () => context.push(AppRouterName.walletSend),
                    ),
                    WalletQuickActionButton(
                      label: 'wallet.receive'.tr(),
                      icon: Icons.arrow_downward,
                      onTap: () => context.push(AppRouterName.walletReceive),
                    ),
                    WalletQuickActionButton(
                      label: 'wallet.qrCode'.tr(),
                      icon: Icons.qr_code,
                      onTap: () => context.push(AppRouterName.walletReceive),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'wallet.recentTransactions'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'wallet.viewAll'.tr(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: WalletMockData.recentTransactions.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF0F0F0),
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final transaction = WalletMockData.recentTransactions[index];
                      return WalletTransactionTile(transaction: transaction);
                    },
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100), // padding for FAB
            )
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        elevation: 6,
        shape: const CircleBorder(),
        onPressed: () {
          context.push(AppRouterName.walletScanner);
        },
        child: const Icon(
          Icons.document_scanner_outlined,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = WalletMockData.currentUser;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
              onPressed: () => context.pop(),
              padding: EdgeInsets.zero,
              alignment: AlignmentDirectional.centerStart,
            ),
          ),
          Image.asset(
            'assets/bd563dcd9d7f8c94622a4f349454f5162e5b8a79.png',
            width: 180,
            height: 90,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Text(
              'ciro WALLET',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => context.push(AppRouterName.walletNotifications),
                  icon: const Icon(Icons.notifications_none, color: Color(0xFF1A1A1A)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => context.push(AppRouterName.walletProfile),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: user.avatarUrl != null
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? Text(
                            user.displayName.substring(0, 1),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
