import os
from _curses import KEY_BACKSPACE
from random import randint

from fuzzy_score_1 import score
from fuzzy_score_2 import fuzzy_search_2


def _read_one_wide_char_win(): return msvcrt.getwch()


def _char_can_be_escape_win(char): return True if char in ("\x00", "à") else False


def _dump_keyboard_buff_win():
    try:
        msvcrt.ungetwch("a")
    except OSError:
        return msvcrt.getwch()
    else:
        _ = msvcrt.getwch();
        return ""


def _read_one_wide_char_nix():
    old_settings = termios.tcgetattr(sys.stdin.fileno());
    tty.setraw(sys.stdin.fileno())
    wchar = sys.stdin.read(1)
    termios.tcsetattr(sys.stdin.fileno(), termios.TCSANOW, old_settings);
    return wchar


def _char_can_be_escape_nix(char): return True if char == "\x1b" else False


def _dump_keyboard_buff_nix():
    old_settings = termios.tcgetattr(sys.stdin.fileno())
    tty.setraw(sys.stdin.fileno());
    os.set_blocking(sys.stdin.fileno(), False)
    buffer_dump = ""
    while char := sys.stdin.read(1): buffer_dump += char
    os.set_blocking(sys.stdin.fileno(), True);
    termios.tcsetattr(sys.stdin.fileno(), termios.TCSANOW, old_settings)
    if buffer_dump:
        return buffer_dump
    else:
        return ""


if os.name == "nt":
    import msvcrt

    read_one_wdchar, char_can_escape, dump_key_buffer = _read_one_wide_char_win, _char_can_be_escape_win, _dump_keyboard_buff_win
if os.name == "posix":
    import termios, tty, sys

    read_one_wdchar, char_can_escape, dump_key_buffer = _read_one_wide_char_nix, _char_can_be_escape_nix, _dump_keyboard_buff_nix


def getch_but_it_actually_works():
    wchar = read_one_wdchar()
    if char_can_escape(wchar):
        dump = dump_key_buffer()
        return wchar + dump
    else:
        return wchar


LINE_UP = '\033[1A'
LINE_CLEAR = '\x1b[2K'


class BufPrint:
    pattern = ""
    results = []
    last_pattern = ""
    last_items_len = []
    limit = 20

    def clear(self):
        for i in reversed(self.last_items_len):
            print(' ' * i, end='\r')
            print(end=LINE_UP)

        print(' ' * len(self.last_pattern), end='\r')

    def print(self, _pattern: str, _items: list):
        print(_pattern, flush=True)
        sub_items = _items[0:min(len(_items), self.limit)]
        for i, item in enumerate(sub_items):
            print(item, flush=True)

        print(end=LINE_UP, flush=True)

        self.last_pattern = _pattern
        self.last_items_len = [len(i) for i in sub_items]


def run_search(alg):
    pattern = ""
    buf_print = BufPrint()

    text_file = open("../benchmark_data/linux_files_list.txt", 'r')
    texts = text_file.readlines()

    ch = getch_but_it_actually_works()
    while ch != '\x1b':
        results: list[(str, int)] = []
        buf_print.clear()

        if ch in [KEY_BACKSPACE, '\b', '\x7f']:
            pattern = pattern[0:len(pattern) - 1]
        else:
            pattern += ch

        for text in texts:
            score = alg(text, pattern)
            if score is not None:
                results.append((text.strip(), score))

        results = sorted(results, key=lambda x: x[1], reverse=True)
        results = [f"[{r[1]}] {r[0]}" for r in results]

        buf_print.print(pattern, results)

        ch = getch_but_it_actually_works()

    text_file.close()


def run_fuzzy_score_1():
    run_search(score)


def run_fuzzy_score_2():
    run_search(fuzzy_search_2)


if __name__ == '__main__':
    def alg(text: str, pattern: str) -> int:
        # for r in [-2, None, -4, 6, 0]:
        #     yield r
        return randint(-100000, 100000)


    # run_search(alg)
    run_fuzzy_score_2()
