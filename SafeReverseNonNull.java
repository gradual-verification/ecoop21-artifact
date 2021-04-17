import edu.umd.cs.findbugs.annotations.NonNull;

class Main {
  static @NonNull String reverse(String str) {
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
