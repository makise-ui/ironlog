import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/tokens.dart';

class ThisWeekProgressBar extends StatelessWidget {
  const ThisWeekProgressBar({
    super.key,
    required this.completedWeekdays,
    required this.todayWeekday,
    this.workoutsCount = 0,
  });

  final Set<int> completedWeekdays; // 1 = Monday ... 7 = Sunday
  final int todayWeekday; // 1 = Monday ... 7 = Sunday
  final int workoutsCount;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: S.lg, vertical: S.md),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.hairline),
        boxShadow: context.isDark
            ? null
            : [
                const BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THIS WEEK',
                style: T.label.copyWith(color: C.text2),
              ),
              const SizedBox(height: 2),
              Text(
                '$workoutsCount / 5 days trained',
                style: T.body.copyWith(
                  fontSize: 12.5,
                  color: C.text1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(7, (index) {
              final weekday = index + 1;
              final isDone = completedWeekdays.contains(weekday);
              final isToday = weekday == todayWeekday;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _days[index],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                        color: isToday ? C.accent : C.text2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? C.positive
                            : (isToday ? C.accent.withValues(alpha: 0.25) : Colors.transparent),
                        border: Border.all(
                          color: isDone
                              ? C.positive
                              : (isToday ? C.accent : C.hairline),
                          width: isToday ? 1.5 : 1.0,
                        ),
                      ),
                      child: isDone
                          ? const Center(
                              child: Icon(
                                Icons.check_rounded,
                                size: 8,
                                color: Colors.black,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
