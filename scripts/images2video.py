import cv2
import os

path = os.path.join("..", "data")

for video_type in ["short", "medium", "long"]:
    for directory in os.listdir(os.path.join(path, video_type)):
        print("Working on {}...".format(directory))
        for subdirectory in os.listdir(os.path.join(path, video_type, directory)):
            image_folder = os.path.join(path, video_type, directory, subdirectory)
            video_name = os.path.join(path, video_type, directory, subdirectory, "video.mp4")

            if os.path.exists(video_name):
                continue

            images = [img for img in os.listdir(image_folder) if img.endswith(".jpg")]

            frame = cv2.imread(os.path.join(image_folder, images[0]))
            height, width, layers = frame.shape
            height = int(height/4)
            width = int(width/4)
            frame = cv2.resize(frame, (width, height))

            fourcc = cv2.VideoWriter_fourcc(*'mp4v')
            video = cv2.VideoWriter(video_name, fourcc, 10, (width, height))

            for image in images:
                frame = cv2.imread(os.path.join(image_folder, image))
                frame = cv2.resize(frame, (width, height))
                video.write(frame)

            cv2.destroyAllWindows()
            video.release()