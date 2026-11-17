import '../localization/app_translations.dart';

abstract final class AppString {
  static String _currentLocale = 'en';

  static void setLocale(String code) {
    _currentLocale = code.toLowerCase().trim();
  }

  static String get currentLocale => _currentLocale;

  static String _tr(String key, String fallback) {
    return AppTranslations.get(_currentLocale, key, fallback);
  }

  /// Like [_tr], but also fills placeholders in the translated text.
  ///
  /// Translations are stored as plain text, e.g. "{total} people liked you".
  /// Each entry in [params] replaces `{name}`, `{{name}}` and the positional
  /// `{0}`, `{1}`... (in map order). The English fallbacks are already
  /// interpolated by Dart, so they pass through unchanged.
  static String _trp(String key, String fallback, Map<String, Object?> params) {
    var text = _tr(key, fallback);
    var index = 0;
    params.forEach((name, value) {
      final v = '${value ?? ''}';
      text = text
          .replaceAll('{{$name}}', v)
          .replaceAll('{$name}', v)
          .replaceAll('{$index}', v);
      index++;
    });
    return text;
  }

  // ---------- LOCALIZATION ----------
  static String get language => _tr('language', 'Language');
  static String get selectLanguage => _tr('selectLanguage', 'Select Language');

  static String get exploreCountLoading =>
      _tr('exploreCountLoading', 'Finding your people…');
  static String get exploreCountNone =>
      _tr('exploreCountNone', 'Nobody here yet');
  static String get exploreCountOne =>
      _tr('exploreCountOne', '1 person vibing');

  static String exploreCountMany(int count) =>
      _trp('exploreCountMany', '{count} people vibing', {'count': count});

  /// Label for the "people vibing" pill.
  static String exploreCount(int count) => switch (count) {
    0 => exploreCountNone,
    1 => exploreCountOne,
    _ => exploreCountMany(count),
  };

  // ---------- COMMON ----------
  static String get signUp => _tr('signUp', "Sign Up");
  static String get send => _tr('send', "Send");
  static String get shareApp => _tr('shareApp', "Share App");
  static String get cancel => _tr('cancel', "Cancel");
  static String get continueText => _tr('continueText', "Continue");
  static String get skip => _tr('skip', "Skip");
  static String get retry => _tr('retry', "Retry");
  static String get signOutText => _tr('signOutText', "Sign out");
  static String get welcomeUser => _tr('welcomeUser', "Welcome, User");
  static String get description => _tr('description', "Description");
  static String get signUpSubHeading => _tr('signUpSubHeading', "Create your account to continue");
  static String get reason => _tr('reason', "Reason");
  static String get userName => _tr('userName', "Username");
  static String get createUserName => _tr('createUserName', "Create Username");
  static String get reasonForDeletion => _tr('reasonForDeletion', "Reason for Deletion");
  static String get fullName => _tr('fullName', "Full Name");
  static String get enterFullName => _tr('enterFullName', "Enter Your Full Name");
  static String get loading => _tr('loading', 'Loading');
  static String get save => _tr('save', 'Save');
  static String get edit => _tr('edit', 'Edit');
  static String get write => _tr('write', 'Write');
  static String get done => _tr('done', 'Done');
  static String get delete => _tr('delete', 'Delete');
  static String get unblock => _tr('unblock', 'Unblock');
  static String get upgrade => _tr('upgrade', 'Upgrade');
  static String get reset => _tr('reset', 'Reset');
  static String get notNow => _tr('notNow', 'Not now');
  static String get noFileSelected => _tr('noFileSelected', 'No file selected');
  static String get pullDownToRetry => _tr('pullDownToRetry', 'Pull down to try again.');
  static String get someoneFallback => _tr('someoneFallback', 'Someone');
  static String get you => _tr('you', 'You');
  static String get add => _tr('add', 'Add');
  static String get set => _tr('set', 'Set');

  static String hiUser(String name) =>
      _trp('hiUser', 'Hi, $name', {'name': name});

  static String get email => _tr('email', "Email");
  static String get enterEmail => _tr('enterEmail', "Enter Your Email");

  static String get phoneNumber => _tr('phoneNumber', "Phone Number");
  static String get enterPhoneNumber => _tr('enterPhoneNumber', "Enter Your Phone Number");

  static String get contactNumber => _tr('contactNumber', "Contact Number");
  static String get enterContactNumber => _tr('enterContactNumber', "Enter Your Contact Number");

  static String get country => _tr('country', "Country");
  static String get selectCountry => _tr('selectCountry', "Select your Country");

  static String get city => _tr('city', "City");
  static String get selectCity => _tr('selectCity', "Select your City");

  static String get createPassword => _tr('createPassword', "Create Password");
  static String get passwordHint => _tr('passwordHint', "e.g. MyPass#2024");

  static String get confirmPassword => _tr('confirmPassword', "Confirm Password");
  static String get confirmPasswordHint => _tr('confirmPasswordHint', "Re-enter Password");

  // ---------- TERMS & PRIVACY ----------
  static String get agreePrefix => _tr('agreePrefix', "I agree to the ");
  static String get termsConditions => _tr('termsConditions', "Terms & Conditions");
  static String get and => _tr('and', "and");
  static String get privacyPolicy => _tr('privacyPolicy', "Privacy Policy");

  // ---------- FOOTER ----------
  static String get alreadyHaveAccount => _tr('alreadyHaveAccount', "Already have an account? ");
  static String get signIn => _tr('signIn', "Sign In");

  static String get notifications => _tr('notifications', "Notifications");
  static String get pushNotifications => _tr('pushNotifications', "Push Notifications");
  static String get changePassword => _tr('changePassword', "Change Password");
  static String get faq => _tr('faq', "FAQ");
  static String get aboutApplication => _tr('aboutApplication', "About Application");
  static String get termsOfService => _tr('termsOfService', "Terms Of Service");
  static String get helpAndSupport => _tr('helpAndSupport', "Help and support");
  static String get deleteAccount => _tr('deleteAccount', "Delete Account");
  static String get logout => _tr('logout', "Logout");
  static String get reasonForContact => _tr('reasonForContact', "Reason for Contact");
  static String get contactAdminDesc => _tr('contactAdminDesc', "I am having an issue with...");
  static String get deleteAccountDesc => _tr('deleteAccountDesc', "I am deleting Account because...");

  static String get forceUpdateTitle => _tr('forceUpdateTitle', "Update Required");
  static String get forceUpdateSubTitle => _tr('forceUpdateSubTitle', "A new version of the app is available. Please update to continue using the app.");
  static String get whatsNew => _tr('whatsNew', "What's New");
  static String get updateNow => _tr('updateNow', "Update Now");

  // ---------- PREMIUM / WATCH-AD PAYWALL ----------
  static String get buyPremium => _tr('buyPremium', "Buy Premium");
  static String get watchAd => _tr('watchAd', "Watch Ad");
  static String get watchAnAd => _tr('watchAnAd', 'Watch an ad');
  static String get cozunePremium => _tr('cozunePremium', 'cozune Premium');
  static String get restorePurchase => _tr('restorePurchase', 'Restore purchase');
  static String get restoring => _tr('restoring', 'Restoring…');
  static String get premiumBillingNote => _tr('premiumBillingNote', 'Billed through the App Store or Play Store. Cancel any time from your store account.');
  static String get premiumStarted => _tr('premiumStarted', 'Premium started. Your full radius is open.');
  static String get premiumFinishPayment => _tr('premiumFinishPayment', 'Finish the payment to start Premium.');
  static String get premiumRestored => _tr('premiumRestored', 'Premium restored.');
  static String get premiumNoPurchaseFound => _tr('premiumNoPurchaseFound', 'No previous purchase found on this account.');
  static String get bestValue => _tr('bestValue', 'BEST VALUE');
  static String get premiumTitle => _tr('premiumTitle', 'See everyone.\nFilter everything.');

  // Premium plan fallback labels & sub-labels
  static String get planMonthlyLabel => _tr('planMonthlyLabel', '1 month');
  static String get planMonthlySublabel => _tr('planMonthlySublabel', 'Our most popular plan');
  static String get planWeeklyLabel => _tr('planWeeklyLabel', '1 week');
  static String get planWeeklySublabel => _tr('planWeeklySublabel', 'Try it out, cancel anytime');
  static String get planYearlyLabel => _tr('planYearlyLabel', '1 year');
  static String get planYearlySublabel => _tr('planYearlySublabel', 'Best price per month');

  static String startPremiumPrice(String price) =>
      _trp('startPremiumPrice', 'Start Premium · $price', {'price': price});

  // Premium benefits
  static String get benefitSeeEveryoneClaim => _tr('benefitSeeEveryoneClaim', 'See everyone nearby');
  static String get benefitSeeEveryoneDetail => _tr('benefitSeeEveryoneDetail', 'No daily limit on your radar.');
  static String get benefitSeeWhoLikedClaim => _tr('benefitSeeWhoLikedClaim', 'See who liked you');
  static String get benefitSeeWhoLikedDetail => _tr('benefitSeeWhoLikedDetail', 'Every name, before you reply.');
  static String get benefitNoAdsClaim => _tr('benefitNoAdsClaim', 'No ads, ever');
  static String get benefitNoAdsDetail => _tr('benefitNoAdsDetail', 'Nothing to watch, nothing to sit through.');
  static String get benefitEveryFilterClaim => _tr('benefitEveryFilterClaim', 'Every filter');
  static String get benefitEveryFilterDetail => _tr('benefitEveryFilterDetail', 'Online now, verified, situation, atmosphere and vibe.');
  static String get benefitStartConvoClaim => _tr('benefitStartConvoClaim', 'Start any conversation');
  static String get benefitStartConvoDetail => _tr('benefitStartConvoDetail', 'No cap on openers.');

  static String get outOfLikesTitle => _tr('outOfLikesTitle', "You're Out of Likes");
  static String get outOfLikesDescription => _tr('outOfLikesDescription', "Go Premium for unlimited likes, or watch a quick ad to keep swiping.");

