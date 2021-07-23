import os
import json

path = os.path.join("..", "data")

list_atomic_events = []
list_events = []

for video_type in os.listdir(path):
    if video_type == "data.zip":
        continue

    for directory in os.listdir(os.path.join(path, video_type)):

        for subdirectory in os.listdir(os.path.join(path, video_type, directory)):
            with open(os.path.join(path, video_type, directory, subdirectory, "graph.json")) as file:
                graph = json.load(file)

            list_atomic_events.append(graph[0]["AtomicEvents"])
            list_events.append(graph[0]["Events"])

print(sum(len(sent) for sent in list_atomic_events) / len(list_atomic_events))
print(sum(len(sent) for sent in list_events) / len(list_events))