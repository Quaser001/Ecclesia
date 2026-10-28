import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_as.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kha.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('as'),
    Locale('bn'),
    Locale('hi'),
    Locale('kha'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'CalFit'**
  String get appName;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @unknownBrand.
  ///
  /// In en, this message translates to:
  /// **'Unknown brand'**
  String get unknownBrand;

  /// No description provided for @unnamedProduct.
  ///
  /// In en, this message translates to:
  /// **'Unnamed product'**
  String get unnamedProduct;

  /// No description provided for @scanAProduct.
  ///
  /// In en, this message translates to:
  /// **'Scan a product'**
  String get scanAProduct;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get navInsights;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n}m'**
  String timeMinutes(int n);

  /// No description provided for @timeHours.
  ///
  /// In en, this message translates to:
  /// **'{n}h'**
  String timeHours(int n);

  /// No description provided for @timeDays.
  ///
  /// In en, this message translates to:
  /// **'{n}d'**
  String timeDays(int n);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the CalFit server. Check your internet and try again.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'That took too long. Please try again.'**
  String get errorTimeout;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'The CalFit server is having a bad moment. Please try again shortly.'**
  String get errorServer;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that.'**
  String get errorNotFound;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session needs refreshing. Please try again.'**
  String get errorUnauthorized;

  /// No description provided for @errorScanLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s scan limit. It resets at midnight (UTC).'**
  String get errorScanLimit;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorImageOpen.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open that image. Please try another.'**
  String get errorImageOpen;

  /// No description provided for @greetingStillUp.
  ///
  /// In en, this message translates to:
  /// **'Still up'**
  String get greetingStillUp;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @greetingNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get greetingNight;

  /// No description provided for @homeTitleNoName.
  ///
  /// In en, this message translates to:
  /// **'Let\'s check your food'**
  String get homeTitleNoName;

  /// No description provided for @homeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your dashboard'**
  String get homeErrorTitle;

  /// No description provided for @latestScan.
  ///
  /// In en, this message translates to:
  /// **'Latest scan · {when}'**
  String latestScan(String when);

  /// No description provided for @firstScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan your first product'**
  String get firstScanTitle;

  /// No description provided for @firstScanBody.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of the back of any packaged food. We\'ll read the label and tell you how well it fits your profile.'**
  String get firstScanBody;

  /// No description provided for @personaliseTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalise your scores'**
  String get personaliseTitle;

  /// No description provided for @personaliseBody.
  ///
  /// In en, this message translates to:
  /// **'Add your conditions, allergies and goals.'**
  String get personaliseBody;

  /// No description provided for @statScans.
  ///
  /// In en, this message translates to:
  /// **'Scans'**
  String get statScans;

  /// No description provided for @statAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get statAverage;

  /// No description provided for @statBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get statBest;

  /// No description provided for @scoringForYou.
  ///
  /// In en, this message translates to:
  /// **'Scoring for you'**
  String get scoringForYou;

  /// No description provided for @scoringEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet, so scores use general guidance only.'**
  String get scoringEmpty;

  /// No description provided for @allergyChip.
  ///
  /// In en, this message translates to:
  /// **'{name} allergy'**
  String allergyChip(String name);

  /// No description provided for @recentScans.
  ///
  /// In en, this message translates to:
  /// **'Recent scans'**
  String get recentScans;

  /// No description provided for @switchToLight.
  ///
  /// In en, this message translates to:
  /// **'Switch to light mode'**
  String get switchToLight;

  /// No description provided for @switchToDark.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark mode'**
  String get switchToDark;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your history'**
  String get historyErrorTitle;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Every product you scan shows up here with its score, so you can look back at it any time.'**
  String get historyEmptyBody;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle;

  /// No description provided for @insightsErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your insights'**
  String get insightsErrorTitle;

  /// No description provided for @insightsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your trends live here'**
  String get insightsEmptyTitle;

  /// No description provided for @insightsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Scan a few products and you\'ll see your average score, what gets flagged most, and your best picks.'**
  String get insightsEmptyBody;

  /// No description provided for @averageScore.
  ///
  /// In en, this message translates to:
  /// **'average score'**
  String get averageScore;

  /// No description provided for @scanCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 scan} other{{count} scans}}'**
  String scanCount(int count);

  /// No description provided for @weekByWeek.
  ///
  /// In en, this message translates to:
  /// **'Week by week'**
  String get weekByWeek;

  /// No description provided for @weekByWeekBody.
  ///
  /// In en, this message translates to:
  /// **'Average score of what you scanned each week'**
  String get weekByWeekBody;

  /// No description provided for @weekNoScans.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}: no scans'**
  String weekNoScans(String date);

  /// No description provided for @weekSummary.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}: average {score} from {count} scans'**
  String weekSummary(String date, String score, int count);

  /// No description provided for @flaggedMost.
  ///
  /// In en, this message translates to:
  /// **'What gets flagged most'**
  String get flaggedMost;

  /// No description provided for @flaggedMostBody.
  ///
  /// In en, this message translates to:
  /// **'Issues found across your scans'**
  String get flaggedMostBody;

  /// No description provided for @countOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total}'**
  String countOfTotal(int count, int total);

  /// No description provided for @bestPicks.
  ///
  /// In en, this message translates to:
  /// **'Your best picks'**
  String get bestPicks;

  /// No description provided for @secondLook.
  ///
  /// In en, this message translates to:
  /// **'Worth a second look'**
  String get secondLook;

  /// No description provided for @secondLookBody.
  ///
  /// In en, this message translates to:
  /// **'Products that scored low for your profile'**
  String get secondLookBody;

  /// No description provided for @basedOnScans.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Based on your last scan.} other{Based on your last {count} scans.}}'**
  String basedOnScans(int count);

  /// No description provided for @yourGoals.
  ///
  /// In en, this message translates to:
  /// **'Your goals'**
  String get yourGoals;

  /// No description provided for @yourGoalsBody.
  ///
  /// In en, this message translates to:
  /// **'How your scans line up with what you\'re working toward'**
  String get yourGoalsBody;

  /// No description provided for @goalFits.
  ///
  /// In en, this message translates to:
  /// **'{fits} of {checked} scans fit this goal'**
  String goalFits(int fits, int checked);

  /// No description provided for @goalNoData.
  ///
  /// In en, this message translates to:
  /// **'No scans with the details this goal needs yet.'**
  String get goalNoData;

  /// No description provided for @goalNotTracked.
  ///
  /// In en, this message translates to:
  /// **'Not tracked yet. CalFit doesn\'t have a scoring rule for this goal.'**
  String get goalNotTracked;

  /// No description provided for @goalMainIssue.
  ///
  /// In en, this message translates to:
  /// **'Most common issue: {issue}'**
  String goalMainIssue(String issue);

  /// No description provided for @goalChecks.
  ///
  /// In en, this message translates to:
  /// **'Checks: {basis}'**
  String goalChecks(String basis);

  /// No description provided for @addGoalsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add goals in Profile to see how your scans line up with them.'**
  String get addGoalsPrompt;

  /// No description provided for @toTargetLose.
  ///
  /// In en, this message translates to:
  /// **'{kg} kg above your target weight'**
  String toTargetLose(String kg);

  /// No description provided for @toTargetGain.
  ///
  /// In en, this message translates to:
  /// **'{kg} kg below your target weight'**
  String toTargetGain(String kg);

  /// No description provided for @atTarget.
  ///
  /// In en, this message translates to:
  /// **'You\'re at your target weight'**
  String get atTarget;

  /// No description provided for @goal_weight_loss.
  ///
  /// In en, this message translates to:
  /// **'Weight loss'**
  String get goal_weight_loss;

  /// No description provided for @goal_muscle_gain.
  ///
  /// In en, this message translates to:
  /// **'Muscle gain'**
  String get goal_muscle_gain;

  /// No description provided for @goal_maintain_weight.
  ///
  /// In en, this message translates to:
  /// **'Maintain weight'**
  String get goal_maintain_weight;

  /// No description provided for @goal_improve_energy.
  ///
  /// In en, this message translates to:
  /// **'More energy'**
  String get goal_improve_energy;

  /// No description provided for @goal_improve_digestion.
  ///
  /// In en, this message translates to:
  /// **'Better digestion'**
  String get goal_improve_digestion;

  /// No description provided for @goal_reduce_inflammation.
  ///
  /// In en, this message translates to:
  /// **'Less inflammation'**
  String get goal_reduce_inflammation;

  /// No description provided for @goal_manage_blood_sugar.
  ///
  /// In en, this message translates to:
  /// **'Manage blood sugar'**
  String get goal_manage_blood_sugar;

  /// No description provided for @goal_heart_health.
  ///
  /// In en, this message translates to:
  /// **'Heart health'**
  String get goal_heart_health;

  /// No description provided for @condition_diabetes_type_1.
  ///
  /// In en, this message translates to:
  /// **'Type 1 diabetes'**
  String get condition_diabetes_type_1;

  /// No description provided for @condition_diabetes_type_2.
  ///
  /// In en, this message translates to:
  /// **'Type 2 diabetes'**
  String get condition_diabetes_type_2;

  /// No description provided for @condition_prediabetes.
  ///
  /// In en, this message translates to:
  /// **'Prediabetes'**
  String get condition_prediabetes;

  /// No description provided for @condition_hypertension.
  ///
  /// In en, this message translates to:
  /// **'Hypertension'**
  String get condition_hypertension;

  /// No description provided for @condition_high_cholesterol.
  ///
  /// In en, this message translates to:
  /// **'High cholesterol'**
  String get condition_high_cholesterol;

  /// No description provided for @condition_celiac_disease.
  ///
  /// In en, this message translates to:
  /// **'Celiac disease'**
  String get condition_celiac_disease;

  /// No description provided for @condition_ibs.
  ///
  /// In en, this message translates to:
  /// **'IBS'**
  String get condition_ibs;

  /// No description provided for @condition_kidney_disease.
  ///
  /// In en, this message translates to:
  /// **'Kidney disease'**
  String get condition_kidney_disease;

  /// No description provided for @condition_heart_disease.
  ///
  /// In en, this message translates to:
  /// **'Heart disease'**
  String get condition_heart_disease;

  /// No description provided for @condition_obesity.
  ///
  /// In en, this message translates to:
  /// **'Obesity'**
  String get condition_obesity;

  /// No description provided for @condition_lactose_intolerance.
  ///
  /// In en, this message translates to:
  /// **'Lactose intolerance'**
  String get condition_lactose_intolerance;

  /// No description provided for @condition_anaemia.
  ///
  /// In en, this message translates to:
  /// **'Anaemia'**
  String get condition_anaemia;

  /// No description provided for @diet_vegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get diet_vegetarian;

  /// No description provided for @diet_vegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get diet_vegan;

  /// No description provided for @diet_gluten_free.
  ///
  /// In en, this message translates to:
  /// **'Gluten-free'**
  String get diet_gluten_free;

  /// No description provided for @diet_dairy_free.
  ///
  /// In en, this message translates to:
  /// **'Dairy-free'**
  String get diet_dairy_free;

  /// No description provided for @diet_halal.
  ///
  /// In en, this message translates to:
  /// **'Halal'**
  String get diet_halal;

  /// No description provided for @diet_kosher.
  ///
  /// In en, this message translates to:
  /// **'Kosher'**
  String get diet_kosher;

  /// No description provided for @diet_low_carb.
  ///
  /// In en, this message translates to:
  /// **'Low carb'**
  String get diet_low_carb;

  /// No description provided for @diet_keto.
  ///
  /// In en, this message translates to:
  /// **'Keto'**
  String get diet_keto;

  /// No description provided for @diet_paleo.
  ///
  /// In en, this message translates to:
  /// **'Paleo'**
  String get diet_paleo;

  /// No description provided for @suitabilityExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent fit'**
  String get suitabilityExcellent;

  /// No description provided for @suitabilityGood.
  ///
  /// In en, this message translates to:
  /// **'Good fit'**
  String get suitabilityGood;

  /// No description provided for @suitabilityFair.
  ///
  /// In en, this message translates to:
  /// **'Fair fit'**
  String get suitabilityFair;

  /// No description provided for @suitabilityPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor fit'**
  String get suitabilityPoor;

  /// No description provided for @suitabilityNotSuitable.
  ///
  /// In en, this message translates to:
  /// **'Not suitable'**
  String get suitabilityNotSuitable;

  /// No description provided for @suitabilityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get suitabilityUnknown;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @profileErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile'**
  String get profileErrorTitle;

  /// No description provided for @addYourName.
  ///
  /// In en, this message translates to:
  /// **'Add your name'**
  String get addYourName;

  /// No description provided for @introduceYourself.
  ///
  /// In en, this message translates to:
  /// **'Tap the pencil to introduce yourself'**
  String get introduceYourself;

  /// No description provided for @signedInAnonymously.
  ///
  /// In en, this message translates to:
  /// **'Signed in anonymously on this device'**
  String get signedInAnonymously;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get editName;

  /// No description provided for @profileSetup.
  ///
  /// In en, this message translates to:
  /// **'Profile setup'**
  String get profileSetup;

  /// No description provided for @filledOf.
  ///
  /// In en, this message translates to:
  /// **'{filled} of {total}'**
  String filledOf(int filled, int total);

  /// No description provided for @moreAccurate.
  ///
  /// In en, this message translates to:
  /// **'The more you add, the more accurate your scores get.'**
  String get moreAccurate;

  /// No description provided for @sectionGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get sectionGoals;

  /// No description provided for @goalsCaption.
  ///
  /// In en, this message translates to:
  /// **'What are you working toward?'**
  String get goalsCaption;

  /// No description provided for @sectionConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get sectionConditions;

  /// No description provided for @conditionsCaption.
  ///
  /// In en, this message translates to:
  /// **'We lower scores for products that aggravate these.'**
  String get conditionsCaption;

  /// No description provided for @sectionDiet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get sectionDiet;

  /// No description provided for @dietCaption.
  ///
  /// In en, this message translates to:
  /// **'We flag products that break these.'**
  String get dietCaption;

  /// No description provided for @sectionAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get sectionAllergies;

  /// No description provided for @allergiesCaption.
  ///
  /// In en, this message translates to:
  /// **'Anything in these ingredients means we warn you.'**
  String get allergiesCaption;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get nameHint;

  /// No description provided for @allergiesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. peanut, soy'**
  String get allergiesHint;

  /// No description provided for @noAllergies.
  ///
  /// In en, this message translates to:
  /// **'No allergies added.'**
  String get noAllergies;

  /// No description provided for @addAllergy.
  ///
  /// In en, this message translates to:
  /// **'Add allergy'**
  String get addAllergy;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @bodyTitle.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get bodyTitle;

  /// No description provided for @bodyCaption.
  ///
  /// In en, this message translates to:
  /// **'Optional. Used for BMI and to track your goals.'**
  String get bodyCaption;

  /// No description provided for @addBodyDetails.
  ///
  /// In en, this message translates to:
  /// **'Add height, weight and more'**
  String get addBodyDetails;

  /// No description provided for @bodyEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Body details'**
  String get bodyEditTitle;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @targetWeight.
  ///
  /// In en, this message translates to:
  /// **'Target weight'**
  String get targetWeight;

  /// No description provided for @bmi.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get bmi;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @birthYear.
  ///
  /// In en, this message translates to:
  /// **'Year of birth'**
  String get birthYear;

  /// No description provided for @sex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sex;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sexOther;

  /// No description provided for @activityLevel.
  ///
  /// In en, this message translates to:
  /// **'Activity level'**
  String get activityLevel;

  /// No description provided for @activity_sedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get activity_sedentary;

  /// No description provided for @activity_sedentary_hint.
  ///
  /// In en, this message translates to:
  /// **'Desk job, little exercise'**
  String get activity_sedentary_hint;

  /// No description provided for @activity_light.
  ///
  /// In en, this message translates to:
  /// **'Lightly active'**
  String get activity_light;

  /// No description provided for @activity_light_hint.
  ///
  /// In en, this message translates to:
  /// **'Light exercise 1–3 days a week'**
  String get activity_light_hint;

  /// No description provided for @activity_moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderately active'**
  String get activity_moderate;

  /// No description provided for @activity_moderate_hint.
  ///
  /// In en, this message translates to:
  /// **'Exercise 3–5 days a week'**
  String get activity_moderate_hint;

  /// No description provided for @activity_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activity_active;

  /// No description provided for @activity_active_hint.
  ///
  /// In en, this message translates to:
  /// **'Hard exercise 6–7 days a week'**
  String get activity_active_hint;

  /// No description provided for @activity_very_active.
  ///
  /// In en, this message translates to:
  /// **'Very active'**
  String get activity_very_active;

  /// No description provided for @activity_very_active_hint.
  ///
  /// In en, this message translates to:
  /// **'Physical job plus training'**
  String get activity_very_active_hint;

  /// No description provided for @unitCm.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get unitCm;

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{age} yrs'**
  String ageYears(int age);

  /// No description provided for @bmiUnderweight.
  ///
  /// In en, this message translates to:
  /// **'Underweight'**
  String get bmiUnderweight;

  /// No description provided for @bmiNormal.
  ///
  /// In en, this message translates to:
  /// **'Healthy range'**
  String get bmiNormal;

  /// No description provided for @bmiOverweight.
  ///
  /// In en, this message translates to:
  /// **'Overweight'**
  String get bmiOverweight;

  /// No description provided for @bmiObese.
  ///
  /// In en, this message translates to:
  /// **'Obese'**
  String get bmiObese;

  /// No description provided for @bmiNote.
  ///
  /// In en, this message translates to:
  /// **'BMI bands for Asian Indians: 18.5–22.9 healthy, 23–24.9 overweight, 25+ obese.'**
  String get bmiNote;

  /// No description provided for @bmiNeedsBoth.
  ///
  /// In en, this message translates to:
  /// **'Add height and weight to see your BMI.'**
  String get bmiNeedsBoth;

  /// No description provided for @invalidRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a number between {min} and {max}'**
  String invalidRange(String min, String max);

  /// No description provided for @clearValue.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearValue;

  /// No description provided for @prescription.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get prescription;

  /// No description provided for @prescriptionReading.
  ///
  /// In en, this message translates to:
  /// **'Reading your prescription…'**
  String get prescriptionReading;

  /// No description provided for @prescriptionBody.
  ///
  /// In en, this message translates to:
  /// **'Scan one to suggest conditions and allergies. You confirm before anything is saved.'**
  String get prescriptionBody;

  /// No description provided for @prescriptionConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Read a prescription?'**
  String get prescriptionConsentTitle;

  /// No description provided for @prescriptionConsentGemini.
  ///
  /// In en, this message translates to:
  /// **'Your photo is sent to Google Gemini to be read.'**
  String get prescriptionConsentGemini;

  /// No description provided for @prescriptionConsentNoSave.
  ///
  /// In en, this message translates to:
  /// **'CalFit does not save the photo or what is read from it.'**
  String get prescriptionConsentNoSave;

  /// No description provided for @prescriptionConsentSuggestOnly.
  ///
  /// In en, this message translates to:
  /// **'We only suggest conditions and allergies. Nothing is added unless you tick it and confirm.'**
  String get prescriptionConsentSuggestOnly;

  /// No description provided for @prescriptionConsentNotAdvice.
  ///
  /// In en, this message translates to:
  /// **'This is not medical advice. Check every suggestion.'**
  String get prescriptionConsentNotAdvice;

  /// No description provided for @agreeAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get agreeAndContinue;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewTitle;

  /// No description provided for @selectWhatToAdd.
  ///
  /// In en, this message translates to:
  /// **'Select what to add'**
  String get selectWhatToAdd;

  /// No description provided for @addSelected.
  ///
  /// In en, this message translates to:
  /// **'Add selected ({count})'**
  String addSelected(int count);

  /// No description provided for @nothingToAdd.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find anything to add from this photo.'**
  String get nothingToAdd;

  /// No description provided for @tickWhatApplies.
  ///
  /// In en, this message translates to:
  /// **'Tick what applies to you. Nothing is added until you confirm.'**
  String get tickWhatApplies;

  /// No description provided for @inferredFromMedicine.
  ///
  /// In en, this message translates to:
  /// **'Inferred from a medicine ({medicine}). Check this applies to you.'**
  String inferredFromMedicine(String medicine);

  /// No description provided for @statedOnPrescription.
  ///
  /// In en, this message translates to:
  /// **'Stated on the prescription'**
  String get statedOnPrescription;

  /// No description provided for @readNotAdded.
  ///
  /// In en, this message translates to:
  /// **'Read but not added'**
  String get readNotAdded;

  /// No description provided for @newScan.
  ///
  /// In en, this message translates to:
  /// **'New scan'**
  String get newScan;

  /// No description provided for @scanHeadline.
  ///
  /// In en, this message translates to:
  /// **'Photograph the back of the pack'**
  String get scanHeadline;

  /// No description provided for @scanBody.
  ///
  /// In en, this message translates to:
  /// **'Get the ingredients and nutrition table in the frame. We\'ll check it against your conditions, allergies and goals.'**
  String get scanBody;

  /// No description provided for @tapToTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to take a photo'**
  String get tapToTakePhoto;

  /// No description provided for @orPickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Or pick one from your gallery'**
  String get orPickFromGallery;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @checkThisProduct.
  ///
  /// In en, this message translates to:
  /// **'Check this product'**
  String get checkThisProduct;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @tipsTitle.
  ///
  /// In en, this message translates to:
  /// **'For the best result'**
  String get tipsTitle;

  /// No description provided for @tipBackOfPack.
  ///
  /// In en, this message translates to:
  /// **'The front works; the back gives the fullest check'**
  String get tipBackOfPack;

  /// No description provided for @tipLight.
  ///
  /// In en, this message translates to:
  /// **'Good light, no glare on the plastic'**
  String get tipLight;

  /// No description provided for @tipFillFrame.
  ///
  /// In en, this message translates to:
  /// **'Fill the frame with the ingredients and nutrition table'**
  String get tipFillFrame;

  /// No description provided for @stepReadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Reading the label'**
  String get stepReadingLabel;

  /// No description provided for @stepCheckingProfile.
  ///
  /// In en, this message translates to:
  /// **'Checking your profile'**
  String get stepCheckingProfile;

  /// No description provided for @stepWeighing.
  ///
  /// In en, this message translates to:
  /// **'Weighing the findings'**
  String get stepWeighing;

  /// No description provided for @stepAlternatives.
  ///
  /// In en, this message translates to:
  /// **'Finding alternatives'**
  String get stepAlternatives;

  /// No description provided for @scanResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan result'**
  String get scanResultTitle;

  /// No description provided for @scanDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan details'**
  String get scanDetailsTitle;

  /// No description provided for @couldntOpenScan.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this scan'**
  String get couldntOpenScan;

  /// No description provided for @cantReadLabel.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read this label'**
  String get cantReadLabel;

  /// No description provided for @cantReadLabelBody.
  ///
  /// In en, this message translates to:
  /// **'The photo was blurry or the label was out of frame. A clearer, closer shot of the back of the pack usually works.'**
  String get cantReadLabelBody;

  /// No description provided for @tryAnotherPhoto.
  ///
  /// In en, this message translates to:
  /// **'Try another photo'**
  String get tryAnotherPhoto;

  /// No description provided for @scannedWhen.
  ///
  /// In en, this message translates to:
  /// **'Scanned {when}'**
  String scannedWhen(String when);

  /// No description provided for @outOf10.
  ///
  /// In en, this message translates to:
  /// **'out of 10'**
  String get outOf10;

  /// No description provided for @scoreOutOf10.
  ///
  /// In en, this message translates to:
  /// **'Score {score} out of 10'**
  String scoreOutOf10(String score);

  /// No description provided for @whatWeFound.
  ///
  /// In en, this message translates to:
  /// **'What we found ({count})'**
  String whatWeFound(int count);

  /// No description provided for @severityAvoid.
  ///
  /// In en, this message translates to:
  /// **'Avoid'**
  String get severityAvoid;

  /// No description provided for @severityCaution.
  ///
  /// In en, this message translates to:
  /// **'Caution'**
  String get severityCaution;

  /// No description provided for @severityHeadsUp.
  ///
  /// In en, this message translates to:
  /// **'Heads up'**
  String get severityHeadsUp;

  /// No description provided for @severityGoodToKnow.
  ///
  /// In en, this message translates to:
  /// **'Good to know'**
  String get severityGoodToKnow;

  /// No description provided for @pointsLost.
  ///
  /// In en, this message translates to:
  /// **'−{points} pts'**
  String pointsLost(String points);

  /// No description provided for @onTheLabel.
  ///
  /// In en, this message translates to:
  /// **'On the label'**
  String get onTheLabel;

  /// No description provided for @perServingNote.
  ///
  /// In en, this message translates to:
  /// **'Per serving. A dash means it wasn\'t on the label.'**
  String get perServingNote;

  /// No description provided for @nutrientCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get nutrientCalories;

  /// No description provided for @nutrientTotalFat.
  ///
  /// In en, this message translates to:
  /// **'Total fat'**
  String get nutrientTotalFat;

  /// No description provided for @nutrientSaturatedFat.
  ///
  /// In en, this message translates to:
  /// **'Saturated fat'**
  String get nutrientSaturatedFat;

  /// No description provided for @nutrientSodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium'**
  String get nutrientSodium;

  /// No description provided for @nutrientCarbs.
  ///
  /// In en, this message translates to:
  /// **'Total carbs'**
  String get nutrientCarbs;

  /// No description provided for @nutrientSugars.
  ///
  /// In en, this message translates to:
  /// **'Sugars'**
  String get nutrientSugars;

  /// No description provided for @nutrientProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get nutrientProtein;

  /// No description provided for @ingredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// No description provided for @tryInstead.
  ///
  /// In en, this message translates to:
  /// **'Try instead'**
  String get tryInstead;

  /// No description provided for @tryInsteadBody.
  ///
  /// In en, this message translates to:
  /// **'Real products from the same category that suit you better'**
  String get tryInsteadBody;

  /// No description provided for @inOurDatabase.
  ///
  /// In en, this message translates to:
  /// **'In our database'**
  String get inOurDatabase;

  /// No description provided for @noAlternative.
  ///
  /// In en, this message translates to:
  /// **'No better-fit alternative to suggest for this one.'**
  String get noAlternative;

  /// No description provided for @serverTextNote.
  ///
  /// In en, this message translates to:
  /// **'Details from the scan are in English for now.'**
  String get serverTextNote;

  /// No description provided for @disclaimerShort.
  ///
  /// In en, this message translates to:
  /// **'CalFit reads labels; it is not medical advice. Ask a doctor or dietitian for a diagnosis or treatment.'**
  String get disclaimerShort;

  /// No description provided for @disclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'A quick note before you start'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'CalFit scans a product label and tells you how well it fits the profile you set. It cannot replace a doctor or dietitian and it won\'t know everything that is in a food.\n\nAlways read the pack yourself if you have an allergy, and check with your clinician before changing anything in your diet because of a scan.'**
  String get disclaimerBody;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Same as phone'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @textSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get textSizeSmall;

  /// No description provided for @textSizeDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get textSizeDefault;

  /// No description provided for @textSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get textSizeLarge;

  /// No description provided for @textSizeExtraLarge.
  ///
  /// In en, this message translates to:
  /// **'Extra large'**
  String get textSizeExtraLarge;

  /// No description provided for @textSizePreview.
  ///
  /// In en, this message translates to:
  /// **'Masala noodles · 1,172 mg sodium per 100 g'**
  String get textSizePreview;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languagePhone.
  ///
  /// In en, this message translates to:
  /// **'Same as phone'**
  String get languagePhone;

  /// No description provided for @translationNote.
  ///
  /// In en, this message translates to:
  /// **'Translations are being checked by native speakers; some wording may change.'**
  String get translationNote;

  /// No description provided for @privacyAndData.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get privacyAndData;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @deleteMyData.
  ///
  /// In en, this message translates to:
  /// **'Delete my data'**
  String get deleteMyData;

  /// No description provided for @deleteMyDataBody.
  ///
  /// In en, this message translates to:
  /// **'Removes your profile, scans and photos from CalFit\'s servers.'**
  String get deleteMyDataBody;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all your data?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your profile, every scan and every photo will be permanently deleted from CalFit\'s servers. This can\'t be undone.'**
  String get deleteConfirmBody;

  /// No description provided for @deleteConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get deleteConfirmButton;

  /// No description provided for @dataDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your data has been deleted.'**
  String get dataDeleted;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @dataSources.
  ///
  /// In en, this message translates to:
  /// **'Data sources'**
  String get dataSources;

  /// No description provided for @dataSourcesBody.
  ///
  /// In en, this message translates to:
  /// **'Product data from Open Food Facts (openfoodfacts.org), available under the Open Database Licence. BMI bands follow the consensus cut-offs for Asian Indians.'**
  String get dataSourcesBody;

  /// No description provided for @notMedicalAdviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Not medical advice'**
  String get notMedicalAdviceTitle;

  /// No description provided for @viewPhoto.
  ///
  /// In en, this message translates to:
  /// **'View the photo'**
  String get viewPhoto;

  /// No description provided for @onbWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Know what\'s in your food'**
  String get onbWelcomeTitle;

  /// No description provided for @onbWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Photograph the back of any packaged food. CalFit reads the label and tells you how well it fits you.'**
  String get onbWelcomeBody;

  /// No description provided for @onbPointScan.
  ///
  /// In en, this message translates to:
  /// **'Works with Indian packs: biscuits, namkeen, noodles, drinks and more'**
  String get onbPointScan;

  /// No description provided for @onbPointPersonal.
  ///
  /// In en, this message translates to:
  /// **'Scores change with your conditions, allergies and goals'**
  String get onbPointPersonal;

  /// No description provided for @onbPointAlternatives.
  ///
  /// In en, this message translates to:
  /// **'Suggests real, similar products that suit you better'**
  String get onbPointAlternatives;

  /// No description provided for @onbChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onbChooseLanguage;

  /// No description provided for @onbProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us a little about you'**
  String get onbProfileTitle;

  /// No description provided for @onbProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Pick anything that applies. You can change it any time in Profile.'**
  String get onbProfileBody;

  /// No description provided for @onbAllergiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get onbAllergiesTitle;

  /// No description provided for @onbConditionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Health conditions'**
  String get onbConditionsTitle;

  /// No description provided for @onbDietTitle.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get onbDietTitle;

  /// No description provided for @onbSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'One important note'**
  String get onbSafetyTitle;

  /// No description provided for @onbGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onbGetStarted;

  /// No description provided for @onbNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onbNext;

  /// No description provided for @onbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onbSkip;

  /// No description provided for @onbStep.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onbStep(int current, int total);

  /// No description provided for @allergy_peanut.
  ///
  /// In en, this message translates to:
  /// **'Peanut'**
  String get allergy_peanut;

  /// No description provided for @allergy_milk.
  ///
  /// In en, this message translates to:
  /// **'Milk'**
  String get allergy_milk;

  /// No description provided for @allergy_gluten.
  ///
  /// In en, this message translates to:
  /// **'Gluten'**
  String get allergy_gluten;

  /// No description provided for @allergy_soy.
  ///
  /// In en, this message translates to:
  /// **'Soy'**
  String get allergy_soy;

  /// No description provided for @allergy_egg.
  ///
  /// In en, this message translates to:
  /// **'Egg'**
  String get allergy_egg;

  /// No description provided for @allergy_tree_nuts.
  ///
  /// In en, this message translates to:
  /// **'Tree nuts'**
  String get allergy_tree_nuts;

  /// No description provided for @nutrientSalt.
  ///
  /// In en, this message translates to:
  /// **'Salt'**
  String get nutrientSalt;

  /// No description provided for @atAGlance.
  ///
  /// In en, this message translates to:
  /// **'At a glance'**
  String get atAGlance;

  /// No description provided for @levelsPer100g.
  ///
  /// In en, this message translates to:
  /// **'Per 100 g, on the standard traffic-light scale. The same for everyone.'**
  String get levelsPer100g;

  /// No description provided for @levelsPer100ml.
  ///
  /// In en, this message translates to:
  /// **'Per 100 ml, on the standard traffic-light scale. The same for everyone.'**
  String get levelsPer100ml;

  /// No description provided for @levelLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get levelLow;

  /// No description provided for @levelMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get levelMedium;

  /// No description provided for @levelHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get levelHigh;

  /// No description provided for @feedbackQuestion.
  ///
  /// In en, this message translates to:
  /// **'Was this result right?'**
  String get feedbackQuestion;

  /// No description provided for @feedbackWhy.
  ///
  /// In en, this message translates to:
  /// **'Your answer helps us check how accurate CalFit is.'**
  String get feedbackWhy;

  /// No description provided for @feedbackYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get feedbackYes;

  /// No description provided for @feedbackNo.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get feedbackNo;

  /// No description provided for @feedbackWhatWrong.
  ///
  /// In en, this message translates to:
  /// **'What was wrong?'**
  String get feedbackWhatWrong;

  /// No description provided for @issueWrongProduct.
  ///
  /// In en, this message translates to:
  /// **'Wrong product'**
  String get issueWrongProduct;

  /// No description provided for @issueWrongNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition numbers'**
  String get issueWrongNutrition;

  /// No description provided for @issueWrongIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get issueWrongIngredients;

  /// No description provided for @issueMissedAllergen.
  ///
  /// In en, this message translates to:
  /// **'Missed an allergen'**
  String get issueMissedAllergen;

  /// No description provided for @issueScoreUnfair.
  ///
  /// In en, this message translates to:
  /// **'Score feels wrong'**
  String get issueScoreUnfair;

  /// No description provided for @issueOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get issueOther;

  /// No description provided for @feedbackSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get feedbackSend;

  /// No description provided for @feedbackThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you. This helps us get better.'**
  String get feedbackThanks;

  /// No description provided for @feedbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send that. Check your connection and try again.'**
  String get feedbackFailed;

  /// No description provided for @pickerConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Is this the product?'**
  String get pickerConfirmTitle;

  /// No description provided for @pickerChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Which one is it?'**
  String get pickerChooseTitle;

  /// No description provided for @pickerReadAs.
  ///
  /// In en, this message translates to:
  /// **'We read “{text}” on the pack.'**
  String pickerReadAs(String text);

  /// No description provided for @pickerYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, that\'s it'**
  String get pickerYes;

  /// No description provided for @pickerNoRetake.
  ///
  /// In en, this message translates to:
  /// **'No, retake the photo'**
  String get pickerNoRetake;

  /// No description provided for @pickerNoneRetake.
  ///
  /// In en, this message translates to:
  /// **'None of these, retake'**
  String get pickerNoneRetake;

  /// No description provided for @sourceOpenFoodFacts.
  ///
  /// In en, this message translates to:
  /// **'Open Food Facts'**
  String get sourceOpenFoodFacts;

  /// No description provided for @sourceCalfitDb.
  ///
  /// In en, this message translates to:
  /// **'CalFit database'**
  String get sourceCalfitDb;

  /// No description provided for @retakeHint.
  ///
  /// In en, this message translates to:
  /// **'Take the photo again with the product name in view, or photograph the back of the pack.'**
  String get retakeHint;

  /// No description provided for @identifiedAs.
  ///
  /// In en, this message translates to:
  /// **'Identified as {name}'**
  String identifiedAs(String name);

  /// No description provided for @identifiedSource.
  ///
  /// In en, this message translates to:
  /// **'Nutrition per 100 g/ml from {source}'**
  String identifiedSource(String source);

  /// No description provided for @notThisProduct.
  ///
  /// In en, this message translates to:
  /// **'Not this product?'**
  String get notThisProduct;

  /// No description provided for @removeScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this scan?'**
  String get removeScanTitle;

  /// No description provided for @removeScanBody.
  ///
  /// In en, this message translates to:
  /// **'It will be deleted from your history so you can take the photo again.'**
  String get removeScanBody;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @scanRemoved.
  ///
  /// In en, this message translates to:
  /// **'Scan removed. Tap Scan to try again.'**
  String get scanRemoved;

  /// No description provided for @couldntRemove.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove the scan. Try again.'**
  String get couldntRemove;

  /// No description provided for @servingUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Serving size unknown'**
  String get servingUnknownTitle;

  /// No description provided for @servingUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'This label\'s numbers don\'t say whether they\'re per 100 g/ml or per serving. Check the pack and add the serving size; we\'ll use it the next time you scan this product.'**
  String get servingUnknownBody;

  /// No description provided for @addServingSize.
  ///
  /// In en, this message translates to:
  /// **'Add serving size'**
  String get addServingSize;

  /// No description provided for @servingSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Serving size'**
  String get servingSheetTitle;

  /// No description provided for @servingAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'One serving (g or ml)'**
  String get servingAmountLabel;

  /// No description provided for @servingAmountHelp.
  ///
  /// In en, this message translates to:
  /// **'On the pack, look for “serving size” or the net quantity.'**
  String get servingAmountHelp;

  /// No description provided for @servingBasisLabel.
  ///
  /// In en, this message translates to:
  /// **'The numbers on the label are'**
  String get servingBasisLabel;

  /// No description provided for @basisPer100.
  ///
  /// In en, this message translates to:
  /// **'Per 100 g/ml'**
  String get basisPer100;

  /// No description provided for @basisPerServing.
  ///
  /// In en, this message translates to:
  /// **'Per serving'**
  String get basisPerServing;

  /// No description provided for @servingSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {amount} g/ml per serving. We\'ll use it the next time you scan this product.'**
  String servingSaved(String amount);

  /// No description provided for @servingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Check your connection and try again.'**
  String get servingSaveFailed;

  /// No description provided for @labelNotePer100.
  ///
  /// In en, this message translates to:
  /// **'Per 100 g/ml, from {source}. A dash means it isn\'t known.'**
  String labelNotePer100(String source);

  /// No description provided for @labelNoteYourServing.
  ///
  /// In en, this message translates to:
  /// **'Per serving of {amount} g/ml, the serving size you saved.'**
  String labelNoteYourServing(String amount);

  /// No description provided for @confirmingProduct.
  ///
  /// In en, this message translates to:
  /// **'Checking this product…'**
  String get confirmingProduct;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['as', 'bn', 'en', 'hi', 'kha'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'as':
      return AppLocalizationsAs();
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'kha':
      return AppLocalizationsKha();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
