import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/subscription_expiry/subscription_expiration_info.dart';

/// The one access decision used by the Android UI and connection flow.
/// It is derived from the last successfully downloaded server profile only;
/// notification/cache data is deliberately not an authority for access.
enum SubscriptionAccessState { active, expired, unknown }

SubscriptionAccessState subscriptionAccessState(ProfileEntity? profile) {
  if (profile is! RemoteProfileEntity) return SubscriptionAccessState.unknown;

  // Providers that have ended access commonly replace profile-title with this
  // explicit server metadata even when their traffic header was cached by an
  // intermediary. Never let a positive old counter override it.
  final title = profile.name.trim().toLowerCase();
  if (RegExp(r'оплатите\s+доступ|подписка\s+истекла|срок\s+подписки\s+ист[её]к').hasMatch(title)) {
    return SubscriptionAccessState.expired;
  }

  final expiry = SubscriptionExpirationInfo.fromProfile(profile)?.expiresAt;
  if (expiry == null) return SubscriptionAccessState.unknown;
  return expiry.isAfter(DateTime.now()) ? SubscriptionAccessState.active : SubscriptionAccessState.expired;
}

bool subscriptionBlocksConnection(ProfileEntity? profile) =>
    subscriptionAccessState(profile) == SubscriptionAccessState.expired;
