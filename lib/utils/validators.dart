String? validateDescription(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a description';
  }
  return null;
}
