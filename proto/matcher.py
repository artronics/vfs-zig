def print_marker(_marker: list[int], text: str, pattern: str, pattern_subset: list[int]):
    print(f"{text} | {pattern}     ====> {_marker}")
    print(f"{pattern_subset} -> {[pattern[0:pi + 1] for pi in pattern_subset]}")
    print("__________________________________")


def marker(text: str, pattern: str, pattern_subset: list[int]) -> list[int]:
    _marker = [0] * len(text)
    for i in range(len(text)):
        for j in pattern_subset:
            m_i = i - j
            if pattern[j] == text[i] and m_i >= 0:
                _marker[m_i] += 1

    print_marker(_marker, text, pattern, pattern_subset)

    return _marker


def test_marker():
    marker("", "", [0])
    marker("a", "a", [0])
    marker("a", "b", [0])
    marker("aa", "a", [0])
    marker("ab", "a", [0])
    marker("ab", "ab", [0])
    marker("ab", "ab", [0, 1])
    marker("aba", "ab", [0, 1])
    marker("ab", "ab", [1])
    marker("ababab", "ababab", [0, 1, 2, 3, 4, 5])


if __name__ == '__main__':
    test_marker()
