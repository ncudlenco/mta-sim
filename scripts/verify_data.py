import os

for dirr in os.listdir("data"):
    print(dirr)
    for subdirr in os.listdir(os.path.join("data", dirr)):
        images = []

        for filename in os.listdir(os.path.join("data", dirr, subdirr)):
            if filename.endswith(".jpg"):
                images.append(filename)

        assert len(images) > 20, dirr