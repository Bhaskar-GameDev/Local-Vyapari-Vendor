import 'package:flutter/widgets.dart';

/// English string table for the app.
///
/// The multi-language (l10n) system was removed: there is no locale switching,
/// no ARB/codegen pipeline and no `flutter_localizations` delegate. This is a
/// plain, hand-written set of English strings. [of] ignores the [BuildContext]
/// and returns a shared singleton, so existing `AppLocalizations.of(context).x`
/// call sites keep working unchanged.
class AppLocalizations {
  const AppLocalizations();

  static const AppLocalizations _instance = AppLocalizations();

  static AppLocalizations of(BuildContext context) => _instance;

  String get appTitle => 'Local Vyapari Vendor';

  String get commonCancel => 'Cancel';

  String get commonSave => 'Save';

  String get commonDelete => 'Delete';

  String get commonEdit => 'Edit';

  String get commonRetry => 'Retry';

  String get commonClose => 'Close';

  String get commonContinue => 'Continue';

  String get commonConfirm => 'Confirm';

  String get commonDone => 'Done';

  String get commonOk => 'OK';

  String get commonError => 'Error';

  String get commonSuccess => 'Success';

  String get commonLoading => 'Loading...';

  String get commonNext => 'Next';

  String get commonBack => 'Back';

  String get commonSubmit => 'Submit';

  String get commonSearch => 'Search';

  String get commonRefresh => 'Refresh';

  String get commonShare => 'Share';

  String get commonYes => 'Yes';

  String get commonNo => 'No';

  String get merchantPortal => 'Merchant Portal';

  String get storefrontTagline => 'Local Vyapari Storefront Terminal';

  String get emailAddress => 'Email Address';

  String get phoneNumber => 'Phone Number';

  String get password => 'Password';

  String get emailRequired => 'Email is required';

  String get enterValidEmailAddress => 'Enter a valid email address';

  String get enterValidEmail => 'Enter a valid email';

  String get phoneRequired => 'Phone number is required';

  String get enterValid10DigitNumber => 'Enter a valid 10-digit number';

  String get passwordRequired => 'Password is required';

  String get passwordMinChars => 'Password must be at least 6 characters';

  String get atLeast6Chars => 'At least 6 characters required';

  String get signingIn => 'Signing In...';

  String get signIn => 'Sign In';

  String get orContinueWith => 'or continue with';

  String get continueWithGoogle => 'Continue with Google';

  String get continueWithApple => 'Continue with Apple';

  String get forgotPassword => 'Forgot Password?';

  String get createAccount => 'Create Account';

  String get passwordResetSuccess =>
      'Password reset successfully! You can now log in.';

  String get signInFailed => 'Sign-in Failed';

  String get authenticationFailed => 'Authentication Failed';

  String get signingYouIn => 'Signing you in…';

  String get requestingVerification => 'Requesting verification...';

  String get verifyPhoneNumber => 'Verify Phone Number';

  String otpSentToPhone(String phone) {
    return 'We have sent a verification OTP to $phone.';
  }

  String get sixDigitOtp => '6-Digit OTP';

  String get newOtpSent => 'A new OTP has been sent.';

  String get codeResent => 'Code Resent';

  String get resendFailed => 'Resend Failed';

  String get verifyAndRegister => 'Verify & Register';

  String get verificationCanceledOrFailed => 'Verification canceled or failed';

  String get verificationFailed => 'Verification Failed';

  String get otpRequestFailed => 'OTP Request Failed';

  String get joinLocalVyapari => 'Join Local Vyapari';

  String get reachNearbyCustomers => 'Reach thousands of nearby customers';

  String get confirmPassword => 'Confirm Password';

  String get pleaseConfirmPassword => 'Please confirm your password';

  String get passwordsDoNotMatch => 'Passwords do not match';

  String get createMyStore => 'Create My Store';

  String get alreadyHaveAccount => 'Already have an account?';

  String get resetPassword => 'Reset Password';

