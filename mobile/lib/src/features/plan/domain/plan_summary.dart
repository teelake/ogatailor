class PlanSummary {
  const PlanSummary({
    required this.planCode,
    required this.customerCount,
    this.customerLimit,
  });

  final String planCode;
  final int customerCount;
  final int? customerLimit;

  bool get isFree => planCode == 'free';
}
