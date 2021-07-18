import os
from collections import Counter
from nltk.tokenize import RegexpTokenizer, word_tokenize, sent_tokenize
import matplotlib.pyplot as plt
from nltk.corpus import stopwords

path = os.path.join("..", "data")

counter_words = Counter()
list_words = []
list_sentences = []
list_sent_tokens = []

tokenizer = RegexpTokenizer(r'\w+')

for video_type in ["short", "medium", "long"]:
    for directory in os.listdir(os.path.join(path, video_type)):

        for subdirectory in os.listdir(os.path.join(path, video_type, directory)):
            with open(os.path.join(path, video_type, directory, subdirectory, "labels.txt")) as file:
                text = file.read()

        list_sentences.append(text)
        list_words += word_tokenize(text)
        list_sent_tokens.append(word_tokenize(text))

        tokens = tokenizer.tokenize(text)

        for token in tokens:
            counter_words[token] += 1

total_num_sent = 0
for descr in list_sentences:
    total_num_sent += len(sent_tokenize(descr))

print("Total tokens: {}".format(len(list_words)))
print("Vocabulary size: {}".format(len(set(list_words))))
print("Avg description length: {}".format(sum(len(sent) for sent in list_sent_tokens) / len(list_sent_tokens)))
print("Total sentences: {}".format(total_num_sent))
print("Avg num sent per description: {}".format(total_num_sent / len(list_sent_tokens)))
print("Hapax legolema: {}".format([sorted(counter_words.items(), key=lambda x: x[1])[:100]]))

list_sent_len = [len(sent) for sent in list_sent_tokens] * 6

plt.hist(list_sent_len, bins=40)
plt.ylabel("Frequency", fontsize=18)
plt.tick_params(axis='both', which='major', labelsize=14)
plt.xlabel("Number of words", fontsize=18)
plt.show()

N = 25
list_freq, list_words = [], []
for word, freq in sorted(counter_words.items(), key=lambda x: x[1], reverse=True)[:N]:
    list_words.append(word)
    list_freq.append(freq)

fig, (ax1, ax2) = plt.subplots(2, 1)
ax1.bar(list_words, list_freq)
ax1.tick_params(axis='both', which='major', labelsize=14)
ax1.set_ylabel("Frequency", fontsize=18)

counter = 0
list_freq, list_words = [], []
for word, freq in sorted(counter_words.items(), key=lambda x: x[1], reverse=True):
    if counter == 25:
        break

    if word.lower() not in stopwords.words('english') and word != "Afterwards":
        list_words.append(word)
        list_freq.append(freq)

        counter += 1

ax2 = plt.subplot(212)

ax2.bar(list_words, list_freq)
ax2.set_ylabel("Frequency", fontsize=18)
ax2.tick_params(axis='both', which='major', labelsize=14)
ax2.set_xlabel("Lexical forms", fontsize=18)

plt.show()