  String get enterTheCode => 'Enter the code';

  String get verifyYourNumber => 'Verify your number';

  String resetCodeSentTo(String phone) {
    return 'We sent a 6-digit code to +91 $phone. Enter it below and choose a new password.';
  }

  String get resetPhonePrompt =>
      'Enter your registered phone number and we\'ll send you a one-time code to reset your password.';

  String stepNOf2(int step) {
    return 'STEP $step OF 2';
  }

  String get registeredPhoneNumber => 'Registered Phone Number';

  String get sendOtp => 'Send OTP';

  String get enter6DigitOtp => 'Enter 6-Digit OTP';

  String get otpRequired => 'OTP is required';

  String get otpMust6Digits => 'OTP must be 6 digits';

  String get newPasswordLabel => 'New Password';

  String get newPasswordRequired => 'New password is required';

  String get changePhoneNumber => 'Change phone number';

  String otpSentToShort(String phone) {
    return 'OTP sent to $phone';
  }

  String get newOtpSentShort => 'A new OTP has been sent';

  String get passwordResetFailed => 'Password reset failed';

  String get passwordResetFailedTitle => 'Password Reset Failed';

  String get addMobileNumber => 'Add Mobile Number';

  String get signOut => 'Sign out';

  String get invalidNumber => 'Invalid Number';

  String get enterValid10DigitNumberDot =>
      'Please enter a valid 10-digit number.';

  String get otpSentCheckSms => 'OTP sent. Please check your SMS messages.';

  String get codeSent => 'Code Sent';

  String get mobileNumberVerified => 'Mobile number verified.';

  String get allSet => 'All set';

  String get verificationFailedRetry =>
      'Verification failed. Please try again.';

  String get verifyYourMobileNumber => 'Verify your mobile number';

  String linkPhoneEmailContext(String email) {
    return 'You signed in as $email. Customers reach you and discover your shop by your mobile number, so we need to verify one before you continue.';
  }

  String get linkPhoneNoEmailContext =>
      'Customers reach you and discover your shop by your mobile number, so we need to verify one before you continue.';

  String get mobileNumber => 'Mobile Number';

  String get verifyAndContinue => 'Verify & Continue';

  String get changeNumber => 'Change number';

  String get goodMorning => 'Good morning,';

  String get goodAfternoon => 'Good afternoon,';

  String get goodEvening => 'Good evening,';

  String get yourStore => 'Your Store';

  String get notifications => 'Notifications';

  String get open => 'Open';

  String get closed => 'Closed';

  String get todaysViews => 'Today\'s views';

  String get todaysClicks => 'Today\'s clicks';

  String get totalReviews => 'Total reviews';

  String get products => 'Products';

  String get liveOffers => 'Live Offers';

  String get viewsToday => 'Views Today';

  String get totalClicksLabel => 'Total Clicks';

  String get overview => 'Overview';

  String get sevenDays => '7 days';

  String get performance => 'Performance';

  String get viewsLegend => 'Views';

  String get clicksLegend => 'Clicks';

  String get noTrafficData => 'No traffic data yet.';

  String get customerRatings => 'Customer Ratings';

  String nTotal(int count) {
    return '$count total';
  }

  String get lowStockAlerts => 'Low Stock Alerts';

  String get errorLoadingInventory => 'Error loading inventory.';

  String get allProductsStocked => 'All products are well-stocked.';

  String onlyNLeft(int count) {
    return 'Only $count left';
  }

  String get security => 'Security';

  String get signOutEverywhereTitle => 'Sign out everywhere?';

  String get signOutEverywhereBody =>
      'This signs out all other devices. You will stay signed in here.';

  String get signOutAll => 'Sign out all';

  String get signedOutOtherDevices => 'Signed out of all other devices.';

  String get couldNotComplete => 'Could not complete. Try again.';

  String get signOutFailed => 'Sign-out Failed';

  String get whereYouSignedIn => 'Where you signed in';

  String get couldNotLoadDevices => 'Could not load devices';

