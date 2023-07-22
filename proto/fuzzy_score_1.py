from assertpy import assert_that


def is_boundary(text, idx):
    return idx == 0 or text[idx - 1] in {" ", "_", "/", "."} or \
        (ord(text[idx]) & 0b0010_0000) ^ (ord(text[idx - 1]) & 0b0010_0000) == 32


def test_is_boundary():
    assert ~is_boundary("aa", 1)
    assert ~is_boundary("az", 1)
    assert ~is_boundary("za", 1)
    assert ~is_boundary("AA", 1)
    assert ~is_boundary("AZ", 1)
    assert ~is_boundary("ZA", 1)

    assert is_boundary("a", 0)
    assert is_boundary("aA", 1)
    assert is_boundary("Aa", 1)
    assert is_boundary("Az", 1)
    assert is_boundary("zA", 1)
    assert is_boundary("cB", 1)

    assert is_boundary(".a", 1)
    assert is_boundary("/a", 1)
    assert is_boundary("_a", 1)
    assert is_boundary(" a", 1)


def eq_ignore_case(a, b):
    return a == b or abs(ord(a) - ord(b)) == 32


def test_eq_ignore_case():
    assert eq_ignore_case("a", "A")
    assert eq_ignore_case("Z", "z")
    assert eq_ignore_case("a", "a")
    assert eq_ignore_case("z", "z")


# cost of copy i.e. a match
_Qc = +1
# cost of delete i.e. a mismatch
_Qd = -1

# const of the distance itself. This indicate P0P1xy has higher score than P0xP1y even though,
# they have the same "total" distance.
_QDi = -1
# Cost off kill. We found all the matches. It's either 0 or -1. 0 if there is nothing left, -1 otherwise
_Qk = lambda idx: 0 if idx == 0 else -1

# test for the set of word boundary
_Ab = lambda text, idx: is_boundary(text, idx)

# const of boundary. Axyz | a has the cost of Qb i.e. ignore xyz distance because A is the beginning of a word
_Qb = -1


def score(text, pattern, ignore_case=True):
    i = len(text)
    j = len(pattern)
    _score = 0

    _di_acc = 0

    boundary = False
    while i > 0:
        i -= 1
        if (text[i] == pattern[j - 1]) or (ignore_case and eq_ignore_case(text[i], pattern[j - 1])):
            j -= 1
            _score += _Qc

            boundary = _Ab(text, i)
            if boundary:
                _score += 0 if _di_acc == 0 else _Qb
            else:
                _score += 0 if _di_acc == 0 else _QDi
                _score += _di_acc
            _di_acc = 0

            if j == 0:
                _score += _Qk(i)
                break
        else:
            _di_acc += _Qd
            if boundary:
                # commit _di_acc and reset
                _score += _di_acc
                _di_acc = 0
                # should we count it as QDi as well?
                # _score += _QDi

        boundary = _Ab(text, i)
    # print(f"{'✓' if j == 0 else '✗'} [{_score}] ∈ {text} | {pattern}")
    return _score if j == 0 else None


# const unrolled values to make assertion in tests more clear
_Qk0 = _Qk(0)
_Qk1 = _Qk(23)


def test_score_base():
    print("\n")
    s = score("", "")
    assert_that(s).is_equal_to(0)

    # adding a character at the beginning (s) so, we know it's not being considered as word boundary
    s = score("sad", "ad")
    assert_that(s).is_equal_to(2 * _Qc + _Qk1)
    s = score("sabcd", "ad")
    assert_that(s).is_equal_to((2 * _Qc) + (2 * _Qd) + (1 * _QDi) + _Qk1)

    s = score("sabcdbc", "ad")
    assert_that(s).is_equal_to((2 * _Qc) + (4 * _Qd) + (2 * _QDi) + _Qk1)

    s = score("saxyybyzxcy", "abc")
    assert_that(s).is_equal_to((3 * _Qc) + (7 * _Qd) + (3 * _QDi) + _Qk1)


def test_score_word_boundary():
    print("\n")
    s = score("a", "a")
    assert_that(s).is_equal_to(_Qc)
    s = score("_axyz", "a")
    assert_that(s).is_equal_to(_Qc + _Qb + _Qk1)
    s = score("_A", "a")
    assert_that(s).is_equal_to(_Qc + _Qk1)
    s = score("Aa", "a")
    assert_that(s).is_equal_to(_Qc + _Qk1)
    s = score("Xaxyz", "a")
    assert_that(s).is_equal_to(_Qc + _Qb + _Qk1)
    s = score("xAxxyz", "a")
    assert_that(s).is_equal_to(_Qc + _Qb + _Qk1)

    s = score("ssaxyzBxyz", "ab")
    assert_that(s).is_equal_to((2 * _Qc) + _Qb + (3 * _Qd) + _QDi + _Qk1)
    s = score("ssaxyzBxyzCxyz", "ab")
    assert_that(s).is_equal_to((2 * _Qc) + _Qb + (7 * _Qd) + (2 * _QDi) + _Qk1)
    s = score("ssCxyzaxyzBxyzCxyz", "ab")
    assert_that(s).is_equal_to((2 * _Qc) + _Qb + (7 * _Qd) + (2 * _QDi) + _Qk1)

    # TODO: this is a bug. Committing Qd results in acc being zero and then QDi is not getting added
    s = score("sayYxbyZxcy", "abc")
    assert_that(s).is_equal_to((3 * _Qc) + (7 * _Qd) + (3 * _QDi) + _Qk1)


def test_relative_scoring():
    print("\n")
    pattern = "abc"
    # var "a" is always base-line
    a = score("abc", pattern)

    b = score("abcd", pattern)
    assert_that(a).is_greater_than(b)
    b = score("_abc", pattern)
    assert_that(a).is_greater_than(b)
    b = score("Aabc", pattern)
    assert_that(a).is_greater_than(b)

    print("We don't about the distance when match is found. i.e. Qk (kill) is a fixed score")
    a = score("aabc", pattern)
    b = score("xyzaabc", pattern)
    assert_that(a).is_equal_to(b)

    print("A word boundary has fixed distance")
    a = score("AxyzBzyzCxyz", pattern)
    b = score("axyzbzyzcxyz", pattern)
    assert_that(a).is_greater_than(b)

    print("A word boundary has fixed distance only if the match character is at the beginning.")
    print("This rule applies differently when case of a char changes. It's relative change.")
    a = score("sayYxbyZxcy", pattern)
    b = score("saxyybyzxcy", pattern)
    assert_that(a).is_equal_to(b)


if __name__ == '__main__':
    print("\n")
    score("", "")
    score("ad", "ad")
    score("abcd", "ad")

    print("\nnumber of mismatches at the end doesn't matter i.e. Qk; the last distance is either 0 or -1")
    score("xyad", "ad")
    score("xyzyzdad", "ad")

    print("\nthe total number distances |di| i.e. P0P1xy vs P0xP1y")
    score("adxyz", "ad")
    score("axyzd", "ad")
    score("axydz", "ad")

    print("\na word boundary has the total distance of Qb. In 'AxyzyBcd' both 'xyzy' and 'cd' "
          "have the same distance=Qb no matter how long each one is.")
    score("xyAdxyxy", "ad")
    score("xyAcdxyxy", "acd")
    score("xyAdxy", "ad")
    score("xyAdxyBxy", "ad")
    score("xyadxybxy", "ad")


def test_boundary_score():
    s = score("xyAdxyBxy", "ad")
    print(s)
