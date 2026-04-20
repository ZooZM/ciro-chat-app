import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PHONE NUMBER FORMATTER  ── formats digits as '### ### ###' while typing
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip everything except digits
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Apply the '### ### ###' mask (max 10 digits to match maxLength)
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 10; i++) {
      if (i == 3 || i == 6) buffer.write(' ');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM COUNTRY PICKER BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

void showCiroCountryPicker({
  required BuildContext context,
  required Country selected,
  required void Function(Country) onSelect,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CiroCountrySheet(selected: selected, onSelect: onSelect),
  );
}

class _CiroCountrySheet extends StatefulWidget {
  final Country selected;
  final void Function(Country) onSelect;
  const _CiroCountrySheet({required this.selected, required this.onSelect});

  @override
  State<_CiroCountrySheet> createState() => _CiroCountrySheetState();
}

class _CiroCountrySheetState extends State<_CiroCountrySheet> {
  late List<Country> _all;
  late List<Country> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _all = CountryService().getAll();
    _filtered = List.from(_all);
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_all)
          : _all
                .where(
                  (c) =>
                      c.name.toLowerCase().contains(q) ||
                      c.phoneCode.contains(q),
                )
                .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_filter)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.82;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10.resH),
            child: Container(
              width: 36.resW,
              height: 4.resH,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.resW,
              vertical: 4.resH,
            ),
            child: Container(
              height: 46.resH,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12.resR),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: AppTypography.body1.copyWith(color: Colors.black87),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: 'Search country',
                  hintStyle: AppTypography.body2.copyWith(
                    color: Colors.grey[400],
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[400],
                    size: 20.resW,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 13.resH),
                ),
              ),
            ),
          ),

          SizedBox(height: 4.resH),

          // Country list — no dividers, generous padding
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 8.resW),
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final c = _filtered[i];
                final isSelected = c.countryCode == widget.selected.countryCode;

                return InkWell(
                  onTap: () {
                    widget.onSelect(c);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(8.resR),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.resW,
                      vertical: 14.resH,
                    ),
                    decoration: isSelected
                        ? BoxDecoration(
                            color: AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8.resR),
                          )
                        : null,
                    child: Row(
                      children: [
                        // Flag
                        Text(c.flagEmoji, style: TextStyle(fontSize: 26.resSp)),
                        SizedBox(width: 16.resW),
                        // Country name
                        Expanded(
                          child: Text(
                            c.name,
                            style: AppTypography.body1.copyWith(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Dial code — right aligned, muted
                        Text(
                          '+${c.phoneCode}',
                          style: AppTypography.body2.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 8.resH),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CIRO PHONE FIELD — Green-outlined button + pill input
// ─────────────────────────────────────────────────────────────────────────────

class CiroPhoneField extends StatefulWidget {
  final void Function(String fullNumber) onChanged;
  final String? Function(String?)? validator;
  final Country? initialCountry;

  const CiroPhoneField({
    Key? key,
    required this.onChanged,
    this.validator,
    this.initialCountry,
  }) : super(key: key);

  @override
  State<CiroPhoneField> createState() => _CiroPhoneFieldState();
}

class _CiroPhoneFieldState extends State<CiroPhoneField> {
  late Country _country;
  final _ctrl = TextEditingController();

  static Country get _defaultCountry =>
      CountryService().findByCode('EG') ?? CountryService().getAll().first;

  @override
  void initState() {
    super.initState();
    _country = widget.initialCountry ?? _defaultCountry;
    _ctrl.addListener(_notify);
  }

  void _notify() {
    // Strip spaces before sending to backend — e.g. '123 456 890' → '1234567890'
    final clean = _ctrl.text.replaceAll(' ', '');
    widget.onChanged('+${_country.phoneCode}$clean');
  }

  @override
  void dispose() {
    _ctrl
      ..removeListener(_notify)
      ..dispose();
    super.dispose();
  }

  // Shared between button and field for visual consistency
  static const _radius = BorderRadius.all(Radius.circular(30));
  static const _borderSide = BorderSide(color: AppColors.primary, width: 1.6);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start, // align to top so counter sits below field
      children: [
        // ── Country Code Button ─────────────────────────────────────────────
        GestureDetector(
          onTap: () => showCiroCountryPicker(
            context: context,
            selected: _country,
            onSelect: (c) => setState(() {
              _country = c;
              _notify();
            }),
          ),
          child: Container(
            height: 52.resH,
            padding: EdgeInsets.symmetric(horizontal: 12.resW),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _radius,
              border: Border.all(color: AppColors.primary, width: 1.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_country.flagEmoji, style: TextStyle(fontSize: 22.resSp)),
                SizedBox(width: 6.resW),
                Text(
                  '+${_country.phoneCode}',
                  style: AppTypography.body1.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4.resW),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.black54,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        SizedBox(width: 12.resW),

        // ── Phone Number Input (with live digit counter) ────────────────────
        Expanded(
          child: TextFormField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [_PhoneNumberFormatter()],
            // Custom counter: counts only digits, ignores the inserted spaces
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) {
                  final digitCount = _ctrl.text.replaceAll(' ', '').length;
                  return Text(
                    '$digitCount / 10',
                    style: AppTypography.caption.copyWith(
                      color: digitCount == 10
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  );
                },
            style: AppTypography.body1.copyWith(color: Colors.black87),
            cursorColor: AppColors.primary,
            validator: widget.validator,
            decoration: InputDecoration(
              hintText: '123 456 890',
              hintStyle: AppTypography.body1.copyWith(
                color: AppColors.primary.withOpacity(0.35),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.resW,
                vertical: 14.resH,
              ),
              border: const OutlineInputBorder(
                borderRadius: _radius,
                borderSide: _borderSide,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: _radius,
                borderSide: _borderSide,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: _radius,
                borderSide: _borderSide.copyWith(width: 2.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: _radius,
                borderSide: BorderSide(color: AppColors.error, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: _radius,
                borderSide: BorderSide(color: AppColors.error, width: 2.0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