  String get noOtherDevices => 'No other devices recorded.';

  String get signOutAllOtherDevices => 'Sign out of all other devices';

  String get locationUnavailable => 'Location unavailable';

  String get unknownDevice => 'Unknown device';

  String lastActive(String time) {
    return 'Last active: $time';
  }

  String get remove => 'Remove';

  String get navHome => 'Home';

  String get navProducts => 'Products';

  String get navOffers => 'Offers';

  String get navChats => 'Chats';

  String get navProfile => 'Profile';

  String get loadingStorefront => 'Loading storefront…';

  String get failedToLoadShop => 'Failed to load shop details';

  String get logout => 'Logout';

  String get merchantPartner => 'Merchant Partner';

  String get myShopProfile => 'My Shop Profile';

  String get toggleTheme => 'Toggle Theme';

  String themeModeSnack(String mode) {
    return 'Theme mode: $mode';
  }

  String get themeSystem => 'System Default';

  String get themeDark => 'Dark Theme';

  String get themeLight => 'Light Theme';

  String get shopMarkedOpen => 'Shop marked as Open';

  String get shopMarkedClosed => 'Shop marked as Closed';

  String get updateFailed => 'Update Failed';

  String get shopIsOpen => 'Shop is Open';

  String get customersSeeOpen => 'Customers can see you as open';

  String get customersSeeClosed => 'Customers will see your shop as closed';

  String get shopDetails => 'Shop Details';

  String get shopNameLabel => 'Shop Name';

  String get notSet => 'Not Set';

  String get descriptionLabel => 'Description';

  String get addressLabel => 'Address';

  String get gpsCoordinates => 'Storefront GPS Coordinates';

  String get notSetRequiredDiscovery => 'Not Set (Required for discovery)';

  String get phoneLabel => 'Phone';

  String get appPreferences => 'App Preferences';

  String get appTheme => 'App Theme';

  String get themeSystemFollowsDevice => 'System Default (follows device)';

  String get securitySubtitle => 'Where you signed in and sign out everywhere';

  String get securityLinkedAccounts => 'Security & Linked Accounts';

  String get boundEmail => 'Bound Email Address';

  String get notBound => 'Not Bound';

  String get emailBoundSuccess => 'Email bound successfully!';

  String get boundPhone => 'Bound Phone Number';

  String get phoneBoundSuccess => 'Phone number bound successfully!';

  String errorLoadingAccounts(String error) {
    return 'Error loading accounts: $error';
  }

  String get shareLocalVyapari => 'Share Local Vyapari';

  String get inviteOthers => 'Invite other vyaparis or customers';

  String get editProfile => 'Edit Profile';

  String errorGeneric(String error) {
    return 'Error: $error';
  }

  String get selectAppTheme => 'Select App Theme';

  String get followsDeviceSettings => 'Follows device settings';

  String get lightThemeSubtitle => 'Light background with dark text';

  String get darkThemeSubtitle => 'Dark background with light text';

  String get copyDownloadLink => 'Copy download link';

  String get shareAppMessage =>
      'Check out Local Vyapari App! Discover nearby retail shops and get exclusive local offers: https://localvyapari.com/download';

  String get linkCopied => 'App link copied to your clipboard.';

  String get shareViaWhatsApp => 'Share via WhatsApp';

  String get couldNotOpenWhatsApp => 'Could not open WhatsApp.';

  String get unableToShare => 'Unable to Share';

  String get bindEmailTitle => 'Bind Email Address';

  String get bindingFailed => 'Binding failed';

  String get bindingFailedTitle => 'Binding Failed';

  String get bind => 'Bind';

  String get bindPhoneTitle => 'Bind Phone Number';

  String get verificationFailedMsg => 'Verification failed';

  String get verifyAndLink => 'Verify & Link';

  String get deleteProduct => 'Delete Product';

  String confirmDeleteProduct(String name) {
    return 'Are you sure you want to delete "$name"? This action cannot be undone.';
  }

