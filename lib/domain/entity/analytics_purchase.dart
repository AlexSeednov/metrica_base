/// Order contents for the E-commerce reports.
///
/// One object for the checkout start and the purchase: the funnel steps link
/// up only when both carry identical contents.
final class AnalyticsPurchase {
  ///
  const AnalyticsPurchase({
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.category,
    required this.totalAmount,
    required this.quantity,
    required this.isFree,
    required this.currency,
    this.paymentId,
  });

  /// Links the checkout start to the purchase in the funnel. Not the backend
  /// payment id: that one appears only after a successful payment.
  final String orderId;

  ///
  final int productId;

  ///
  final String productName;

  /// Stable key of the product type, not a localized name: the report
  /// breakdowns would split by language.
  final String category;

  /// For all of [quantity], not per unit.
  final double totalAmount;

  ///
  final int quantity;

  ///
  final bool isFree;

  /// ISO 4217 code of the amounts, e.g. `RUB`.
  final String currency;

  /// Backend payment id; known only after the payment, see [withPayment].
  final int? paymentId;

  /// Price of one unit, which E-commerce reports take apart from the total.
  /// A quantity below two counts as one.
  double get unitAmount => quantity > 1 ? totalAmount / quantity : totalAmount;

  /// The same order with the settled payment's id. [orderId] stays, so the
  /// purchase links to the checkout start.
  AnalyticsPurchase withPayment(int? paymentId) => AnalyticsPurchase(
    orderId: orderId,
    productId: productId,
    productName: productName,
    category: category,
    totalAmount: totalAmount,
    quantity: quantity,
    isFree: isFree,
    currency: currency,
    paymentId: paymentId,
  );
}
