
class Main {
  static String reverse(String str) {
    if (str == null) return null;
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