  static String get discoveryLimitTitle => _tr('discoveryLimitTitle', "Want to See More People?");
  static String get discoveryLimitDescription => _tr('discoveryLimitDescription', "You've seen all 30 profiles for today. Go Premium for unlimited discovery, or watch a quick ad to unlock more.");

  static String get seeWhoLikedYouTitle => _tr('seeWhoLikedYouTitle', "Someone Likes You");
  static String get seeWhoLikedYouDescription => _tr('seeWhoLikedYouDescription', "Unlock Premium to see who it is instantly, or watch an ad to reveal one now.");

  static String get seeWhoVisitedYouTitle => _tr('seeWhoVisitedYouTitle', 'Someone visited you');
  static String get seeWhoVisitedYouDescription => _tr('seeWhoVisitedYouDescription', 'Go Premium to see everyone who visits, or watch a short ad to reveal this person.');

  // ---------- VISITORS ----------
  static String get visitorsTitle => _tr('visitorsTitle', 'Visitors');
  static String get visitorsOpen => _tr('visitorsOpen', 'Who visited your profile');
  static String get visitorsEmptyTitle => _tr('visitorsEmptyTitle', 'No visitors yet');
  static String get visitorsEmptyBody => _tr('visitorsEmptyBody', 'When someone opens your profile, they show up here.');
  static String get visitorsLoadFailed => _tr('visitorsLoadFailed', "Couldn't load your visitors");
  static String get visitorsWindow => _tr('visitorsWindow', 'From the last 90 days.');
  static String get visitorsAdEach => _tr('visitorsAdEach', 'Watch an ad to reveal each one.');
  static String get visitorsRevealConfirmTitle => _tr('visitorsRevealConfirmTitle', 'Reveal this visitor?');
  static String get visitorsRevealLabel => _tr('visitorsRevealLabel', 'Reveal');
  static String get visitorsUnlockFailed => _tr('visitorsUnlockFailed', "That didn't unlock them. Try again in a moment.");

  static String visitorsPersonCount(int total) => total == 1
      ? _tr('visitorsPersonCountOne', '1 person visited you')
      : _trp('visitorsPersonCountMany', '$total people visited you', {'total': total});

  static String visitorsFreeRevealsLeft(int free) => free == 1
      ? _tr('visitorsFreeRevealsLeftOne', 'Tap a photo to reveal them. 1 free reveal left.')
      : _trp('visitorsFreeRevealsLeftMany', 'Tap a photo to reveal them. $free free reveals left.', {'free': free});

  static String visitorsRevealCreditCost(int cost, int balance) => _trp(
    'visitorsRevealCreditCost',
    'Uses ${cost == 1 ? '1 credit' : '$cost credits'}. You have $balance.',
    {'cost': cost, 'balance': balance},
  );

  static String visitorsRevealed(String? name) => _trp(
    'visitorsRevealed',
    'Revealed ${name ?? someoneFallback}',
    {'name': name ?? someoneFallback},
  );

  static String get rewindTitle => _tr('rewindTitle', "Want a Do-Over?");
  static String get rewindDescription => _tr('rewindDescription', "Rewind your last swipe with Premium, or watch a short ad to undo it now.");

  static String get boostTitle => _tr('boostTitle', "Get Seen First");
  static String get boostDescription => _tr('boostDescription', "Boost your profile with Premium, or watch an ad for a free boost.");

  static String get matchLimitTitle => _tr('matchLimitTitle', "You've Hit Today's Limit");
  static String get matchLimitDescription => _tr('matchLimitDescription', "Go Premium for unlimited matches, or watch an ad to unlock a few more.");

  static String get genericPaywallTitle => _tr('genericPaywallTitle', "Unlock This Feature");
  static String get genericPaywallDescription => _tr('genericPaywallDescription', "Upgrade to Premium for full access, or watch a short ad to continue.");

  static String get mutualChatPaywallTitle => _tr('mutualChatPaywallTitle', "Unlock Mutual Chat");
  static String get mutualChatPaywallDescription => _tr('mutualChatPaywallDescription', "Upgrade to Premium to chat with your mutual matches instantly, or watch a short ad to unlock this chat.");

  // ---------- ONBOARDING: SECTION LABELS ----------
  static String get sectionIdentity => _tr('sectionIdentity', 'IDENTITY');
  static String get sectionYourVibe => _tr('sectionYourVibe', 'YOUR VIBE');
  static String get sectionLocation => _tr('sectionLocation', 'LOCATION');
  static String get sectionAgreement => _tr('sectionAgreement', 'AGREEMENT');

  // ---------- ONBOARDING: AGE ----------
  static String get ageTitle => _tr('ageTitle', 'How old are you?');
  static String get ageSubtitle => _tr('ageSubtitle', 'Cozune is for adults only. Please share your birth date.');
  static String get displayNameCaps => _tr('displayNameCaps', 'DISPLAY NAME');
  static String get displayNameHint => _tr('displayNameHint', 'How should we call you?');
  static String get dayLabel => _tr('dayLabel', 'DAY');
  static String get dayHint => _tr('dayHint', 'DD');
  static String get monthLabel => _tr('monthLabel', 'MONTH');
  static String get monthHint => _tr('monthHint', 'MM');
  static String get yearLabel => _tr('yearLabel', 'YEAR');
  static String get yearHint => _tr('yearHint', 'YYYY');
  static String get ageEnterName => _tr('ageEnterName', 'Please enter your display name');
  static String get ageSelectDob => _tr('ageSelectDob', 'Please select your birth date');
  static String get ageSelectDobFirst => _tr('ageSelectDobFirst', 'Please select your birth date first');
  static String get ageMustBeAdult => _tr('ageMustBeAdult', 'You must be 18 or older to continue');
  static String get ageUnderage => _tr('ageUnderage', 'You must be 18 or older to use cozune');
  static String get ageConfirm => _tr('ageConfirm', "I confirm I'm 18 or older");
  static String get ageNotePrivacy => _tr('ageNotePrivacy', "We use your date of birth to confirm you're 18+. It stays private — only your age is shown.");
  static String get ageNoteOtp => _tr('ageNoteOtp', 'A verification code (OTP) may be sent to confirm your birth date if required.');

  // ---------- ONBOARDING: BASICS ----------
  static String get basicsTitle => _tr('basicsTitle', 'The Basics');
  static String get displayNameLabel => _tr('displayNameLabel', 'Display name');
  static String get basicsNameTooShort => _tr('basicsNameTooShort', 'Please enter a display name of at least 2 characters');
  static String get basicsSelectGender => _tr('basicsSelectGender', 'Please select your gender');
  static String get iAmA => _tr('iAmA', 'I am a');
  static String get pronounsLabel => _tr('pronounsLabel', 'Pronouns');
  static String get bioLabel => _tr('bioLabel', 'Bio');
  static String get bioHint => _tr('bioHint', 'Seeking genuine connections...');
  static String get pricingNote => _tr('pricingNote', 'cozune is free for women & non-binary/trans-women; men subscribe to message.');

  static String get genderWoman => _tr('genderWoman', 'Woman');
  static String get genderMan => _tr('genderMan', 'Man');
  static String get genderNonBinary => _tr('genderNonBinary', 'Non-binary');
  static String get genderTransWoman => _tr('genderTransWoman', 'Trans woman');
  static String get genderTransMan => _tr('genderTransMan', 'Trans man');
  static String get genderIntersex => _tr('genderIntersex', 'Intersex');
  static String get genderSelfDescribe => _tr('genderSelfDescribe', 'Self-describe');

  static String get pronounSheHer => _tr('pronounSheHer', 'She/Her');
  static String get pronounHeHim => _tr('pronounHeHim', 'He/Him');
  static String get pronounTheyThem => _tr('pronounTheyThem', 'They/Them');
  static String get pronounOther => _tr('pronounOther', 'Other');

  // ---------- ONBOARDING: INTENT & ATMOSPHERE ----------
  static String get intentTitle => _tr('intentTitle', 'Define your cozune.');
  static String get currentIntent => _tr('currentIntent', 'Current Intent');
  static String get intentSubtitle => _tr('intentSubtitle', 'What are you looking for today?');
  static String get yourAtmosphere => _tr('yourAtmosphere', 'Your Atmosphere');
  static String get atmosphereSubtitle => _tr('atmosphereSubtitle', 'Select the qualities that describe you.');
  static String get intentSelectError => _tr('intentSelectError', 'Please select what you are here for');
  static String get vibesNoun => _tr('vibesNoun', 'vibes');
  static String get tagsUnavailable => _tr('tagsUnavailable', "Couldn't load the options. You can continue and add these later.");

  // ---------- ONBOARDING: STATUS ----------
  static String get statusTitle => _tr('statusTitle', 'My situation.');
  static String get statusSubtitle => _tr('statusSubtitle', 'Honesty up front saves everyone time. Pick the one that fits.');
  static String get statusPickError => _tr('statusPickError', 'Please pick the option that fits you');
  static String get statusSingle => _tr('statusSingle', 'Single');
  static String get statusSingleBlurb => _tr('statusSingleBlurb', 'Unattached and looking.');
  static String get statusSeeing => _tr('statusSeeing', 'Seeing someone');
  static String get statusSeeingBlurb => _tr('statusSeeingBlurb', 'Dating, nothing exclusive yet.');
  static String get statusOpen => _tr('statusOpen', 'Open relationship');
  static String get statusOpenBlurb => _tr('statusOpenBlurb', 'Partnered, with the freedom to explore.');
  static String get statusCouple => _tr('statusCouple', 'Couple');
  static String get statusCoupleBlurb => _tr('statusCoupleBlurb', 'Here together, looking together.');
  static String get statusPrivate => _tr('statusPrivate', 'Prefer not to say');
  static String get statusPrivateBlurb => _tr('statusPrivateBlurb', 'Keep this off my profile.');

  // ---------- ONBOARDING: PREFERENCES ----------
  static String get vibeTitle => _tr('vibeTitle', 'Define your vibe.');
  static String get vibeSubtitle => _tr('vibeSubtitle', 'Answer as many of these as you like — each one has its own allowance, and they all stay private until you match with someone.');
  static String get hardNos => _tr('hardNos', "Hard no's");
  static String get showOnProfile => _tr('showOnProfile', 'Show on profile');
  static String get catalogueError => _tr('catalogueError', "Couldn't load the tag options. You can continue and set these later.");

