import cv2
import os

path = os.path.join(".", "data_out")

for directory in os.listdir(path):
    print("Working on {}...".format(directory))
    for subdirectory in os.listdir(os.path.join(path, directory)):
        image_folder = os.path.join(path, directory, subdirectory)
        video_name = os.path.join(image_folder, "video.mp4")

        if os.path.exists(video_name):
            continue

        images = [img for img in os.listdir(image_folder) if img.endswith(".jpg")]

        frame = cv2.imread(os.path.join(image_folder, images[0]))
        height, width, layers = frame.shape
        # height = int(height/4)
        # width = int(width/4)
        # frame = cv2.resize(frame, (width, height))

        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        video = cv2.VideoWriter(video_name, fourcc, 20, (width, height))

        for image in images:
            frame = cv2.imread(os.path.join(image_folder, image))
            frame = cv2.resize(frame, (width, height))
            video.write(frame)

        cv2.destroyAllWindows()
        video.release()