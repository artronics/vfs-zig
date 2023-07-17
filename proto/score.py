def score(text, pattern):
    i = len(text)
    j = len(pattern)
    _score = 0

    # cost of copy i.e. a match
    _Qc = +1
    # cost of delete i.e. mismatch
    _Qd = -1

    # The const of the distance itself. This indicate P0P1xy has higher score than P0xP1y even though,
    # they have the same "total" distance.
    _QDi = -1
    # Cost off kill. We found all the matches. The rest is either 0 if it's the end of no matter how long it's -1
    _Qk = lambda _i: 0 if _i == 0 else -1

    # Set of word boundary
    _Ab = lambda idx: text[idx] in {0, " ", "/", "."} or abs(ord(text[idx]) - ord(text[idx])) == 32

    _di_acc = 0

    while i > 0:
        i -= 1
        if text[i] == pattern[j - 1]:
            j -= 1
            _score += _Qc
            _score += _di_acc
            _score += 0 if _di_acc == 0 else _QDi
            _di_acc = 0
            if j == 0:
                _score += _Qk(i)
                break
        else:
            # _score += _Qd
            _di_acc += _Qd

    print(f"{'✓' if j == 0 else '✗'} [{_score}] ∈ {text} | {pattern}")
    return _score if j == 0 else None


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


if __name__ == '__main__':
    test_is_boundary()
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
    score("xyAdxy", "ad")