  // ---------- ONBOARDING: PHOTOS ----------
  static String get photosTitle => _tr('photosTitle', 'Show yourself');
  static String get photosSubtitle => _tr('photosSubtitle', 'Upload up to 5 photos. You can always add more later.');
  static String get photoPrimaryTile => _tr('photoPrimaryTile', 'Primary Photo');
  static String get photoPrimaryBadge => _tr('photoPrimaryBadge', 'Primary');
  static String get photoGuidelines => _tr('photoGuidelines', 'Keep photos clear and respectful — no nudity.');
  static String get photoTipsTitle => _tr('photoTipsTitle', 'Tips for a better match');
  static String get tipLightingTitle => _tr('tipLightingTitle', 'Natural Lighting');
  static String get tipLightingBody => _tr('tipLightingBody', 'Daylight softens features and creates a more authentic presence.');
  static String get tipEyesTitle => _tr('tipEyesTitle', 'Eyes Visible');
  static String get tipEyesBody => _tr('tipEyesBody', 'Avoid heavy sunglasses. Direct eye contact increases verification speed.');
  static String get continueWithoutPhotos => _tr('continueWithoutPhotos', 'Continue without photos');
  static String get galleryError => _tr('galleryError', 'Could not open the gallery. Please try again.');
  static String get photosRejectedDefault => _tr('photosRejectedDefault', "Those photos don't meet our content guidelines. You can add different ones from your profile.");
  static String get photosUploadFailed => _tr('photosUploadFailed', "Photos couldn't be uploaded right now — you can add them later from your profile.");

  static String photoStepError(String message) => _trp(
    'photoStepError',
    "Couldn't save this step: $message",
    {'message': message},
  );

  static String photosPartialRejected(int uploaded, int total, int rejected) => _trp(
    'photosPartialRejected',
    "Added $uploaded of $total. ${rejected == 1 ? 'One photo' : '$rejected photos'} didn't meet our content guidelines.",
    {'uploaded': uploaded, 'total': total, 'rejected': rejected},
  );

  static String photosPartialFailed(int uploaded, int total) => _trp(
    'photosPartialFailed',
    'Uploaded $uploaded of $total photos.',
    {'uploaded': uploaded, 'total': total},
  );

  // ---------- ONBOARDING: LOCATION ----------
  static String get locationTitle => _tr('locationTitle', 'Turn on location');
  static String get locationBody => _tr('locationBody', 'cozune uses your location to connect you with people physically near you right now. Without it there is nobody to show you.');
  static String get locationNoteBand => _tr('locationNoteBand', 'Others only see a band — "2-5 km away" — never your exact spot, and never a number.');
  static String get locationNoteSettings => _tr('locationNoteSettings', 'You can turn this off any time in your phone\u2019s settings. Nothing else on your profile depends on it.');
  static String get allowLocation => _tr('allowLocation', 'Allow location');
  static String get locationError => _tr('locationError', 'Could not get your location. Please try again.');

  // ---------- IDENTITY VERIFICATION (live face check) ----------
  static String get verifyTitle => _tr('verifyTitle', 'Get verified');
  static String get verifyIntro => _tr('verifyIntro', 'Show people you are who your photos say. It takes about 30 seconds.');
  static String get verifyHowSteps => _tr('verifyHowSteps', 'Look at the camera, then follow the prompts: turn your head each way, blink and smile.');
  static String get verifyHowPhotos => _tr('verifyHowPhotos', 'We take 4 photos and check it\u2019s a real person, that it\u2019s you in all of them, and that your profile photos match.');
  static String get verifyHowPrivate => _tr('verifyHowPrivate', 'They\u2019re stored privately and never shown on your profile. They\u2019re deleted after 12 months, or sooner if you delete your account.');
  static String get verifyHowLater => _tr('verifyHowLater', 'Once you\u2019re verified, new photos with a face need to include you. The tick lasts 12 months; then a quick check renews it.');
  static String get verifyConsent => _tr('verifyConsent', 'By tapping "Agree and start", you agree that cozune may take these photos and compare your face in them with your profile photos, only to confirm it\u2019s you, and keep them for up to 12 months.');
  static String get verifyStart => _tr('verifyStart', 'Agree and start');
  static String get verifyCheckAgain => _tr('verifyCheckAgain', 'Agree and check again');
  static String get verifyAlready => _tr('verifyAlready', 'You\u2019re verified');
  static String get verifyAlreadyBody => _tr('verifyAlreadyBody', 'Your profile shows the tick. Check again if you\u2019ve changed how you look, so new photos keep matching.');

  static String verifyValidUntil(String date) =>
      _trp('verifyValidUntil', 'Your tick lasts until $date.', {'date': date});

  static String get verifyUnavailable => _tr('verifyUnavailable', 'Verification isn\u2019t available right now. Try again later.');

  static String get verifyStepStraight => _tr('verifyStepStraight', 'Look straight at the camera');
  static String get verifyStepTurn => _tr('verifyStepTurn', 'Slowly turn your head to one side');
  static String get verifyStepTurnBack => _tr('verifyStepTurnBack', 'Now turn to the other side');
  static String get verifyStepBlink => _tr('verifyStepBlink', 'Blink slowly');
  static String get verifyStepSmile => _tr('verifyStepSmile', 'Give us a big smile');

  static String get verifyHintNoFace => _tr('verifyHintNoFace', 'Fit your face inside the circle');
  static String get verifyHintManyFaces => _tr('verifyHintManyFaces', 'Make sure only you are in view');
  static String get verifyHintCloser => _tr('verifyHintCloser', 'Move a little closer');
  static String get verifyHintBack => _tr('verifyHintBack', 'Move back a little');
  static String get verifyHintStraight => _tr('verifyHintStraight', 'Face the camera straight on');
  static String get verifyHintDark => _tr('verifyHintDark', 'We can\u2019t see your face. Find some light.');
  static String get verifyHintPreparing => _tr('verifyHintPreparing', 'Getting the camera ready\u2026');

  static String get verifyChecking => _tr('verifyChecking', 'Checking your photos\u2026');
  static String get verifyCheckingBody => _tr('verifyCheckingBody', 'This takes a few seconds.');
  static String get verifyDone => _tr('verifyDone', 'You\u2019re verified');
  static String get verifyDoneBody => _tr('verifyDoneBody', 'Your profile now shows the tick, everywhere people see you.');
  static String get verifyFailedTitle => _tr('verifyFailedTitle', 'Not verified yet');
  static String get verifyRecheckFailed => _tr('verifyRecheckFailed', 'That check didn\u2019t pass');
  static String get verifyStillVerified => _tr('verifyStillVerified', 'You\u2019re still verified \u2014 your earlier check stands.');
  static String get verifyCouldNotFinish => _tr('verifyCouldNotFinish', 'Couldn\u2019t finish');
  static String get verifyPhotoUnreadable => _tr('verifyPhotoUnreadable', 'Can\u2019t be checked');
  static String get verifyTryAgain => _tr('verifyTryAgain', 'Try again');
  static String get verifyNotNow => _tr('verifyNotNow', 'Not now');
  static String get verifyDoneButton => _tr('verifyDoneButton', 'Done');
  static String get verifyPhotosTitle => _tr('verifyPhotosTitle', 'Almost there');
  static String get verifyRemoveAndFinish => _tr('verifyRemoveAndFinish', 'Remove and finish');
  static String get verifyRemoving => _tr('verifyRemoving', 'Removing photos\u2026');
  static String get verifyUploadFailed => _tr('verifyUploadFailed', 'Your photos didn\u2019t upload. Check your connection and try again.');
  static String get verifyCameraDenied => _tr('verifyCameraDenied', 'cozune needs your camera for this. Allow camera access in your phone\u2019s Settings, then come back.');
  static String get verifyCameraUnavailable => _tr('verifyCameraUnavailable', 'We couldn\u2019t open your front camera.');
  static String get verifyTooManyTries => _tr('verifyTooManyTries', 'You\u2019ve tried a lot today. Try again tomorrow.');

  // ---------- ONBOARDING: AGREEMENT ----------
  static String get agreementTitle => _tr('agreementTitle', 'The vibe agreement');
  static String get agreementSubtitle => _tr('agreementSubtitle', 'One tap each. All four are required.');
  static String get agreementAdult => _tr('agreementAdult', "I'm 18 or older");
  static String get agreementRespectful => _tr('agreementRespectful', "I'll be respectful");
  static String get agreementNoHarassment => _tr('agreementNoHarassment', 'No harassment');
  static String get agreementConsent => _tr('agreementConsent', 'Consent always matters');
  static String get agreementNote => _tr('agreementNote', 'We store your acceptance with the date and the version of these terms.');
  static String get enterCozune => _tr('enterCozune', 'Enter cozune');

  // ---------- LOGIN ----------
  static String get loginEyebrow => _tr('loginEyebrow', '18+ \u00b7 Verified people only');
  static String get loginHeadline => _tr('loginHeadline', "Who's around you\ntonight?");
  static String get loginBody => _tr('loginBody', 'Real, verified people nearby who want the same thing you do. No endless swiping.');
  static String get phoneNumberLabel => _tr('phoneNumberLabel', 'Phone number');
  static String get phoneFieldHint => _tr('phoneFieldHint', '000 000 0000');
  static String get sendCode => _tr('sendCode', 'Send code');
  static String get continueWithGoogle => _tr('continueWithGoogle', 'Continue with Google');
  static String get orText => _tr('orText', 'OR');
  static String get loginTerms => _tr('loginTerms', "By continuing you confirm you're 18 or older and agree to our Terms and Privacy Policy.");
  static String get sendCodeFailed => _tr('sendCodeFailed', "Couldn't send the code. Try again.");
  static String get countryIndia => _tr('countryIndia', 'India');
  static String get countryUs => _tr('countryUs', 'US');

  static String countryDigitsError(String name, int digits) => _trp(
    'countryDigitsError',
    '$name numbers are $digits digits',
    {'name': name, 'digits': digits},
  );

