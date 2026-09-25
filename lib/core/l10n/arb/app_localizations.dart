import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_as.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_brx.dart';
import 'app_localizations_de.dart';
import 'app_localizations_doi.dart';
import 'app_localizations_el.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_ha.dart';
import 'app_localizations_he.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_km.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_kok.dart';
import 'app_localizations_ks.dart';
import 'app_localizations_mai.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_mni.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_my.dart';
import 'app_localizations_ne.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_or.dart';
import 'app_localizations_pa.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_sa.dart';
import 'app_localizations_sat.dart';
import 'app_localizations_sd.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_sw.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tl.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'arb/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('as'),
    Locale('bn'),
    Locale('brx'),
    Locale('de'),
    Locale('doi'),
    Locale('el'),
    Locale('en'),
    Locale('es'),
    Locale('fa'),
    Locale('fr'),
    Locale('gu'),
    Locale('ha'),
    Locale('he'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('km'),
    Locale('kn'),
    Locale('ko'),
    Locale('kok'),
    Locale('ks'),
    Locale('mai'),
    Locale('ml'),
    Locale('mni'),
    Locale('mr'),
    Locale('my'),
    Locale('ne'),
    Locale('nl'),
    Locale('or'),
    Locale('pa'),
    Locale('pl'),
    Locale('pt'),
    Locale('ru'),
    Locale('sa'),
    Locale('sat'),
    Locale('sd'),
    Locale('sv'),
    Locale('sw'),
    Locale('ta'),
    Locale('te'),
    Locale('th'),
    Locale('tl'),
    Locale('tr'),
    Locale('uk'),
    Locale('ur'),
    Locale('vi'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Royal Pixels'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @searchLanguage.
  ///
  /// In en, this message translates to:
  /// **'Search language...'**
  String get searchLanguage;

  /// No description provided for @deviceDefault.
  ///
  /// In en, this message translates to:
  /// **'Device Default'**
  String get deviceDefault;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System Language'**
  String get systemLanguage;

  /// No description provided for @currentLanguage.
  ///
  /// In en, this message translates to:
  /// **'Current language'**
  String get currentLanguage;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @setWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Set as Wallpaper'**
  String get setWallpaper;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @premium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @likes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likes;

  /// No description provided for @wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Wallpapers'**
  String get wallpapers;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @social.
  ///
  /// In en, this message translates to:
  /// **'Social Feed'**
  String get social;

  /// No description provided for @myWallpapers.
  ///
  /// In en, this message translates to:
  /// **'My Wallpapers'**
  String get myWallpapers;

  /// No description provided for @diamonds.
  ///
  /// In en, this message translates to:
  /// **'Diamonds'**
  String get diamonds;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @legalPolicy.
  ///
  /// In en, this message translates to:
  /// **'Legal & Policy'**
  String get legalPolicy;

  /// No description provided for @legalInfo.
  ///
  /// In en, this message translates to:
  /// **'Legal Information'**
  String get legalInfo;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get openInBrowser;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @developedBy.
  ///
  /// In en, this message translates to:
  /// **'Developed by Royal Shubham Pixel Labs'**
  String get developedBy;

  /// No description provided for @premiumWallpapers.
  ///
  /// In en, this message translates to:
  /// **'Premium wallpapers for your device'**
  String get premiumWallpapers;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed successfully'**
  String get languageChanged;

  /// No description provided for @deviceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Device Language'**
  String get deviceLanguage;

  /// No description provided for @n20.
  ///
  /// In en, this message translates to:
  /// **'+20💎'**
  String get n20;

  /// No description provided for @n80Diamonds50Bonus30.
  ///
  /// In en, this message translates to:
  /// **'+80 Diamonds  (50 + bonus 30)'**
  String get n80Diamonds50Bonus30;

  /// No description provided for @n4k.
  ///
  /// In en, this message translates to:
  /// **'4K'**
  String get n4k;

  /// No description provided for @n4kUltraHd.
  ///
  /// In en, this message translates to:
  /// **'4K Ultra HD'**
  String get n4kUltraHd;

  /// No description provided for @n5AdsdayResetsAtMidnight15sCooldown20PerAd.
  ///
  /// In en, this message translates to:
  /// **'5 ads/day • Resets at midnight • 15s cooldown • 20 💎 per ad'**
  String get n5AdsdayResetsAtMidnight15sCooldown20PerAd;

  /// No description provided for @n50LanguagesTapToSwitchInstantly.
  ///
  /// In en, this message translates to:
  /// **'50 languages — tap to switch instantly'**
  String get n50LanguagesTapToSwitchInstantly;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get account;

  /// No description provided for @accountApp.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT & APP'**
  String get accountApp;

  /// No description provided for @adminControl.
  ///
  /// In en, this message translates to:
  /// **'ADMIN CONTROL'**
  String get adminControl;

  /// No description provided for @amoledMode.
  ///
  /// In en, this message translates to:
  /// **'AMOLED Mode'**
  String get amoledMode;

  /// No description provided for @appFeel.
  ///
  /// In en, this message translates to:
  /// **'APP FEEL'**
  String get appFeel;

  /// No description provided for @aboutRoyalPixels.
  ///
  /// In en, this message translates to:
  /// **'About Royal Pixels'**
  String get aboutRoyalPixels;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @adminUpload.
  ///
  /// In en, this message translates to:
  /// **'Admin Upload'**
  String get adminUpload;

  /// No description provided for @adminDailyActiveUsersReport.
  ///
  /// In en, this message translates to:
  /// **'Admin — Daily Active Users Report'**
  String get adminDailyActiveUsersReport;

  /// No description provided for @allTheWaysToEarnRoyalDiamonds.
  ///
  /// In en, this message translates to:
  /// **'All the ways to earn Royal Diamonds'**
  String get allTheWaysToEarnRoyalDiamonds;

  /// No description provided for @allWallpapersDesignsAndContentAreOwnedOrLicensedByRoyalShubhamPixelLabsAndAreProtectedUnderApplicableCopyrightLawsTheseWallpapersAreProvidedForPersonalUseOnlyUnauthorizedCopyingReproductionDistributionOrResaleIsStrictlyProhibitednnifYouBelieveAnyContentViolatesCopyrightPleaseContactUsForImmediateRemoval.
  ///
  /// In en, this message translates to:
  /// **'All wallpapers, designs, and content are owned or licensed by Royal Shubham Pixel Labs and are protected under applicable copyright laws. These wallpapers are provided for personal use only. Unauthorized copying, reproduction, distribution, or resale is strictly prohibited.\\n\\nIf you believe any content violates copyright, please contact us for immediate removal.'**
  String
      get allWallpapersDesignsAndContentAreOwnedOrLicensedByRoyalShubhamPixelLabsAndAreProtectedUnderApplicableCopyrightLawsTheseWallpapersAreProvidedForPersonalUseOnlyUnauthorizedCopyingReproductionDistributionOrResaleIsStrictlyProhibitednnifYouBelieveAnyContentViolatesCopyrightPleaseContactUsForImmediateRemoval;

  /// No description provided for @areYouSureYouWantToDeleteThisWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this wallpaper?'**
  String get areYouSureYouWantToDeleteThisWallpaper;

  /// No description provided for @autoDailyWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Auto Daily Wallpaper'**
  String get autoDailyWallpaper;

  /// No description provided for @claim.
  ///
  /// In en, this message translates to:
  /// **'CLAIM'**
  String get claim;

  /// No description provided for @claimDailyReward.
  ///
  /// In en, this message translates to:
  /// **'CLAIM DAILY REWARD'**
  String get claimDailyReward;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'CLEAR ALL'**
  String get clearAll;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @categoryCovers.
  ///
  /// In en, this message translates to:
  /// **'Category Covers'**
  String get categoryCovers;

  /// No description provided for @claim50Diamonds.
  ///
  /// In en, this message translates to:
  /// **'Claim 50 Diamonds'**
  String get claim50Diamonds;

  /// No description provided for @clearAll1.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll1;

  /// No description provided for @clearAllNotifications.
  ///
  /// In en, this message translates to:
  /// **'Clear All Notifications?'**
  String get clearAllNotifications;

  /// No description provided for @comeBackEveryDayToBuildYourStreak.
  ///
  /// In en, this message translates to:
  /// **'Come back every day to build your streak'**
  String get comeBackEveryDayToBuildYourStreak;

  /// No description provided for @comeBackTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow!'**
  String get comeBackTomorrow;

  /// No description provided for @connectingToGooglePlay.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Google Play…'**
  String get connectingToGooglePlay;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @contentType.
  ///
  /// In en, this message translates to:
  /// **'Content Type'**
  String get contentType;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @dailyLimitReachedBackTomorrow.
  ///
  /// In en, this message translates to:
  /// **'DAILY LIMIT REACHED • BACK TOMORROW'**
  String get dailyLimitReachedBackTomorrow;

  /// No description provided for @dailyRewards.
  ///
  /// In en, this message translates to:
  /// **'DAILY REWARDS'**
  String get dailyRewards;

  /// No description provided for @dauDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'DAU data unavailable'**
  String get dauDataUnavailable;

  /// No description provided for @dailyActiveUsers.
  ///
  /// In en, this message translates to:
  /// **'Daily Active Users'**
  String get dailyActiveUsers;

  /// No description provided for @dailyRewardClaimed.
  ///
  /// In en, this message translates to:
  /// **'Daily Reward Claimed!'**
  String get dailyRewardClaimed;

  /// No description provided for @day7Bonus.
  ///
  /// In en, this message translates to:
  /// **'Day 7 Bonus!'**
  String get day7Bonus;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Delete Wallpaper'**
  String get deleteWallpaper;

  /// No description provided for @diamondCost.
  ///
  /// In en, this message translates to:
  /// **'Diamond Cost'**
  String get diamondCost;

  /// No description provided for @diamondStore.
  ///
  /// In en, this message translates to:
  /// **'Diamond Store'**
  String get diamondStore;

  /// No description provided for @diamondsRequiredToUnlockThisWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Diamonds required to unlock this wallpaper'**
  String get diamondsRequiredToUnlockThisWallpaper;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @downloadSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Download Successful'**
  String get downloadSuccessful;

  /// No description provided for @earnDiamonds.
  ///
  /// In en, this message translates to:
  /// **'EARN DIAMONDS'**
  String get earnDiamonds;

  /// No description provided for @elite.
  ///
  /// In en, this message translates to:
  /// **'ELITE'**
  String get elite;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'EXPLORE'**
  String get explore;

  /// No description provided for @editWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Edit Wallpaper'**
  String get editWallpaper;

  /// No description provided for @exploreNow.
  ///
  /// In en, this message translates to:
  /// **'Explore Now'**
  String get exploreNow;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'FAVORITES'**
  String get favorites;

  /// No description provided for @feeds.
  ///
  /// In en, this message translates to:
  /// **'FEEDS'**
  String get feeds;

  /// No description provided for @feed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// No description provided for @gemsCollected.
  ///
  /// In en, this message translates to:
  /// **'Gems Collected!'**
  String get gemsCollected;

  /// No description provided for @getPro.
  ///
  /// In en, this message translates to:
  /// **'Get PRO'**
  String get getPro;

  /// No description provided for @goHome.
  ///
  /// In en, this message translates to:
  /// **'Go Home'**
  String get goHome;

  /// No description provided for @guestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get guestUser;

  /// No description provided for @hapticEngine.
  ///
  /// In en, this message translates to:
  /// **'HAPTIC ENGINE'**
  String get hapticEngine;

  /// No description provided for @hardwareLimitation.
  ///
  /// In en, this message translates to:
  /// **'Hardware Limitation'**
  String get hardwareLimitation;

  /// No description provided for @howManyRequiredToUnlock.
  ///
  /// In en, this message translates to:
  /// **'How many 💎 required to unlock'**
  String get howManyRequiredToUnlock;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @loadingMore.
  ///
  /// In en, this message translates to:
  /// **'LOADING MORE...'**
  String get loadingMore;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get listening;

  /// No description provided for @loginEveryDayToGrowYourStash.
  ///
  /// In en, this message translates to:
  /// **'Login every day to grow your stash'**
  String get loginEveryDayToGrowYourStash;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @membershipWallet.
  ///
  /// In en, this message translates to:
  /// **'MEMBERSHIP & WALLET'**
  String get membershipWallet;

  /// No description provided for @manageCategoryCover.
  ///
  /// In en, this message translates to:
  /// **'Manage Category Cover'**
  String get manageCategoryCover;

  /// No description provided for @manualUpiPaymentsAreTemporarilyClosedForSystemMaintenancePleaseCheckBackLater.
  ///
  /// In en, this message translates to:
  /// **'Manual UPI payments are temporarily closed for system maintenance. Please check back later.'**
  String
      get manualUpiPaymentsAreTemporarilyClosedForSystemMaintenancePleaseCheckBackLater;

  /// No description provided for @markAsPremium.
  ///
  /// In en, this message translates to:
  /// **'Mark as Premium'**
  String get markAsPremium;

  /// No description provided for @newItem.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get newItem;

  /// No description provided for @noSpam.
  ///
  /// In en, this message translates to:
  /// **'No Spam'**
  String get noSpam;

  /// No description provided for @noWallpapersFound.
  ///
  /// In en, this message translates to:
  /// **'No Wallpapers Found'**
  String get noWallpapersFound;

  /// No description provided for @noCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get noCategoriesYet;

  /// No description provided for @noWallpapersFound1.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers found'**
  String get noWallpapersFound1;

  /// No description provided for @nothingToSeeHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing to see here'**
  String get nothingToSeeHere;

  /// No description provided for @optimizeEngine.
  ///
  /// In en, this message translates to:
  /// **'OPTIMIZE ENGINE'**
  String get optimizeEngine;

  /// No description provided for @onetimePaymentNeverExpires.
  ///
  /// In en, this message translates to:
  /// **'One-time payment · Never expires'**
  String get onetimePaymentNeverExpires;

  /// No description provided for @onetimePaymentLifetimeAccessnnoSubscriptionsNoRecurringCharges.
  ///
  /// In en, this message translates to:
  /// **'One-time payment. Lifetime access.\\nNo subscriptions, no recurring charges.'**
  String get onetimePaymentLifetimeAccessnnoSubscriptionsNoRecurringCharges;

  /// No description provided for @openingWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Opening wallpaper...'**
  String get openingWallpaper;

  /// No description provided for @pREMIUMWALLPAPERS.
  ///
  /// In en, this message translates to:
  /// **'P R E M I U M  W A L L P A P E R S'**
  String get pREMIUMWALLPAPERS;

  /// No description provided for @perdayBreakdownLast7Days.
  ///
  /// In en, this message translates to:
  /// **'PER-DAY BREAKDOWN (LAST 7 DAYS)'**
  String get perdayBreakdownLast7Days;

  /// No description provided for @pick.
  ///
  /// In en, this message translates to:
  /// **'PICK'**
  String get pick;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get preferences;

  /// No description provided for @pro.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get pro;

  /// No description provided for @proMembership.
  ///
  /// In en, this message translates to:
  /// **'PRO MEMBERSHIP'**
  String get proMembership;

  /// No description provided for @proMembershipActive.
  ///
  /// In en, this message translates to:
  /// **'PRO MEMBERSHIP ACTIVE'**
  String get proMembershipActive;

  /// No description provided for @paymentsClosed.
  ///
  /// In en, this message translates to:
  /// **'Payments Closed'**
  String get paymentsClosed;

  /// No description provided for @perfectVibesForYourHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'Perfect vibes for your home screen'**
  String get perfectVibesForYourHomeScreen;

  /// No description provided for @pleaseSelectACategoryAndEnterANewName.
  ///
  /// In en, this message translates to:
  /// **'Please select a category and enter a new name!'**
  String get pleaseSelectACategoryAndEnterANewName;

  /// No description provided for @pleaseSelectAnImageFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select an image first!'**
  String get pleaseSelectAnImageFirst;

  /// No description provided for @precisiontunedVibrationPhysicsForRoyalPixels.
  ///
  /// In en, this message translates to:
  /// **'Precision-tuned vibration physics for Royal Pixels'**
  String get precisiontunedVibrationPhysicsForRoyalPixels;

  /// No description provided for @precisiontunedVibrationResponse.
  ///
  /// In en, this message translates to:
  /// **'Precision-tuned vibration response'**
  String get precisiontunedVibrationResponse;

  /// No description provided for @premiumMembership.
  ///
  /// In en, this message translates to:
  /// **'Premium Membership'**
  String get premiumMembership;

  /// No description provided for @premiumBadgeForExclusiveWallpapers.
  ///
  /// In en, this message translates to:
  /// **'Premium badge for exclusive wallpapers'**
  String get premiumBadgeForExclusiveWallpapers;

  /// No description provided for @premiumWallpapersForYourDevice1.
  ///
  /// In en, this message translates to:
  /// **'Premium wallpapers for your device.'**
  String get premiumWallpapersForYourDevice1;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// No description provided for @publishWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Publish Wallpaper'**
  String get publishWallpaper;

  /// No description provided for @purchaseSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Purchase Successful!'**
  String get purchaseSuccessful;

  /// No description provided for @reel.
  ///
  /// In en, this message translates to:
  /// **'REEL'**
  String get reel;

  /// No description provided for @royalCollection.
  ///
  /// In en, this message translates to:
  /// **'ROYAL COLLECTION'**
  String get royalCollection;

  /// No description provided for @royalPixels.
  ///
  /// In en, this message translates to:
  /// **'ROYAL PIXELS'**
  String get royalPixels;

  /// No description provided for @readFullPrivacyPolicyHere.
  ///
  /// In en, this message translates to:
  /// **'Read Full Privacy Policy here'**
  String get readFullPrivacyPolicyHere;

  /// No description provided for @remixWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Remix Wallpaper'**
  String get remixWallpaper;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Remove Wallpaper'**
  String get removeWallpaper;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get removeFromFavorites;

  /// No description provided for @renameCategory.
  ///
  /// In en, this message translates to:
  /// **'Rename Category'**
  String get renameCategory;

  /// No description provided for @requiresCustomToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Requires custom 💎 to unlock'**
  String get requiresCustomToUnlock;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @restrictedUsage.
  ///
  /// In en, this message translates to:
  /// **'Restricted Usage'**
  String get restrictedUsage;

  /// No description provided for @royalPixelsAdminReportConfidentialDoNotDistribute.
  ///
  /// In en, this message translates to:
  /// **'Royal Pixels — Admin Report  •  Confidential  •  Do not distribute'**
  String get royalPixelsAdminReportConfidentialDoNotDistribute;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'SAVED'**
  String get saved;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @searchWallpapers.
  ///
  /// In en, this message translates to:
  /// **'Search Wallpapers...'**
  String get searchWallpapers;

  /// No description provided for @secure.
  ///
  /// In en, this message translates to:
  /// **'Secure'**
  String get secure;

  /// No description provided for @securePaymentViaGooglePlayInstantActivation.
  ///
  /// In en, this message translates to:
  /// **'Secure payment via Google Play · Instant activation'**
  String get securePaymentViaGooglePlayInstantActivation;

  /// No description provided for @selectAnExistingCategoryToRenameThisWillUpdateTheCategoryPropertyOfAllAssociatedWallpapersAndMigrateItsCoverImageIfOneExists.
  ///
  /// In en, this message translates to:
  /// **'Select an existing category to rename. This will update the category property of all associated wallpapers and migrate its cover image if one exists.'**
  String
      get selectAnExistingCategoryToRenameThisWillUpdateTheCategoryPropertyOfAllAssociatedWallpapersAndMigrateItsCoverImageIfOneExists;

  /// No description provided for @sessionProgress.
  ///
  /// In en, this message translates to:
  /// **'Session Progress'**
  String get sessionProgress;

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @setCategoryCover.
  ///
  /// In en, this message translates to:
  /// **'Set Category Cover'**
  String get setCategoryCover;

  /// No description provided for @setting.
  ///
  /// In en, this message translates to:
  /// **'Setting…'**
  String get setting;

  /// No description provided for @showsACyan4kBadgeOnTheWallpaperCard.
  ///
  /// In en, this message translates to:
  /// **'Shows a cyan \"4K\" badge on the wallpaper card'**
  String get showsACyan4kBadgeOnTheWallpaperCard;

  /// No description provided for @showsAmberPickBadgeOnCard.
  ///
  /// In en, this message translates to:
  /// **'Shows amber ★ PICK badge on card'**
  String get showsAmberPickBadgeOnCard;

  /// No description provided for @showsAnAmberPickBadgeOnTheWallpaperCard.
  ///
  /// In en, this message translates to:
  /// **'Shows an amber \"★ PICK\" badge on the wallpaper card'**
  String get showsAnAmberPickBadgeOnTheWallpaperCard;

  /// No description provided for @showsCyan4kBadgeOnCard.
  ///
  /// In en, this message translates to:
  /// **'Shows cyan 4K badge on card'**
  String get showsCyan4kBadgeOnCard;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign In with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInToSyncYourData.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your data'**
  String get signInToSyncYourData;

  /// No description provided for @specialCuratedWallpapersForYou.
  ///
  /// In en, this message translates to:
  /// **'Special curated wallpapers for you'**
  String get specialCuratedWallpapersForYou;

  /// No description provided for @syncYourFavoritesAndProgress.
  ///
  /// In en, this message translates to:
  /// **'Sync your favorites and progress'**
  String get syncYourFavoritesAndProgress;

  /// No description provided for @testImpulse.
  ///
  /// In en, this message translates to:
  /// **'TEST IMPULSE'**
  String get testImpulse;

  /// No description provided for @topUp.
  ///
  /// In en, this message translates to:
  /// **'TOP UP'**
  String get topUp;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @tapAnywhereToClose.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to close'**
  String get tapAnywhereToClose;

  /// No description provided for @tapToChooseCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose cover image'**
  String get tapToChooseCoverImage;

  /// No description provided for @tapToChooseWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose wallpaper'**
  String get tapToChooseWallpaper;

  /// No description provided for @tapToOpen.
  ///
  /// In en, this message translates to:
  /// **'Tap to open'**
  String get tapToOpen;

  /// No description provided for @thenUseThemToUnlockAWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Then use them to unlock a wallpaper'**
  String get thenUseThemToUnlockAWallpaper;

  /// No description provided for @thisActionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get thisActionCannotBeUndone;

  /// No description provided for @thisIsAPreviewHighqualityOriginalImageIsProvidedWhenYouDownloadOrSetAsWallpaper.
  ///
  /// In en, this message translates to:
  /// **'This is a preview. High-quality original image is provided when you download or set as wallpaper.'**
  String
      get thisIsAPreviewHighqualityOriginalImageIsProvidedWhenYouDownloadOrSetAsWallpaper;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @ultraHd4k.
  ///
  /// In en, this message translates to:
  /// **'Ultra HD / 4K'**
  String get ultraHd4k;

  /// No description provided for @unlockEverything.
  ///
  /// In en, this message translates to:
  /// **'Unlock Everything'**
  String get unlockEverything;

  /// No description provided for @unlocking.
  ///
  /// In en, this message translates to:
  /// **'Unlocking…'**
  String get unlocking;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @updatingCategoriesAndProperties.
  ///
  /// In en, this message translates to:
  /// **'Updating categories and properties...'**
  String get updatingCategoriesAndProperties;

  /// No description provided for @uploadingToImagekitFirebase.
  ///
  /// In en, this message translates to:
  /// **'Uploading to ImageKit & Firebase...'**
  String get uploadingToImagekitFirebase;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'VIEW'**
  String get view;

  /// No description provided for @watchEarn.
  ///
  /// In en, this message translates to:
  /// **'WATCH & EARN'**
  String get watchEarn;

  /// No description provided for @watchAdEarn20.
  ///
  /// In en, this message translates to:
  /// **'WATCH AD  •  EARN +20 💎'**
  String get watchAdEarn20;

  /// No description provided for @wallpaperApplied.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper Applied'**
  String get wallpaperApplied;

  /// No description provided for @wallpaperUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper Unlocked!'**
  String get wallpaperUnlocked;

  /// No description provided for @watchAdsEarnDiamondsMax100dayResetsMidnight.
  ///
  /// In en, this message translates to:
  /// **'Watch ads · earn diamonds · max 100/day · resets midnight'**
  String get watchAdsEarnDiamondsMax100dayResetsMidnight;

  /// No description provided for @yourBalance.
  ///
  /// In en, this message translates to:
  /// **'YOUR BALANCE'**
  String get yourBalance;

  /// No description provided for @youCompletedAFullStreakChooseYourBonus.
  ///
  /// In en, this message translates to:
  /// **'You completed a full streak! Choose your bonus:'**
  String get youCompletedAFullStreakChooseYourBonus;

  /// No description provided for @youHaveLifetimeAccessToAllPremiumWallpapersEnjoyRoyalPixelsPro.
  ///
  /// In en, this message translates to:
  /// **'You have lifetime access to all premium wallpapers. Enjoy Royal Pixels PRO!'**
  String get youHaveLifetimeAccessToAllPremiumWallpapersEnjoyRoyalPixelsPro;

  /// No description provided for @youHaveUnlimitedAccessToAllPremiumWallpapersEnjoyYourLifetimeProMembership.
  ///
  /// In en, this message translates to:
  /// **'You have unlimited access to all premium wallpapers. Enjoy your lifetime PRO membership!'**
  String
      get youHaveUnlimitedAccessToAllPremiumWallpapersEnjoyYourLifetimeProMembership;

  /// No description provided for @yourDeviceDoesNotSupportPrecisionHaptics.
  ///
  /// In en, this message translates to:
  /// **'Your device does not support precision haptics.'**
  String get yourDeviceDoesNotSupportPrecisionHaptics;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'users'**
  String get users;

  /// No description provided for @n2026RoyalShubhamPixelLabs.
  ///
  /// In en, this message translates to:
  /// **'© 2026 Royal Shubham Pixel Labs.'**
  String get n2026RoyalShubhamPixelLabs;

  /// No description provided for @claimed.
  ///
  /// In en, this message translates to:
  /// **'✅ Claimed!'**
  String get claimed;

  /// No description provided for @dailyReward.
  ///
  /// In en, this message translates to:
  /// **'🎁 Daily Reward!'**
  String get dailyReward;

  /// No description provided for @day7Bonus1.
  ///
  /// In en, this message translates to:
  /// **'🎁 Day 7 Bonus!'**
  String get day7Bonus1;

  /// No description provided for @lifetimeProOnetimePayment.
  ///
  /// In en, this message translates to:
  /// **'👑  LIFETIME PRO  ·  ONE-TIME PAYMENT'**
  String get lifetimeProOnetimePayment;

  /// No description provided for @youSave90090Off.
  ///
  /// In en, this message translates to:
  /// **'🔥 You save ₹900 — 90% OFF'**
  String get youSave90090Off;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'as',
        'bn',
        'brx',
        'de',
        'doi',
        'el',
        'en',
        'es',
        'fa',
        'fr',
        'gu',
        'ha',
        'he',
        'hi',
        'id',
        'it',
        'ja',
        'km',
        'kn',
        'ko',
        'kok',
        'ks',
        'mai',
        'ml',
        'mni',
        'mr',
        'my',
        'ne',
        'nl',
        'or',
        'pa',
        'pl',
        'pt',
        'ru',
        'sa',
        'sat',
        'sd',
        'sv',
        'sw',
        'ta',
        'te',
        'th',
        'tl',
        'tr',
        'uk',
        'ur',
        'vi',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'as':
      return AppLocalizationsAs();
    case 'bn':
      return AppLocalizationsBn();
    case 'brx':
      return AppLocalizationsBrx();
    case 'de':
      return AppLocalizationsDe();
    case 'doi':
      return AppLocalizationsDoi();
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fa':
      return AppLocalizationsFa();
    case 'fr':
      return AppLocalizationsFr();
    case 'gu':
      return AppLocalizationsGu();
    case 'ha':
      return AppLocalizationsHa();
    case 'he':
      return AppLocalizationsHe();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'km':
      return AppLocalizationsKm();
    case 'kn':
      return AppLocalizationsKn();
    case 'ko':
      return AppLocalizationsKo();
    case 'kok':
      return AppLocalizationsKok();
    case 'ks':
      return AppLocalizationsKs();
    case 'mai':
      return AppLocalizationsMai();
    case 'ml':
      return AppLocalizationsMl();
    case 'mni':
      return AppLocalizationsMni();
    case 'mr':
      return AppLocalizationsMr();
    case 'my':
      return AppLocalizationsMy();
    case 'ne':
      return AppLocalizationsNe();
    case 'nl':
      return AppLocalizationsNl();
    case 'or':
      return AppLocalizationsOr();
    case 'pa':
      return AppLocalizationsPa();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'sa':
      return AppLocalizationsSa();
    case 'sat':
      return AppLocalizationsSat();
    case 'sd':
      return AppLocalizationsSd();
    case 'sv':
      return AppLocalizationsSv();
    case 'sw':
      return AppLocalizationsSw();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
    case 'th':
      return AppLocalizationsTh();
    case 'tl':
      return AppLocalizationsTl();
    case 'tr':
      return AppLocalizationsTr();
    case 'uk':
      return AppLocalizationsUk();
    case 'ur':
      return AppLocalizationsUr();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
