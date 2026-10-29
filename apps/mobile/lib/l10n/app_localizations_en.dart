// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'CalFit';

  @override
  String get tryAgain => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get seeAll => 'See all';

  @override
  String get saved => 'Saved';

  @override
  String get notSet => 'Not set';

  @override
  String get unknownBrand => 'Unknown brand';

  @override
  String get unnamedProduct => 'Unnamed product';

  @override
  String get scanAProduct => 'Scan a product';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get navInsights => 'Insights';

  @override
  String get navProfile => 'Profile';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutes(int n) {
    return '${n}m';
  }

  @override
  String timeHours(int n) {
    return '${n}h';
  }

  @override
  String timeDays(int n) {
    return '${n}d';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get errorNetwork =>
      'Can\'t reach the CalFit server. Check your internet and try again.';

  @override
  String get errorTimeout => 'That took too long. Please try again.';

  @override
  String get errorServer =>
      'The CalFit server is having a bad moment. Please try again shortly.';

  @override
  String get errorNotFound => 'We couldn\'t find that.';

  @override
  String get errorUnauthorized =>
      'Your session needs refreshing. Please try again.';

  @override
  String get errorScanLimit =>
      'You\'ve reached today\'s scan limit. It resets at midnight (UTC).';

  @override
  String get errorProfileReset =>
      'Your sign-in was reset, so your health profile is no longer on our server. Please fill it in again in Profile before scanning.';

  @override
  String get errorPrescriptionLimit =>
      'You\'ve reached today\'s prescription limit. Try again tomorrow.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorImageOpen =>
      'We couldn\'t open that image. Please try another.';

  @override
  String get greetingStillUp => 'Still up';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get greetingNight => 'Good night';

  @override
  String get homeTitleNoName => 'Let\'s check your food';

  @override
  String get homeErrorTitle => 'Couldn\'t load your dashboard';

  @override
  String latestScan(String when) {
    return 'Latest scan · $when';
  }

  @override
  String get firstScanTitle => 'Scan your first product';

  @override
  String get firstScanBody =>
      'Take a photo of the back of any packaged food. We\'ll read the label and tell you how well it fits your profile.';

  @override
  String get personaliseTitle => 'Personalise your scores';

  @override
  String get personaliseBody => 'Add your conditions, allergies and goals.';

  @override
  String get statScans => 'Scans';

  @override
  String get statAverage => 'Average';

  @override
  String get statBest => 'Best';

  @override
  String get scoringForYou => 'Scoring for you';

  @override
  String get scoringEmpty =>
      'Nothing added yet, so scores use general guidance only.';

  @override
  String get scoredForTitle => 'Scored for';

  @override
  String get scoredForNote =>
      'Your profile when you scanned this. Changing your profile later doesn\'t change this rating.';

  @override
  String get scoredForNone =>
      'No allergies, conditions, diets or goals were set.';

  @override
  String allergyChip(String name) {
    return '$name allergy';
  }

  @override
  String get recentScans => 'Recent scans';

  @override
  String get switchToLight => 'Switch to light mode';

  @override
  String get switchToDark => 'Switch to dark mode';

  @override
  String get historyTitle => 'History';

  @override
  String get historyErrorTitle => 'Couldn\'t load your history';

  @override
  String get historyEmptyTitle => 'Nothing here yet';

  @override
  String get historyEmptyBody =>
      'Every product you scan shows up here with its score, so you can look back at it any time.';

  @override
  String get insightsTitle => 'Insights';

  @override
  String get insightsErrorTitle => 'Couldn\'t load your insights';

  @override
  String get insightsEmptyTitle => 'Your trends live here';

  @override
  String get insightsEmptyBody =>
      'Scan a few products and you\'ll see your average score, what gets flagged most, and your best picks.';

  @override
  String get averageScore => 'average score';

  @override
  String scanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scans',
      one: '1 scan',
    );
    return '$_temp0';
  }

  @override
  String get weekByWeek => 'Week by week';

  @override
  String get weekByWeekBody => 'Average score of what you scanned each week';

  @override
  String weekNoScans(String date) {
    return 'Week of $date: no scans';
  }

  @override
  String weekSummary(String date, String score, int count) {
    return 'Week of $date: average $score from $count scans';
  }

  @override
  String get flaggedMost => 'What gets flagged most';

  @override
  String get flaggedMostBody => 'Issues found across your scans';

  @override
  String countOfTotal(int count, int total) {
    return '$count of $total';
  }

  @override
  String get bestPicks => 'Your best picks';

  @override
  String get secondLook => 'Worth a second look';

  @override
  String get secondLookBody => 'Products that scored low for your profile';

  @override
  String basedOnScans(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Based on your last $count scans.',
      one: 'Based on your last scan.',
    );
    return '$_temp0';
  }

  @override
  String get yourGoals => 'Your goals';

  @override
  String get yourGoalsBody =>
      'How your scans line up with what you\'re working toward';

  @override
  String goalFits(int fits, int checked) {
    return '$fits of $checked scans fit this goal';
  }

  @override
  String get goalNoData => 'No scans with the details this goal needs yet.';

  @override
  String get goalNotTracked =>
      'Not tracked yet. CalFit doesn\'t have a scoring rule for this goal.';

  @override
  String goalMainIssue(String issue) {
    return 'Most common issue: $issue';
  }

  @override
  String goalChecks(String basis) {
    return 'Checks: $basis';
  }

  @override
  String get addGoalsPrompt =>
      'Add goals in Profile to see how your scans line up with them.';

  @override
  String toTargetLose(String kg) {
    return '$kg kg above your target weight';
  }

  @override
  String toTargetGain(String kg) {
    return '$kg kg below your target weight';
  }

  @override
  String get atTarget => 'You\'re at your target weight';

  @override
  String get goal_weight_loss => 'Weight loss';

  @override
  String get goal_muscle_gain => 'Muscle gain';

  @override
  String get goal_maintain_weight => 'Maintain weight';

  @override
  String get goal_improve_energy => 'More energy';

  @override
  String get goal_improve_digestion => 'Better digestion';

  @override
  String get goal_reduce_inflammation => 'Less inflammation';

  @override
  String get goal_manage_blood_sugar => 'Manage blood sugar';

  @override
  String get goal_heart_health => 'Heart health';

  @override
  String get condition_diabetes_type_1 => 'Type 1 diabetes';

  @override
  String get condition_diabetes_type_2 => 'Type 2 diabetes';

  @override
  String get condition_prediabetes => 'Prediabetes';

  @override
  String get condition_hypertension => 'Hypertension';

  @override
  String get condition_high_cholesterol => 'High cholesterol';

  @override
  String get condition_celiac_disease => 'Celiac disease';

  @override
  String get condition_ibs => 'IBS';

  @override
  String get condition_kidney_disease => 'Kidney disease';

  @override
  String get condition_heart_disease => 'Heart disease';

  @override
  String get condition_obesity => 'Obesity';

  @override
  String get condition_lactose_intolerance => 'Lactose intolerance';

  @override
  String get condition_anaemia => 'Anaemia';

  @override
  String get diet_vegetarian => 'Vegetarian';

  @override
  String get diet_vegan => 'Vegan';

  @override
  String get diet_gluten_free => 'Gluten-free';

  @override
  String get diet_dairy_free => 'Dairy-free';

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
  String get suitabilityExcellent => 'Excellent fit';

  @override
  String get suitabilityGood => 'Good fit';

  @override
  String get suitabilityFair => 'Fair fit';

  @override
  String get suitabilityPoor => 'Poor fit';

  @override
  String get suitabilityNotSuitable => 'Not suitable';

  @override
  String get suitabilityUnknown => 'Unknown';

  @override
  String get profileTitle => 'Profile';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get profileErrorTitle => 'Couldn\'t load your profile';

  @override
  String get addYourName => 'Add your name';

  @override
  String get introduceYourself => 'Tap the pencil to introduce yourself';

  @override
  String get signedInAnonymously => 'Signed in anonymously on this device';

  @override
  String get editName => 'Edit name';

  @override
  String get profileSetup => 'Profile setup';

  @override
  String filledOf(int filled, int total) {
    return '$filled of $total';
  }

  @override
  String get moreAccurate =>
      'The more you add, the more accurate your scores get.';

  @override
  String get sectionGoals => 'Goals';

  @override
  String get goalsCaption => 'What are you working toward?';

  @override
  String get sectionConditions => 'Conditions';

  @override
  String get conditionsCaption =>
      'We lower scores for products that aggravate these.';

  @override
  String get sectionDiet => 'Diet';

  @override
  String get dietCaption => 'We flag products that break these.';

  @override
  String get sectionAllergies => 'Allergies';

  @override
  String get allergiesCaption =>
      'Anything in these ingredients means we warn you.';

  @override
  String get yourName => 'Your name';

  @override
  String get nameHint => 'What should we call you?';

  @override
  String get allergiesHint => 'e.g. peanut, soy';

  @override
  String get noAllergies => 'No allergies added.';

  @override
  String get addAllergy => 'Add allergy';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get bodyTitle => 'Body';

  @override
  String get bodyCaption => 'Optional. Used for BMI and to track your goals.';

  @override
  String get addBodyDetails => 'Add height, weight and more';

  @override
  String get bodyEditTitle => 'Body details';

  @override
  String get height => 'Height';

  @override
  String get weight => 'Weight';

  @override
  String get targetWeight => 'Target weight';

  @override
  String get bmi => 'BMI';

  @override
  String get age => 'Age';

  @override
  String get birthYear => 'Year of birth';

  @override
  String get sex => 'Sex';

  @override
  String get sexFemale => 'Female';

  @override
  String get sexMale => 'Male';

  @override
  String get sexOther => 'Other';

  @override
  String get activityLevel => 'Activity level';

  @override
  String get activity_sedentary => 'Sedentary';

  @override
  String get activity_sedentary_hint => 'Desk job, little exercise';

  @override
  String get activity_light => 'Lightly active';

  @override
  String get activity_light_hint => 'Light exercise 1–3 days a week';

  @override
  String get activity_moderate => 'Moderately active';

  @override
  String get activity_moderate_hint => 'Exercise 3–5 days a week';

  @override
  String get activity_active => 'Active';

  @override
  String get activity_active_hint => 'Hard exercise 6–7 days a week';

  @override
  String get activity_very_active => 'Very active';

  @override
  String get activity_very_active_hint => 'Physical job plus training';

  @override
  String get unitCm => 'cm';

  @override
  String get unitKg => 'kg';

  @override
  String ageYears(int age) {
    return '$age yrs';
  }

  @override
  String get bmiUnderweight => 'Underweight';

  @override
  String get bmiNormal => 'Healthy range';

  @override
  String get bmiOverweight => 'Overweight';

  @override
  String get bmiObese => 'Obese';

  @override
  String get bmiNote =>
      'BMI bands for Asian Indians: 18.5–22.9 healthy, 23–24.9 overweight, 25+ obese.';

  @override
  String get bmiNeedsBoth => 'Add height and weight to see your BMI.';

  @override
  String invalidRange(String min, String max) {
    return 'Enter a number between $min and $max';
  }

  @override
  String get clearValue => 'Clear';

  @override
  String get prescription => 'Prescription';

  @override
  String get prescriptionReading => 'Reading your prescription…';

  @override
  String get prescriptionBody =>
      'Scan one to suggest conditions and allergies. You confirm before anything is saved.';

  @override
  String get prescriptionConsentTitle => 'Read a prescription?';

  @override
  String get prescriptionConsentGemini =>
      'Your photo is sent to Google Gemini to be read.';

  @override
  String get prescriptionConsentNoSave =>
      'CalFit does not save the photo or what is read from it.';

  @override
  String get prescriptionConsentSuggestOnly =>
      'We only suggest conditions and allergies. Nothing is added unless you tick it and confirm.';

  @override
  String get prescriptionConsentNotAdvice =>
      'This is not medical advice. Check every suggestion.';

  @override
  String get agreeAndContinue => 'Agree and continue';

  @override
  String get reviewTitle => 'Review';

  @override
  String get selectWhatToAdd => 'Select what to add';

  @override
  String addSelected(int count) {
    return 'Add selected ($count)';
  }

  @override
  String get nothingToAdd =>
      'We couldn\'t find anything to add from this photo.';

  @override
  String get tickWhatApplies =>
      'Tick what applies to you. Nothing is added until you confirm.';

  @override
  String inferredFromMedicine(String medicine) {
    return 'Inferred from a medicine ($medicine). Check this applies to you.';
  }

  @override
  String get statedOnPrescription => 'Stated on the prescription';

  @override
  String get readNotAdded => 'Read but not added';

  @override
  String get newScan => 'New scan';

  @override
  String get scanHeadline => 'Photograph the back of the pack';

  @override
  String get scanBody =>
      'Get the ingredients and nutrition table in the frame. We\'ll check it against your conditions, allergies and goals.';

  @override
  String get tapToTakePhoto => 'Tap to take a photo';

  @override
  String get orPickFromGallery => 'Or pick one from your gallery';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get checkThisProduct => 'Check this product';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get tipsTitle => 'For the best result';

  @override
  String get tipBackOfPack =>
      'The front works; the back gives the fullest check';

  @override
  String get tipLight => 'Good light, no glare on the plastic';

  @override
  String get tipFillFrame =>
      'Fill the frame with the ingredients and nutrition table';

  @override
  String get stepReadingLabel => 'Reading the label';

  @override
  String get stepCheckingProfile => 'Checking your profile';

  @override
  String get stepWeighing => 'Weighing the findings';

  @override
  String get stepAlternatives => 'Finding alternatives';

  @override
  String get scanResultTitle => 'Scan result';

  @override
  String get scanDetailsTitle => 'Scan details';

  @override
  String get couldntOpenScan => 'Couldn\'t open this scan';

  @override
  String get cantReadLabel => 'We couldn\'t read this label';

  @override
  String get cantReadLabelBody =>
      'The photo was blurry or the label was out of frame. A clearer, closer shot of the back of the pack usually works.';

  @override
  String get tryAnotherPhoto => 'Try another photo';

  @override
  String scannedWhen(String when) {
    return 'Scanned $when';
  }

  @override
  String get outOf10 => 'out of 10';

  @override
  String scoreOutOf10(String score) {
    return 'Score $score out of 10';
  }

  @override
  String whatWeFound(int count) {
    return 'What we found ($count)';
  }

  @override
  String get severityAvoid => 'Avoid';

  @override
  String get severityCaution => 'Caution';

  @override
  String get severityHeadsUp => 'Heads up';

  @override
  String get severityGoodToKnow => 'Good to know';

  @override
  String pointsLost(String points) {
    return '−$points pts';
  }

  @override
  String get onTheLabel => 'On the label';

  @override
  String get perServingNote =>
      'Per serving. A dash means it wasn\'t on the label.';

  @override
  String get nutrientCalories => 'Calories';

  @override
  String get nutrientTotalFat => 'Total fat';

  @override
  String get nutrientSaturatedFat => 'Saturated fat';

  @override
  String get nutrientSodium => 'Sodium';

  @override
  String get nutrientCarbs => 'Total carbs';

  @override
  String get nutrientSugars => 'Sugars';

  @override
  String get nutrientProtein => 'Protein';

  @override
  String get ingredients => 'Ingredients';

  @override
  String get tryInstead => 'Try instead';

  @override
  String get tryInsteadBody =>
      'Real products from the same category that suit you better';

  @override
  String get inOurDatabase => 'In our database';

  @override
  String get noAlternative =>
      'No better-fit alternative to suggest for this one.';

  @override
  String get serverTextNote => 'Details from the scan are in English for now.';

  @override
  String get disclaimerShort =>
      'CalFit reads labels; it is not medical advice. Ask a doctor or dietitian for a diagnosis or treatment.';

  @override
  String get disclaimerTitle => 'A quick note before you start';

  @override
  String get disclaimerBody =>
      'CalFit scans a product label and tells you how well it fits the profile you set. It cannot replace a doctor or dietitian and it won\'t know everything that is in a food.\n\nAlways read the pack yourself if you have an allergy, and check with your clinician before changing anything in your diet because of a scan.';

  @override
  String get gotIt => 'Got it';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'Same as phone';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get textSize => 'Text size';

  @override
  String get textSizeSmall => 'Small';

  @override
  String get textSizeDefault => 'Default';

  @override
  String get textSizeLarge => 'Large';

  @override
  String get textSizeExtraLarge => 'Extra large';

  @override
  String get textSizePreview => 'Masala noodles · 1,172 mg sodium per 100 g';

  @override
  String get language => 'Language';

  @override
  String get languagePhone => 'Same as phone';

  @override
  String get translationNote =>
      'Translations are being checked by native speakers; some wording may change.';

  @override
  String get privacyAndData => 'Privacy & data';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get deleteMyData => 'Delete my data';

  @override
  String get deleteMyDataBody =>
      'Removes your profile, scans and photos from CalFit\'s servers.';

  @override
  String get deleteConfirmTitle => 'Delete all your data?';

  @override
  String get deleteConfirmBody =>
      'Your profile, every scan and every photo will be permanently deleted from CalFit\'s servers. This can\'t be undone.';

  @override
  String get deleteConfirmButton => 'Delete everything';

  @override
  String get dataDeleted => 'Your data has been deleted.';

  @override
  String get about => 'About';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get dataSources => 'Data sources';

  @override
  String get dataSourcesBody =>
      'Product data from Open Food Facts (openfoodfacts.org), available under the Open Database Licence. BMI bands follow the consensus cut-offs for Asian Indians.';

  @override
  String get notMedicalAdviceTitle => 'Not medical advice';

  @override
  String get viewPhoto => 'View the photo';

  @override
  String get onbWelcomeTitle => 'Know what\'s in your food';

  @override
  String get onbWelcomeBody =>
      'Photograph the back of any packaged food. CalFit reads the label and tells you how well it fits you.';

  @override
  String get onbPointScan =>
      'Works with Indian packs: biscuits, namkeen, noodles, drinks and more';

  @override
  String get onbPointPersonal =>
      'Scores change with your conditions, allergies and goals';

  @override
  String get onbPointAlternatives =>
      'Suggests real, similar products that suit you better';

  @override
  String get onbChooseLanguage => 'Choose your language';

  @override
  String get onbProfileTitle => 'Tell us a little about you';

  @override
  String get onbProfileBody =>
      'Pick anything that applies. You can change it any time in Profile.';

  @override
  String get onbAllergiesTitle => 'Allergies';

  @override
  String get onbConditionsTitle => 'Health conditions';

  @override
  String get onbDietTitle => 'Diet';

  @override
  String get onbSafetyTitle => 'One important note';

  @override
  String get onbGetStarted => 'Get started';

  @override
  String get onbNext => 'Next';

  @override
  String get onbSkip => 'Skip';

  @override
  String onbStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get allergy_peanut => 'Peanut';

  @override
  String get allergy_milk => 'Milk';

  @override
  String get allergy_gluten => 'Gluten';

  @override
  String get allergy_soy => 'Soy';

  @override
  String get allergy_egg => 'Egg';

  @override
  String get allergy_tree_nuts => 'Tree nuts';

  @override
  String get nutrientSalt => 'Salt';

  @override
  String get atAGlance => 'At a glance';

  @override
  String get levelsPer100g =>
      'Per 100 g, on the standard traffic-light scale. The same for everyone.';

  @override
  String get levelsPer100ml =>
      'Per 100 ml, on the standard traffic-light scale. The same for everyone.';

  @override
  String get levelLow => 'Low';

  @override
  String get levelMedium => 'Medium';

  @override
  String get levelHigh => 'High';

  @override
  String get feedbackQuestion => 'Was this result right?';

  @override
  String get feedbackWhy =>
      'Your answer helps us check how accurate CalFit is.';

  @override
  String get feedbackYes => 'Yes';

  @override
  String get feedbackNo => 'Not quite';

  @override
  String get feedbackWhatWrong => 'What was wrong?';

  @override
  String get issueWrongProduct => 'Wrong product';

  @override
  String get issueWrongNutrition => 'Nutrition numbers';

  @override
  String get issueWrongIngredients => 'Ingredients';

  @override
  String get issueMissedAllergen => 'Missed an allergen';

  @override
  String get issueScoreUnfair => 'Score feels wrong';

  @override
  String get issueOther => 'Something else';

  @override
  String get feedbackSend => 'Send';

  @override
  String get feedbackThanks => 'Thank you. This helps us get better.';

  @override
  String get feedbackFailed =>
      'Couldn\'t send that. Check your connection and try again.';

  @override
  String get pickerConfirmTitle => 'Is this the product?';

  @override
  String get pickerChooseTitle => 'Which one is it?';

  @override
  String pickerReadAs(String text) {
    return 'We read “$text” on the pack.';
  }

  @override
  String get pickerYes => 'Yes, that\'s it';

  @override
  String get pickerNoRetake => 'No, retake the photo';

  @override
  String get pickerNoneRetake => 'None of these, retake';

  @override
  String get sourceOpenFoodFacts => 'Open Food Facts';

  @override
  String get sourceCalfitDb => 'CalFit database';

  @override
  String get retakeHint =>
      'Take the photo again with the product name in view, or photograph the back of the pack.';

  @override
  String identifiedAs(String name) {
    return 'Identified as $name';
  }

  @override
  String identifiedSource(String source) {
    return 'Nutrition per 100 g/ml from $source';
  }

  @override
  String get notThisProduct => 'Not this product?';

  @override
  String get removeScanTitle => 'Remove this scan?';

  @override
  String get removeScanBody =>
      'It will be deleted from your history so you can take the photo again.';

  @override
  String get remove => 'Remove';

  @override
  String get scanRemoved => 'Scan removed. Tap Scan to try again.';

  @override
  String get couldntRemove => 'Couldn\'t remove the scan. Try again.';

  @override
  String get servingUnknownTitle => 'Serving size unknown';

  @override
  String get servingUnknownBody =>
      'This label\'s numbers don\'t say whether they\'re per 100 g/ml or per serving. Check the pack and add the serving size; we\'ll use it the next time you scan this product.';

  @override
  String get addServingSize => 'Add serving size';

  @override
  String get servingSheetTitle => 'Serving size';

  @override
  String get servingAmountLabel => 'One serving (g or ml)';

  @override
  String get servingAmountHelp =>
      'On the pack, look for “serving size” or the net quantity.';

  @override
  String get servingBasisLabel => 'The numbers on the label are';

  @override
  String get basisPer100 => 'Per 100 g/ml';

  @override
  String get basisPerServing => 'Per serving';

  @override
  String servingSaved(String amount) {
    return 'Saved: $amount g/ml per serving. We\'ll use it the next time you scan this product.';
  }

  @override
  String get servingSaveFailed =>
      'Couldn\'t save. Check your connection and try again.';

  @override
  String labelNotePer100(String source) {
    return 'Per 100 g/ml, from $source. A dash means it isn\'t known.';
  }

  @override
  String labelNoteYourServing(String amount) {
    return 'Per serving of $amount g/ml, the serving size you saved.';
  }

  @override
  String get confirmingProduct => 'Checking this product…';
}