  static String countryOptionSubtitle(String code, String digits) => _trp(
    'countryOptionSubtitle',
    '$code \u00b7 $digits digits',
    {'code': code, 'digits': digits},
  );

  static String countrySemantics(String name, String code) => _trp(
    'countrySemantics',
    'Country: $name, $code',
    {'name': name, 'code': code},
  );

  static String get googleFailed => _tr('googleFailed', "Couldn't sign in with Google. Try again.");
  static String get googleNotConfigured => _tr('googleNotConfigured', 'Google sign-in not configured for this build (DEVELOPER_ERROR 10) \u2014 the package name and signing SHA-1 are not registered as an Android OAuth client.');
  static String get googleCancelled => _tr('googleCancelled', 'Sign-in cancelled.');
  static String get googlePlayServices => _tr('googlePlayServices', 'Google sign-in failed (12500) \u2014 check the Play Services account on this device.');
  static String get googleNetwork => _tr('googleNetwork', 'Network error reaching Google. Check the connection.');

  static String googleUnknown(String code, String? message) => _trp(
    'googleUnknown',
    'Google sign-in failed: $code \u2014 $message',
    {'code': code, 'message': message},
  );

  // ---------- OTP ----------
  static String get otpTitle => _tr('otpTitle', "Verify it's you");
  static String get otpSubtitle => _tr('otpSubtitle', 'Enter the code sent to your phone or email.');
  static String get otpIncomplete => _tr('otpIncomplete', 'Please enter the complete OTP');
  static String get otpResent => _tr('otpResent', 'OTP resent!');
  static String get otpDidntReceive => _tr('otpDidntReceive', "Didn't receive a code?  ");
  static String get otpResend => _tr('otpResend', 'Resend code');
  static String get otpVerifyContinue => _tr('otpVerifyContinue', 'Verify & Continue');

  static String otpInvalid(Object error) =>
      _trp('otpInvalid', 'Invalid OTP: $error', {'error': error});

  static String otpResendFailed(Object error) =>
      _trp('otpResendFailed', 'Failed to resend: $error', {'error': error});

  // ---------- SPLASH ----------
  static String get splashErrorTitle => _tr('splashErrorTitle', "Couldn't reach cozune");
  static String get maintenanceTitleDefault => _tr('maintenanceTitleDefault', "We're upgrading our systems");
  static String get maintenanceMessageDefault => _tr('maintenanceMessageDefault', "Our platform is currently undergoing scheduled maintenance. We'll be back online shortly!");
  static String get maintenanceStillActive => _tr('maintenanceStillActive', 'Current App is in Maintenance Mode!');
  static String get splashLoadingPreparing => _tr('splashLoadingPreparing', 'Preparing Your Experience...');
  static String get splashLoadingAlmostReady => _tr('splashLoadingAlmostReady', 'Almost Ready...');
  static String get splashCriticalError => _tr('splashCriticalError', 'A critical error occurred while starting the app.\nPlease try restarting.');

  // ---------- SETTINGS ----------
  static String get settingsSignOutTitle => _tr('settingsSignOutTitle', 'Sign out of cozune?');
  static String get settingsSignOutBody => _tr(
    'settingsSignOutBody',
    "Your profile and chats stay as they are. You just won't get notifications until you sign back in.",
  );
  static String get settingsSignOutButton => _tr('settingsSignOutButton', 'Sign out');
  static String get settingsDeleteTitle => _tr('settingsDeleteTitle', 'Delete your account?');
  static String get settingsDeleteBody => _tr(
    'settingsDeleteBody',
    'This permanently deletes your account and all of its data. It cannot be undone.',
  );
  static String get settingsSectionProfile => _tr('settingsSectionProfile', 'Profile');
  static String get settingsSectionDisplay => _tr('settingsSectionDisplay', 'Display');
  static String get settingsSectionAccount => _tr('settingsSectionAccount', 'Account');
  static String get settingsDarkMode => _tr('settingsDarkMode', 'Dark mode');
  static String get settingsSignOutRow => _tr('settingsSignOutRow', 'Sign out');
  static String get settingsDeleteAccountRow => _tr('settingsDeleteAccountRow', 'Delete account');
  static String get settingsBlockedAccounts => _tr('settingsBlockedAccounts', 'Blocked accounts');
  static String get settingsSecurityNotice => _tr('settingsSecurityNotice', 'Security notice');

  // ---------- BLOCKED ACCOUNTS ----------
  static String get blockedAccountsTitle => _tr('blockedAccountsTitle', 'Blocked accounts');
  static String get blockedAccountsLoadError => _tr('blockedAccountsLoadError', "Couldn't load your blocked list");
  static String get blockedAccountsEmptyTitle => _tr('blockedAccountsEmptyTitle', 'Nobody blocked');
  static String get blockedAccountsEmptyBody => _tr('blockedAccountsEmptyBody', 'People you block are listed here, so you can always let them back in.');
  static String get blockedUnblockCancel => _tr('blockedUnblockCancel', 'Cancel');
  static String get blockedUnblockBody => _tr('blockedUnblockBody', 'You will be able to see and message each other again. Anything they sent while blocked stays undelivered.');

  static String blockedUnblockTitle(String name) =>
      _trp('blockedUnblockTitle', 'Unblock $name?', {'name': name});

  // ---------- EDIT PROFILE ----------
  static String get editProfileTitle => _tr('editProfileTitle', 'Edit profile');
  static String get editProfileBioPlaceholder => _tr('editProfileBioPlaceholder', 'Say something worth replying to.');
  static String get editProfileBioUpdated => _tr('editProfileBioUpdated', 'Bio updated');
  static String get editProfileNameTooShort => _tr('editProfileNameTooShort', 'Your name needs at least 2 characters.');
  static String get editProfilePickIntent => _tr('editProfilePickIntent', 'Pick what you are here for.');
  static String get editProfileNoGender => _tr('editProfileNoGender', 'Finish setting up your profile before renaming it.');
  static String get editProfileSaved => _tr('editProfileSaved', 'Profile updated');

  // ---------- YOU SCREEN ----------
  static String get youTabPhotos => _tr('youTabPhotos', 'Photos');
  static String get youTabAbout => _tr('youTabAbout', 'About');
  static String get youAboutTitle => _tr('youAboutTitle', 'About you');
  static String get youFactHereFor => _tr('youFactHereFor', 'Here for');
  static String get youFactSituation => _tr('youFactSituation', 'Situation');
  static String get youFactInThreeWords => _tr('youFactInThreeWords', 'In three words');
  static String get youFactYourKindOfNight => _tr('youFactYourKindOfNight', 'Your kind of night');
  static String get youFactPrivateUntilMatch => _tr('youFactPrivateUntilMatch', 'Private until you match');
  static String get youFactHardNos => _tr('youFactHardNos', "Hard no's");
  static String get youFactHardNosShown => _tr('youFactHardNosShown', 'Shown on your profile');
  static String get youFactHardNosHidden => _tr('youFactHardNosHidden', 'Hidden from your profile');
  static String get youFactWhereYouAre => _tr('youFactWhereYouAre', 'Where you are');
  static String get youNotSet => _tr('youNotSet', 'Not set');
  static String get youVibesUpdated => _tr('youVibesUpdated', 'Vibes updated');
  static String get youLoadError => _tr('youLoadError', "Couldn't load your profile.");
  static String get youAddPhotos => _tr('youAddPhotos', 'Add photos');

  static String youAddMorePhotos(int count) => _trp(
    'youAddMorePhotos',
    'Add $count more ${count == 1 ? 'photo' : 'photos'}',
    {'count': count},
  );

  static String get youShowPeopleWhoYouAre => _tr('youShowPeopleWhoYouAre', 'Show people who you are.');
  static String get youTellPeopleAboutYourself => _tr('youTellPeopleAboutYourself', 'Tell people about yourself.');
  static String get youDescribeYourVibe => _tr('youDescribeYourVibe', 'Describe your vibe.');
  static String get youShareWhatYouAreInto => _tr('youShareWhatYouAreInto', 'Share what you are into.');

  static String youCompleteSteps(int done, int total) => _trp(
    'youCompleteSteps',
    '$done of $total complete',
    {'done': done, 'total': total},
  );

  // ---------- YOU HEADER ----------
  static String get youHeaderAddPhoto => _tr('youHeaderAddPhoto', 'Add photo');
  static String get youHeaderSettings => _tr('youHeaderSettings', 'Settings');
  static String get youHeaderVisits => _tr('youHeaderVisits', 'Visits');
  static String get youHeaderLikes => _tr('youHeaderLikes', 'Likes');
  static String get youHeaderFriends => _tr('youHeaderFriends', 'Friends');
  static String get youHeaderEditProfile => _tr('youHeaderEditProfile', 'Edit profile');
  static String get youHeaderWriteBio => _tr('youHeaderWriteBio', 'Write a bio');
  static String get youHeaderBioPrompt => _tr('youHeaderBioPrompt', 'Add a bio \u2014 say something worth replying to.');
  static String get youHeaderLocationOn => _tr('youHeaderLocationOn', 'Location \u00b7 On');
  static String get youHeaderLocationOff => _tr('youHeaderLocationOff', 'Location \u00b7 Off');
  static String get youHeaderLiveLocationOn => _tr('youHeaderLiveLocationOn', 'Live location is on. Choose who can see you');
  static String get youHeaderLiveLocationOff => _tr('youHeaderLiveLocationOff', 'Live location is off. Choose who can see you');

  // ---------- PROFILE EDIT SHEETS ----------
  static String get editBioSheetTitle => _tr('editBioSheetTitle', 'Edit bio');
  static String get editBioHint => _tr('editBioHint', 'Say something worth replying to...');
  static String get editVibesSheetTitle => _tr('editVibesSheetTitle', 'My vibe');
  static String get editVibesDescription => _tr('editVibesDescription', 'Pick the qualities that describe you. ');

