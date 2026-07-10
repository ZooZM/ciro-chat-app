import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

enum PaymentType { chipIn, invoice, pos }
enum PaymentStatus { unpaid, paid, dueSoon, rejected }

class PaymentHistoryItem {
  final String dateGroup;
  final PaymentType type;
  final PaymentStatus status;
  final String title;
  final String subtitle;

  PaymentHistoryItem({
    required this.dateGroup,
    required this.type,
    required this.status,
    required this.title,
    required this.subtitle,
  });
}

class PaymentsHistoryScreen extends StatefulWidget {
  const PaymentsHistoryScreen({super.key});

  @override
  State<PaymentsHistoryScreen> createState() => _PaymentsHistoryScreenState();
}

class _PaymentsHistoryScreenState extends State<PaymentsHistoryScreen> {
  PaymentType? _selectedTypeFilter;
  PaymentStatus? _selectedStatusFilter;

  // Mock data matching the mockup exactly
  late final List<PaymentHistoryItem> _allPayments = [
    PaymentHistoryItem(
      dateGroup: 'payments_today'.tr(),
      type: PaymentType.chipIn,
      status: PaymentStatus.unpaid,
      title: 'Unpaid Chip-in',
      subtitle: 'Dinner at Bella Italia',
    ),
    PaymentHistoryItem(
      dateGroup: 'May 23,2024',
      type: PaymentType.invoice,
      status: PaymentStatus.paid,
      title: 'Invoice Paid',
      subtitle: '#INV-2024-000123',
    ),
    PaymentHistoryItem(
      dateGroup: 'May 1,2024',
      type: PaymentType.invoice,
      status: PaymentStatus.dueSoon,
      title: 'Due soon',
      subtitle: '#INV-2024-000123',
    ),
    PaymentHistoryItem(
      dateGroup: 'May 1,2024',
      type: PaymentType.pos,
      status: PaymentStatus.paid,
      title: 'POS Paid',
      subtitle: '#INV-2024-000123',
    ),
    PaymentHistoryItem(
      dateGroup: 'Feb 23,2024',
      type: PaymentType.invoice,
      status: PaymentStatus.unpaid,
      title: 'Unpaid Invoice',
      subtitle: '#INV-2024-000123',
    ),
    PaymentHistoryItem(
      dateGroup: 'Jan 23,2024',
      type: PaymentType.chipIn,
      status: PaymentStatus.paid,
      title: 'Chip-in Paid',
      subtitle: 'Dinner at Bella Italia',
    ),
    PaymentHistoryItem(
      dateGroup: 'Jan 23,2024',
      type: PaymentType.pos,
      status: PaymentStatus.rejected,
      title: 'POS Rejected',
      subtitle: '#INV-2024-000123',
    ),
  ];

