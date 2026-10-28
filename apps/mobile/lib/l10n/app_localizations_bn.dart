// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appName => 'CalFit';

  @override
  String get tryAgain => 'আবার চেষ্টা করুন';

  @override
  String get cancel => 'বাতিল';

  @override
  String get save => 'সেভ করুন';

  @override
  String get done => 'হয়ে গেছে';

  @override
  String get edit => 'বদলান';

  @override
  String get add => 'যোগ করুন';

  @override
  String get close => 'বন্ধ করুন';

  @override
  String get back => 'ফিরে যান';

  @override
  String get seeAll => 'সব দেখুন';

  @override
  String get saved => 'সেভ হয়েছে';

  @override
  String get notSet => 'দেওয়া হয়নি';

  @override
  String get unknownBrand => 'ব্র্যান্ড অজানা';

  @override
  String get unnamedProduct => 'নামহীন পণ্য';

  @override
  String get scanAProduct => 'পণ্য স্ক্যান করুন';

  @override
  String get navHome => 'হোম';

  @override
  String get navHistory => 'ইতিহাস';

  @override
  String get navInsights => 'ইনসাইটস';

  @override
  String get navProfile => 'প্রোফাইল';

  @override
  String get timeJustNow => 'এইমাত্র';

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
  String get today => 'আজ';

  @override
  String get yesterday => 'গতকাল';

  @override
  String get errorNetwork =>
      'CalFit সার্ভারে পৌঁছানো যাচ্ছে না। ইন্টারনেট দেখে আবার চেষ্টা করুন।';

  @override
  String get errorTimeout => 'অনেক সময় লেগেছে। আবার চেষ্টা করুন।';

  @override
  String get errorServer =>
      'CalFit সার্ভারে এখন সমস্যা হচ্ছে। একটু পরে চেষ্টা করুন।';

  @override
  String get errorNotFound => 'এটি পাওয়া যায়নি।';

  @override
  String get errorUnauthorized =>
      'আপনার সেশন রিফ্রেশ করতে হবে। আবার চেষ্টা করুন।';

  @override
  String get errorScanLimit =>
      'আজকের স্ক্যানের সীমা শেষ। মধ্যরাতে (UTC) আবার শুরু হবে।';

  @override
  String get errorProfileReset =>
      'আপনার সাইন-ইন রিসেট হয়েছে, তাই আপনার স্বাস্থ্য প্রোফাইল আর আমাদের সার্ভারে নেই। স্ক্যান করার আগে অনুগ্রহ করে প্রোফাইলে এটি আবার পূরণ করুন।';

  @override
  String get errorPrescriptionLimit =>
      'আজকের প্রেসক্রিপশনের সীমা পূর্ণ হয়েছে। আগামীকাল আবার চেষ্টা করুন।';

  @override
  String get errorGeneric => 'কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get errorImageOpen => 'ছবিটি খোলা গেল না। অন্য একটি বেছে নিন।';

  @override
  String get greetingStillUp => 'এখনও জেগে আছেন';

  @override
  String get greetingMorning => 'সুপ্রভাত';

  @override
  String get greetingAfternoon => 'শুভ দুপুর';

  @override
  String get greetingEvening => 'শুভ সন্ধ্যা';

  @override
  String get greetingNight => 'শুভ রাত্রি';

  @override
  String get homeTitleNoName => 'চলুন খাবার যাচাই করি';

  @override
  String get homeErrorTitle => 'ড্যাশবোর্ড লোড হয়নি';

  @override
  String latestScan(String when) {
    return 'শেষ স্ক্যান · $when';
  }

  @override
  String get firstScanTitle => 'প্রথম পণ্যটি স্ক্যান করুন';

  @override
  String get firstScanBody =>
      'যেকোনো প্যাকেটজাত খাবারের পিছনের ছবি তুলুন। আমরা লেবেল পড়ে জানাব এটি আপনার প্রোফাইলের সঙ্গে কতটা মানানসই।';

  @override
  String get personaliseTitle => 'স্কোর নিজের মতো করে নিন';

  @override
  String get personaliseBody => 'আপনার অসুখ, অ্যালার্জি আর লক্ষ্য যোগ করুন।';

  @override
  String get statScans => 'স্ক্যান';

  @override
  String get statAverage => 'গড়';

  @override
  String get statBest => 'সেরা';

  @override
  String get scoringForYou => 'আপনার জন্য স্কোরিং';

  @override
  String get scoringEmpty =>
      'এখনও কিছু যোগ করা হয়নি, তাই স্কোর সাধারণ নির্দেশিকা অনুযায়ী।';

  @override
  String allergyChip(String name) {
    return '$name-এ অ্যালার্জি';
  }

  @override
  String get recentScans => 'সাম্প্রতিক স্ক্যান';

  @override
  String get switchToLight => 'লাইট মোডে যান';

  @override
  String get switchToDark => 'ডার্ক মোডে যান';

  @override
  String get historyTitle => 'ইতিহাস';

  @override
  String get historyErrorTitle => 'ইতিহাস লোড হয়নি';

  @override
  String get historyEmptyTitle => 'এখানে এখনও কিছু নেই';

  @override
  String get historyEmptyBody =>
      'আপনি যা স্ক্যান করবেন তা স্কোর সহ এখানে থাকবে, যখন খুশি দেখে নিতে পারবেন।';

  @override
  String get insightsTitle => 'ইনসাইটস';

  @override
  String get insightsErrorTitle => 'ইনসাইটস লোড হয়নি';

  @override
  String get insightsEmptyTitle => 'আপনার প্রবণতা এখানে দেখা যাবে';

  @override
  String get insightsEmptyBody =>
      'কয়েকটি পণ্য স্ক্যান করুন, তারপর গড় স্কোর, সবচেয়ে বেশি ধরা পড়া বিষয় আর আপনার সেরা পছন্দ দেখতে পাবেন।';

  @override
  String get averageScore => 'গড় স্কোর';

  @override
  String scanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countটি স্ক্যান',
      one: '1টি স্ক্যান',
    );
    return '$_temp0';
  }

  @override
  String get weekByWeek => 'সপ্তাহ ধরে';

  @override
  String get weekByWeekBody => 'প্রতি সপ্তাহে স্ক্যান করা পণ্যের গড় স্কোর';

  @override
  String weekNoScans(String date) {
    return '$date-এর সপ্তাহ: কোনো স্ক্যান নেই';
  }

  @override
  String weekSummary(String date, String score, int count) {
    return '$date-এর সপ্তাহ: $countটি স্ক্যানে গড় $score';
  }

  @override
  String get flaggedMost => 'সবচেয়ে বেশি যা ধরা পড়ে';

  @override
  String get flaggedMostBody => 'আপনার স্ক্যানে পাওয়া সমস্যা';

  @override
  String countOfTotal(int count, int total) {
    return '$totalটির মধ্যে $count';
  }

  @override
  String get bestPicks => 'আপনার সেরা পছন্দ';

  @override
  String get secondLook => 'আরেকবার দেখার মতো';

  @override
  String get secondLookBody => 'যেসব পণ্যের স্কোর আপনার প্রোফাইলের জন্য কম';

  @override
  String basedOnScans(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'আপনার শেষ $countটি স্ক্যানের ভিত্তিতে।',
      one: 'আপনার শেষ স্ক্যানের ভিত্তিতে।',
    );
    return '$_temp0';
  }

  @override
  String get yourGoals => 'আপনার লক্ষ্য';

  @override
  String get yourGoalsBody => 'আপনার স্ক্যান লক্ষ্যের সঙ্গে কতটা মেলে';

  @override
  String goalFits(int fits, int checked) {
    return '$checkedটির মধ্যে $fitsটি স্ক্যান এই লক্ষ্যের সঙ্গে মেলে';
  }

  @override
  String get goalNoData =>
      'এই লক্ষ্যের জন্য দরকারি তথ্যসহ কোনো স্ক্যান এখনও নেই।';

  @override
  String get goalNotTracked =>
      'এখনও ট্র্যাক হয় না। এই লক্ষ্যের জন্য CalFit-এ কোনো নিয়ম নেই।';

  @override
  String goalMainIssue(String issue) {
    return 'সবচেয়ে সাধারণ সমস্যা: $issue';
  }

  @override
  String goalChecks(String basis) {
    return 'যাচাই: $basis';
  }

  @override
  String get addGoalsPrompt =>
      'প্রোফাইলে লক্ষ্য যোগ করুন, তাহলে দেখবেন আপনার স্ক্যান সেগুলোর সঙ্গে কতটা মেলে।';

  @override
  String toTargetLose(String kg) {
    return 'লক্ষ্য ওজনের চেয়ে $kg kg বেশি';
  }

  @override
  String toTargetGain(String kg) {
    return 'লক্ষ্য ওজনের চেয়ে $kg kg কম';
  }

  @override
  String get atTarget => 'আপনি লক্ষ্য ওজনে আছেন';

  @override
  String get goal_weight_loss => 'ওজন কমানো';

  @override
  String get goal_muscle_gain => 'পেশি বাড়ানো';

  @override
  String get goal_maintain_weight => 'ওজন ঠিক রাখা';

  @override
  String get goal_improve_energy => 'বেশি শক্তি';

  @override
  String get goal_improve_digestion => 'ভালো হজম';

  @override
  String get goal_reduce_inflammation => 'কম প্রদাহ';

  @override
  String get goal_manage_blood_sugar => 'রক্তে শর্করা নিয়ন্ত্রণ';

  @override
  String get goal_heart_health => 'হৃদয়ের স্বাস্থ্য';

  @override
  String get condition_diabetes_type_1 => 'টাইপ ১ ডায়াবেটিস';

  @override
  String get condition_diabetes_type_2 => 'টাইপ ২ ডায়াবেটিস';

  @override
  String get condition_prediabetes => 'প্রিডায়াবেটিস';

  @override
  String get condition_hypertension => 'উচ্চ রক্তচাপ';

  @override
  String get condition_high_cholesterol => 'উচ্চ কোলেস্টেরল';

  @override
  String get condition_celiac_disease => 'সিলিয়াক রোগ';

  @override
  String get condition_ibs => 'IBS';

  @override
  String get condition_kidney_disease => 'কিডনির রোগ';

  @override
  String get condition_heart_disease => 'হৃদরোগ';

  @override
  String get condition_obesity => 'স্থূলতা';

  @override
  String get condition_lactose_intolerance => 'ল্যাকটোজ ইনটলারেন্স';

  @override
  String get condition_anaemia => 'রক্তাল্পতা';

  @override
  String get diet_vegetarian => 'নিরামিষ';

  @override
  String get diet_vegan => 'ভিগান';

  @override
  String get diet_gluten_free => 'গ্লুটেন-মুক্ত';

  @override
  String get diet_dairy_free => 'দুগ্ধ-মুক্ত';

  @override
  String get diet_halal => 'হালাল';

  @override
  String get diet_kosher => 'কোশার';

  @override
  String get diet_low_carb => 'লো কার্ব';

  @override
  String get diet_keto => 'কিটো';

  @override
  String get diet_paleo => 'প্যালিও';

  @override
  String get suitabilityExcellent => 'খুব ভালো মিল';

  @override
  String get suitabilityGood => 'ভালো মিল';

  @override
  String get suitabilityFair => 'মোটামুটি মিল';

  @override
  String get suitabilityPoor => 'দুর্বল মিল';

  @override
  String get suitabilityNotSuitable => 'উপযুক্ত নয়';

  @override
  String get suitabilityUnknown => 'অজানা';

  @override
  String get profileTitle => 'প্রোফাইল';

  @override
  String get settingsTooltip => 'সেটিংস';

  @override
  String get profileErrorTitle => 'প্রোফাইল লোড হয়নি';

  @override
  String get addYourName => 'আপনার নাম যোগ করুন';

  @override
  String get introduceYourself => 'পরিচয় দিতে পেন্সিলে ট্যাপ করুন';

  @override
  String get signedInAnonymously => 'এই ডিভাইসে নাম ছাড়া সাইন ইন করা';

  @override
  String get editName => 'নাম বদলান';

  @override
  String get profileSetup => 'প্রোফাইল সেটআপ';

  @override
  String filledOf(int filled, int total) {
    return '$totalটির মধ্যে $filled';
  }

  @override
  String get moreAccurate => 'যত বেশি যোগ করবেন, স্কোর তত নির্ভুল হবে।';

  @override
  String get sectionGoals => 'লক্ষ্য';

  @override
  String get goalsCaption => 'আপনি কিসের জন্য চেষ্টা করছেন?';

  @override
  String get sectionConditions => 'অসুখ';

  @override
  String get conditionsCaption =>
      'এগুলো বাড়ায় এমন পণ্যের স্কোর আমরা কমিয়ে দিই।';

  @override
  String get sectionDiet => 'ডায়েট';

  @override
  String get dietCaption => 'এগুলো ভাঙে এমন পণ্য আমরা চিহ্নিত করি।';

  @override
  String get sectionAllergies => 'অ্যালার্জি';

  @override
  String get allergiesCaption => 'উপাদানে এর কিছু থাকলে আমরা সতর্ক করি।';

  @override
  String get yourName => 'আপনার নাম';

  @override
  String get nameHint => 'আপনাকে কী নামে ডাকব?';

  @override
  String get allergiesHint => 'যেমন চিনাবাদাম, সয়া';

  @override
  String get noAllergies => 'কোনো অ্যালার্জি যোগ করা হয়নি।';

  @override
  String get addAllergy => 'অ্যালার্জি যোগ করুন';

  @override
  String get takePhoto => 'ছবি তুলুন';

  @override
  String get chooseFromGallery => 'গ্যালারি থেকে বেছে নিন';

  @override
  String get bodyTitle => 'শরীর';

  @override
  String get bodyCaption => 'ঐচ্ছিক। BMI আর লক্ষ্য ট্র্যাক করতে কাজে লাগে।';

  @override
  String get addBodyDetails => 'উচ্চতা, ওজন আর আরও কিছু যোগ করুন';

  @override
  String get bodyEditTitle => 'শরীরের তথ্য';

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
  String get birthYear => 'জন্মসাল';

  @override
  String get sex => 'লিঙ্গ';

  @override
  String get sexFemale => 'মহিলা';

  @override
  String get sexMale => 'পুরুষ';

  @override
  String get sexOther => 'অন্যান্য';

  @override
  String get activityLevel => 'সক্রিয়তার মাত্রা';

  @override
  String get activity_sedentary => 'কম সক্রিয়';

  @override
  String get activity_sedentary_hint => 'বসে কাজ, ব্যায়াম খুব কম';

  @override
  String get activity_light => 'হালকা সক্রিয়';

  @override
  String get activity_light_hint => 'সপ্তাহে ১–৩ দিন হালকা ব্যায়াম';

  @override
  String get activity_moderate => 'মাঝারি সক্রিয়';

  @override
  String get activity_moderate_hint => 'সপ্তাহে ৩–৫ দিন ব্যায়াম';

  @override
  String get activity_active => 'সক্রিয়';

  @override
  String get activity_active_hint => 'সপ্তাহে ৬–৭ দিন কঠোর ব্যায়াম';

  @override
  String get activity_very_active => 'খুব সক্রিয়';

  @override
  String get activity_very_active_hint => 'শারীরিক পরিশ্রমের কাজ ও ট্রেনিং';

  @override
  String get unitCm => 'cm';

  @override
  String get unitKg => 'kg';

  @override
  String ageYears(int age) {
    return '$age বছর';
  }

  @override
  String get bmiUnderweight => 'কম ওজন';

  @override
  String get bmiNormal => 'স্বাস্থ্যকর সীমা';

  @override
  String get bmiOverweight => 'বেশি ওজন';

  @override
  String get bmiObese => 'স্থূলতা';

  @override
  String get bmiNote =>
      'ভারতীয়দের জন্য BMI সীমা: 18.5–22.9 স্বাস্থ্যকর, 23–24.9 বেশি ওজন, 25+ স্থূলতা।';

  @override
  String get bmiNeedsBoth => 'BMI দেখতে উচ্চতা ও ওজন যোগ করুন।';

  @override
  String invalidRange(String min, String max) {
    return '$min থেকে $max-এর মধ্যে একটি সংখ্যা লিখুন';
  }

  @override
  String get clearValue => 'মুছুন';

  @override
  String get prescription => 'প্রেসক্রিপশন';

  @override
  String get prescriptionReading => 'আপনার প্রেসক্রিপশন পড়া হচ্ছে…';

  @override
  String get prescriptionBody =>
      'স্ক্যান করলে আমরা অসুখ ও অ্যালার্জি সুপারিশ করব। কিছু সেভ হওয়ার আগে আপনি নিশ্চিত করবেন।';

  @override
  String get prescriptionConsentTitle => 'প্রেসক্রিপশন পড়বেন?';

  @override
  String get prescriptionConsentGemini =>
      'আপনার ছবি পড়ার জন্য Google Gemini-তে পাঠানো হয়।';

  @override
  String get prescriptionConsentNoSave =>
      'CalFit ছবি বা তা থেকে পড়া তথ্য সেভ করে না।';

  @override
  String get prescriptionConsentSuggestOnly =>
      'আমরা শুধু অসুখ ও অ্যালার্জি সুপারিশ করি। আপনি টিক দিয়ে নিশ্চিত না করলে কিছু যোগ হয় না।';

  @override
  String get prescriptionConsentNotAdvice =>
      'এটি চিকিৎসা পরামর্শ নয়। প্রতিটি সুপারিশ যাচাই করুন।';

  @override
  String get agreeAndContinue => 'রাজি, এগিয়ে যান';

  @override
  String get reviewTitle => 'যাচাই';

  @override
  String get selectWhatToAdd => 'কী যোগ করবেন বেছে নিন';

  @override
  String addSelected(int count) {
    return 'বাছাই করা যোগ করুন ($count)';
  }

  @override
  String get nothingToAdd => 'এই ছবি থেকে যোগ করার মতো কিছু পাওয়া যায়নি।';

  @override
  String get tickWhatApplies =>
      'যা আপনার ক্ষেত্রে প্রযোজ্য তাতে টিক দিন। নিশ্চিত না করা পর্যন্ত কিছু যোগ হয় না।';

  @override
  String inferredFromMedicine(String medicine) {
    return 'ওষুধ ($medicine) থেকে অনুমান। এটি আপনার ক্ষেত্রে প্রযোজ্য কিনা দেখুন।';
  }

  @override
  String get statedOnPrescription => 'প্রেসক্রিপশনে লেখা আছে';

  @override
  String get readNotAdded => 'পড়া হয়েছে কিন্তু যোগ হয়নি';

  @override
  String get newScan => 'নতুন স্ক্যান';

  @override
  String get scanHeadline => 'প্যাকেটের পিছনের ছবি তুলুন';

  @override
  String get scanBody =>
      'উপাদান আর পুষ্টি তালিকা ফ্রেমে রাখুন। আমরা এটি আপনার অসুখ, অ্যালার্জি আর লক্ষ্যের সঙ্গে মিলিয়ে দেখব।';

  @override
  String get tapToTakePhoto => 'ছবি তুলতে ট্যাপ করুন';

  @override
  String get orPickFromGallery => 'অথবা গ্যালারি থেকে বেছে নিন';

  @override
  String get camera => 'ক্যামেরা';

  @override
  String get gallery => 'গ্যালারি';

  @override
  String get checkThisProduct => 'এই পণ্যটি যাচাই করুন';

  @override
  String get removePhoto => 'ছবি সরান';

  @override
  String get tipsTitle => 'সেরা ফলের জন্য';

  @override
  String get tipBackOfPack => 'সামনের ছবিও চলে; পিছনের ছবিতে পুরো যাচাই হয়';

  @override
  String get tipLight => 'ভালো আলো, প্লাস্টিকে ঝলক যেন না থাকে';

  @override
  String get tipFillFrame => 'উপাদান আর পুষ্টি তালিকা দিয়ে ফ্রেম ভরান';

  @override
  String get stepReadingLabel => 'লেবেল পড়া হচ্ছে';

  @override
  String get stepCheckingProfile => 'আপনার প্রোফাইল দেখা হচ্ছে';

  @override
  String get stepWeighing => 'ফলাফল বিচার করা হচ্ছে';

  @override
  String get stepAlternatives => 'বিকল্প খোঁজা হচ্ছে';

  @override
  String get scanResultTitle => 'স্ক্যানের ফল';

  @override
  String get scanDetailsTitle => 'স্ক্যানের বিবরণ';

  @override
  String get couldntOpenScan => 'এই স্ক্যানটি খোলা গেল না';

  @override
  String get cantReadLabel => 'এই লেবেলটি পড়া গেল না';

  @override
  String get cantReadLabelBody =>
      'ছবিটি ঝাপসা ছিল বা লেবেল ফ্রেমের বাইরে ছিল। প্যাকেটের পিছনের পরিষ্কার, কাছ থেকে তোলা ছবি সাধারণত কাজ করে।';

  @override
  String get tryAnotherPhoto => 'অন্য ছবি চেষ্টা করুন';

  @override
  String scannedWhen(String when) {
    return 'স্ক্যান করা হয়েছে $when';
  }

  @override
  String get outOf10 => '10-র মধ্যে';

  @override
  String scoreOutOf10(String score) {
    return 'স্কোর 10-র মধ্যে $score';
  }

  @override
  String whatWeFound(int count) {
    return 'আমরা যা পেয়েছি ($count)';
  }

  @override
  String get severityAvoid => 'এড়িয়ে চলুন';

  @override
  String get severityCaution => 'সাবধান';

  @override
  String get severityHeadsUp => 'খেয়াল রাখুন';

  @override
  String get severityGoodToKnow => 'জেনে রাখুন';

  @override
  String pointsLost(String points) {
    return '−$points পয়েন্ট';
  }

  @override
  String get onTheLabel => 'লেবেলে';

  @override
  String get perServingNote => 'প্রতি সার্ভিং। ড্যাশ মানে লেবেলে ছিল না।';

  @override
  String get nutrientCalories => 'ক্যালোরি';

  @override
  String get nutrientTotalFat => 'মোট ফ্যাট';

  @override
  String get nutrientSaturatedFat => 'স্যাচুরেটেড ফ্যাট';

  @override
  String get nutrientSodium => 'সোডিয়াম';

  @override
  String get nutrientCarbs => 'মোট কার্বস';

  @override
  String get nutrientSugars => 'চিনি';

  @override
  String get nutrientProtein => 'প্রোটিন';

  @override
  String get ingredients => 'উপাদান';

  @override
  String get tryInstead => 'এর বদলে চেষ্টা করুন';

  @override
  String get tryInsteadBody => 'একই ধরনের আসল পণ্য যা আপনার জন্য বেশি উপযুক্ত';

  @override
  String get inOurDatabase => 'আমাদের ডেটাবেসে';

  @override
  String get noAlternative =>
      'এর জন্য এর চেয়ে ভালো কোনো বিকল্প সুপারিশ করার নেই।';

  @override
  String get serverTextNote => 'স্ক্যানের বিবরণ আপাতত ইংরেজিতে।';

  @override
  String get disclaimerShort =>
      'CalFit লেবেল পড়ে; এটি চিকিৎসা পরামর্শ নয়। রোগ নির্ণয় বা চিকিৎসার জন্য ডাক্তার বা ডায়েটিশিয়ানকে জিজ্ঞেস করুন।';

  @override
  String get disclaimerTitle => 'শুরুর আগে একটি কথা';

  @override
  String get disclaimerBody =>
      'CalFit পণ্যের লেবেল স্ক্যান করে জানায় এটি আপনার প্রোফাইলের সঙ্গে কতটা মানানসই। এটি ডাক্তার বা ডায়েটিশিয়ানের জায়গা নিতে পারে না, আর খাবারে কী আছে তার সব কিছু জানে না।\n\nঅ্যালার্জি থাকলে প্যাকেট নিজে অবশ্যই পড়ুন, আর কোনো স্ক্যানের কারণে খাদ্যাভ্যাস বদলানোর আগে আপনার চিকিৎসকের সঙ্গে কথা বলুন।';

  @override
  String get gotIt => 'বুঝেছি';

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get appearance => 'চেহারা';

  @override
  String get theme => 'থিম';

  @override
  String get themeSystem => 'ফোনের মতো';

  @override
  String get themeLight => 'লাইট';

  @override
  String get themeDark => 'ডার্ক';

  @override
  String get textSize => 'লেখার আকার';

  @override
  String get textSizeSmall => 'ছোট';

  @override
  String get textSizeDefault => 'সাধারণ';

  @override
  String get textSizeLarge => 'বড়';

  @override
  String get textSizeExtraLarge => 'অনেক বড়';

  @override
  String get textSizePreview => 'মশলা নুডলস · প্রতি 100 g-এ 1,172 mg সোডিয়াম';

  @override
  String get language => 'ভাষা';

  @override
  String get languagePhone => 'ফোনের মতো';

  @override
  String get translationNote =>
      'অনুবাদ মাতৃভাষীরা যাচাই করছেন; কিছু শব্দ বদলাতে পারে।';

  @override
  String get privacyAndData => 'গোপনীয়তা ও ডেটা';

  @override
  String get privacyPolicy => 'গোপনীয়তা নীতি';

  @override
  String get deleteMyData => 'আমার ডেটা মুছুন';

  @override
  String get deleteMyDataBody =>
      'CalFit-এর সার্ভার থেকে আপনার প্রোফাইল, স্ক্যান ও ছবি মুছে দেয়।';

  @override
  String get deleteConfirmTitle => 'আপনার সব ডেটা মুছবেন?';

  @override
  String get deleteConfirmBody =>
      'আপনার প্রোফাইল, প্রতিটি স্ক্যান ও প্রতিটি ছবি CalFit-এর সার্ভার থেকে চিরতরে মুছে যাবে। এটি আর ফেরানো যাবে না।';

  @override
  String get deleteConfirmButton => 'সব মুছুন';

  @override
  String get dataDeleted => 'আপনার ডেটা মুছে ফেলা হয়েছে।';

  @override
  String get about => 'সম্পর্কে';

  @override
  String version(String version) {
    return 'সংস্করণ $version';
  }

  @override
  String get dataSources => 'ডেটার উৎস';

  @override
  String get dataSourcesBody =>
      'পণ্যের ডেটা Open Food Facts (openfoodfacts.org) থেকে, Open Database Licence অনুযায়ী। BMI সীমা ভারতীয়দের জন্য সর্বসম্মত কাট-অফ অনুসারে।';

  @override
  String get notMedicalAdviceTitle => 'চিকিৎসা পরামর্শ নয়';

  @override
  String get viewPhoto => 'ছবি দেখুন';

  @override
  String get onbWelcomeTitle => 'জানুন আপনার খাবারে কী আছে';

  @override
  String get onbWelcomeBody =>
      'যেকোনো প্যাকেটজাত খাবারের পিছনের ছবি তুলুন। CalFit লেবেল পড়ে জানায় এটি আপনার জন্য কতটা উপযুক্ত।';

  @override
  String get onbPointScan =>
      'ভারতীয় প্যাকেটের জন্য: বিস্কুট, নোনতা, নুডলস, পানীয় আর আরও';

  @override
  String get onbPointPersonal =>
      'স্কোর বদলায় আপনার অসুখ, অ্যালার্জি আর লক্ষ্য অনুযায়ী';

  @override
  String get onbPointAlternatives =>
      'আপনার জন্য ভালো, একই রকম আসল পণ্য সুপারিশ করে';

  @override
  String get onbChooseLanguage => 'আপনার ভাষা বেছে নিন';

  @override
  String get onbProfileTitle => 'নিজের সম্পর্কে একটু বলুন';

  @override
  String get onbProfileBody =>
      'যা প্রযোজ্য বেছে নিন। প্রোফাইলে যখন খুশি বদলাতে পারবেন।';

  @override
  String get onbAllergiesTitle => 'অ্যালার্জি';

  @override
  String get onbConditionsTitle => 'স্বাস্থ্য সমস্যা';

  @override
  String get onbDietTitle => 'ডায়েট';

  @override
  String get onbSafetyTitle => 'একটি জরুরি কথা';

  @override
  String get onbGetStarted => 'শুরু করুন';

  @override
  String get onbNext => 'পরের';

  @override
  String get onbSkip => 'বাদ দিন';

  @override
  String onbStep(int current, int total) {
    return 'ধাপ $current / $total';
  }

  @override
  String get allergy_peanut => 'চিনাবাদাম';

  @override
  String get allergy_milk => 'দুধ';

  @override
  String get allergy_gluten => 'গ্লুটেন';

  @override
  String get allergy_soy => 'সয়া';

  @override
  String get allergy_egg => 'ডিম';

  @override
  String get allergy_tree_nuts => 'বাদাম';

  @override
  String get nutrientSalt => 'লবণ';

  @override
  String get atAGlance => 'এক নজরে';

  @override
  String get levelsPer100g =>
      'প্রতি 100 গ্রামে, মানক ট্রাফিক-লাইট মাপে। সবার জন্য একই।';

  @override
  String get levelsPer100ml =>
      'প্রতি 100 মিলিতে, মানক ট্রাফিক-লাইট মাপে। সবার জন্য একই।';

  @override
  String get levelLow => 'কম';

  @override
  String get levelMedium => 'মাঝারি';

  @override
  String get levelHigh => 'বেশি';

  @override
  String get feedbackQuestion => 'এই ফলাফল কি ঠিক ছিল?';

  @override
  String get feedbackWhy => 'আপনার উত্তর থেকে আমরা দেখি CalFit কতটা নির্ভুল।';

  @override
  String get feedbackYes => 'হ্যাঁ';

  @override
  String get feedbackNo => 'পুরোপুরি না';

  @override
  String get feedbackWhatWrong => 'কী ভুল ছিল?';

  @override
  String get issueWrongProduct => 'ভুল পণ্য';

  @override
  String get issueWrongNutrition => 'পুষ্টির সংখ্যা';

  @override
  String get issueWrongIngredients => 'উপাদান';

  @override
  String get issueMissedAllergen => 'অ্যালার্জেন বাদ পড়েছে';

  @override
  String get issueScoreUnfair => 'স্কোর ভুল মনে হচ্ছে';

  @override
  String get issueOther => 'অন্য কিছু';

  @override
  String get feedbackSend => 'পাঠান';

  @override
  String get feedbackThanks => 'ধন্যবাদ। এতে আমরা আরও ভালো হতে পারি।';

  @override
  String get feedbackFailed => 'পাঠানো যায়নি। সংযোগ দেখে আবার চেষ্টা করুন।';

  @override
  String get pickerConfirmTitle => 'এটাই কি পণ্যটি?';

  @override
  String get pickerChooseTitle => 'কোনটি?';

  @override
  String pickerReadAs(String text) {
    return 'আমরা প্যাকে “$text” পড়েছি।';
  }

  @override
  String get pickerYes => 'হ্যাঁ, এটাই';

  @override
  String get pickerNoRetake => 'না, আবার ছবি তুলুন';

  @override
  String get pickerNoneRetake => 'কোনোটাই না, আবার তুলুন';

  @override
  String get sourceOpenFoodFacts => 'Open Food Facts';

  @override
  String get sourceCalfitDb => 'CalFit ডেটাবেস';

  @override
  String get retakeHint =>
      'পণ্যের নাম স্পষ্ট দেখিয়ে আবার ছবি তুলুন, বা প্যাকের পিছনের ছবি তুলুন।';

  @override
  String identifiedAs(String name) {
    return 'চিহ্নিত: $name';
  }

  @override
  String identifiedSource(String source) {
    return 'প্রতি 100 গ্রাম/মিলিতে পুষ্টি, উৎস: $source';
  }

  @override
  String get notThisProduct => 'এই পণ্য নয়?';

  @override
  String get removeScanTitle => 'এই স্ক্যান সরাবেন?';

  @override
  String get removeScanBody =>
      'এটি আপনার ইতিহাস থেকে মুছে যাবে, যাতে আবার ছবি তুলতে পারেন।';

  @override
  String get remove => 'সরান';

  @override
  String get scanRemoved =>
      'স্ক্যান সরানো হয়েছে। আবার চেষ্টা করতে স্ক্যান চাপুন।';

  @override
  String get couldntRemove => 'স্ক্যান সরানো যায়নি। আবার চেষ্টা করুন।';

  @override
  String get servingUnknownTitle => 'সার্ভিং সাইজ অজানা';

  @override
  String get servingUnknownBody =>
      'এই লেবেলের সংখ্যাগুলো প্রতি 100 গ্রাম/মিলি না প্রতি সার্ভিং, তা বলা নেই। প্যাক দেখে সার্ভিং সাইজ যোগ করুন; পরের বার এই পণ্য স্ক্যান করলে আমরা এটি ব্যবহার করব।';

  @override
  String get addServingSize => 'সার্ভিং সাইজ যোগ করুন';

  @override
  String get servingSheetTitle => 'সার্ভিং সাইজ';

  @override
  String get servingAmountLabel => 'এক সার্ভিং (গ্রাম বা মিলি)';

  @override
  String get servingAmountHelp => 'প্যাকে “serving size” বা নেট পরিমাণ দেখুন।';

  @override
  String get servingBasisLabel => 'লেবেলের সংখ্যাগুলো';

  @override
  String get basisPer100 => 'প্রতি 100 গ্রাম/মিলি';

  @override
  String get basisPerServing => 'প্রতি সার্ভিং';

  @override
  String servingSaved(String amount) {
    return 'সেভ হয়েছে: প্রতি সার্ভিং $amount গ্রাম/মিলি। পরের বার এই পণ্য স্ক্যান করলে আমরা এটি ব্যবহার করব।';
  }

  @override
  String get servingSaveFailed =>
      'সেভ করা যায়নি। সংযোগ দেখে আবার চেষ্টা করুন।';

  @override
  String labelNotePer100(String source) {
    return 'প্রতি 100 গ্রাম/মিলি, উৎস: $source। ড্যাশ মানে অজানা।';
  }

  @override
  String labelNoteYourServing(String amount) {
    return '$amount গ্রাম/মিলির সার্ভিংয়ে, আপনার সেভ করা সার্ভিং সাইজ।';
  }

  @override
  String get confirmingProduct => 'পণ্যটি দেখা হচ্ছে…';
}