  // ---------- DASHBOARD / RADAR ----------
  static String get dashboardTabRadar => _tr('dashboardTabRadar', 'Radar');
  static String get dashboardTabLikes => _tr('dashboardTabLikes', 'Likes');
  static String get dashboardTabExplore => _tr('dashboardTabExplore', 'Explore');
  static String get dashboardTabChats => _tr('dashboardTabChats', 'Chats');
  static String get dashboardTabYou => _tr('dashboardTabYou', 'You');

  static String get dashboardConnectionError => _tr('dashboardConnectionError', 'Check your connection and pull down to try again.');
  static String get dashboardSetLocation => _tr('dashboardSetLocation', 'Set your location');
  static String get dashboardSeenEveryone => _tr('dashboardSeenEveryone', 'You have seen everyone for now');
  static String get dashboardPremiumRadarBody => _tr('dashboardPremiumRadarBody', 'Premium opens the rest of your radius, with no daily limit.');
  static String get dashboardSeePremium => _tr('dashboardSeePremium', 'See everyone with Premium');
  static String get dashboardFilteredEmpty => _tr('dashboardFilteredEmpty', 'Quiet in your radius right now');
  static String get dashboardFilteredEmptyBody => _tr('dashboardFilteredEmptyBody', 'Nobody nearby matches these filters. Clear a few and check back — who is around changes through the day.');
  static String get dashboardOpenFilters => _tr('dashboardOpenFilters', 'Open filters');
  static String get dashboardShowMorePeople => _tr('dashboardShowMorePeople', 'Show more people');
  static String get dashboardFiltersLabel => _tr('dashboardFiltersLabel', 'Filters');
  static String get dashboardFilterOnlineNow => _tr('dashboardFilterOnlineNow', 'Online now');
  static String get dashboardFilterActiveToday => _tr('dashboardFilterActiveToday', 'Active today');
  static String get dashboardAlreadyCounted => _tr('dashboardAlreadyCounted', 'That one was already counted');

  static String dashboardUnlockedCredits(int credits) => _trp(
    'dashboardUnlockedCredits',
    'Unlocked \u2014 $credits credits added',
    {'credits': credits},
  );

  // ---------- DISCOVERY FILTERS ----------
  static String get filterSheetTitle => _tr('filterSheetTitle', 'Filters');
  static String get filterReset => _tr('filterReset', 'Reset');
  static String get filterShowResults => _tr('filterShowResults', 'Show results');
  static String get filterFreeSectionLabel => _tr('filterFreeSectionLabel', 'Free');
  static String get filterFreeSubtitle => _tr('filterFreeSubtitle', 'Available on every account');
  static String get filterShowMeLabel => _tr('filterShowMeLabel', 'SHOW ME');
  static String get filterShowMeHint => _tr('filterShowMeHint', 'Leave all unselected to see everyone.');
  static String get filterAgeRangeLabel => _tr('filterAgeRangeLabel', 'AGE RANGE');
  static String get filterIntentLabel => _tr('filterIntentLabel', 'INTENT');
  static String get filterPremiumLabel => _tr('filterPremiumLabel', 'Premium');
  static String get filterPremiumIncluded => _tr('filterPremiumIncluded', 'Included with your plan');
  static String get filterPremiumLocked => _tr('filterPremiumLocked', 'Unlock to filter by these');
  static String get filterPremiumSituationLabel => _tr('filterPremiumSituationLabel', 'SITUATION');
  static String get filterVerifiedOnly => _tr('filterVerifiedOnly', 'Verified only');
  static String get filterVerifiedOnlySubtitle => _tr('filterVerifiedOnlySubtitle', 'People who passed the live check.');
  static String get filterOnlineNow => _tr('filterOnlineNow', 'Online now');
  static String get filterOnlineNowSubtitle => _tr('filterOnlineNowSubtitle', 'Active this moment.');
  static String get filterRecentlyActive => _tr('filterRecentlyActive', 'Recently active');
  static String get filterRecentlyActiveSubtitle => _tr('filterRecentlyActiveSubtitle', 'Seen in the last 24 hours.');
  static String get filterPremiumNudge => _tr('filterPremiumNudge', 'Premium filters are ignored until you upgrade.');
  static String get filterUpgrade => _tr('filterUpgrade', 'Upgrade');

  static String filterShowCount(int total) => total == 1
      ? _tr('filterShowCountOne', 'Show 1 person')
      : _trp('filterShowCountMany', 'Show $total people', {'total': total});

  // Filter: gender options
  static String get filterGenderWoman => _tr('filterGenderWoman', 'Woman');
  static String get filterGenderNonBinary => _tr('filterGenderNonBinary', 'Non-binary');
  static String get filterGenderTransWoman => _tr('filterGenderTransWoman', 'Trans woman');
  static String get filterGenderTransMan => _tr('filterGenderTransMan', 'Trans man');
  static String get filterGenderIntersex => _tr('filterGenderIntersex', 'Intersex');

  // Filter: intent options
  static String get filterIntentRightNow => _tr('filterIntentRightNow', 'Right now');
  static String get filterIntentCasual => _tr('filterIntentCasual', 'Casual');
  static String get filterIntentDating => _tr('filterIntentDating', 'Dating');
  static String get filterIntentSerious => _tr('filterIntentSerious', 'Serious');
  static String get filterIntentFriends => _tr('filterIntentFriends', 'Friends');
  static String get filterIntentJustChatting => _tr('filterIntentJustChatting', 'Just chatting');
  static String get filterIntentOpenToAnything => _tr('filterIntentOpenToAnything', 'Open to anything');

  // Filter: situation options
  static String get filterSituationSingle => _tr('filterSituationSingle', 'Single');
  static String get filterSituationSeeingSomeone => _tr('filterSituationSeeingSomeone', 'Seeing someone');
  static String get filterSituationOpenRelationship => _tr('filterSituationOpenRelationship', 'Open relationship');
  static String get filterSituationCouple => _tr('filterSituationCouple', 'Couple');

  // ---------- PREMIUM FILTER PROMPT ----------
  static String get premiumFilterPromptBody => _tr('premiumFilterPromptBody', 'Premium narrows the circle down to who is around right now. Distance, who you see, age and intent stay free.');
  static String get premiumFilterSeePremium => _tr('premiumFilterSeePremium', 'See Premium');
  static String get premiumFilterNotNow => _tr('premiumFilterNotNow', 'Not now');

  // ---------- LIKES / FAVOURITES ----------
  static String get likesTabLikes => _tr('likesTabLikes', 'Likes');
  static String get likesTabMutual => _tr('likesTabMutual', 'Mutual');
  static String get likedYouTitle => _tr('likedYouTitle', 'Liked you');
  static String get likesEmptyTitle => _tr('likesEmptyTitle', 'No likes yet');
  static String get likesEmptyBody => _tr('likesEmptyBody', 'Keep an eye on your radar — the people you like can see you too.');
  static String get likesLoadError => _tr('likesLoadError', 'Could not load your likes.');
  static String get likesAddError => _tr('likesAddError', 'Could not add the like. Please try again.');
  static String get likesRevealWithPremium => _tr('likesRevealWithPremium', 'Reveal everyone with Premium');
  static String get likesMadeFirstMove => _tr('likesMadeFirstMove', 'They already made the first move.');
  static String get likesPremiumRevealBody => _tr('premiumRevealBody', 'Premium reveals every one of them, and lets you reply.');
  static String get likesAlreadyCounted => _tr('likesAlreadyCounted', 'That one was already counted');

  static String likesUnlocked(int credits) => _trp(
    'likesUnlocked',
    'Unlocked \u2014 $credits credits added',
    {'credits': credits},
  );

  static String likesPersonCount(int total) => total == 1
      ? _tr('likesPersonCountOne', '1 person liked you')
      : _trp('likesPersonCountMany', '$total people liked you', {'total': total});

  static String likesRemainingCount(int count) => count == 1
      ? _tr('likesRemainingCountOne', '1 more person liked you')
      : _trp('likesRemainingCountMany', '$count more people liked you', {'count': count});

  // ---------- MUTUAL (MATCHES) ----------
  static String get mutualEmptyTitle => _tr('mutualEmptyTitle', 'No matches yet');
  static String get mutualEmptyBody => _tr('mutualEmptyBody', 'When you like someone who already liked you, they show up here — free to message, always.');
  static String get mutualBothLiked => _tr('mutualBothLiked', 'You both liked each other');
  static String get mutualConversationGoing => _tr('mutualConversationGoing', 'You have a conversation going');

  static String mutualMessageLabel(String name) =>
      _trp('mutualMessageLabel', 'Message $name', {'name': name});

  // ---------- CHAT LIST / REQUESTS ----------
  static String get chatTabVibing => _tr('chatTabVibing', 'Vibing');
  static String get chatTabNewEnergy => _tr('chatTabNewEnergy', 'New Energy');
  static String get chatArchivedLabel => _tr('chatArchivedLabel', 'Archived chats');
  static String get chatConvoEmptyTitle => _tr('chatConvoEmptyTitle', 'No conversations yet');
  static String get chatConvoEmptyBody => _tr('chatConvoEmptyBody', 'When someone replies to your opener, the conversation moves here.');
  static String get chatInboxEmptyTitle => _tr('chatInboxEmptyTitle', 'Nothing new');
  static String get chatInboxEmptyBody => _tr('chatInboxEmptyBody', 'Openers waiting for a reply — yours or theirs — show up here.');
  static String get chatSayHello => _tr('chatSayHello', 'Say hello');
  static String get chatLoadError => _tr('chatLoadError', 'Could not load conversations.');

  static String chatOptionsLabel(String userName) => _trp(
    'chatOptionsLabel',
    'Options for $userName',
    {'userName': userName},
  );

  // ---------- ARCHIVED CHATS ----------
  static String get archivedTitle => _tr('archivedTitle', 'Archived');
  static String get archivedLoadError => _tr('archivedLoadError', 'Could not load archived chats.');
  static String get archivedEmptyTitle => _tr('archivedEmptyTitle', 'Nothing archived');
  static String get archivedEmptyBody => _tr('archivedEmptyBody', 'Chats you archive are kept here, out of your inbox but not deleted.');

