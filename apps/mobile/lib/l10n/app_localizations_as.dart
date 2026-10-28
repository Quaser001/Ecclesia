// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Assamese (`as`).
class AppLocalizationsAs extends AppLocalizations {
  AppLocalizationsAs([String locale = 'as']) : super(locale);

  @override
  String get appName => 'CalFit';

  @override
  String get tryAgain => 'আকৌ চেষ্টা কৰক';

  @override
  String get cancel => 'বাতিল';

  @override
  String get save => 'ছেভ কৰক';

  @override
  String get done => 'হ\'ল';

  @override
  String get edit => 'সলনি কৰক';

  @override
  String get add => 'যোগ কৰক';

  @override
  String get close => 'বন্ধ কৰক';

  @override
  String get back => 'উভতি যাওক';

  @override
  String get seeAll => 'সকলো চাওক';

  @override
  String get saved => 'ছেভ হ\'ল';

  @override
  String get notSet => 'দিয়া হোৱা নাই';

  @override
  String get unknownBrand => 'ব্ৰেণ্ড অজ্ঞাত';

  @override
  String get unnamedProduct => 'নামহীন সামগ্ৰী';

  @override
  String get scanAProduct => 'সামগ্ৰী স্কেন কৰক';

  @override
  String get navHome => 'হোম';

  @override
  String get navHistory => 'ইতিহাস';

  @override
  String get navInsights => 'ইনছাইটছ';

  @override
  String get navProfile => 'প্ৰফাইল';

  @override
  String get timeJustNow => 'এইমাত্ৰ';

  @override
  String timeMinutes(int n) {
    return '$n মি.';
  }

  @override
  String timeHours(int n) {
    return '$n ঘ.';
  }

  @override
  String timeDays(int n) {
    return '$n দিন';
  }

  @override
  String get today => 'আজি';

  @override
  String get yesterday => 'কালি';

  @override
  String get errorNetwork =>
      'CalFit ছাৰ্ভাৰলৈ যাব পৰা নাই। ইণ্টাৰনেট চাই আকৌ চেষ্টা কৰক।';

  @override
  String get errorTimeout => 'বহুত সময় লাগিল। আকৌ চেষ্টা কৰক।';

  @override
  String get errorServer =>
      'CalFit ছাৰ্ভাৰত এতিয়া সমস্যা হৈছে। অলপ পিছত চেষ্টা কৰক।';

  @override
  String get errorNotFound => 'এইটো পোৱা নগ\'ল।';

  @override
  String get errorUnauthorized =>
      'আপোনাৰ ছেছন ৰিফ্ৰেছ কৰিব লাগিব। আকৌ চেষ্টা কৰক।';

  @override
  String get errorScanLimit =>
      'আজিৰ স্কেনৰ সীমা শেষ হ\'ল। মাজনিশা (UTC) পুনৰ আৰম্ভ হ\'ব।';

  @override
  String get errorGeneric => 'কিবা ভুল হ\'ল। আকৌ চেষ্টা কৰক।';

  @override
  String get errorImageOpen => 'ছবিখন খুলিব পৰা নগ\'ল। আন এখন বাছি লওক।';

  @override
  String get greetingStillUp => 'এতিয়াও সাৰে আছে';

  @override
  String get greetingMorning => 'শুভ ৰাতিপুৱা';

  @override
  String get greetingAfternoon => 'শুভ দুপৰীয়া';

  @override
  String get greetingEvening => 'শুভ সন্ধিয়া';

  @override
  String get greetingNight => 'শুভ ৰাতি';

  @override
  String get homeTitleNoName => 'আহক খাদ্য পৰীক্ষা কৰোঁ';

  @override
  String get homeErrorTitle => 'ডেশ্বব\'ৰ্ড লোড হোৱা নাই';

  @override
  String latestScan(String when) {
    return 'শেহতীয়া স্কেন · $when';
  }

  @override
  String get firstScanTitle => 'আপোনাৰ প্ৰথম সামগ্ৰী স্কেন কৰক';

  @override
  String get firstScanBody =>
      'যিকোনো পেকেটযুক্ত খাদ্যৰ পিছফালৰ ছবি তোলক। আমি লেবেল পঢ়ি ক\'ম ই আপোনাৰ প্ৰফাইলৰ বাবে কিমান উপযুক্ত।';

  @override
  String get personaliseTitle => 'স্ক\'ৰ নিজৰ মতে কৰক';

  @override
  String get personaliseBody => 'আপোনাৰ ৰোগ, এলাৰ্জী আৰু লক্ষ্য যোগ কৰক।';

  @override
  String get statScans => 'স্কেন';

  @override
  String get statAverage => 'গড়';

  @override
  String get statBest => 'শ্ৰেষ্ঠ';

  @override
  String get scoringForYou => 'আপোনাৰ বাবে স্ক\'ৰিং';

