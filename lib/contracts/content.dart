/// Info pages and order tracking, mirroring DevA -final/src/domains/content
/// and the delivery tracking route.
library;

class Faq {
  const Faq(
      {required this.id,
      required this.category,
      required this.question,
      required this.answer});
  final String id;
  final String category;
  final String question;
  final String answer;
  factory Faq.fromJson(Map<String, dynamic> json) => Faq(
      id: json['id'] as String,
      category: json['category'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String);
}

class LegalDocument {
  const LegalDocument(
      {required this.slug,
      required this.title,
      required this.updatedAt,
      required this.bodyHtml});
  final String slug;
  final String title;
  final String updatedAt;

  /// Small HTML subset (h2, p, ul/li, table, b, div.encart), same as the site.
  final String bodyHtml;
  factory LegalDocument.fromJson(Map<String, dynamic> json) => LegalDocument(
      slug: json['slug'] as String,
      title: json['title'] as String,
      updatedAt: json['updatedAt'] as String,
      bodyHtml: json['bodyHtml'] as String? ?? '');
}

class TrackingStep {
  const TrackingStep(
      {required this.code,
      required this.label,
      required this.detail,
      required this.reached,
      this.at});
  final String code;
  final String label;
  final String detail;
  final bool reached;
  final String? at;
  factory TrackingStep.fromJson(Map<String, dynamic> json) => TrackingStep(
      code: json['code'] as String,
      label: json['label'] as String,
      detail: json['detail'] as String,
      reached: json['reached'] as bool,
      at: json['at'] as String?);
}

class OrderTracking {
  const OrderTracking(
      {required this.orderNumber, required this.status, required this.steps});
  final String orderNumber;
  final String status;
  final List<TrackingStep> steps;
  factory OrderTracking.fromJson(Map<String, dynamic> json) => OrderTracking(
      orderNumber: json['orderNumber'] as String,
      status: json['status'] as String,
      steps: (json['steps'] as List<dynamic>)
          .map((s) => TrackingStep.fromJson(s as Map<String, dynamic>))
          .toList());
}
