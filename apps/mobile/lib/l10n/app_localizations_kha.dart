// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Khasi (`kha`).
class AppLocalizationsKha extends AppLocalizations {
  AppLocalizationsKha([String locale = 'kha']) : super(locale);

  @override
  String get appName => 'CalFit';

  @override
  String get tryAgain => 'Pyrshang sa shisien';

  @override
  String get cancel => 'Pynsangeh';

  @override
  String get save => 'Buh';

  @override
  String get done => 'Lah dep';

  @override
  String get edit => 'Pynkylla';

  @override
  String get add => 'Pyndap';

  @override
  String get close => 'Khang';

  @override
  String get back => 'Phai';

  @override
  String get seeAll => 'Khmih baroh';

  @override
  String get saved => 'Lah buh';

  @override
  String get notSet => 'Ym pat pyndap';

  @override
  String get unknownBrand => 'Ym tip ïa ka brand';

  @override
  String get unnamedProduct => 'Ka mar ym don kyrteng';

  @override
  String get scanAProduct => 'Scan ïa ka mar';

  @override
  String get navHome => 'Ïing';

  @override
  String get navHistory => 'History';

  @override
  String get navInsights => 'Insights';

  @override
  String get navProfile => 'Profile';

  @override
  String get timeJustNow => 'mynta';

  @override
  String timeMinutes(int n) {
    return '$n min';
  }

  @override
  String timeHours(int n) {
    return '$n kynta';
  }

  @override
  String timeDays(int n) {
    return '$n sngi';
  }

  @override
  String get today => 'Mynta ka sngi';

  @override
  String get yesterday => 'Mynhynnin';

  @override
  String get errorNetwork =>
      'Ym lah ban poi sha ka server jong CalFit. Peit ïa ka internet bad pyrshang sa shisien.';

  @override
  String get errorTimeout => 'La slem bha. Sngewbha pyrshang sa shisien.';

  @override
  String get errorServer =>
      'Ka server jong CalFit ka don jingeh mynta. Pyrshang hadien.';

  @override
  String get errorNotFound => 'Ym shem ïa kane.';

  @override
  String get errorUnauthorized =>
      'Dei ban pynthymmai ïa ka session. Sngewbha pyrshang sa shisien.';

  @override
  String get errorScanLimit =>
      'Lah dep ka jingkhap scan jong mynta ka sngi. Kan sdang thymmai ha pdeng miet (UTC).';

  @override
  String get errorProfileReset =>
      'Ka sign-in jong phi la reset, namarkata ka profile koit-khiah jong phi kam don shuh ha ka server jong ngi. Sngewbha thoh biang ha Profile shwa ba phi scan.';

  @override
  String get errorPrescriptionLimit =>
      'Phi la poi ha ka jingkhang prescription jong kane ka sngi. Pyrshang biang lashai.';

  @override
  String get errorGeneric =>
      'Don kaei kaei ba bakla. Sngewbha pyrshang sa shisien.';

  @override
  String get errorImageOpen =>
      'Ym lah ban plie ïa kane ka dur. Sngewbha jied kawei pat.';

  @override
  String get greetingStillUp => 'Hynrei pat ïai sngewthuh';

  @override
  String get greetingMorning => 'Khublei, mynstep';

  @override
  String get greetingAfternoon => 'Khublei, mynsngi';

  @override
  String get greetingEvening => 'Khublei, janmiet';

  @override
  String get greetingNight => 'Khublei, mynmiet';

  @override
  String get homeTitleNoName => 'To peit ïa ka jingbam jong phi';

  @override
  String get homeErrorTitle => 'Ym lah ban plie ïa ka dashboard';

  @override
  String latestScan(String when) {
    return 'Ka scan kaba khatduh · $when';
  }

  @override
  String get firstScanTitle => 'Scan ïa ka mar kaba nyngkong';