  String get productDeleted => 'Product deleted successfully';

  String get deleteFailed => 'Delete Failed';

  String get myProducts => 'My Products';

  String get noProducts => 'No products found. Add one!';

  String get failedToLoadProducts => 'Failed to load products';

  String get addProduct => 'Add Product';

  String get noRatings => 'No ratings';

  String stockLabel(int count) {
    return 'Stock: $count';
  }

  String get active => 'Active';

  String get activeOffers => 'Active Offers';

  String get noOffers => 'No active offers. Create a flash sale!';

  String expiredOn(String date) {
    return 'Expired on $date';
  }

  String offerSubtitle(int percent, String date) {
    return '$percent% OFF • Ends $date';
  }

  String get failedToLoadOffers => 'Failed to load offers';

  String get createOffer => 'Create Offer';

  String get customerChats => 'Customer Chats';

  String get noMessagesYet => 'No messages yet';

  String get noMessagesBody =>
      'When customers query your products or shop, their conversations will appear here.';

  String get deleteChat => 'Delete Chat';

  String confirmDeleteChat(String name) {
    return 'Are you sure you want to delete this conversation with $name? This will remove it from your chats list.';
  }

  String conversationDeleted(String name) {
    return 'Conversation with $name deleted';
  }

  String get failedToLoadChats => 'Failed to load chats';

  String get startChatting => 'Start chatting';

  String get yesterday => 'Yesterday';

  String get tryAgain => 'Try Again';

  String resendCodeIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  String get resendCode => 'Resend code';

  String get backOnline => 'Back online';

  String get noInternet => 'No internet connection';

  String get offlineMode => '· Offline mode';

  String get confirmDeleteEntireChat =>
      'Are you sure you want to delete this entire conversation? This action cannot be undone.';

  String get customer => 'Customer';

  String get startConversation => 'Start a conversation';

  String get startConversationBody =>
      'Send a friendly message to begin the chat.';

  String errorLoadingMessages(String error) {
    return 'Error loading messages: $error';
  }

  String get typeYourMessage => 'Type your message...';

  String productReviewsTitle(String name) {
    return '$name Reviews';
  }

  String get noReviewsYet => 'No Reviews Yet';

  String get productReviewsEmpty =>
      'Reviews and ratings for this product will appear here.';

  String customerFeedback(int count) {
    return 'Customer Feedback ($count)';
  }

  String errorLoadingReviews(String error) {
    return 'Error loading reviews: $error';
  }

  String nRatings(int count) {
    return '$count ratings';
  }

  String get anonymousUser => 'Anonymous User';

  String get noCommentLeft => 'No comment left.';

  String get storeRatingsReviews => 'Store Ratings & Reviews';

  String get vendorReviewsEmpty =>
      'Customer feedback and ratings will appear here once submitted.';

  String customerComments(int count) {
    return 'Customer Comments ($count)';
  }

  String get selectTime => 'Select Time';

  String get shopCoordinatesUpdated => 'Shop coordinates updated!';

  String couldNotFetchLocation(String error) {
    return 'Could not fetch location: $error';
  }

  String get locationError => 'Location Error';

  String get verify => 'Verify';

  String get editShopProfile => 'Edit Shop Profile';

  String get setUpYourShop => 'Set Up Your Shop';

  String get merchantProfilePending =>
      'Merchant Profile Pending: Complete your shop setup to activate your vendor account.';

  String get welcomeToLocalVyapari => 'Welcome to Local Vyapari!';

  String get setupShopSubtitle =>
      'Please fill in your business details to build your digital storefront and start listing products.';

  String get uploadShopLogo => 'Upload Shop Logo';

  String get businessShopName => 'Business / Shop Name';

  String get enterBusinessName => 'Please enter business name';

  String get shopDescription => 'Shop Description';

  String get describeYourShop => 'Please describe your shop';

  String get contactPhoneNumber => 'Contact Phone Number';

  String get enterPhoneNumber => 'Please enter phone number';