  // ---------- CHAT ACTIONS MENU ----------
  static String get chatActionMoveToInbox => _tr('chatActionMoveToInbox', 'Moved back to your inbox');
  static String get chatActionArchived => _tr('chatActionArchived', 'Archived');
  static String get chatActionNotificationsOn => _tr('chatActionNotificationsOn', 'Notifications on');
  static String get chatActionMuted => _tr('chatActionMuted', 'Muted \u2014 messages still arrive, quietly');
  static String get chatActionDeleteTitle => _tr('chatActionDeleteTitle', 'Delete this conversation?');
  static String get chatActionDeleteConfirm => _tr('chatActionDeleteConfirm', 'Delete');
  static String get chatActionConversationDeleted => _tr('chatActionConversationDeleted', 'Conversation deleted');

  static String chatActionDeleteBody(String userName) => _trp(
    'chatActionDeleteBody',
    'It disappears from your inbox. $userName keeps their ',
    {'userName': userName},
  );

  static String chatActionBlockTitle(String userName) => _trp(
    'chatActionBlockTitle',
    'Block $userName?',
    {'userName': userName},
  );

  static String get chatActionBlockBody => _tr('chatActionBlockBody', 'They will not be able to message you, and you will not see each other anywhere in cozune. Anything they send from now on will not reach you.\n\nYou can undo this in You → Blocked accounts.');

  // ---------- CHAT DETAIL ----------
  static String get chatDetailBack => _tr('chatDetailBack', 'Back');
  static String get chatDetailMoreOptions => _tr('chatDetailMoreOptions', 'More options');
  static String get chatDetailSayHello => _tr('chatDetailSayHello', 'Say hello 👋');
  static String get chatDetailTodayHeader => _tr('chatDetailTodayHeader', 'TODAY');
  static String get chatDetailMessageOptions => _tr('chatDetailMessageOptions', 'Message options');
  static String get chatDetailCopied => _tr('chatDetailCopied', 'Copied');
  static String get chatDetailEditDeletePremium => _tr('chatDetailEditDeletePremium', 'Editing and deleting messages are premium features');
  static String get chatDetailDeleteMsgTitle => _tr('chatDetailDeleteMsgTitle', 'Delete this message?');
  static String get chatDetailDeleteMsgCancel => _tr('chatDetailDeleteMsgCancel', 'Cancel');
  static String get chatDetailDeleteMsgConfirm => _tr('chatDetailDeleteMsgConfirm', 'Delete');
  static String get chatDetailHintText => _tr('chatDetailHintText', 'Say something nice...');
  static String get chatDetailCopyLabel => _tr('chatDetailCopyLabel', 'Copy');
  static String get chatDetailEditLabel => _tr('chatDetailEditLabel', 'Edit');
  static String get chatDetailDeleteLabel => _tr('chatDetailDeleteLabel', 'Delete');
  static String get chatDetailSaveLabel => _tr('chatDetailSaveLabel', 'Save');
  static String get chatDetailSayFirst => _tr('chatDetailSayFirst', 'Say something first');
  static String get chatDetailSendError => _tr('chatDetailSendError', 'Something went wrong. Please try again.');
  static String get chatDetailAccountDeactivated => _tr('chatDetailAccountDeactivated', 'Account deactivated');
  static String get chatDetailActiveNow => _tr('chatDetailActiveNow', 'Active now');
  static String get chatDetailEditMsgTitle => _tr('chatDetailEditMsgTitle', 'Edit message');
  static String get chatDetailEdited => _tr('chatDetailEdited', 'edited');
  static String get chatDetailTyping => _tr('chatDetailTyping', 'typing…');

  static String chatDetailDeleteMsgBody(String name) => _trp(
    'chatDetailDeleteMsgBody',
    'It disappears for both of you. $name will see that a message was deleted, in the place it was.',
    {'name': name},
  );

  static String chatDetailMatchedWith(String name) =>
      _trp('chatDetailMatchedWith', 'You matched with $name', {'name': name});

  static String chatDetailNobodyFirst(String name) => _trp(
    'chatDetailNobodyFirst',
    'Neither of you has said anything yet. Someone has to go first.',
    {'name': name},
  );

  static String chatDetailAndLikedEachOther(String name) => _trp(
    'chatDetailAndLikedEachOther',
    'You and $name liked each other.',
    {'name': name},
  );

  // ---------- MESSAGE LIMIT PAYWALL ----------
  static String get msgLimitUnlocked => _tr('msgLimitUnlocked', 'Unlocked \u2014 send your message again');
  static String get msgLimitAlreadyCounted => _tr('msgLimitAlreadyCounted', 'That one was already counted');
  static String get msgLimitCreditsTitle => _tr('msgLimitCreditsTitle', 'New chats need credits');
  static String get msgLimitUnlimitedLabel => _tr('msgLimitUnlimitedLabel', 'Unlimited new chats with Premium');
  static String get msgLimitFreeBody => _tr('msgLimitFreeBody', 'Free accounts get a few new conversations a day. Replying to ');

  static String msgLimitResetAt(String time) =>
      _trp('msgLimitResetAt', 'New chats reset at $time.', {'time': time});

  static String msgLimitAllUsed(int count) =>
      _trp('msgLimitAllUsed', 'All $count new chats used today', {'count': count});

  static String msgLimitFreeWithCount(int limit) => _trp(
    'msgLimitFreeWithCount',
    'Free accounts can start $limit new conversations a day. Replying to people who already wrote to you is always free.',
    {'limit': limit},
  );

  static String msgLimitCreditCostBody(int cost) => _trp(
    'msgLimitCreditCostBody',
    'Starting a conversation costs $cost ',
    {'cost': cost},
  );

  // ---------- LOCATION SHARING ----------
  static String get locationSharingOff => _tr('locationSharingOff', "Off \u2014 you're not on anyone's map");
  static String get locationSharingEveryone => _tr('locationSharingEveryone', 'Shared with everyone');
  static String get locationSharingAllFriends => _tr('locationSharingAllFriends', 'Shared with all friends');
  static String get locationSharingSelectedFriends => _tr('locationSharingSelectedFriends', 'Selected friends');

  // Location audience screen
  static String get locationAudienceNoFriends => _tr('locationAudienceNoFriends', 'No friends yet');
  static String get locationAudienceNoFriendsBody => _tr('locationAudienceNoFriendsBody', 'A friend is someone you have got talking to. Reply to an opener, or send one, and they will show up here.');
  static String get locationAudienceLoadErrorRetry => _tr('locationAudienceLoadErrorRetry', 'Go back and try again in a moment.');
  static String get locationAudienceSearchHint => _tr('locationAudienceSearchHint', 'Search friends');
  static String get locationAudienceNoResults => _tr('locationAudienceNoResults', 'Nobody by that name');
  static String get locationAudienceNoResultsBody => _tr('locationAudienceNoResultsBody', 'Only people you are vibing with can be picked.');

  static String locationAudienceSaveLabel(int count) => count == 0
      ? _tr('locationAudienceSaveLabelNone', 'Save (nobody)')
      : _trp('locationAudienceSaveLabelMany', 'Save ($count)', {'count': count});

  static String locationSharedWithCount(int count) => _trp(
    'locationSharedWithCount',
    'Shared with $count ${count == 1 ? 'friend' : 'friends'}',
    {'count': count},
  );

  // Live location line
  static String get locationLineOnly => _tr('locationLineOnly', 'Only you can see this. It stays on your device.');
  static String get locationLineSearchingFrom => _tr('locationLineSearchingFrom', 'Radar now searches from here. Pull to refresh it.');
  static String get locationLineMoveRadar => _tr('locationLineMoveRadar', 'Move my radar here');
  static String get locationLineMoving => _tr('locationLineMoving', 'Moving\u2026');
  static String get locationLineLocating => _tr('locationLineLocating', 'Locating\u2026');
  static String get locationLineAllow => _tr('locationLineAllow', 'Allow location to see where you are');
  static String get locationLineUnavailable => _tr('locationLineUnavailable', 'Location unavailable \u2014 tap to retry');

  // ---------- MATCH CELEBRATION ----------
  static String get matchCelebrationSendMessage => _tr('matchCelebrationSendMessage', 'Send a message');
  static String get matchCelebrationKeepBrowsing => _tr('matchCelebrationKeepBrowsing', 'Keep browsing');

  static String matchCelebrationAndLiked(String name) => _trp(
    'matchCelebrationAndLiked',
    'You and $name liked each other.',
    {'name': name},
  );

  static String matchCelebrationSemantic(String name) => _trp(
    'matchCelebrationSemantic',
    "It's a match. You and $name liked each other.",
    {'name': name},
  );

  // ---------- UPLOAD FILE SHEET ----------
  static String get uploadCamera => _tr('uploadCamera', 'Camera');
  static String get uploadCameraSubtitle => _tr('uploadCameraSubtitle', 'Click a photo using camera');
  static String get uploadGallery => _tr('uploadGallery', 'Gallery');
  static String get uploadGallerySubtitle => _tr('uploadGallerySubtitle', 'Select a photo from gallery');

  // ---------- SECURITY BREACH ----------
  static String get securityAlertTitle => _tr('securityAlertTitle', 'Security Alert');
  static String get securityAlertHeadline => _tr('securityAlertHeadline', "This device isn't secure right now");
  static String get securityCheckAgain => _tr('securityCheckAgain', 'Check Again');
  static String get securityResolveAndCheck => _tr('securityResolveAndCheck', 'Resolve the issue(s) above, then tap "Check Again" to continue.');

