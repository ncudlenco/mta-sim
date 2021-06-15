import sys
import Actions
import Objects

class Room:

    def __init__(self, name, actions=[]):
        self.name = name
        self.objects = []

    def add_object(self, object):
        if object not in self.objects:
            self.objects = self.objects + [object]

    def __str__(self):
        return self.name# + ":" +  str(self.objects)

    def __repr__(self):
        return self.__str__()

def get_room_list():
    R = ["Kitchen", "Living", "BathRoom", "BedRoom", "Gym", ""]
    rooms = []
    for room in R:
        rooms.append(Room(room))
    return rooms

def associate_objects_to_rooms(rooms, objects):

    DROP = {"Kitchen": "Chair Drink Food Painting Sink Table", 
            "Living": "ArmChair Book Chair TurnTable Sofa",
            "BedRoom": "Bed",
            "BathRoom": "Sink",
            "BarRoom": "Drink Food",
            "Gym": "BenchPress Treadmill TwoDumbbells GymBike",
            }

    
    # add MobielPhone and Cigarette to every room
    # TODO:
    # add Painting
    # add TaiChi in Gym
    for r in rooms:
        index = Objects.find_obj_by_name("MobilePhone", objects)
        r.add_object(objects[index])
        index = Objects.find_obj_by_name("Cigarette", objects)
        r.add_object(objects[index])
        

    for room in rooms:
        if room.name in DROP:
            for obj in DROP[room.name].split(" "):
                index = Objects.find_obj_by_name(obj, objects)
                if index == -1:
                    print("Object {0} for room {1} not found in the list of objects.".format(obj, room))
                    sys.exit()
                room.add_object(objects[index])
