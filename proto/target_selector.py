import random

if __name__ == '__main__':
    text_file = open("../benchmark_data/linux_files_list.txt", 'r')
    texts = text_file.readlines()

    rand_line = random.randint(0, len(texts))

    print(texts[rand_line])
