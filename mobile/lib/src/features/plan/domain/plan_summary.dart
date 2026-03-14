class PlanSummary {
  const PlanSummary({
    required this.planCode,
    required this.customerCount,
    this.customerLimit,
    this.invoicesUsedThisMonth = 0,
    this.invoicesPerMonth,
  });

  final String planCode;
  final int customerCount;
  final int? customerLimit;
  final int invoicesUsedThisMonth;
  final int? invoicesPerMonth;

  bool get hasInvoiceLimit => invoicesPerMonth != null && invoicesPerMonth! > 0;
  bool get isAtInvoiceLimit =>
      hasInvoiceLimit && invoicesUsedThisMonth >= invoicesPerMonth!;
  bool get isNearInvoiceLimit =>
      hasInvoiceLimit &&
      invoicesPerMonth! > 0 &&
      invoicesUsedThisMonth >= (invoicesPerMonth! * 0.8).floor();

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
