class PlanSummary {
  const PlanSummary({
    required this.planCode,
    required this.customerCount,
    this.customerLimit,
  });

  final String planCode;
  final int customerCount;
  final int? customerLimit;

  bool get isStarter => planCode == 'starter';
  bool get isGrowth => planCode == 'growth';
  bool get isPro => planCode == 'pro';
  bool get hasPremiumAccess => isGrowth || isPro;

  String get displayName {
    if (isGrowth) return 'Growth';
    if (isPro) return 'Pro';
    return 'Starter';
  }
}