  // Security risk titles
  static String get securityRiskRooted => _tr('securityRiskRooted', 'Rooted / Jailbroken Device');
  static String get securityRiskRootedBody => _tr('securityRiskRootedBody', 'Your device has elevated (root/jailbreak) access enabled, which can ');
  static String get securityRiskBootloader => _tr('securityRiskBootloader', 'Bootloader Unlocked');
  static String get securityRiskBootloaderBody => _tr('securityRiskBootloaderBody', "Your device's bootloader is unlocked, allowing the operating system ");
  static String get securityRiskDebugger => _tr('securityRiskDebugger', 'Debugger Detected');
  static String get securityRiskHooking => _tr('securityRiskHooking', 'App Hooking Detected');
  static String get securityRiskTampered => _tr('securityRiskTampered', 'App Integrity Compromised');
  static String get securityRiskTamperedBody => _tr('securityRiskTamperedBody', 'This app installation appears to have been modified from its ');
  static String get securityRiskSignature => _tr('securityRiskSignature', 'Invalid App Signature');
  static String get securityRiskSignatureBody => _tr('securityRiskSignatureBody', "This copy of the app doesn't match our verified release signature.");
  static String get securityRiskEmulator => _tr('securityRiskEmulator', 'Emulator Detected');
  static String get securityRiskEmulatorBody => _tr('securityRiskEmulatorBody', 'This app is running on a virtual/emulated device rather than ');
  static String get securityRiskCloned => _tr('securityRiskCloned', 'Cloned App Instance');
  static String get securityRiskClonedBody => _tr('securityRiskClonedBody', 'A duplicate or cloned instance of this app was detected on your ');
  static String get securityRiskScreenRecording => _tr('securityRiskScreenRecording', 'Screen Recording Active');
  static String get securityRiskScreenRecordingBody => _tr('securityRiskScreenRecordingBody', 'Screen recording or mirroring is currently active, which could ');
  static String get securityRiskNoPasscode => _tr('securityRiskNoPasscode', 'Device Passcode Not Set');
  static String get securityRiskNoPasscodeBody => _tr('securityRiskNoPasscodeBody', "Your device doesn't have a screen lock configured. Please set one ");
  static String get securityRiskBuildVerification => _tr('securityRiskBuildVerification', 'App Build Verification Failed');
  static String get securityRiskBuildVerificationBody => _tr('securityRiskBuildVerificationBody', 'This build of the app failed an internal integrity check.');
  static String get securityRiskFakeLocation => _tr('securityRiskFakeLocation', 'Fake Location Detected');
  static String get securityRiskFakeLocationBody => _tr('securityRiskFakeLocationBody', 'A mock/fake GPS location app is active on this device.');
  static String get securityRiskExternalStorage => _tr('securityRiskExternalStorage', 'Installed on External Storage');
  static String get securityRiskExternalStorageBody => _tr('securityRiskExternalStorageBody', 'This app was installed on external/removable storage, which is not ');

  // Security risk messages (from security_service.dart)
  static String get securityMsgRooted => _tr('securityMsgRooted', 'Your device appears to be rooted or jailbroken.');
  static String get securityMsgDebugger => _tr('securityMsgDebugger', 'A debugger is attached to this app.');
  static String get securityMsgDevOptions => _tr('securityMsgDevOptions', 'Developer options or USB debugging is enabled.');
  static String get securityMsgHooking => _tr('securityMsgHooking', 'App hooking activity was detected.');
  static String get securityMsgTampered => _tr('securityMsgTampered', 'This app installation appears to be tampered with.');
  static String get securityMsgIntegrityFailed => _tr('securityMsgIntegrityFailed', 'App integrity check failed.');
  static String get securityMsgCloned => _tr('securityMsgCloned', 'Multiple app instances or a cloned app were detected.');
  static String get securityMsgScreenRecording => _tr('securityMsgScreenRecording', 'Screen recording is active.');
  static String get securityMsgNoPasscode => _tr('securityMsgNoPasscode', 'Your device has no passcode or lock screen set.');
  static String get securityMsgObfuscation => _tr('securityMsgObfuscation', 'App code obfuscation could not be verified.');
  static String get securityMsgMockLocation => _tr('securityMsgMockLocation', 'Mock location is enabled on this device.');
  static String get securityMsgExternalStorage => _tr('securityMsgExternalStorage', 'The app is installed on external storage.');
  static String get securityMsgScreenshot => _tr('securityMsgScreenshot', 'A screenshot was just taken.');
  static String get securityMsgNoHardware => _tr('securityMsgNoHardware', 'Secure hardware storage is unavailable on this device.');
  static String get securityMsgVpn => _tr('securityMsgVpn', 'A VPN connection is active.');
  static String get securityMsgLocationSpoofing => _tr('securityMsgLocationSpoofing', 'Location spoofing was detected.');
  static String get securityMsgUiAutomation => _tr('securityMsgUiAutomation', 'UI automation activity was detected.');
  static String get securityMsgRestored => _tr('securityMsgRestored', 'App data was recently restored or reinstalled.');

  // ---------- COMMON / GENERAL UI ----------
  static String get all => _tr('all', 'All');
  static String get close => _tr('close', 'Close');
  static String get error => _tr('error', 'Error');
  static String get goBack => _tr('goBack', 'Go back');
  static String get identity => _tr('identity', 'Identity');
  static String get interestsAndVibes => _tr('interestsAndVibes', 'Interests & vibes');
  static String get leave => _tr('leave', 'Leave');
  static String get leaveCozune => _tr('leaveCozune', 'Leave cozune?');
  static String get nextPhoto => _tr('nextPhoto', 'Next photo');
  static String get previousPhoto => _tr('previousPhoto', 'Previous photo');
  static String get profileDetails => _tr('profileDetails', 'Profile details');
  static String get removeFile => _tr('removeFile', 'Remove File');
  static String get removePhoto => _tr('removePhoto', 'Remove Photo');
  static String get report => _tr('report', 'Report');
  static String get reportedThankYou => _tr('reportedThankYou', 'Reported — thank you');
  static String get saveChanges => _tr('saveChanges', 'Save changes');
  static String get searchByName => _tr('searchByName', 'Search by name');
  static String get seeAll => _tr('seeAll', 'See all');
  static String get sendOpenerHint => _tr('sendOpenerHint', 'Send an opener...');
  static String get sendOpener => _tr('sendOpener', 'Send opener');
  static String get failedToLoadImage => _tr('failedToLoadImage', 'Failed to load image');
  static String get uploadDocument => _tr('uploadDocument', 'Upload document');
  static String get unsupportedPlatform => _tr('unsupportedPlatform', 'Unsupported Platform');
  static String get zoomIn => _tr('zoomIn', 'Zoom in');
  static String get zoomOut => _tr('zoomOut', 'Zoom out');
  static String get verification => _tr('verification', 'Verification');
  static String get liveLocation => _tr('liveLocation', 'Live location');
  static String get premiumMember => _tr('premiumMember', 'Premium member');

  // ---------- EXPLORE ----------
  static String get exploreBackToMap => _tr('exploreBackToMap', 'Back to the map');
  static String get exploreCenterMap => _tr('exploreCenterMap', 'Center map on your location');
  static String get exploreLoadError => _tr('exploreLoadError', "Couldn't load Explore");
  static String get exploreMapLoadError => _tr('exploreMapLoadError', "Explore map couldn't load");
  static String get exploreMapSemantics => _tr('exploreMapSemantics', 'Explore map. People near you, shown where they roughly are. Pinch to zoom, drag with two fingers to tilt and rotate.');
  static String get exploreNeedsLocation => _tr('exploreNeedsLocation', 'Explore needs your location');
  static String get exploreLoadingMap => _tr('exploreLoadingMap', 'Loading the map…');
  static String get exploreEmptyTitle => _tr('exploreEmptyTitle', 'Nobody on your map yet');
  static String get exploreEmptyBody => _tr('exploreEmptyBody', 'People show up here once you are both talking — when someone replies to you, they appear on the map.');
  static String get showEveryoneOnMap => _tr('showEveryoneOnMap', 'Show everyone on the map');

  // ---------- LOCATION SHARING SCREEN ----------
  static String get whoCanSeeMyLocation => _tr('whoCanSeeMyLocation', 'WHO CAN SEE MY LOCATION');
  static String get locationAudienceEveryone => _tr('locationAudienceEveryone', 'Everyone');
  static String get locationAudienceAnyoneDesc => _tr('locationAudienceAnyoneDesc', 'Anyone who has messaged you, replied or not');
  static String get locationAudienceAllFriends => _tr('locationAudienceAllFriends', 'All friends');
  static String get locationAudienceVibingDesc => _tr('locationAudienceVibingDesc', "Everyone you're vibing with");
  static String get locationAudienceSelectedDesc => _tr('locationAudienceSelectedDesc', 'Only the people you pick');
  static String get locationAudienceNoOne => _tr('locationAudienceNoOne', 'No one');
  static String get turnOffLocationSharing => _tr('turnOffLocationSharing', 'Turn off location sharing');
  static String get shareLiveLocation => _tr('shareLiveLocation', 'Share live location');
  static String get locationFriendsLoadError => _tr('locationFriendsLoadError', "Couldn't load your friends");

  // ---------- YOU / PROFILE SCREEN EXTRA ----------
  static String get youCompleteProfile => _tr('youCompleteProfile', 'Complete your profile');
  static String get youPickThreeWords => _tr('youPickThreeWords', 'Pick your three words');
  static String get youSetKindOfNight => _tr('youSetKindOfNight', 'Set your kind of night');
  static String get yourVibeTitle => _tr('yourVibeTitle', 'Your vibe');
  static String get theirVibe => _tr('theirVibe', 'Their vibe');
  static String get verifyIdentityToSeeMore => _tr('verifyIdentityToSeeMore', 'Verify your identity to see more about them.');
  static String get photoMakeCover => _tr('photoMakeCover', 'Make this my cover photo');
  static String get photoIsCover => _tr('photoIsCover', 'This is your cover photo');
  static String get photoDelete => _tr('photoDelete', 'Delete photo');
  static String get photoDeleteConfirmTitle => _tr('photoDeleteConfirmTitle', 'Delete photo?');

  // ---------- DASHBOARD / RADAR EXTRA ----------
  static String get dashboardLoadError => _tr('dashboardLoadError', "Couldn't load your radar");
  static String get dashboardLocationPromptBody => _tr('dashboardLocationPromptBody', 'cozune needs to know roughly where you are before it can show you who is nearby.');