  @override
  String get scoringEmpty =>
      'এতিয়াও একো যোগ কৰা হোৱা নাই, সেয়ে স্ক\'ৰ সাধাৰণ নিৰ্দেশনা অনুসৰি।';

  @override
  String allergyChip(String name) {
    return '$nameত এলাৰ্জী';
  }

  @override
  String get recentScans => 'শেহতীয়া স্কেন';

  @override
  String get switchToLight => 'লাইট ম\'ডলৈ যাওক';

  @override
  String get switchToDark => 'ডাৰ্ক ম\'ডলৈ যাওক';

  @override
  String get historyTitle => 'ইতিহাস';

  @override
  String get historyErrorTitle => 'ইতিহাস লোড হোৱা নাই';

  @override
  String get historyEmptyTitle => 'ইয়াত এতিয়াও একো নাই';

  @override
  String get historyEmptyBody =>
      'আপুনি যি স্কেন কৰিব সেয়া স্ক\'ৰৰ সৈতে ইয়াত থাকিব, যেতিয়াই মন যায় চাব পাৰিব।';

  @override
  String get insightsTitle => 'ইনছাইটছ';

  @override
  String get insightsErrorTitle => 'ইনছাইটছ লোড হোৱা নাই';

  @override
  String get insightsEmptyTitle => 'আপোনাৰ প্ৰৱণতা ইয়াত দেখা যাব';

  @override
  String get insightsEmptyBody =>
      'কেইটামান সামগ্ৰী স্কেন কৰক, তাৰ পিছত গড় স্ক\'ৰ, আটাইতকৈ বেছি ধৰা পৰা কথা আৰু আপোনাৰ ভাল বাছনি দেখিব।';

  @override
  String get averageScore => 'গড় স্ক\'ৰ';