  @override
  String get firstScanBody =>
      'Shim dur ïa ka liang hadien jong ka packet jingbam. Ngin pule ïa ka label bad ong kumno ka biang ïa ka profile jong phi.';

  @override
  String get personaliseTitle => 'Pynbiang ïa ki score na ka bynta jong phi';

  @override
  String get personaliseBody =>
      'Pyndap ïa ki jingpang, ki allergy bad ki thong jong phi.';

  @override
  String get statScans => 'Ki scan';

  @override
  String get statAverage => 'Average';

  @override
  String get statBest => 'Kaba bha tam';

  @override
  String get scoringForYou => 'Score na ka bynta jong phi';

  @override
  String get scoringEmpty =>
      'Ym pat pyndap kano kano, te ki score ki bud tang ki jingmut baroh kawei.';

  @override
  String allergyChip(String name) {
    return 'Allergy $name';
  }

  @override
  String get recentScans => 'Ki scan ba mynta';

  @override
  String get switchToLight => 'Leit sha ka mode shai';

  @override
  String get switchToDark => 'Leit sha ka mode dum';

  @override
  String get historyTitle => 'History';

  @override
  String get historyErrorTitle => 'Ym lah ban plie ïa ka history';

  @override
  String get historyEmptyTitle => 'Ym pat don kano kano hangne';

  @override
  String get historyEmptyBody =>
      'Ki mar baroh ba phi scan kin paw hangne lem bad ka score, ba phi lah ban khmih ha kano kano ka por.';

  @override
  String get insightsTitle => 'Insights';

  @override
  String get insightsErrorTitle => 'Ym lah ban plie ïa ki insights';

  @override
  String get insightsEmptyTitle => 'Ki trend jong phi kin paw hangne';

  @override
  String get insightsEmptyBody =>
      'Scan ïa katto katne ki mar, nangta phin ïohi ïa ka average score, kaei ba paw bun tam, bad ki mar kiba bha tam.';

  @override
  String get averageScore => 'average score';

