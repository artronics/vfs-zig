from assertpy import assert_that

from run_search import run_search

# cost of delete i.e. a mismatch
_Qd = -1
# Cost off kill. We found all the matches. It's either 0 or -1. 0 if there is nothing left, -1 otherwise
_Qk = lambda idx: 0 if idx == 0 else -1


def fuzzy_search_2(text: str, pattern: str):
    i = len(text)
    j = len(pattern)
    _score = 0
    _di_acc = 0
    while i > 0:
        i -= 1
        if text[i] == pattern[j - 1]:
            j -= 1
            if j == 0:
                _score += _Qk(i)
                break

        else:
            _score += _Qd

    # print(f"{'✓' if j == 0 else '✗'} [{_score}] ∈ {text} | {pattern}")
    return _score if j == 0 else None


if __name__ == '__main__':
    run_search(fuzzy_search_2)

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
