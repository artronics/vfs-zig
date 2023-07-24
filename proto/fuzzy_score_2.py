from enum import Enum

from assertpy import assert_that

boundary_set = {" ", "_", "-", "/", "."}


def case_is_different(a, b):
    return (ord(a) & 0b0010_0000) ^ (ord(b) & 0b0010_0000) == 32


def is_start_boundary(text, index) -> bool:
    _current = text[index]
    if index == 0:
        return _current not in boundary_set  # boundary characters aren't considered as start

    _prev = text[index - 1]
    return (_prev in boundary_set) or case_is_different(_prev, _current)


def is_end_boundary(text, index):
    _current = text[index]
    if index == len(text) - 1:
        return _current not in boundary_set  # boundary characters aren't considered as end

    _next = text[index + 1]
    return (_next in boundary_set) or case_is_different(_next, _current)


def test_is_boundary():
    def what(t, i):
        s = is_start_boundary(t, i)
        e = is_end_boundary(t, i)
        print(f"{t} : {'START' if s else '  N/A'} | {' END' if e else ' N/A'}")
        print(f"{' ' * i}^")

    print()
    what("fooBar", 3)
    what("fooBar", 4)

    what("FOObar", 3)
    what("FOObar", 2)

    what("fooBAR", 3)
    what("fooBAR", 2)

    s = is_start_boundary("a", 0)
    e = is_end_boundary("a", 0)
    assert_that(s and e).is_true()

    s = is_start_boundary("BaR", 0)
    e = is_end_boundary("a", 0)
    assert_that(s and e).is_true()

    s = is_start_boundary("_", 0)
    e = is_end_boundary("_", 0)
    assert_that(s or e).is_false()

    s1 = is_start_boundary("FOObar", 0)
    s2 = is_start_boundary("FOObar", 3)
    assert_that(s1 and s2).is_true()

    e1 = is_end_boundary("FOObar", 2)
    e2 = is_end_boundary("FOObar", 5)
    assert_that(e1 and e2).is_true()


class Boundary(Enum):
    START = -1
    MIDDLE = 0
    END = 1

    @staticmethod
    def boundary(text: str, _current: int):
        boundary_set = {" ", "_", "-", "/", "."}
        if text[_current] in boundary_set:
            return Boundary.MIDDLE

        if _current == 0:
            return Boundary.START
        _prev = _current - 1

        # prev character being in boundary_set has the highest precedent
        if text[_prev] in boundary_set:
            return Boundary.START

        if text[_current].isupper() and text[_prev].islower():
            return Boundary.START

        if _current == len(text) - 1:
            return Boundary.END
        _next = _current + 1

        if text[_current].islower() and text[_next].isupper():
            return Boundary.END

        if text[_next] in boundary_set:
            return Boundary.END

        return Boundary.MIDDLE


def test_start_boundary():
    boundary = Boundary.boundary

    b = boundary("F", 0)
    assert_that(b).is_equal_to(Boundary.START)
    b = boundary("FO", 0)
    assert_that(b).is_equal_to(Boundary.START)
    b = boundary("_F", 0)
    assert_that(b).is_equal_to(Boundary.MIDDLE)
    b = boundary("_f", 0)
    assert_that(b).is_equal_to(Boundary.MIDDLE)
    b = boundary("_f", 1)
    assert_that(b).is_equal_to(Boundary.START)
    b = boundary("f_O", 1)
    assert_that(b).is_equal_to(Boundary.MIDDLE)
    b = boundary("foo", 2)
    assert_that(b).is_equal_to(Boundary.END)
    b = boundary("fo_o", 1)
    assert_that(b).is_equal_to(Boundary.END)
    b = boundary("foOo", 1)
    assert_that(b).is_equal_to(Boundary.END)
    b = boundary("foo", 1)
    assert_that(b).is_equal_to(Boundary.MIDDLE)
    b = boundary("fOo", 1)
    assert_that(b).is_equal_to(Boundary.START)
    b = boundary("FoO", 1)
    assert_that(b).is_equal_to(Boundary.END)
    b = boundary("foO", 2)
    assert_that(b).is_equal_to(Boundary.START)


class Score:
    _qc = +1
    _copy = 0

    _qb = -1
    _boundary = 0

    def copy(self):
        self._copy += 1

    def boundary(self):
        self._boundary += 1

    def score(self):
        return self._copy * self._qc + self._boundary * self._qb


def fuzzy_search_2(text: str, pattern: str):
    _score = Score()
    _di_acc = 0

    i = len(text) - 1
    j = len(pattern) - 1
    if i < 0 or j < 0:
        return None

    current_p = pattern[j]
    prev_p = pattern[j]
    end_boundary_i = i + 1
    boundary = []

    current_start_i = -1
    current_end_i = -1
    prev_start = current_start_i
    prev_end = current_end_i

    while i >= 0:
        start_boundary = is_start_boundary(text, i)
        end_boundary = is_end_boundary(text, i)
        no_boundary = Boundary.boundary(text, i) == Boundary.MIDDLE
        if start_boundary:
            current_start_i = i
        if end_boundary:
            current_end_i = i + 1

        if current_start_i != prev_start and current_end_i != prev_end:
            boundary.append(text[current_start_i:current_end_i])
            prev_end = current_end_i
            prev_start = current_start_i

        if text[i] == current_p:
            _score.copy()
            prev_p = pattern[j]

            if j == 0:
                break
            j -= 1
            current_p = pattern[j]

        elif text[i] == prev_p:
            _score.copy()

        else:
            _di_acc += 1

        i -= 1

    for b in boundary:
        print(b)
    # print(f"{'✓' if j == 0 else '✗'} [{_score}] ∈ {text} | {pattern}")
    return _score if j == 0 else None


def test_search_debug():
    print()
    # s = fuzzy_search_2("xXx", "?")
    s = fuzzy_search_2("fooBar", "?")
    # s = fuzzy_search_2("xFOoBaR", "?")
    # s = fuzzy_search_2("xxFOoBaR", "?")


def test_search():
    s = fuzzy_search_2("a", "a")
    assert_that(s._copy).is_equal_to(1)
    print("last p char will count as one since, loop will be terminated at that point")
    s = fuzzy_search_2("aa", "a")
    assert_that(s._copy).is_equal_to(1)
    s = fuzzy_search_2("ab", "ab")
    assert_that(s._copy).is_equal_to(2)

    s = fuzzy_search_2("aabb", "ab")
    assert_that(s._copy).is_equal_to(3)
    s = fuzzy_search_2("aabab", "ab")
    assert_that(s._copy).is_equal_to(2)


if __name__ == '__main__':
    pass

search = fuzzy_search_2


def test_match():
    print("\n")
    s = search("", "")
    assert_that(s).is_not_none()
    s = search("sad", "ad")
    assert_that(s).is_not_none()
    s = search("sabcd", "ad")
    assert_that(s).is_not_none()

    s = search("sabcd", "xy")
    assert_that(s).is_none()
