import os
import cv2

path = os.path.join("..", "data")

list_images = []

for story_type in os.listdir(path):
    if story_type == "data.zip" or story_type == "short":
        continue

    for directory in sorted(os.listdir(os.path.join(path, story_type)))[50:]:
        print("Working on {}...".format(directory))

        images = []

        for subdirectory in os.listdir(os.path.join(path, story_type, directory)):
            image_folder = os.path.join(path, story_type, directory, subdirectory)

            images = [img for img in os.listdir(image_folder) if img.endswith(".jpg")]

        for image in images:
            img = cv2.imread(os.path.join(image_folder, image))

            print(img.shape)

print("Average video time: {} seconds".format(sum(len(sent) / 30 for sent in list_images) / len(list_images)))