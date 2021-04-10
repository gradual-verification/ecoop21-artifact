package codetoanalyze.java.gradual;

import javax.annotation.Nonnull;
import javax.annotation.Nullable;

class Foo {
  @Nullable Object f;

  static @Nullable Foo mystery() {
    return new Foo();
  }

  static Object takeNull(Foo x) {
    return x == null ? null : x.f;
  }

  static Object firstF(@Nonnull Foo x, Foo y, @Nonnull Foo z) {
    if (x.f != null) {
      return x.f;
    }
    if (y != null && y.f != null) {
      return y.f;
    }
    return z.f;
  }

  Object getF() {
    return f;
  }

  Object firstF(Foo y, @Nonnull Foo z) {
    return firstF(this, y, z);
  }

  static void complain(
    @Nonnull Foo a,
    @Nonnull Foo b,
    @Nonnull Foo c
  ) { }
}

class Bar {
  @Nonnull String s = "Hello, world!";

  @Nullable String getSNullable() {
    return s;
  }

  @Nonnull String getS() {
    return s;
  }
}

class MatchInstrTests {
  static void assignChecksLhs() {
    Foo x = null;
    x.f = null; // should err about null deference
  }

  static void assignChecksRhs() {
    Foo x = null;
    Object y = x.f; // should err about null dereference
  }

  static void assignMakesNonnull() {
    Foo x = Foo.mystery();
    Object y1 = x.f; // should err about possible null dereference
    x = new Foo();
    Object y2 = x.f; // shouldn't err
  }

  static void assignChecksLhsFieldAnnot() {
    Bar x = new Bar();
    x.s = null; // should err about field annotation violation
  }

  static void assignAllowsNonnullFieldAnnot() {
    Bar x = new Bar();
    x.s = "henlo worl"; // shouldn't err
  }

  static void assignAllowsNullableFieldAnnot() {
    Foo x = new Foo();
    x.f = null; // shouldn't err
  }

  static void assumeChecksCond() {
    Foo x = null;
    if (x.f == null) { // should err about null dereference
      x = null;
    }
  }

  static void assumeMakesNonnull() {
    Foo x = Foo.mystery();
    if (x != null) {
      Object y = x.f; // shouldn't err
    }
  }

  static void callStaticAcceptsNullFirstArg() {
    Foo x = null;
    Object y = Foo.takeNull(x); // shouldn't err
  }

  static void callStaticChecksAllAnnots() {
    Foo x = Foo.mystery();
    Foo y = Foo.mystery();
    Foo z = Foo.mystery();
    Object o = Foo.firstF(x, y, z); // should err about x and z
  }

  static void callMethodRejectsNullReceiver() {
    Foo x = null;
    Object y = x.getF(); // should err about null dereference
  }

  static void callMethodChecksAllAnnots() {
    Foo x = new Foo();
    Foo y = Foo.mystery();
    Foo z = Foo.mystery();
    Object o = x.firstF(y, z); // should err about z
  }

  static void callMakesNonnull() {
    Bar x = new Bar();
    String s = x.getSNullable();
    int l1 = s.length(); // should err about possible null dereference
    s = x.getS();
    int l2 = s.length(); // shouldn't err
  }

  static void fieldGivesNullableAnnot() {
    Foo x = new Foo();
    Object y = x.f;
    int z = y.hashCode(); // should err about null dereference
  }

  static void fieldGivesNonnullAnnot() {
    Bar x = new Bar();
    String s = x.s;
    int l = s.length(); // shouldn't err
  }

  static void arrayItemsQuestionMark() {
    String[] ss = new String[2];
    ss[0] = "Hello, world!";
    String a = ss[0];
    String b = ss[1];
    int al = a.length(); // should warn but not err
    int bl = b.length(); // should warn but not err
  }

  static void castsAreStillNull() {
    Foo x = (Foo) null;
    Object y = x.f; // should err about null dereference
  }

  static void logicChecksCompoundExprs() {
    Foo x = new Foo();
    Foo a = Foo.mystery();
    Foo b = Foo.mystery();
    Foo c = Foo.mystery();
    // looks like true case should say b is nonnull
    // but the compound cond expr is split b/c of short-circuiting
    if (!((a == null || b == null) && !(b == x && c != null))) {
      Foo.complain(a, b, c); // should err about a, b, c
    } else {
      Foo.complain(a, b, c); // should err about a, b, c
    }
  }

  static Object canReturnNullWithoutNonnull() {
    return null; // shouldn't err
  }

  static @Nonnull Object cantReturnNullWithNonnull() {
    return null; // should err about null return
  }
}
