from enum import Enum

from assertpy import assert_that


class Boundary2(Enum):
    START = 0
    UPPER = 1
    LOWER = 2
    SEPARATOR = 3
    END = 4

    @staticmethod
    def boundary(text: str, _idx: int, _prev: Enum):
        # TODO: create a state machine that gives a start and end index
        pass


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
    boundary = ""

    while i >= 0:
        start_boundary = Boundary.boundary(text, i) == Boundary.START
        end_boundary = Boundary.boundary(text, i) == Boundary.END
        no_boundary = Boundary.boundary(text, i) == Boundary.MIDDLE
        if start_boundary:
            boundary = text[i: end_boundary_i]
        elif end_boundary:
            end_boundary_i = i + 1

        if start_boundary:
            print(boundary)

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

    # print(f"{'✓' if j == 0 else '✗'} [{_score}] ∈ {text} | {pattern}")
    return _score if j == 0 else None


def test_search_debug():
    print()
    s = fuzzy_search_2("xXx", "?")
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
