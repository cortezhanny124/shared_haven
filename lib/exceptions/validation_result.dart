class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult({required this.isValid, this.errorMessage});

  @override
  String toString() {
    return 'ValidationResult(isValid: $isValid, errorMessage: ${errorMessage ?? "None"})';
  }
}
