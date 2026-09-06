/// Order contents for the E-commerce reports of analytics.
///
/// One object, because the checkout start and the completed purchase have to
/// go out with identical contents — otherwise the steps of the funnel do not
/// link up.
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

  /// Order identifier shared by the checkout start and the purchase — this is
  /// what analytics links the funnel steps by. The server-side payment
  /// identifier would not do: it appears only after a successful payment.
  final String orderId;

  ///
  final int productId;

  ///
  final String productName;

  /// Stable key of the product type — not a localized string, otherwise the
  /// report breakdowns scatter across languages
  final String category;

  /// Total order amount, [quantity] included
  final double totalAmount;

  ///
  final int quantity;

  ///
  final bool isFree;

  /// ISO 4217 currency code of the amounts (`RUB`, say)
  final String currency;

  /// Payment identifier on the backend — known only after the payment
  final int? paymentId;

  /// Unit price: the order keeps it apart from the total
  double get unitAmount => quantity > 1 ? totalAmount / quantity : totalAmount;

  /// Complete the order with the identifier of the settled payment, keeping
  /// [orderId] — otherwise the purchase would not link to the checkout start
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
