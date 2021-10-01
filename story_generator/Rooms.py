import sys
import Actions
import Objects


DROP = {"Kitchen": "Chair Drinks Food Sink", 
        "Living": "ArmChair Book Chair TurnTable Sofa Remote Laptop Desk Watch",
        "BedRoom": "Bed Laptop",
        "BathRoom": "Sink",
        "BarRoom": "Drinks Food",
        "Gym": "BenchPress Treadmill TwoDumbbells GymBike PunchingBag TaiChiObject",
        }

# add certain object to every room
for k, v in DROP.items():
    DROP[k] = v + " MobilePhone Cigarette MultiAgentObject"


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
    # R = ["Gym", ""]
    # R = ["Kitchen", "Living", "BathRoom", "BedRoom", ""]
    # R = ["Kitchen", ""]
    rooms = []
    for room in R:
        rooms.append(Room(room))
    return rooms

def associate_objects_to_rooms(rooms, objects):
    
    for room in rooms:
        if room.name in DROP:
            for obj in DROP[room.name].split(" "):
                index = Objects.find_obj_by_name(obj, objects)
                if index == -1:
                    print("Object {0} for room {1} not found in the list of objects.".format(obj, room))
                    sys.exit()
                room.add_object(objects[index])


