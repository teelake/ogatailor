class PlanTier {
  const PlanTier({
    required this.planCode,
    required this.displayName,
    this.customerLimit,
    required this.customerLimitLabel,
    this.invoicesPerMonth,
    required this.priceNgn,
    required this.features,
  });

  final String planCode;
  final String displayName;
  final int? customerLimit;
  final String customerLimitLabel;
  final int? invoicesPerMonth;
  final int priceNgn;
  final List<String> features;

  bool get isFree => priceNgn <= 0;
  bool get isUpgrade => planCode == 'growth' || planCode == 'pro';
}