  // ---------- LIKES & MUTUAL EXTRA ----------
  static String get likesLoadFailed => _tr('likesLoadFailed', "Couldn't load your likes");
  static String get matchesLoadFailed => _tr('matchesLoadFailed', "Couldn't load your matches");
  static String get likesAdNotAvailable => _tr('likesAdNotAvailable', 'Ad not available right now. Try again shortly.');
  static String get likeAdded => _tr('likeAdded', 'Like added');
  static String get watchAdToGetLike => _tr('watchAdToGetLike', 'Watch the whole ad to get the like.');
  static String get unlimitedLikesWithPremium => _tr('unlimitedLikesWithPremium', 'Unlimited likes with Premium');

  // ---------- CHAT / MESSAGING EXTRA ----------
  static String get chatLoadConversationsError => _tr('chatLoadConversationsError', "Couldn't load conversations");
  static String get chatActionBlock => _tr('chatActionBlock', 'Block');
  static String get chatDeleteChat => _tr('chatDeleteChat', 'Delete chat');
  static String get sendFailureTitle => _tr('sendFailureTitle', "Couldn't send");
  static String get sendFailureConnectionDesc => _tr('sendFailureConnectionDesc', 'Check your connection — your message is still here.');
  static String get sendFailureRateLimit => _tr('sendFailureRateLimit', 'Slow down a little');
  static String get verifyToSendMessages => _tr('verifyToSendMessages', 'Verify to send messages');
  static String get messageNotSent => _tr('messageNotSent', 'Message not sent');

  // ---------- NOTIFICATIONS & INTERNET ----------
  static String get noNotificationsYet => _tr('noNotificationsYet', 'You have no notifications yet.');
  static String get youAreOffline => _tr('youAreOffline', "You're Offline");

  // ---------- AUTH & ONBOARDING EXTRA ----------
  static String get loginAcceptTermsWarning => _tr('loginAcceptTermsWarning', 'Please accept the Terms and Privacy Policy to continue.');
  static String get agreeAllTermsWarning => _tr('agreeAllTermsWarning', 'You must agree to all terms to continue');

  // ---------- AUTO-COLLECTED UI STRINGS ----------
  static String get aFriendIsSomeoneYou => _tr('aFriendIsSomeoneYou', 'A friend is someone you have got talking to. Reply to');
  static String get chatsYouArchiveAreKept => _tr('chatsYouArchiveAreKept', 'Chats you archive are kept here, out of your');
  static String get choose => _tr('choose', 'Choose');
  static String get couldntLoadYourArchive => _tr('couldntLoadYourArchive', 'Couldn\'t load your archive');
  static String get couldntSendTheCodeTry => _tr('couldntSendTheCodeTry', 'Couldn\'t send the code. Try again.');
  static String get cozuneNeedsToKnowRoughly => _tr('cozuneNeedsToKnowRoughly', 'cozune needs to know roughly where you are before it can');
  static String get currentAppIsInMaintenance => _tr('currentAppIsInMaintenance', 'Current App is in Maintenance Mode!');
  static String get displayName => _tr('displayName', 'Display name');
  static String get exploreMapPeopleNearYou => _tr('exploreMapPeopleNearYou', 'Explore map. People near you, shown where they roughly are.');
  static String get hardNos2 => _tr('hardNos2', 'Hard no’s');
  static String get keepAnEyeOnYour => _tr('keepAnEyeOnYour', 'Keep an eye on your radar — the people you like can see you');
  static String get man => _tr('man', 'Man');
  static String get manage => _tr('manage', 'Manage');
  static String get membership => _tr('membership', 'Membership');
  static String get mutedMessagesStillArriveQuietly => _tr('mutedMessagesStillArriveQuietly', 'Muted — messages still arrive, quietly');
  static String get nobodyNearbyMatchesTheseFilters => _tr('nobodyNearbyMatchesTheseFilters', 'Nobody nearby matches these filters. Clear a few and');
  static String get openersWaitingForAReply => _tr('openersWaitingForAReply', 'Openers waiting for a reply — yours or theirs —');
  static String get peopleShowUpHereOnce => _tr('peopleShowUpHereOnce', 'People show up here once you are both talking — when someone');
  static String get peopleYouBlockAreListed => _tr('peopleYouBlockAreListed', 'People you block are listed here, so you can');
  static String get privacy => _tr('privacy', 'Privacy');
  static String get signOutOfCozune => _tr('signOutOfCozune', 'Sign out of cozune?');
  static String get theyWillNotBeAble => _tr('theyWillNotBeAble', 'They will not be able to message you, and you will not see each');
  static String get thisPermanentlyDeletesYourAccount => _tr('thisPermanentlyDeletesYourAccount', 'This permanently deletes your account and all of its data.');
  static String get whenSomeoneRepliesToYour => _tr('whenSomeoneRepliesToYour', 'When someone replies to your opener, the');
  static String get whenYouLikeSomeoneWho => _tr('whenYouLikeSomeoneWho', 'When you like someone who already liked you, they');
  static String get youWillBeAbleTo => _tr('youWillBeAbleTo', 'You will be able to see and message each other again. Anything');
  static String get yourProfileAndChatsStay => _tr('yourProfileAndChatsStay', 'Your profile and chats stay as they are. You just');
  static String get findPeople => _tr('findPeople', 'Find people');

  static String get settingsTitle => _tr('settingsTitle', 'Settings');
  static String get offensiveWordsNotAllowed => _tr('offensiveWordsNotAllowed', "Offensive or abusive words aren't allowed on cozune. Reword it and try again.");
  static String get reportModerationPrompt => _tr('reportModerationPrompt', 'What is happening? This goes to our moderation team and they will not know you reported it.');

  static String reportUser(String userName) =>
      _trp('reportUser', 'Report $userName', {'userName': userName});

  static String userBlocked(String userName) =>
      _trp('userBlocked', '$userName blocked', {'userName': userName});

  static String userUnblocked(String userName) =>
      _trp('userUnblocked', '$userName unblocked', {'userName': userName});

  static String waitForUserToReply(String who) =>
      _trp('waitForUserToReply', 'Wait for $who to reply', {'who': who});

  static String sentCapMessagesWithoutAnswer(int cap, String who) => _trp(
    'sentCapMessagesWithoutAnswer',
    "You've sent $cap messages without an answer. You can send more once $who replies.",
    {'cap': cap, 'who': who},
  );

  static String tooManyMessagesRetryAfter(int? seconds) =>
      seconds != null && seconds > 0
          ? _trp(
        'tooManyMessagesRetryAfterSeconds',
        'Too many messages at once. Try again in ${seconds}s.',
        {'seconds': seconds},
      )
          : _tr('tooManyMessagesRetryAfterMoment', 'Too many messages at once. Try again in a moment.');

  static String userNotAvailable(String who) =>
      _trp('userNotAvailable', '$who is not available right now.', {'who': who});

  // ---------- TAG CATEGORIES ----------
  static String get tagCategoryAtmosphere => _tr('tagCategoryAtmosphere', 'Atmosphere');
  static String get tagCategoryYourEnergy => _tr('tagCategoryYourEnergy', 'Your energy');
  static String get tagCategoryWhatYouAreDrawnTo => _tr('tagCategoryWhatYouAreDrawnTo', "What you're drawn to");
  static String get tagCategoryWhatYouAreLookingFor => _tr('tagCategoryWhatYouAreLookingFor', "What you're looking for");
  static String get tagCategoryYourPace => _tr('tagCategoryYourPace', 'Your pace');
  static String get tagCategoryDatingExperience => _tr('tagCategoryDatingExperience', 'Dating experience');
  static String get tagCategoryYourKindOfDate => _tr('tagCategoryYourKindOfDate', 'Your kind of date');
  static String get tagCategoryHardNos => _tr('tagCategoryHardNos', "Hard no's");
  static String get tagCategoryLoadError => _tr('tagCategoryLoadError', "Couldn't load the tag options.");

  // ---------- MISSING FOR OTP & LOGIN ----------
  static String get otpResendIn => _tr('otpResendIn', 'Resend in ');
  static String get otpSentTo => _tr('otpSentTo', 'Enter the 6-digit code we sent to ');
  static String get otpWrongNumber => _tr('otpWrongNumber', 'Wrong number?');
  static String get otpVerifyButton => _tr('otpVerifyButton', 'Verify & Continue');
  static String get loginMeetExactly => _tr('loginMeetExactly', 'Meet exactly\nwho you want.');
  static String get loginRealPeople => _tr('loginRealPeople', 'An exclusive community of real people. No endless swiping, just meaningful connections.');
  static String get loginVerifiedOnly => _tr('loginVerifiedOnly', 'VERIFIED ONLY');
  static String get activeManagePlan => _tr('activeManagePlan', 'Active — manage your plan');
  static String get premiumBenefitSubtitle => _tr('premiumBenefitSubtitle', 'Unlimited likes, every filter, no ads');
  static String get profileVerifiedSubtitle => _tr('profileVerifiedSubtitle', 'Your profile shows the verified tick');
  static String get getVerifiedSubtitle => _tr('getVerifiedSubtitle', 'Get the tick — a 30-second face check');


  // ---------- APP LOCK ----------
  static String get appLockTitle => _tr('appLockTitle', 'App lock');
  static String get appLockSettingSubtitle => _tr('appLockSettingSubtitle', 'Ask for fingerprint, face or device PIN when you reopen cozune');
  static String get appLockLockedTitle => _tr('appLockLockedTitle', 'Cozune is locked');
  static String get appLockLockedBody => _tr('appLockLockedBody', 'Verify it\u2019s you to continue.');
  static String get appLockUnlockButton => _tr('appLockUnlockButton', 'Unlock');
  static String get appLockUnlockReason => _tr('appLockUnlockReason', 'Unlock Cozune');
  static String get appLockEnableReason => _tr('appLockEnableReason', 'Confirm to turn on app lock');
  static String get appLockDisableReason => _tr('appLockDisableReason', 'Confirm to turn off app lock');
  static String get appLockUnsupportedTitle => _tr('appLockUnsupportedTitle', 'App lock unavailable');
  static String get appLockUnsupportedBody => _tr('appLockUnsupportedBody', 'Set a screen lock (PIN, pattern or biometrics) in your phone\u2019s settings first.');
  static String get appLockSecuredNote => _tr('appLockSecuredNote', 'Protected by your device lock');
}