  String get shopTimings => 'Shop Timings';

  String get shopTimingsSubtitle =>
      'Let customers know when your shop is open.';

  String get opensAt => 'Opens At';

  String get closesAt => 'Closes At';

  String get geolocationalStorefront => 'Geolocational Storefront';

  String get gpsSubtitle =>
      'Accurate GPS coordinates help nearby shoppers find your store on their maps.';

  String get latitude => 'Latitude';

  String get longitude => 'Longitude';

  String get required => 'Required';

  String get detectCurrentLocation => 'Detect Current Location';

  String get shopAddress => 'Shop Address';

  String get enterCompleteAddress => 'Please enter complete address';

  String get saveChanges => 'Save Changes';

  String get createStorefront => 'Create Storefront';

  String get signOutButton => 'Sign Out';

  String get shopProfileUpdated => 'Shop profile updated successfully!';

  String get shopStorefrontCreated => 'Shop storefront created successfully!';

  String get saveFailed => 'Save Failed';

  String get max5Images => 'You can add up to 5 images only';

  String get only5Images => 'Only up to 5 images can be added';

  String get couldNotPickImages => 'Could Not Pick Images';

  String get selectAtLeast1Image => 'Please select at least 1 image';

  String get productUpdated => 'Product updated successfully!';

  String get productAdded => 'Product added successfully!';

  String get couldNotSaveProduct => 'Could Not Save Product';

  String get couldNotDeleteProduct => 'Could Not Delete Product';

  String get editProduct => 'Edit Product';

  String get addNewProduct => 'Add New Product';

  String get productName => 'Product Name';

  String get category => 'Category';

  String get actualPrice => 'Actual Price (₹)';

  String get offerPrice => 'Offer Price (₹)';

  String get invalid => 'Invalid';

  String get stockQty => 'Stock Qty';

  String get viewProductReviews => 'View Product Reviews';

  String get publishProduct => 'Publish Product';

  String productImages(int count) {
    return 'Product Images ($count/5)';
  }

  String get min1Max5 => 'Min 1, Max 5';

  String get addImage => 'Add Image';

  String get offerUpdated => 'Offer updated!';

  String get offerCreated => 'Offer created!';

  String get couldNotSaveOffer => 'Could Not Save Offer';

  String get editFlashSale => 'Edit Flash Sale';

  String get createFlashSale => 'Create Flash Sale';

  String get offerTitleLabel => 'Offer Title (e.g. Weekend Flash Sale)';

  String get discountPercent => 'Discount %';

  String get discountRange => 'Enter a value between 1 and 100';

  String get startsAt => 'Starts At';

  String get endsAt => 'Ends At';

  String get change => 'Change';

  String get updateOffer => 'Update Offer';

  String get launchOffer => 'Launch Offer';

  String get featureInPromoCarousel => 'Feature in Promo Carousel';

  String get featureInPromoCarouselDescription =>
      'Featured offers appear in the highlighted banner at the top of the home screen for nearby users.';

  String get sendFeedback => 'Send Feedback';

  String get feedbackMenuSubtitle => 'Report a bug or suggest an improvement';

  String get feedbackHeading => 'We\'d love your feedback';

  String get feedbackSubheading =>
      'Tell us what\'s working, what\'s broken, or what you\'d like to see next.';

  String get feedbackTypeQuestion => 'What kind of feedback is this?';

  String get feedbackTypeBug => 'Bug';

  String get feedbackTypeFeature => 'Feature';

  String get feedbackTypeGeneral => 'General';

  String get feedbackMessageLabel => 'Your message';

  String get feedbackMessageHint => 'Tell us what\'s on your mind…';

  String get feedbackMessageRequired => 'Please enter your feedback';

  String get feedbackSubmit => 'Submit Feedback';

  String get feedbackSubmittedTitle => 'Thank you!';

  String get feedbackSubmittedBody => 'Your feedback has been submitted.';

  String get feedbackFailedTitle => 'Could Not Send Feedback';
}
