void main() {
  double val = double.nan;
  try {
    print(val.clamp(0.0, 1.0));
  } catch (e) {
    print("Error: $e");
  }
}