  @override
  String scanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scan',
      one: '1 scan',
    );
    return '$_temp0';
  }

  @override
  String get weekByWeek => 'Shi taiew shi taiew';

  @override
  String get weekByWeekBody =>
      'Ka average score jong ki mar ba phi scan man la ka taiew';

  @override
  String weekNoScans(String date) {
    return 'Ka taiew $date: ym don scan';
  }

  @override
  String weekSummary(String date, String score, int count) {
    return 'Ka taiew $date: average $score na $count scan';
  }

  @override
  String get flaggedMost => 'Kaei ba paw bun tam';

  @override
  String get flaggedMostBody => 'Ki jingeh ba shem ha ki scan jong phi';

  @override
  String countOfTotal(int count, int total) {
    return '$count na $total';
  }

  @override
  String get bestPicks => 'Ki mar kiba bha tam';

  @override
  String get secondLook => 'Khmih sa shisien';

  @override
  String get secondLookBody =>
      'Ki mar kiba ïoh score kaba duna na ka bynta ka profile jong phi';

  @override
  String basedOnScans(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Na ki $count scan kiba khatduh jong phi.',
      one: 'Na ka scan kaba khatduh jong phi.',
    );
    return '$_temp0';
  }

  @override
  String get yourGoals => 'Ki thong jong phi';

  @override
  String get yourGoalsBody =>
      'Kumno ki scan jong phi ki biang ïa ki thong jong phi';

  @override
  String goalFits(int fits, int checked) {
    return '$fits na $checked scan ki biang ïa kane ka thong';
  }

  @override
  String get goalNoData =>
      'Ym pat don scan bad ki jingtip ba dei ban don na ka bynta kane ka thong.';

  @override
  String get goalNotTracked =>
      'Ym pat peit. CalFit ym pat don ka rule na ka bynta kane ka thong.';

  @override
  String goalMainIssue(String issue) {
    return 'Ka jingeh kaba paw bun tam: $issue';
  }

  @override
  String goalChecks(String basis) {
    return 'Peit ïa: $basis';
  }

  @override
  String get addGoalsPrompt =>
      'Pyndap ïa ki thong ha Profile ban ïohi kumno ki scan jong phi ki biang.';

  @override
  String toTargetLose(String kg) {
    return '$kg kg kham bun ban ïa ka jingkhia ba phi thong';
  }

  @override
  String toTargetGain(String kg) {
    return '$kg kg kham duna ban ïa ka jingkhia ba phi thong';
  }

  @override
  String get atTarget => 'Phi lah poi ha ka jingkhia ba phi thong';

  @override
  String get goal_weight_loss => 'Pyduna ïa ka jingkhia';

  @override
  String get goal_muscle_gain => 'Pynheh ïa ki doh';

  @override
  String get goal_maintain_weight => 'Ïada ïa ka jingkhia';

  @override
  String get goal_improve_energy => 'Kham bun bor';

  @override
  String get goal_improve_digestion => 'Ka jingthaw kaba kham bha';

  @override
  String get goal_reduce_inflammation => 'Kham duna ka jingshit';

  @override
  String get goal_manage_blood_sugar => 'Ïada ïa ka blood sugar';

  @override
  String get goal_heart_health => 'Ka jingkoit jingkhiah ka dohnud';

  @override
  String get condition_diabetes_type_1 => 'Type 1 diabetes';

  @override
  String get condition_diabetes_type_2 => 'Type 2 diabetes';

  @override
  String get condition_prediabetes => 'Prediabetes';

  @override
  String get condition_hypertension => 'Blood pressure ba jrong';

  @override
  String get condition_high_cholesterol => 'Cholesterol ba jrong';

  @override
  String get condition_celiac_disease => 'Celiac';

  @override
  String get condition_ibs => 'IBS';

  @override
  String get condition_kidney_disease => 'Jingpang kidney';

  @override
  String get condition_heart_disease => 'Jingpang dohnud';

  @override
  String get condition_obesity => 'Jingkhia bun palat';

  @override
  String get condition_lactose_intolerance => 'Lactose intolerance';

  @override
  String get condition_anaemia => 'Anaemia';

  @override
  String get diet_vegetarian => 'Vegetarian';

  @override
  String get diet_vegan => 'Vegan';

  @override
  String get diet_gluten_free => 'Ym don gluten';

  @override
  String get diet_dairy_free => 'Ym don dud';

  @override
  String get diet_halal => 'Halal';

  @override
  String get diet_kosher => 'Kosher';

  @override
  String get diet_low_carb => 'Low carb';

  @override
  String get diet_keto => 'Keto';

  @override
  String get diet_paleo => 'Paleo';

  @override
  String get suitabilityExcellent => 'Biang bha eh';

  @override
  String get suitabilityGood => 'Biang bha';

  @override
  String get suitabilityFair => 'Biang shibit';

  @override
  String get suitabilityPoor => 'Ym biang bha';

  @override
  String get suitabilityNotSuitable => 'Ym biang';

  @override
  String get suitabilityUnknown => 'Ym tip';

  @override
  String get profileTitle => 'Profile';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get profileErrorTitle => 'Ym lah ban plie ïa ka profile';

  @override
  String get addYourName => 'Pyndap ïa ka kyrteng jong phi';

  @override
  String get introduceYourself =>
      'Nym ïa ka pencil ban ai jingtip shaphang jong phi';

  @override
  String get signedInAnonymously => 'Sign in khlem kyrteng ha kane ka device';

  @override
  String get editName => 'Pynkylla ïa ka kyrteng';

  @override
  String get profileSetup => 'Pynbiang ïa ka profile';

  @override
  String filledOf(int filled, int total) {
    return '$filled na $total';
  }

  @override
  String get moreAccurate =>
      'Katba phi pyndap kham bun, katta ki score kin kham beit.';

  @override
  String get sectionGoals => 'Ki thong';

  @override
  String get goalsCaption => 'Kaei ba phi treikam na ka bynta?';

  @override
  String get sectionConditions => 'Ki jingpang';

  @override
  String get conditionsCaption =>
      'Ngi pyduna ïa ka score jong ki mar kiba pynsniew ïa kine.';

  @override
  String get sectionDiet => 'Ka jingbam';

  @override
  String get dietCaption => 'Ngi pynpaw ïa ki mar kiba ym bud ïa kine.';

  @override
  String get sectionAllergies => 'Ki allergy';

  @override
  String get allergiesCaption =>
      'Lada don kine ha ki ingredient, ngin ai jingmaham.';

  @override
  String get yourName => 'Ka kyrteng jong phi';

  @override
  String get nameHint => 'Kumno ngin khot ïa phi?';

  @override
  String get allergiesHint => 'kum ka peanut, soy';

  @override
  String get noAllergies => 'Ym pat pyndap allergy.';

  @override
  String get addAllergy => 'Pyndap allergy';

  @override
  String get takePhoto => 'Shim dur';

  @override
  String get chooseFromGallery => 'Jied na ka gallery';

  @override
  String get bodyTitle => 'Ka met';

  @override
  String get bodyCaption =>
      'Ym donkam. Na ka bynta BMI bad ban peit ïa ki thong jong phi.';

  @override
  String get addBodyDetails => 'Pyndap ïa ka jingjrong, ka jingkhia bad kiwei';

  @override
  String get bodyEditTitle => 'Ki jingtip shaphang ka met';

  @override
  String get height => 'Ka jingjrong';

  @override
  String get weight => 'Ka jingkhia';

  @override
  String get targetWeight => 'Ka jingkhia ba phi thong';

  @override
  String get bmi => 'BMI';

  @override
  String get age => 'Ka rta';

  @override
  String get birthYear => 'U snem ba la kha';

  @override
  String get sex => 'Ka jait';

  @override
  String get sexFemale => 'Kynthei';

  @override
  String get sexMale => 'Shynrang';

  @override
  String get sexOther => 'Kiwei';

  @override
  String get activityLevel => 'Katno phi treikam';

  @override
  String get activity_sedentary => 'Shong bun';

  @override
  String get activity_sedentary_hint => 'Kam shong, khyndiat exercise';

  @override
  String get activity_light => 'Treikam khyndiat';

  @override
  String get activity_light_hint => 'Exercise 1–3 sngi ha ka taiew';

  @override
  String get activity_moderate => 'Treikam pdeng';

  @override
  String get activity_moderate_hint => 'Exercise 3–5 sngi ha ka taiew';

  @override
  String get activity_active => 'Treikam bun';

  @override
  String get activity_active_hint => 'Exercise eh 6–7 sngi ha ka taiew';

  @override
  String get activity_very_active => 'Treikam bun eh';

  @override
  String get activity_very_active_hint => 'Kam ba donkam bor bad training';

  @override
  String get unitCm => 'cm';

  @override
  String get unitKg => 'kg';

  @override
  String ageYears(int age) {
    return '$age snem';
  }

  @override
  String get bmiUnderweight => 'Jingkhia duna';

  @override
  String get bmiNormal => 'Ka jingkhia ba biang';

  @override
  String get bmiOverweight => 'Jingkhia bun';

  @override
  String get bmiObese => 'Jingkhia bun palat';

  @override
  String get bmiNote =>
      'Ki BMI na ka bynta ki Asian Indian: 18.5–22.9 biang, 23–24.9 jingkhia bun, 25+ jingkhia bun palat.';

  @override
  String get bmiNeedsBoth =>
      'Pyndap ïa ka jingjrong bad ka jingkhia ban ïohi ïa ka BMI.';

  @override
  String invalidRange(String min, String max) {
    return 'Thoh ïa ka number hapdeng $min bad $max';
  }

  @override
  String get clearValue => 'Weng';

  @override
  String get prescription => 'Prescription';

  @override
  String get prescriptionReading => 'Pule ïa ka prescription jong phi…';

  @override
  String get prescriptionBody =>
      'Scan ïa kawei ban ngi kren shaphang ki jingpang bad ki allergy. Phi ïa kan pynshisha shuwa ba ngin buh.';

  @override
  String get prescriptionConsentTitle => 'Pule ïa ka prescription?';

  @override
  String get prescriptionConsentGemini =>
      'Ka dur jong phi la phah sha Google Gemini ban pule.';

  @override
  String get prescriptionConsentNoSave =>
      'CalFit ym buh ïa ka dur ne kaei ba la pule na ka.';

  @override
  String get prescriptionConsentSuggestOnly =>
      'Ngi tang ai jingmut shaphang ki jingpang bad ki allergy. Ym pyndap kano kano khlem ba phi tick bad pynshisha.';

  @override
  String get prescriptionConsentNotAdvice =>
      'Kane kam dei ka jingmut doktor. Peit ïa ki jingmut baroh.';

  @override
  String get agreeAndContinue => 'Ngan ïa, leit shaphrang';

  @override
  String get reviewTitle => 'Peit biang';

  @override
  String get selectWhatToAdd => 'Jied ïa kaei ban pyndap';

  @override
  String addSelected(int count) {
    return 'Pyndap ïa kiba la jied ($count)';
  }

  @override
  String get nothingToAdd => 'Ym shem kano kano ban pyndap na kane ka dur.';

  @override
  String get tickWhatApplies =>
      'Tick ïa kaei ba dei na ka bynta jong phi. Ym pyndap kano kano khlem ba phi pynshisha.';

  @override
  String inferredFromMedicine(String medicine) {
    return 'Na ka dawai ($medicine). Peit lada kane ka dei na ka bynta jong phi.';
  }

  @override
  String get statedOnPrescription => 'La thoh ha ka prescription';

  @override
  String get readNotAdded => 'La pule hynrei ym pat pyndap';

  @override
  String get newScan => 'Scan thymmai';

  @override
  String get scanHeadline => 'Shim dur ïa ka liang hadien jong ka packet';

  @override
  String get scanBody =>
      'Buh ïa ki ingredient bad ka nutrition table ha ka frame. Ngin peit lem bad ki jingpang, ki allergy bad ki thong jong phi.';

  @override
  String get tapToTakePhoto => 'Nym ban shim dur';

  @override
  String get orPickFromGallery => 'Ne jied na ka gallery jong phi';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get checkThisProduct => 'Peit ïa kane ka mar';

  @override
  String get removePhoto => 'Weng ïa ka dur';

  @override
  String get tipsTitle => 'Na ka bynta ka jingmih kaba bha tam';

  @override
  String get tipBackOfPack =>
      'Ka liang khmat ka biang; ka liang shadien ka ai ia ka jingpeit kaba pura';

  @override
  String get tipLight => 'Shai bha, ym don jingphyrnai ha ka plastic';

  @override
  String get tipFillFrame =>
      'Pynbiang ïa ka frame da ki ingredient bad ka nutrition table';

  @override
  String get stepReadingLabel => 'Pule ïa ka label';

  @override
  String get stepCheckingProfile => 'Peit ïa ka profile jong phi';

  @override
  String get stepWeighing => 'Peit ïa ki jingshem';

  @override
  String get stepAlternatives => 'Wad ïa kiwei pat';

  @override
  String get scanResultTitle => 'Ka jingmih jong ka scan';

  @override
  String get scanDetailsTitle => 'Ki jingtip jong ka scan';

  @override
  String get couldntOpenScan => 'Ym lah ban plie ïa kane ka scan';

  @override
  String get cantReadLabel => 'Ym lah ban pule ïa kane ka label';

  @override
  String get cantReadLabelBody =>
      'Ka dur ka ym shai ne ka label ka don sharud ka frame. Ka dur kaba shai bad jan jong ka liang hadien ka packet ka trei bha.';

  @override
  String get tryAnotherPhoto => 'Pyrshang da kawei pat ka dur';

  @override
  String scannedWhen(String when) {
    return 'La scan $when';
  }

  @override
  String get outOf10 => 'na 10';

  @override
  String scoreOutOf10(String score) {
    return 'Score $score na 10';
  }

  @override
  String whatWeFound(int count) {
    return 'Kaei ba ngi shem ($count)';
  }

  @override
  String get severityAvoid => 'Kynran';

  @override
  String get severityCaution => 'Ïada';

  @override
  String get severityHeadsUp => 'Peit bha';

  @override
  String get severityGoodToKnow => 'Bha ban tip';

  @override
  String pointsLost(String points) {
    return '−$points pts';
  }

  @override
  String get onTheLabel => 'Ha ka label';

  @override
  String get perServingNote =>
      'Man la ka serving. Ka dash ka mut ba ym don ha ka label.';

  @override
  String get nutrientCalories => 'Calories';

  @override
  String get nutrientTotalFat => 'Fat baroh';

  @override
  String get nutrientSaturatedFat => 'Saturated fat';

  @override
  String get nutrientSodium => 'Sodium';

  @override
  String get nutrientCarbs => 'Carbs baroh';

  @override
  String get nutrientSugars => 'Sugar';

  @override
  String get nutrientProtein => 'Protein';

  @override
  String get ingredients => 'Ki ingredient';

  @override
  String get tryInstead => 'Pyrshang ïa kane pat';

  @override
  String get tryInsteadBody =>
      'Ki mar shisha na ka jait kajuh kiba kham biang ïa phi';

  @override
  String get inOurDatabase => 'Ha ka database jong ngi';

  @override
  String get noAlternative =>
      'Ym don kawei pat kaba kham biang ban ai jingmut.';

  @override
  String get serverTextNote =>
      'Ki jingtip na ka scan ki dang don ha ka ktien English.';

  @override
  String get disclaimerShort =>
      'CalFit ka pule ïa ki label; kam dei ka jingmut doktor. Kylli ïa u doktor ne u dietitian.';

  @override
  String get disclaimerTitle => 'Ka jingtip shuwa ba phi sdang';

  @override
  String get disclaimerBody =>
      'CalFit ka scan ïa ka label bad ka ong kumno ka mar ka biang ïa ka profile jong phi. Kam lah ban shim jaka u doktor ne u dietitian, bad kam tip ïa kaei baroh ba don ha ka jingbam.\n\nLada phi don allergy, pule hi ïa ka packet, bad kylli ïa u doktor jong phi shuwa ba phin pynkylla ïa ka jingbam na ka daw ka scan.';

  @override
  String get gotIt => 'Lah sngewthuh';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearance => 'Kumno ka paw';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'Kum ka phone';

  @override
  String get themeLight => 'Shai';

  @override
  String get themeDark => 'Dum';

  @override
  String get textSize => 'Ka jingheh ki dak';

  @override
  String get textSizeSmall => 'Rit';

  @override
  String get textSizeDefault => 'Kumba dei';

  @override
  String get textSizeLarge => 'Heh';

  @override
  String get textSizeExtraLarge => 'Heh eh';

  @override
  String get textSizePreview => 'Masala noodles · 1,172 mg sodium man la 100 g';

  @override
  String get language => 'Ka ktien';

  @override
  String get languagePhone => 'Kum ka phone';

  @override
  String get translationNote =>
      'Ki nongkren ktien la ki dang peit ïa ki jingkylla ktien; katto katne ki kyntien ki lah ban kylla.';

  @override
  String get privacyAndData => 'Privacy bad data';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get deleteMyData => 'Weng ïa ka data jong nga';

  @override
  String get deleteMyDataBody =>
      'Weng noh ïa ka profile, ki scan bad ki dur jong phi na ki server jong CalFit.';

  @override
  String get deleteConfirmTitle => 'Weng noh ïa ka data baroh jong phi?';

  @override
  String get deleteConfirmBody =>
      'Ka profile, ki scan baroh bad ki dur baroh jong phi kin jah noh na ki server jong CalFit. Ym lah ban pynwan biang.';

  @override
  String get deleteConfirmButton => 'Weng noh baroh';

  @override
  String get dataDeleted => 'La weng noh ïa ka data jong phi.';

  @override
  String get about => 'Shaphang';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get dataSources => 'Na hangno ka data';

  @override
  String get dataSourcesBody =>
      'Ka data jong ki mar na Open Food Facts (openfoodfacts.org), hapoh ka Open Database Licence. Ki BMI ki bud ïa ki cut-off na ka bynta ki Asian Indian.';

  @override
  String get notMedicalAdviceTitle => 'Kam dei ka jingmut doktor';

  @override
  String get viewPhoto => 'Khmih ïa ka dur';

  @override
  String get onbWelcomeTitle => 'Tip ïa kaei ba don ha ka jingbam jong phi';

  @override
  String get onbWelcomeBody =>
      'Shim dur ïa ka liang hadien jong ka packet jingbam. CalFit kan pule ïa ka label bad ong kumno ka biang ïa phi.';

  @override
  String get onbPointScan =>
      'Ki packet na India: biscuit, namkeen, noodles, ki jingdih bad kiwei';

  @override
  String get onbPointPersonal =>
      'Ki score ki kylla katkum ki jingpang, ki allergy bad ki thong jong phi';

  @override
  String get onbPointAlternatives =>
      'Ka ai jingmut ïa ki mar shisha kiba kham biang ïa phi';

  @override
  String get onbChooseLanguage => 'Jied ïa ka ktien jong phi';

  @override
  String get onbProfileTitle => 'Ong khyndiat shaphang jong phi';

  @override
  String get onbProfileBody =>
      'Jied ïa kaei kaei ba dei. Phi lah ban pynkylla ha Profile ha kano kano ka por.';

  @override
  String get onbAllergiesTitle => 'Ki allergy';

  @override
  String get onbConditionsTitle => 'Ki jingpang';

  @override
  String get onbDietTitle => 'Ka jingbam';

  @override
  String get onbSafetyTitle => 'Kawei ka jingtip kaba donkam';

  @override
  String get onbGetStarted => 'Sdang';

  @override
  String get onbNext => 'Shaphrang';

  @override
  String get onbSkip => 'Iehnoh';

  @override
  String onbStep(int current, int total) {
    return 'Ka step $current na $total';
  }

  @override
  String get allergy_peanut => 'Peanut';

  @override
  String get allergy_milk => 'Dud';

  @override
  String get allergy_gluten => 'Gluten';

  @override
  String get allergy_soy => 'Soy';

  @override
  String get allergy_egg => 'Pylleng';

  @override
  String get allergy_tree_nuts => 'Tree nuts';

  @override
  String get nutrientSalt => 'Mluh';

  @override
  String get atAGlance => 'Ha ka jingkhmih kawei';

  @override
  String get levelsPer100g =>
      'Ha man ka 100 g, katkum ki kyrdan traffic-light. Kumjuh na ka bynta baroh.';

  @override
  String get levelsPer100ml =>
      'Ha man ka 100 ml, katkum ki kyrdan traffic-light. Kumjuh na ka bynta baroh.';

  @override
  String get levelLow => 'Duna';

  @override
  String get levelMedium => 'Pdeng';

  @override
  String get levelHigh => 'Bun';

  @override
  String get feedbackQuestion => 'Hato ka jingmih ka biang?';

  @override
  String get feedbackWhy =>
      'Ka jubab jong phi ka iarap ban peit katno ka CalFit ka dei.';

  @override
  String get feedbackYes => 'Hooid';

  @override
  String get feedbackNo => 'Ym pura';

  @override
  String get feedbackWhatWrong => 'Kaei ba bakla?';

  @override
  String get issueWrongProduct => 'Bakla ka product';

  @override
  String get issueWrongNutrition => 'Ki number nutrition';

  @override
  String get issueWrongIngredients => 'Ki ingredient';

  @override
  String get issueMissedAllergen => 'Ym shem ka allergen';

  @override
  String get issueScoreUnfair => 'Ka score kam biang';

  @override
  String get issueOther => 'Kiwei pat';

  @override
  String get feedbackSend => 'Phah';

  @override
  String get feedbackThanks => 'Khublei. Kane ka iarap ia ngi ban kham bha.';

  @override
  String get feedbackFailed =>
      'Ym lah ban phah. Peit ia ka connection bad pyrshang sa shisien.';

  @override
  String get pickerConfirmTitle => 'Hato kane ka product?';

  @override
  String get pickerChooseTitle => 'Kaei kaba?';

  @override
  String pickerReadAs(String text) {
    return 'Ngi la pule “$text” ha ka pack.';
  }

  @override
  String get pickerYes => 'Hooid, kane';

  @override
  String get pickerNoRetake => 'Em, shim biang ka dur';

  @override
  String get pickerNoneRetake => 'Ym kawei na kine, shim biang';

  @override
  String get sourceOpenFoodFacts => 'Open Food Facts';

  @override
  String get sourceCalfitDb => 'CalFit database';

  @override
  String get retakeHint =>
      'Shim biang ka dur ha kaba paw ka kyrteng product, lane shim ia ka liang shadien ka pack.';

  @override
  String identifiedAs(String name) {
    return 'Lah ithuh: $name';
  }

  @override
  String identifiedSource(String source) {
    return 'Nutrition ha man ka 100 g/ml na $source';
  }

  @override
  String get notThisProduct => 'Ym dei kane ka product?';

  @override
  String get removeScanTitle => 'Weng ia kane ka scan?';

  @override
  String get removeScanBody =>
      'Yn weng na ka history jong phi ba phi lah ban shim biang ka dur.';

  @override
  String get remove => 'Weng';

  @override
  String get scanRemoved => 'La weng ia ka scan. Nion Scan ban pyrshang biang.';

  @override
  String get couldntRemove =>
      'Ym lah ban weng ia ka scan. Pyrshang sa shisien.';

  @override
  String get servingUnknownTitle => 'Ym tip ia ka serving size';

  @override
  String get servingUnknownBody =>
      'Ki number ha kane ka label ym ong lada ki long ha man ka 100 g/ml ne ha man ka serving. Peit ia ka pack bad bud ia ka serving size; ngin pyndonkam ha ka por ba phi scan biang ia kane ka product.';

  @override
  String get addServingSize => 'Bud ia ka serving size';

  @override
  String get servingSheetTitle => 'Serving size';

  @override
  String get servingAmountLabel => 'Kawei ka serving (g ne ml)';

  @override
  String get servingAmountHelp =>
      'Ha ka pack, wad ia ka “serving size” ne ka net quantity.';

  @override
  String get servingBasisLabel => 'Ki number ha ka label ki long';

  @override
  String get basisPer100 => 'Ha man ka 100 g/ml';

  @override
  String get basisPerServing => 'Ha man ka serving';

  @override
  String servingSaved(String amount) {
    return 'La save: $amount g/ml ha man ka serving. Ngin pyndonkam ha ka por ba phi scan biang ia kane ka product.';
  }

  @override
  String get servingSaveFailed =>
      'Ym lah ban save. Peit ia ka connection bad pyrshang sa shisien.';

  @override
  String labelNotePer100(String source) {
    return 'Ha man ka 100 g/ml, na $source. Ka dash ka mut ym tip.';
  }

  @override
  String labelNoteYourServing(String amount) {
    return 'Ha ka serving $amount g/ml, ka serving size ba phi la save.';
  }

  @override
  String get confirmingProduct => 'Dang peit ia kane ka product…';
}