  void _showFilterSideSheet() {
    // Current selections for the side sheet
    PaymentType? tempType = _selectedTypeFilter;
    PaymentStatus? tempStatus = _selectedStatusFilter;
    final isRtl = context.locale.languageCode == 'ar';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Filter',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(isRtl ? 0 : 24),
              right: Radius.circular(isRtl ? 24 : 0),
            ),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              height: double.infinity,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'payments_filter_title'.tr(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.black54),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Filter Content Container
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildFilterGroup<PaymentType>(
                                    title: 'payments_filter_type'.tr(),
                                    options: [
                                      {'label': 'payments_filter_all'.tr(), 'value': null},
                                      {'label': 'payments_filter_chip_in'.tr(), 'value': PaymentType.chipIn},
                                      {'label': 'payments_filter_invoice'.tr(), 'value': PaymentType.invoice},
                                      {'label': 'payments_filter_pos'.tr(), 'value': PaymentType.pos},
                                    ],
                                    groupValue: tempType,
                                    onChanged: (val) => setState(() => tempType = val),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFilterGroup<PaymentStatus>(
                                    title: 'payments_filter_status'.tr(),
                                    options: [
                                      {'label': 'payments_filter_all'.tr(), 'value': null},
                                      {'label': 'payments_filter_unpaid'.tr(), 'value': PaymentStatus.unpaid},
                                      {'label': 'payments_filter_due_soon'.tr(), 'value': PaymentStatus.dueSoon},
                                      {'label': 'payments_filter_paid'.tr(), 'value': PaymentStatus.paid},
                                      {'label': 'payments_filter_rejected'.tr(), 'value': PaymentStatus.rejected},
                                    ],
                                    groupValue: tempStatus,
                                    onChanged: (val) => setState(() => tempStatus = val),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      tempType = null;
                                      tempStatus = null;
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    'payments_filter_reset'.tr(),
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    this.setState(() {
                                      _selectedTypeFilter = tempType;
                                      _selectedStatusFilter = tempStatus;
                                    });
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4CA440),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    'payments_filter_apply'.tr(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slideOffset = isRtl ? const Offset(-1, 0) : const Offset(1, 0);
        return SlideTransition(
          position: Tween<Offset>(begin: slideOffset, end: Offset.zero).animate(animation),
          child: child,
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String title,
    required dynamic value,
    required dynamic groupValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    final isSelected = value == groupValue;
    return ChoiceChip(
      label: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onChanged(value);
        }
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: const Color(0xFF4CA440),
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildFilterGroup<T>({
    required String title,
    required List<Map<String, dynamic>> options,
    required T? groupValue,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFC), // Light grey matching design
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          ...options.map((option) {
            final String label = option['label'] as String;
            final T? value = option['value'] as T?;
            final bool isSelected = value == groupValue;

            return InkWell(
              onTap: () => onChanged(value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? const Color(0xFF4CA440) : Colors.grey.shade400,
                      size: 22,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.locale;
    final isRtl = context.locale.languageCode == 'ar';

    final filteredList = _allPayments.where((payment) {
      if (_selectedTypeFilter != null && payment.type != _selectedTypeFilter) return false;
      if (_selectedStatusFilter != null && payment.status != _selectedStatusFilter) return false;
      return true;
    }).toList();

    // Grouping
    final groupedPayments = <String, List<PaymentHistoryItem>>{};
    for (var item in filteredList) {
      groupedPayments.putIfAbsent(item.dateGroup, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'payments_history_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: Icon(isRtl ? Icons.arrow_forward : Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.black87, size: 20),
              onPressed: () {},
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, color: Colors.black87, size: 20),
              onPressed: _showFilterSideSheet,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
      body: groupedPayments.isEmpty
          ? Center(
              child: Text(
                'No payments found.',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: groupedPayments.length,
              itemBuilder: (context, index) {
                final dateGroup = groupedPayments.keys.elementAt(index);
                final items = groupedPayments[dateGroup]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 12, top: index == 0 ? 0 : 16),
                      child: Text(
                        dateGroup,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    ...items.map((item) => _buildPaymentCard(item)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildPaymentCard(PaymentHistoryItem item) {
    Color bgColor;
    Color textColor;
    Widget leadingIcon;
    Widget? trailing;

    if (item.status == PaymentStatus.unpaid || item.status == PaymentStatus.rejected) {
      bgColor = const Color(0xFFFFF0F0);
      textColor = const Color(0xFFE53935);
      
      if (item.type == PaymentType.pos && item.status == PaymentStatus.rejected) {
        leadingIcon = const Icon(Icons.point_of_sale, color: Color(0xFFE53935), size: 24);
      } else {
        leadingIcon = const Icon(Icons.assignment_late_outlined, color: Color(0xFFE53935), size: 24);
      }

      if (item.status == PaymentStatus.unpaid) {
        trailing = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE53935),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'payments_pay_now'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
    } else if (item.status == PaymentStatus.paid) {
      bgColor = const Color(0xFFF0FFF0); // Light Green
      textColor = const Color(0xFF4CA440);
      leadingIcon = Container(
        decoration: const BoxDecoration(
          color: Color(0xFF4CA440),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(2),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
      trailing = const Icon(Icons.check, color: Color(0xFF4CA440));
    } else { // dueSoon
      bgColor = const Color(0xFFFFF6E5); // Light Orange
      textColor = const Color(0xFFFFA000);
      leadingIcon = const Icon(Icons.assignment_late_outlined, color: Color(0xFFFFA000), size: 24); // Ideally clock, but this looks close. Let's use history or assignment with clock.
      
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFA000),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'payments_pay_now'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          leadingIcon,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 16),
            trailing,
          ]
        ],
      ),
    );
  }
}
