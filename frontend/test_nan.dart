void main() {
  double val = double.nan;
  try {
    // ignore: avoid_print
    print(val.clamp(0.0, 1.0));
  } catch (e) {
    // ignore: avoid_print
    print("Error: $e");
  }
}
