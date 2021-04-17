import org.checkerframework.checker.nullness.qual.PolyNull;

class Main {
  static @PolyNull String reverse(@PolyNull String str) {
    if (str == null) return new String();
    StringBuilder builder = new StringBuilder(str);
    builder.reverse();
    return builder.toString();
  }

  public static void main(String[] args) {
    String reversed = reverse(null);
    String frown = reverse(":)");
    String both = reversed.concat(frown);
    System.out.println(both);
  }
}
