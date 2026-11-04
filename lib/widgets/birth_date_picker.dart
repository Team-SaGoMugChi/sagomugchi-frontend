import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'primary_button.dart';

/// 생년월일 선택 바텀시트 — 년·월·일을 돌려서 고른다. 고르면 그 날짜, 닫으면 null.
///
/// 기본 달력(showDatePicker)은 앱에 한국어 설정이 없어 영어로 나오고, 생년월일은
/// 달력을 몇십 년 넘겨야 해서 불편했다. 년·월·일 휠은 SDK의 CupertinoPicker로
/// 만들어 새 의존성이 없다.
Future<DateTime?> showBirthDatePicker(
  BuildContext context, {
  DateTime? initial,
}) {
  final now = DateTime.now();
  return showModalBottomSheet<DateTime>(
    context: context,
    // 기본 높이 제한(화면의 9/16)에 휠이 잘리지 않게 내용만큼 높인다.
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => _BirthDateSheet(
      initial: initial ?? DateTime(now.year - 20),
      firstYear: 1900,
      today: DateTime(now.year, now.month, now.day),
    ),
  );
}

class _BirthDateSheet extends StatefulWidget {
  const _BirthDateSheet({
    required this.initial,
    required this.firstYear,
    required this.today,
  });

  final DateTime initial;
  final int firstYear;
  final DateTime today;

  @override
  State<_BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends State<_BirthDateSheet> {
  static const double _itemExtent = 44;

  late int _year = widget.initial.year;
  late int _month = widget.initial.month;
  late int _day = widget.initial.day;

  late final _yearController = FixedExtentScrollController(
    initialItem: _year - widget.firstYear,
  );
  late final _monthController = FixedExtentScrollController(
    initialItem: _month - 1,
  );
  late final _dayController = FixedExtentScrollController(
    initialItem: _day - 1,
  );

  int get _lastYear => widget.today.year;

  /// 올해는 이번 달까지만 고를 수 있다(미래 생일 없음).
  int get _monthCount => _year == _lastYear ? widget.today.month : 12;

  int get _dayCount {
    final days = DateUtils.getDaysInMonth(_year, _month);
    if (_year == _lastYear && _month == widget.today.month) {
      return widget.today.day;
    }
    return days;
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  /// 년·월이 바뀌어 고른 월·일이 범위를 넘으면 마지막 값으로 당긴다(2월 30일 등).
  void _clamp() {
    if (_month > _monthCount) {
      _month = _monthCount;
      _monthController.jumpToItem(_month - 1);
    }
    if (_day > _dayCount) {
      _day = _dayCount;
      _dayController.jumpToItem(_day - 1);
    }
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int index) label,
    required ValueChanged<int> onSelected,
  }) {
    return Expanded(
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: _itemExtent,
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: (i) => setState(() {
          onSelected(i);
          _clamp();
        }),
        children: [
          for (var i = 0; i < count; i++)
            Center(child: Text(label(i), style: AppTypography.bodyLarge)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.lg,
          AppSpacing.screenH,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('생년월일을 선택해주세요', style: AppTypography.subtitle),
            Gap.h4,
            Text('$_year년 $_month월 $_day일', style: AppTypography.bodySecondary),
            Gap.h16,
            SizedBox(
              height: _itemExtent * 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 가운데 줄(고른 값) 표시.
                  Container(
                    height: _itemExtent,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: AppRadius.button,
                    ),
                  ),
                  Row(
                    children: [
                      _wheel(
                        controller: _yearController,
                        count: _lastYear - widget.firstYear + 1,
                        label: (i) => '${widget.firstYear + i}년',
                        onSelected: (i) => _year = widget.firstYear + i,
                      ),
                      _wheel(
                        controller: _monthController,
                        count: _monthCount,
                        label: (i) => '${i + 1}월',
                        onSelected: (i) => _month = i + 1,
                      ),
                      _wheel(
                        controller: _dayController,
                        count: _dayCount,
                        label: (i) => '${i + 1}일',
                        onSelected: (i) => _day = i + 1,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Gap.h16,
            PrimaryButton(
              label: '선택 완료',
              onPressed: () =>
                  Navigator.of(context).pop(DateTime(_year, _month, _day)),
            ),
          ],
        ),
      ),
    );
  }
}
