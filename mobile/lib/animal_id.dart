/// Mirrors the API's portable animal-directory contract.
String? validateAnimalId(String? input) {
  final value = input?.trim() ?? '';
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$').hasMatch(value)) {
    return 'Use 1–64 letters, digits, underscores or hyphens';
  }
  final reserved = {
    'CON',
    'PRN',
    'AUX',
    'NUL',
    for (var i = 1; i <= 9; i++) ...['COM$i', 'LPT$i'],
  };
  return reserved.contains(value.toUpperCase())
      ? 'This animal ID is a reserved filesystem name'
      : null;
}
