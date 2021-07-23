import os

for dirr in os.listdir("data"):
    print(dirr)
    for subdirr in os.listdir(os.path.join("data", dirr)):
        images = []

        for filename in os.listdir(os.path.join("data", dirr, subdirr)):
            if filename.endswith(".jpg"):
                images.append(filename)

        for image in images[:10] + images[-18:]:
            try:
                os.remove(os.path.join("data", dirr, subdirr, image))
                print(image)
            except FileNotFoundError:
                print("ERROR: image")