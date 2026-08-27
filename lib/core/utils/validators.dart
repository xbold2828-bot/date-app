
String? passwordValidator(String? value, {String fieldName = "Password"}) {
  if (value == null || value.trim().isEmpty) {
    return "$fieldName is required";
  }

  if (value.length < 8) {
    return 'Password must be at least 8 characters long';
  }

  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Password must contain at least one uppercase letter';
  }

  if (!RegExp(r'[a-z]').hasMatch(value)) {
    return 'Password must contain at least one lowercase letter';
  }

  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'Password must contain at least one number';
  }

  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
    return 'Password must contain at least one special character';
  }

  if (value.trim().length > 60) {
    return "Password cannot exceed 60 characters";
  }

  return null;
}

String? validateEmail(
  String? value, {
  String text = "Email",
  int maxLength = 60,
}) {
  if (value == null || value.trim().isEmpty) {
    return "$text is required";
  }

  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  if (!emailRegex.hasMatch(value.trim())) {
    return "Enter valid $text";
  }

  if (value.trim().length > maxLength) {
    return "$text cannot exceed $maxLength characters";
  }

  return null;
}

String? validateUrl(String? value, {String fieldName = "URL"}) {
  if (value == null || value.trim().isEmpty) {
    return "$fieldName is required";
  }

  final trimmedValue = value.trim();

  const urlPattern =
      r'^(https?:\/\/)?'
      r'(www\.)?'
      r'([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}'
      r'(\/[^\s]*)?$';

  final regex = RegExp(urlPattern);

  if (!regex.hasMatch(trimmedValue)) {
    return "Invalid URL";
  }

  return null;
}

String? validateMinAndMaxRequired(
  String? value, {
  String fieldName = "Field",
  int minLength = 3,
  int maxLength = 500,
}) {
  if (value == null || value.trim().isEmpty) {
    return "$fieldName is required";
  }

  final trimmedValue = value.trim();

  if (trimmedValue.length < minLength) {
    return "$fieldName must be at least $minLength characters";
  }

  if (trimmedValue.length > maxLength) {
    return "$fieldName cannot exceed $maxLength characters";
  }

  return null;
}

String? validateRequired(
  String? value, {
  bool isCompleteNewName = false,
  String fieldName = "Field",
  int maxLength = 500,
  bool isImplementMinCheck = true,
  int minLength = 3,
}) {
  if (value == null || value.trim().isEmpty) {
    return isCompleteNewName ? fieldName : "$fieldName is required";
  }

  final trimmedValue = value.trim();
  if (isImplementMinCheck) {
    if (trimmedValue.length < minLength) {
      return "$fieldName must be at least $minLength characters";
    }
  }

  if (trimmedValue.length > maxLength) {
    return "$fieldName cannot exceed $maxLength characters";
  }

  return null;
}

String? bankValidator(
  String? value, {
  required String fieldName,
  int maxLength = 60,
  int minLength = 3,
}) {
  if (value == null || value.trim().isEmpty) {
    return "$fieldName is required";
  }

  if (value.length < minLength) {
    return "$fieldName must be at least $minLength characters long";
  }

  if (value.trim().length > maxLength) {
    return "$fieldName can’t be longer than $maxLength characters";
  }

  return null;
}

String? confirmPasswordValidator({
  required String? value,
  required String createPassword,
}) {
  if (value == null || value.isEmpty) {
    return 'Confirm password is required';
  }

  if (value != createPassword) {
    return 'Passwords do not match';
  }

  if (value.trim().length > 60) {
    return "Password cannot exceed 60 characters";
  }

  return null; // ✅ Match
}

String? validateOtp(String? value) {
  if (value == null || value.isEmpty) {
    return 'OTP is required';
  }
  if (value.length != 4) {
    return 'Enter valid 4-digit OTP';
  }
  return null;
}


String? validateSwiftCode(String? value) {
  if (value == null || value.trim().isEmpty) {
    return "Please enter SWIFT/BIC code";
  }

  final swift = value.trim();

  if (swift.length != 8 && swift.length != 11) {
    return "SWIFT/BIC code must be 8 or 11 characters long";
  }

  final swiftRegex = RegExp(r'^[A-Za-z0-9]+$');

  if (!swiftRegex.hasMatch(swift)) {
    return "Invalid SWIFT/BIC format";
  }

  return null;
}

String? validateIban(String? value) {
  if (value == null || value.trim().isEmpty) {
    return "Please enter IBAN";
  }

  final iban = value.trim().replaceAll(" ", "").toUpperCase();

  /// 🔒 Force exact length = 24
  if (iban.length != 24) {
    return "IBAN must be exactly 24 characters long";
  }
  return null;
}

String? validateMaxLength(
  String? value, {
  String fieldName = "Field",
  int maxLength = 500,
}) {
  if (value == null || value.trim().isEmpty) {
    return null; // Not handling required validation here
  }

  if (value.trim().length > maxLength) {
    return "$fieldName cannot exceed $maxLength characters";
  }

  return null;
}
