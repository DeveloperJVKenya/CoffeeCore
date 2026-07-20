import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scoped translation layer for the Community section only — a lightweight
/// EN/SW toggle stored in-memory (not persisted), independent of the rest
/// of the app, which has no i18n framework of its own yet. Adding a real
/// app-wide flutter_localizations + ARB setup is a bigger, one-time
/// architecture decision better made for the whole app at once; this is a
/// stopgap for the Community feature specifically, given its target
/// audience.
///
/// Covers the main navigational/instructional chrome (screen titles, empty
/// states, buttons, dialogs). Per-post data labels (category/crop/sort
/// names in community_enums.dart) and the deeper post/comment card widgets
/// stay English-only in this pass — retrofitting every widget down to that
/// level is a larger follow-up, not bundled here.
enum CommunityLocale { en, sw }

class CommunityLocaleNotifier extends Notifier<CommunityLocale> {
  @override
  CommunityLocale build() => CommunityLocale.en;

  void toggle() {
    state =
        state == CommunityLocale.en ? CommunityLocale.sw : CommunityLocale.en;
  }
}

final communityLocaleProvider =
    NotifierProvider<CommunityLocaleNotifier, CommunityLocale>(
        CommunityLocaleNotifier.new);

class CommunityStrings {
  const CommunityStrings(this.locale);

  final CommunityLocale locale;

  static CommunityStrings of(WidgetRef ref) =>
      CommunityStrings(ref.watch(communityLocaleProvider));

  String _t(String en, String sw) => locale == CommunityLocale.sw ? sw : en;

  String get communityTitle => _t('Community', 'Jumuiya');
  String get newPost => _t('New Post', 'Chapisho Jipya');
  String get post => _t('Post', 'Chapisha');
  String get noPostsYet => _t(
      'No posts yet — be the first to start a discussion.',
      'Hakuna machapisho bado — kuwa wa kwanza kuanzisha mazungumzo.');
  String get couldNotLoadFeed =>
      _t('Could not load the community feed.', 'Imeshindwa kupakia jumuiya.');
  String get retry => _t('Retry', 'Jaribu tena');
  String get directMessages => _t('Direct messages', 'Ujumbe wa faragha');
  String get notificationsTitle => _t('Notifications', 'Arifa');
  String get noNotificationsYet =>
      _t('No notifications yet.', 'Hakuna arifa bado.');
  String get couldNotLoadNotifications =>
      _t('Could not load notifications.', 'Imeshindwa kupakia arifa.');

  // Create post screen
  String get newPostTitle => _t('New Post', 'Chapisho Jipya');
  String get postTypeLabel => _t('Post type', 'Aina ya chapisho');
  String get discussion => _t('Discussion', 'Mazungumzo');
  String get question => _t('Question', 'Swali');
  String get titleLabel => _t('Title', 'Kichwa');
  String get descriptionLabel => _t('Description', 'Maelezo');
  String get categoryLabel => _t('Category', 'Kategoria');
  String get cropOptionalLabel => _t('Crop (optional)', 'Zao (si lazima)');
  String get photosOptionalLabel =>
      _t('Photos (optional)', 'Picha (si lazima)');
  String get titleRequired =>
      _t('Give your post a title.', 'Andika kichwa cha chapisho lako.');
  String get titleTooShort => _t(
      'A little more detail helps — at least 6 characters.',
      'Maelezo zaidi husaidia — angalau herufi 6.');
  String get descriptionRequired => _t('Add a description.', 'Ongeza maelezo.');
  String get descriptionTooShort => _t(
      'A bit more context will help others respond.',
      'Maelezo zaidi yatasaidia wengine kujibu.');

  // Post detail screen
  String get discussionAppBarTitle => _t('Discussion', 'Mazungumzo');
  String get acceptedSolution => _t('Accepted Solution', 'Jibu Lililokubalika');
  String get answers => _t('Answers', 'Majibu');
  String get comments => _t('Comments', 'Maoni');
  String get shareYourInput => _t('Share your input...', 'Toa maoni yako...');
  String get replyingTo => _t('Replying to', 'Unajibu');
  String get couldNotPostComment => _t(
      'Could not post your comment — try again.',
      'Imeshindwa kutuma maoni — jaribu tena.');
  String get couldNotVote => _t('Could not register your vote — try again.',
      'Imeshindwa kupiga kura — jaribu tena.');
  String get couldNotAccept => _t('Could not accept this solution — try again.',
      'Imeshindwa kukubali jibu hili — jaribu tena.');
  String get couldNotLoadPost =>
      _t('Could not load this post.', 'Imeshindwa kupakia chapisho hili.');

  // Delete / report
  String get deletePostTitle => _t('Delete this post?', 'Futa chapisho hili?');
  String get deleteCommentTitle =>
      _t('Delete this comment?', 'Futa maoni haya?');
  String get deleteConfirmBody =>
      _t('This cannot be undone.', 'Hatua hii haiwezi kutenduliwa.');
  String get cancel => _t('Cancel', 'Ghairi');
  String get delete => _t('Delete', 'Futa');
  String get reportContentTitle =>
      _t('Report this content', 'Ripoti maudhui haya');
  String get reportSubmittedPost => _t('Thanks — this post has been reported.',
      'Asante — chapisho hili limeripotiwa.');
  String get reportSubmittedComment => _t(
      'Thanks — this comment has been reported.',
      'Asante — maoni haya yameripotiwa.');
  String get couldNotDeletePost => _t('Could not delete post — try again.',
      'Imeshindwa kufuta chapisho — jaribu tena.');
  String get couldNotDeleteComment => _t(
      'Could not delete comment — try again.',
      'Imeshindwa kufuta maoni — jaribu tena.');
  String get couldNotSubmitReport => _t('Could not submit report — try again.',
      'Imeshindwa kutuma ripoti — jaribu tena.');
}