  @override
  String scanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটা স্কেন',
      one: '1টা স্কেন',
    );
    return '$_temp0';
  }

  @override
  String get weekByWeek => 'সপ্তাহে সপ্তাহে';

  @override
  String get weekByWeekBody => 'প্ৰতি সপ্তাহত স্কেন কৰা সামগ্ৰীৰ গড় স্ক\'ৰ';

  @override
  String weekNoScans(String date) {
    return '$dateৰ সপ্তাহ: কোনো স্কেন নাই';
  }

  @override
  String weekSummary(String date, String score, int count) {
    return '$dateৰ সপ্তাহ: $countটা স্কেনৰ গড় $score';
  }

  @override
  String get flaggedMost => 'আটাইতকৈ বেছি যি ধৰা পৰে';

  @override
  String get flaggedMostBody => 'আপোনাৰ স্কেনত পোৱা সমস্যা';

  @override
  String countOfTotal(int count, int total) {
    return '$totalটাৰ ভিতৰত $count';
  }

  @override
  String get bestPicks => 'আপোনাৰ শ্ৰেষ্ঠ বাছনি';

  @override
  String get secondLook => 'আকৌ এবাৰ চোৱাৰ যোগ্য';

  @override
  String get secondLookBody => 'যিবোৰ সামগ্ৰীৰ স্ক\'ৰ আপোনাৰ প্ৰফাইলৰ বাবে কম';

  @override
  String basedOnScans(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'আপোনাৰ শেষৰ $countটা স্কেনৰ ভিত্তিত।',
      one: 'আপোনাৰ শেষৰ স্কেনৰ ভিত্তিত।',
    );
    return '$_temp0';
  }

  @override
  String get yourGoals => 'আপোনাৰ লক্ষ্য';

  @override
  String get yourGoalsBody => 'আপোনাৰ স্কেন লক্ষ্যৰ সৈতে কিমান মিলে';

  @override
  String goalFits(int fits, int checked) {
    return '$checkedটাৰ ভিতৰত $fitsটা স্কেন এই লক্ষ্যৰ সৈতে মিলে';
  }

  @override
  String get goalNoData =>
      'এই লক্ষ্যৰ বাবে লাগতিয়াল তথ্য থকা কোনো স্কেন এতিয়াও নাই।';

  @override
  String get goalNotTracked =>
      'এতিয়াও ট্ৰেক কৰা নহয়। এই লক্ষ্যৰ বাবে CalFit-ত কোনো নিয়ম নাই।';

  @override
  String goalMainIssue(String issue) {
    return 'আটাইতকৈ সাধাৰণ সমস্যা: $issue';
  }

  @override
  String goalChecks(String basis) {
    return 'পৰীক্ষা: $basis';
  }

  @override
  String get addGoalsPrompt =>
      'প্ৰফাইলত লক্ষ্য যোগ কৰক, তেতিয়া আপোনাৰ স্কেন সেইবোৰৰ সৈতে কিমান মিলে চাব পাৰিব।';

  @override
  String toTargetLose(String kg) {
    return 'লক্ষ্য ওজনতকৈ $kg kg বেছি';
  }

  @override
  String toTargetGain(String kg) {
    return 'লক্ষ্য ওজনতকৈ $kg kg কম';
  }

  @override
  String get atTarget => 'আপুনি লক্ষ্য ওজনত আছে';

  @override
  String get goal_weight_loss => 'ওজন কমোৱা';

  @override
  String get goal_muscle_gain => 'মাংসপেশী বঢ়োৱা';

  @override
  String get goal_maintain_weight => 'ওজন বজাই ৰখা';

  @override
  String get goal_improve_energy => 'বেছি শক্তি';

  @override
  String get goal_improve_digestion => 'ভাল হজম';

  @override
  String get goal_reduce_inflammation => 'কম প্ৰদাহ';

  @override
  String get goal_manage_blood_sugar => 'তেজত চেনি নিয়ন্ত্ৰণ';

  @override
  String get goal_heart_health => 'হৃদযন্ত্ৰৰ স্বাস্থ্য';

  @override
  String get condition_diabetes_type_1 => 'টাইপ ১ ডায়েবেটিছ';

  @override
  String get condition_diabetes_type_2 => 'টাইপ ২ ডায়েবেটিছ';

  @override
  String get condition_prediabetes => 'প্ৰিডায়েবেটিছ';

  @override
  String get condition_hypertension => 'উচ্চ ৰক্তচাপ';

  @override
  String get condition_high_cholesterol => 'উচ্চ কলেষ্টেৰল';

  @override
  String get condition_celiac_disease => 'চিলিয়াক ৰোগ';

  @override
  String get condition_ibs => 'IBS';

  @override
  String get condition_kidney_disease => 'বৃক্কৰ ৰোগ';

  @override
  String get condition_heart_disease => 'হৃদৰোগ';

  @override
  String get condition_obesity => 'স্থূলতা';

  @override
  String get condition_lactose_intolerance => 'লেক্টোজ ইনটলাৰেন্স';

  @override
  String get condition_anaemia => 'ৰক্তহীনতা';

  @override
  String get diet_vegetarian => 'নিৰামিষ';

  @override
  String get diet_vegan => 'ভিগান';

  @override
  String get diet_gluten_free => 'গ্লুটেন-মুক্ত';

  @override
  String get diet_dairy_free => 'গাখীৰ-মুক্ত';

  @override
  String get diet_halal => 'হালাল';

  @override
  String get diet_kosher => 'কোশ্বাৰ';

  @override
  String get diet_low_carb => 'ল\' কাৰ্ব';

  @override
  String get diet_keto => 'কিট\'';

  @override
  String get diet_paleo => 'পেলিঅ\'';

  @override
  String get suitabilityExcellent => 'অতি ভাল মিল';

  @override
  String get suitabilityGood => 'ভাল মিল';

  @override
  String get suitabilityFair => 'মজলীয়া মিল';

  @override
  String get suitabilityPoor => 'দুৰ্বল মিল';

  @override
  String get suitabilityNotSuitable => 'উপযুক্ত নহয়';

  @override
  String get suitabilityUnknown => 'অজ্ঞাত';

  @override
  String get profileTitle => 'প্ৰফাইল';

  @override
  String get settingsTooltip => 'ছেটিংছ';

  @override
  String get profileErrorTitle => 'প্ৰফাইল লোড হোৱা নাই';

  @override
  String get addYourName => 'আপোনাৰ নাম যোগ কৰক';

  @override
  String get introduceYourself => 'চিনাকি দিবলৈ পেঞ্চিলত টেপ কৰক';

  @override
  String get signedInAnonymously => 'এই ডিভাইচত নাম নোহোৱাকৈ ছাইন ইন কৰা';

  @override
  String get editName => 'নাম সলনি কৰক';

  @override
  String get profileSetup => 'প্ৰফাইল ছেটআপ';

  @override
  String filledOf(int filled, int total) {
    return '$totalটাৰ ভিতৰত $filled';
  }

  @override
  String get moreAccurate => 'যিমান বেছি যোগ কৰিব, স্ক\'ৰ সিমান সঠিক হ\'ব।';

  @override
  String get sectionGoals => 'লক্ষ্য';

  @override
  String get goalsCaption => 'আপুনি কিহৰ বাবে চেষ্টা কৰি আছে?';

  @override
  String get sectionConditions => 'ৰোগ';

  @override
  String get conditionsCaption => 'এইবোৰ বঢ়োৱা সামগ্ৰীৰ স্ক\'ৰ আমি কমাই দিওঁ।';

  @override
  String get sectionDiet => 'আহাৰ';

  @override
  String get dietCaption => 'এইবোৰ ভঙা সামগ্ৰী আমি চিহ্নিত কৰোঁ।';

  @override
  String get sectionAllergies => 'এলাৰ্জী';

  @override
  String get allergiesCaption => 'উপাদানত ইয়াৰ কিবা থাকিলে আমি সতৰ্ক কৰোঁ।';

  @override
  String get yourName => 'আপোনাৰ নাম';

  @override
  String get nameHint => 'আপোনাক কি নামেৰে মাতিম?';

  @override
  String get allergiesHint => 'যেনে বাদাম, ছয়া';

  @override
  String get noAllergies => 'কোনো এলাৰ্জী যোগ কৰা হোৱা নাই।';

  @override
  String get addAllergy => 'এলাৰ্জী যোগ কৰক';

  @override
  String get takePhoto => 'ছবি তোলক';

  @override
  String get chooseFromGallery => 'গেলেৰীৰ পৰা বাছক';

  @override
  String get bodyTitle => 'শৰীৰ';

  @override
  String get bodyCaption => 'ঐচ্ছিক। BMI আৰু লক্ষ্য ট্ৰেক কৰিবলৈ ব্যৱহাৰ হয়।';

  @override
  String get addBodyDetails => 'উচ্চতা, ওজন আৰু অধিক যোগ কৰক';

  @override
  String get bodyEditTitle => 'শৰীৰৰ তথ্য';

  @override
  String get height => 'উচ্চতা';

  @override
  String get weight => 'ওজন';

  @override
  String get targetWeight => 'লক্ষ্য ওজন';

  @override
  String get bmi => 'BMI';

  @override
  String get age => 'বয়স';

  @override
  String get birthYear => 'জন্মৰ বছৰ';

  @override
  String get sex => 'লিংগ';

  @override
  String get sexFemale => 'মহিলা';

  @override
  String get sexMale => 'পুৰুষ';

  @override
  String get sexOther => 'অন্য';

  @override
  String get activityLevel => 'সক্ৰিয়তাৰ স্তৰ';

  @override
  String get activity_sedentary => 'কম সক্ৰিয়';

  @override
  String get activity_sedentary_hint => 'বহি কাম, ব্যায়াম অতি কম';

  @override
  String get activity_light => 'অলপ সক্ৰিয়';

  @override
  String get activity_light_hint => 'সপ্তাহত ১–৩ দিন পাতল ব্যায়াম';

  @override
  String get activity_moderate => 'মধ্যমীয়াকৈ সক্ৰিয়';

  @override
  String get activity_moderate_hint => 'সপ্তাহত ৩–৫ দিন ব্যায়াম';

  @override
  String get activity_active => 'সক্ৰিয়';

  @override
  String get activity_active_hint => 'সপ্তাহত ৬–৭ দিন কঠোৰ ব্যায়াম';

  @override
  String get activity_very_active => 'অতি সক্ৰিয়';

  @override
  String get activity_very_active_hint => 'শাৰীৰিক কাম আৰু প্ৰশিক্ষণ';

  @override
  String get unitCm => 'cm';

  @override
  String get unitKg => 'kg';

  @override
  String ageYears(int age) {
    return '$age বছৰ';
  }

  @override
  String get bmiUnderweight => 'কম ওজন';

  @override
  String get bmiNormal => 'স্বাস্থ্যকৰ সীমা';

  @override
  String get bmiOverweight => 'বেছি ওজন';

  @override
  String get bmiObese => 'স্থূলতা';

  @override
  String get bmiNote =>
      'ভাৰতীয়ৰ বাবে BMI সীমা: 18.5–22.9 স্বাস্থ্যকৰ, 23–24.9 বেছি ওজন, 25+ স্থূলতা।';

  @override
  String get bmiNeedsBoth => 'BMI চাবলৈ উচ্চতা আৰু ওজন যোগ কৰক।';

  @override
  String invalidRange(String min, String max) {
    return '$minৰ পৰা $maxৰ ভিতৰত এটা সংখ্যা লিখক';
  }

  @override
  String get clearValue => 'মচক';

  @override
  String get prescription => 'প্ৰেছক্ৰিপচন';

  @override
  String get prescriptionReading => 'আপোনাৰ প্ৰেছক্ৰিপচন পঢ়ি আছোঁ…';

  @override
  String get prescriptionBody =>
      'স্কেন কৰিলে আমি ৰোগ আৰু এলাৰ্জীৰ পৰামৰ্শ দিম। কিবা ছেভ হোৱাৰ আগতে আপুনি নিশ্চিত কৰিব।';

  @override
  String get prescriptionConsentTitle => 'প্ৰেছক্ৰিপচন পঢ়িব নেকি?';

  @override
  String get prescriptionConsentGemini =>
      'আপোনাৰ ছবি পঢ়িবলৈ Google Gemini-লৈ পঠিওৱা হয়।';

  @override
  String get prescriptionConsentNoSave =>
      'CalFit-এ ছবি বা তাৰ পৰা পঢ়া তথ্য ছেভ নকৰে।';

  @override
  String get prescriptionConsentSuggestOnly =>
      'আমি কেৱল ৰোগ আৰু এলাৰ্জীৰ পৰামৰ্শ দিওঁ। আপুনি টিক দি নিশ্চিত নকৰালৈকে একো যোগ নহয়।';

  @override
  String get prescriptionConsentNotAdvice =>
      'এইটো চিকিৎসাৰ পৰামৰ্শ নহয়। প্ৰতিটো পৰামৰ্শ পৰীক্ষা কৰক।';

  @override
  String get agreeAndContinue => 'সন্মত, আগবাঢ়ক';

  @override
  String get reviewTitle => 'পৰীক্ষা';

  @override
  String get selectWhatToAdd => 'কি যোগ কৰিব বাছক';

  @override
  String addSelected(int count) {
    return 'বাছনি কৰাখিনি যোগ কৰক ($count)';
  }

  @override
  String get nothingToAdd => 'এই ছবিৰ পৰা যোগ কৰিবলগীয়া একো পোৱা নগ\'ল।';

  @override
  String get tickWhatApplies =>
      'যি আপোনাৰ ক্ষেত্ৰত প্ৰযোজ্য তাত টিক দিয়ক। নিশ্চিত নকৰালৈকে একো যোগ নহয়।';

  @override
  String inferredFromMedicine(String medicine) {
    return 'দৰৱ ($medicine)ৰ পৰা অনুমান। ই আপোনাৰ ক্ষেত্ৰত প্ৰযোজ্য নেকি চাওক।';
  }

  @override
  String get statedOnPrescription => 'প্ৰেছক্ৰিপচনত লিখা আছে';

  @override
  String get readNotAdded => 'পঢ়া হ\'ল কিন্তু যোগ কৰা নহ\'ল';

  @override
  String get newScan => 'নতুন স্কেন';

  @override
  String get scanHeadline => 'পেকেটৰ পিছফালৰ ছবি তোলক';

  @override
  String get scanBody =>
      'উপাদান আৰু পুষ্টিৰ তালিকা ফ্ৰেমত ৰাখক। আমি ইয়াক আপোনাৰ ৰোগ, এলাৰ্জী আৰু লক্ষ্যৰ সৈতে মিলাই চাম।';

  @override
  String get tapToTakePhoto => 'ছবি তুলিবলৈ টেপ কৰক';

  @override
  String get orPickFromGallery => 'নাইবা গেলেৰীৰ পৰা বাছক';

  @override
  String get camera => 'কেমেৰা';

  @override
  String get gallery => 'গেলেৰী';

  @override
  String get checkThisProduct => 'এই সামগ্ৰীটো পৰীক্ষা কৰক';

  @override
  String get removePhoto => 'ছবি আঁতৰাওক';

  @override
  String get tipsTitle => 'ভাল ফলাফলৰ বাবে';

  @override
  String get tipBackOfPack =>
      'আগফালৰ ফটোও চলে; পিছফালৰ ফটোৱে সম্পূৰ্ণ পৰীক্ষা দিয়ে';

  @override
  String get tipLight => 'ভাল পোহৰ, প্লাষ্টিকত জিলিকনি নাথাকে যেন';

  @override
  String get tipFillFrame => 'উপাদান আৰু পুষ্টিৰ তালিকাৰে ফ্ৰেম ভৰাওক';

  @override
  String get stepReadingLabel => 'লেবেল পঢ়ি আছোঁ';

  @override
  String get stepCheckingProfile => 'আপোনাৰ প্ৰফাইল চাই আছোঁ';

  @override
  String get stepWeighing => 'ফলাফল বিচাৰ কৰি আছোঁ';

  @override
  String get stepAlternatives => 'বিকল্প বিচাৰি আছোঁ';

  @override
  String get scanResultTitle => 'স্কেনৰ ফলাফল';

  @override
  String get scanDetailsTitle => 'স্কেনৰ বিৱৰণ';

  @override
  String get couldntOpenScan => 'এই স্কেনটো খুলিব পৰা নগ\'ল';

  @override
  String get cantReadLabel => 'এই লেবেলটো পঢ়িব পৰা নগ\'ল';

  @override
  String get cantReadLabelBody =>
      'ছবিখন অস্পষ্ট আছিল বা লেবেল ফ্ৰেমৰ বাহিৰত আছিল। পেকেটৰ পিছফালৰ স্পষ্ট, ওচৰৰ পৰা তোলা ছবিয়ে সাধাৰণতে কাম কৰে।';

  @override
  String get tryAnotherPhoto => 'আন ছবি চেষ্টা কৰক';

  @override
  String scannedWhen(String when) {
    return 'স্কেন কৰা হৈছে $when';
  }

  @override
  String get outOf10 => '10ৰ ভিতৰত';

  @override
  String scoreOutOf10(String score) {
    return 'স্ক\'ৰ 10ৰ ভিতৰত $score';
  }

  @override
  String whatWeFound(int count) {
    return 'আমি যি পালোঁ ($count)';
  }

  @override
  String get severityAvoid => 'এৰাই চলক';

  @override
  String get severityCaution => 'সাৱধান';

  @override
  String get severityHeadsUp => 'মন কৰক';

  @override
  String get severityGoodToKnow => 'জানি থোৱা ভাল';

  @override
  String pointsLost(String points) {
    return '−$points পইণ্ট';
  }

  @override
  String get onTheLabel => 'লেবেলত';

  @override
  String get perServingNote => 'প্ৰতি ছাৰ্ভিং। ডেশ্বৰ অৰ্থ লেবেলত নাছিল।';

  @override
  String get nutrientCalories => 'কেলৰি';

  @override
  String get nutrientTotalFat => 'মুঠ চৰ্বি';

  @override
  String get nutrientSaturatedFat => 'সংপৃক্ত চৰ্বি';

  @override
  String get nutrientSodium => 'ছডিয়াম';

  @override
  String get nutrientCarbs => 'মুঠ কাৰ্বছ';

  @override
  String get nutrientSugars => 'চেনি';

  @override
  String get nutrientProtein => 'প্ৰ\'টিন';

  @override
  String get ingredients => 'উপাদান';

  @override
  String get tryInstead => 'ইয়াৰ সলনি চেষ্টা কৰক';

  @override
  String get tryInsteadBody =>
      'একে শ্ৰেণীৰ প্ৰকৃত সামগ্ৰী যি আপোনাৰ বাবে বেছি উপযুক্ত';

  @override
  String get inOurDatabase => 'আমাৰ ডাটাবেছত';

  @override
  String get noAlternative =>
      'ইয়াৰ বাবে ইয়াতকৈ ভাল বিকল্প পৰামৰ্শ দিবলগীয়া নাই।';

  @override
  String get serverTextNote => 'স্কেনৰ বিৱৰণ এতিয়ালৈ ইংৰাজীত।';

  @override
  String get disclaimerShort =>
      'CalFit-এ লেবেল পঢ়ে; ই চিকিৎসাৰ পৰামৰ্শ নহয়। ৰোগ নিৰ্ণয় বা চিকিৎসাৰ বাবে ডাক্তৰ বা ডায়েটিচিয়ানক সোধক।';

  @override
  String get disclaimerTitle => 'আৰম্ভ কৰাৰ আগতে এটা কথা';

  @override
  String get disclaimerBody =>
      'CalFit-এ সামগ্ৰীৰ লেবেল স্কেন কৰি কয় ই আপোনাৰ প্ৰফাইলৰ বাবে কিমান উপযুক্ত। ই ডাক্তৰ বা ডায়েটিচিয়ানৰ ঠাই ল\'ব নোৱাৰে, আৰু খাদ্যত কি আছে তাৰ সকলো নাজানে।\n\nএলাৰ্জী থাকিলে পেকেট নিজে নিশ্চয় পঢ়ক, আৰু কোনো স্কেনৰ বাবে আহাৰ সলনি কৰাৰ আগতে আপোনাৰ চিকিৎসকৰ সৈতে কথা পাতক।';

  @override
  String get gotIt => 'বুজি পালোঁ';

  @override
  String get settingsTitle => 'ছেটিংছ';

  @override
  String get appearance => 'ৰূপ';

  @override
  String get theme => 'থিম';

  @override
  String get themeSystem => 'ফোনৰ দৰে';

  @override
  String get themeLight => 'লাইট';

  @override
  String get themeDark => 'ডাৰ্ক';

  @override
  String get textSize => 'আখৰৰ আকাৰ';

  @override
  String get textSizeSmall => 'সৰু';

  @override
  String get textSizeDefault => 'সাধাৰণ';

  @override
  String get textSizeLarge => 'ডাঙৰ';

  @override
  String get textSizeExtraLarge => 'অতি ডাঙৰ';

  @override
  String get textSizePreview => 'মচলা নুডলছ · প্ৰতি 100 gত 1,172 mg ছডিয়াম';

  @override
  String get language => 'ভাষা';

  @override
  String get languagePhone => 'ফোনৰ দৰে';

  @override
  String get translationNote =>
      'অনুবাদ মাতৃভাষীসকলে পৰীক্ষা কৰি আছে; কিছুমান শব্দ সলনি হ\'ব পাৰে।';

  @override
  String get privacyAndData => 'গোপনীয়তা আৰু ডাটা';

  @override
  String get privacyPolicy => 'গোপনীয়তা নীতি';

  @override
  String get deleteMyData => 'মোৰ ডাটা মচক';

  @override
  String get deleteMyDataBody =>
      'CalFit-ৰ ছাৰ্ভাৰৰ পৰা আপোনাৰ প্ৰফাইল, স্কেন আৰু ছবি মচি পেলায়।';

  @override
  String get deleteConfirmTitle => 'আপোনাৰ সকলো ডাটা মচিব নেকি?';

  @override
  String get deleteConfirmBody =>
      'আপোনাৰ প্ৰফাইল, প্ৰতিটো স্কেন আৰু প্ৰতিখন ছবি CalFit-ৰ ছাৰ্ভাৰৰ পৰা চিৰদিনৰ বাবে মচ খাব। ইয়াক ঘূৰাই অনা নাযাব।';

  @override
  String get deleteConfirmButton => 'সকলো মচক';

  @override
  String get dataDeleted => 'আপোনাৰ ডাটা মচি পেলোৱা হ\'ল।';

  @override
  String get about => 'বিষয়ে';

  @override
  String version(String version) {
    return 'সংস্কৰণ $version';
  }

  @override
  String get dataSources => 'ডাটাৰ উৎস';

  @override
  String get dataSourcesBody =>
      'সামগ্ৰীৰ ডাটা Open Food Facts (openfoodfacts.org)ৰ পৰা, Open Database Licence অনুসৰি। BMI সীমা ভাৰতীয়ৰ বাবে সৰ্বসন্মত কাট-অফ অনুসৰি।';

  @override
  String get notMedicalAdviceTitle => 'চিকিৎসাৰ পৰামৰ্শ নহয়';

  @override
  String get viewPhoto => 'ছবি চাওক';

  @override
  String get onbWelcomeTitle => 'জানক আপোনাৰ খাদ্যত কি আছে';

  @override
  String get onbWelcomeBody =>
      'যিকোনো পেকেটযুক্ত খাদ্যৰ পিছফালৰ ছবি তোলক। CalFit-এ লেবেল পঢ়ি কয় ই আপোনাৰ বাবে কিমান উপযুক্ত।';

  @override
  String get onbPointScan =>
      'ভাৰতীয় পেকেটৰ বাবে: বিস্কুট, নিমকি, নুডলছ, পানীয় আৰু অধিক';

  @override
  String get onbPointPersonal =>
      'স্ক\'ৰ আপোনাৰ ৰোগ, এলাৰ্জী আৰু লক্ষ্য অনুসৰি সলনি হয়';

  @override
  String get onbPointAlternatives =>
      'আপোনাৰ বাবে ভাল, একে ধৰণৰ প্ৰকৃত সামগ্ৰীৰ পৰামৰ্শ দিয়ে';

  @override
  String get onbChooseLanguage => 'আপোনাৰ ভাষা বাছক';

  @override
  String get onbProfileTitle => 'নিজৰ বিষয়ে অলপ কওক';

  @override
  String get onbProfileBody =>
      'যি প্ৰযোজ্য বাছক। প্ৰফাইলত যেতিয়াই মন যায় সলনি কৰিব পাৰিব।';

  @override
  String get onbAllergiesTitle => 'এলাৰ্জী';

  @override
  String get onbConditionsTitle => 'স্বাস্থ্যৰ সমস্যা';

  @override
  String get onbDietTitle => 'আহাৰ';

  @override
  String get onbSafetyTitle => 'এটা গুৰুত্বপূৰ্ণ কথা';

  @override
  String get onbGetStarted => 'আৰম্ভ কৰক';

  @override
  String get onbNext => 'পিছৰ';

  @override
  String get onbSkip => 'এৰি দিয়ক';

  @override
  String onbStep(int current, int total) {
    return 'স্তৰ $current / $total';
  }

  @override
  String get allergy_peanut => 'বাদাম';

  @override
  String get allergy_milk => 'গাখীৰ';

  @override
  String get allergy_gluten => 'গ্লুটেন';

  @override
  String get allergy_soy => 'ছয়া';

  @override
  String get allergy_egg => 'কণী';

  @override
  String get allergy_tree_nuts => 'গছৰ বাদাম';

  @override
  String get nutrientSalt => 'নিমখ';

  @override
  String get atAGlance => 'এক নজৰত';

  @override
  String get levelsPer100g =>
      'প্ৰতি 100 গ্ৰামত, মানক ট্ৰেফিক-লাইট মাপত। সকলোৰে বাবে একে।';

  @override
  String get levelsPer100ml =>
      'প্ৰতি 100 মিলিত, মানক ট্ৰেফিক-লাইট মাপত। সকলোৰে বাবে একে।';

  @override
  String get levelLow => 'কম';

  @override
  String get levelMedium => 'মধ্যমীয়া';

  @override
  String get levelHigh => 'বেছি';

  @override
  String get feedbackQuestion => 'এই ফলাফল শুদ্ধ আছিল নে?';

  @override
  String get feedbackWhy =>
      'আপোনাৰ উত্তৰে CalFit কিমান সঠিক সেয়া পৰীক্ষা কৰাত সহায় কৰে।';

  @override
  String get feedbackYes => 'হয়';

  @override
  String get feedbackNo => 'সম্পূৰ্ণ নহয়';

  @override
  String get feedbackWhatWrong => 'কি ভুল আছিল?';

  @override
  String get issueWrongProduct => 'ভুল সামগ্ৰী';

  @override
  String get issueWrongNutrition => 'পুষ্টিৰ সংখ্যা';

  @override
  String get issueWrongIngredients => 'উপাদান';

  @override
  String get issueMissedAllergen => 'এলাৰ্জেন বাদ পৰিল';

  @override
  String get issueScoreUnfair => 'স্ক\'ৰ ভুল যেন লাগিছে';

  @override
  String get issueOther => 'আন কিবা';

  @override
  String get feedbackSend => 'পঠিয়াওক';

  @override
  String get feedbackThanks => 'ধন্যবাদ। ইয়াৰ দ্বাৰা আমি উন্নত হ\'ব পাৰোঁ।';

  @override
  String get feedbackFailed =>
      'পঠিয়াব পৰা নগ\'ল। সংযোগ পৰীক্ষা কৰি আকৌ চেষ্টা কৰক।';

  @override
  String get pickerConfirmTitle => 'এইটোৱেই সামগ্ৰীটো নেকি?';

  @override
  String get pickerChooseTitle => 'কোনটো?';

  @override
  String pickerReadAs(String text) {
    return 'আমি পেকত “$text” পঢ়িলোঁ।';
  }

  @override
  String get pickerYes => 'হয়, এইটোৱেই';

  @override
  String get pickerNoRetake => 'নহয়, আকৌ ফটো লওক';

  @override
  String get pickerNoneRetake => 'এটাও নহয়, আকৌ লওক';

  @override
  String get sourceOpenFoodFacts => 'Open Food Facts';

  @override
  String get sourceCalfitDb => 'CalFit ডাটাবেছ';

  @override
  String get retakeHint =>
      'সামগ্ৰীৰ নাম স্পষ্টকৈ দেখুৱাই আকৌ ফটো লওক, বা পেকৰ পিছফালৰ ফটো লওক।';

  @override
  String identifiedAs(String name) {
    return 'চিনাক্ত: $name';
  }

  @override
  String identifiedSource(String source) {
    return 'প্ৰতি 100 গ্ৰাম/মিলিত পুষ্টি, উৎস: $source';
  }

  @override
  String get notThisProduct => 'এই সামগ্ৰী নহয়?';

  @override
  String get removeScanTitle => 'এই স্কেন আঁতৰাবনে?';

  @override
  String get removeScanBody =>
      'ই আপোনাৰ ইতিহাসৰ পৰা মচি পেলোৱা হ\'ব, যাতে আপুনি আকৌ ফটো ল\'ব পাৰে।';

  @override
  String get remove => 'আঁতৰাওক';

  @override
  String get scanRemoved => 'স্কেন আঁতৰোৱা হ\'ল। আকৌ চেষ্টা কৰিবলৈ স্কেন টিপক।';

  @override
  String get couldntRemove => 'স্কেন আঁতৰাব পৰা নগ\'ল। আকৌ চেষ্টা কৰক।';

  @override
  String get servingUnknownTitle => 'চাৰ্ভিং চাইজ অজ্ঞাত';

  @override
  String get servingUnknownBody =>
      'এই লেবেলৰ সংখ্যাবোৰ প্ৰতি 100 গ্ৰাম/মিলি নে প্ৰতি চাৰ্ভিং, সেয়া কোৱা নাই। পেকটো চাই চাৰ্ভিং চাইজ যোগ কৰক; পিছৰবাৰ এই সামগ্ৰী স্কেন কৰিলে আমি ইয়াক ব্যৱহাৰ কৰিম।';

  @override
  String get addServingSize => 'চাৰ্ভিং চাইজ যোগ কৰক';

  @override
  String get servingSheetTitle => 'চাৰ্ভিং চাইজ';

  @override
  String get servingAmountLabel => 'এটা চাৰ্ভিং (গ্ৰাম বা মিলি)';

  @override
  String get servingAmountHelp => 'পেকত “serving size” বা নেট পৰিমাণ চাওক।';

  @override
  String get servingBasisLabel => 'লেবেলৰ সংখ্যাবোৰ';

  @override
  String get basisPer100 => 'প্ৰতি 100 গ্ৰাম/মিলি';

  @override
  String get basisPerServing => 'প্ৰতি চাৰ্ভিং';

  @override
  String servingSaved(String amount) {
    return 'ছেভ হ\'ল: প্ৰতি চাৰ্ভিং $amount গ্ৰাম/মিলি। পিছৰবাৰ এই সামগ্ৰী স্কেন কৰিলে আমি ইয়াক ব্যৱহাৰ কৰিম।';
  }

  @override
  String get servingSaveFailed =>
      'ছেভ কৰিব পৰা নগ\'ল। সংযোগ পৰীক্ষা কৰি আকৌ চেষ্টা কৰক।';

  @override
  String labelNotePer100(String source) {
    return 'প্ৰতি 100 গ্ৰাম/মিলি, উৎস: $source। ডেশ মানে অজ্ঞাত।';
  }

  @override
  String labelNoteYourServing(String amount) {
    return '$amount গ্ৰাম/মিলিৰ চাৰ্ভিঙত, আপুনি ছেভ কৰা চাৰ্ভিং চাইজ।';
  }

  @override
  String get confirmingProduct => 'সামগ্ৰীটো পৰীক্ষা কৰা হৈছে…';
}
