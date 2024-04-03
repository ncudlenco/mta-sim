import cv2
import os

path = "Z:\\More games\\GTA San Andreas\\MTA-SA1.6\\server\\mods\\deathmatch\\resources\\sv2l\\complex_graphs"
directories = [ name for name in os.listdir(path) if os.path.isdir(os.path.join(path, name)) ]
# for directory in directories:
directory = "c10.json_out"
print("Working on {}...".format(directory))
for dd in os.listdir(os.path.join(path, directory)):
# dd = "e1774eab-a4c7-438c-8695-25604f6e2944"
    for subdirectory in os.listdir(os.path.join(path, directory, dd)):
        image_folder = os.path.join(path, directory, dd, subdirectory)
        video_folder = image_folder #os.path.join(path, "videos")
        video_name = os.path.join(video_folder, "{}.mp4".format(directory))

        if os.path.exists(video_name):
            continue

        images = [img for img in os.listdir(image_folder) if img.endswith(".jpg")]

        frame = cv2.imread(os.path.join(image_folder, images[0]))
        height, width, layers = frame.shape
        # height = int(height/4)
        # width = int(width/4)
        # frame = cv2.resize(frame, (width, height))

        fourcc = cv2.VideoWriter_fourcc(*'mp4v')

        video = cv2.VideoWriter(video_name, fourcc, 15, (width, height))

        cur = 1
        for image in images:
            print(f"Working on {cur} / {len(images)}")
            frame = cv2.imread(os.path.join(image_folder, image))
            frame = cv2.resize(frame, (width, height))
            video.write(frame)
            cur += 1

        cv2.destroyAllWindows()
        video.release()
        print("Done {}".format(video_name))