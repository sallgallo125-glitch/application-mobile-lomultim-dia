import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/errors.dart';
import '../../api/repositories/member_repositories.dart';
import '../../contracts/content.dart';
import '../../contracts/gift_card.dart';
import '../../contracts/loyalty.dart';
import '../account/account_providers.dart';
import '../home/home_providers.dart';

final loyaltyRepositoryProvider =
    Provider((ref) => LoyaltyRepository(ref.watch(apiClientProvider)));
final giftCardRepositoryProvider =
    Provider((ref) => GiftCardRepository(ref.watch(apiClientProvider)));
final contentRepositoryProvider =
    Provider((ref) => ContentRepository(ref.watch(apiClientProvider)));

// LO+
final loyaltyMemberProvider = FutureProvider<LoyaltyMember>(
    (ref) => ref.watch(loyaltyRepositoryProvider).getMember());

/// "Utiliser mes points" switched on in the cart: the checkout then starts
/// with the most points the order allows (whole blocks of 100).
final usePointsFromCartProvider = StateProvider<bool>((ref) => false);
final loyaltyMovementsProvider = FutureProvider<List<LoyaltyMovement>>(
    (ref) => ref.watch(loyaltyRepositoryProvider).listMovements());
final loyaltyRewardsProvider = FutureProvider<List<LoyaltyReward>>(
    (ref) => ref.watch(loyaltyRepositoryProvider).listRewards());
final loyaltyReferralsProvider = FutureProvider<LoyaltyReferrals>(
    (ref) => ref.watch(loyaltyRepositoryProvider).getReferrals());
final loyaltyChallengesProvider = FutureProvider<LoyaltyChallenges>(
    (ref) => ref.watch(loyaltyRepositoryProvider).getChallenges());

/// Everything that shows a points balance must refresh after it changes.
void invalidatePoints(Ref ref) {
  ref.invalidate(loyaltyMemberProvider);
  ref.invalidate(loyaltyMovementsProvider);
  ref.invalidate(loyaltyChallengesProvider);
  ref.invalidate(accountSummaryProvider);
}

class LoyaltyActions {
  LoyaltyActions(this.ref);
  final Ref ref;
  Future<LoyaltyVoucher> convert(String rewardId, {int? points}) async {
    final voucher = await ref
        .read(loyaltyRepositoryProvider)
        .convert(rewardId, points: points);
    invalidatePoints(ref);
    return voucher;
  }
}

final loyaltyActionsProvider = Provider((ref) => LoyaltyActions(ref));

// Gift cards
final myGiftCardsProvider = FutureProvider<List<GiftCard>>(
    (ref) => ref.watch(giftCardRepositoryProvider).listMine());

class GiftCardActions {
  GiftCardActions(this.ref);
  final Ref ref;
  Future<GiftCard> buy(
      {required int amountXof,
      required GiftCardDelivery delivery,
      required String recipientName,
      String? message}) async {
    final card = await ref.read(giftCardRepositoryProvider).buy(
        amountXof: amountXof,
        delivery: delivery,
        recipientName: recipientName,
        message: message);
    ref.invalidate(myGiftCardsProvider);
    return card;
  }

  Future<void> setSuspended(String id, bool suspended) async {
    await ref.read(giftCardRepositoryProvider).setSuspended(id, suspended);
    ref.invalidate(myGiftCardsProvider);
  }
}

final giftCardActionsProvider = Provider((ref) => GiftCardActions(ref));

// Content
final faqsProvider = FutureProvider<List<Faq>>(
    (ref) => ref.watch(contentRepositoryProvider).listFaqs());
final legalDocumentsProvider = FutureProvider<List<LegalDocument>>(
    (ref) => ref.watch(contentRepositoryProvider).listLegal());
final legalDocumentProvider = FutureProvider.family<LegalDocument, String>(
    (ref, slug) => ref.watch(contentRepositoryProvider).getLegal(slug));

/// User-facing text for a failed call: the server's message when it gave one.
String errorMessage(Object error, String fallback) =>
    error is ApiHttpError && error.message != null ? error.message! : fallback;
