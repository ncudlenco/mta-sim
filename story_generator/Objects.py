import sys
import Actions

class Object:

    def __init__(self, name, actions=[], id=[]):
        self.name = name
        self.actions = actions
        self.id = None

    def add_action(self, action):
        if action not in self.actions:
            self.actions = self.actions + [action]

    def set_id(self, id):
        if self.id != None:
            print("Error when setting id {0}. Object {1} already has id {2}!".format(id, self.name, self.id))
            sys.exit()
        self.id = id

    def __str__(self):
        return self.name# + ":" +  str(self.actions)

    def __repr__(self):
        return self.__str__()

    def generate_node(self):

        obj_dict = {}
        target_dict = {}

        obj_dict["Action"] = "Exists"
        # obj_dict["id"] = self.id
        obj_dict["Entities"] = [self.id]
        obj_dict["Location"] = None
        obj_dict["Timeframe"] = None
        obj_dict["Properties"] = {"Type": self.name}
        # target_dict["id"] = self.id
        # target_dict["Name"] = self.name

        # obj_dict["Target"] = target_dict

        return obj_dict

    def get_obj_rooms(self, rooms):
        rs = []
        for k, v in rooms.items():
            if self.name in v:
                rs.append(k)
        return list(set(rs))

def get_obj_list():
    OBJECT_CLASSES = ["ArmChair", "Bed", "BenchPress", "BenchPressBar", "Book", "Bookshelf", "Chair", "Cigarette",
                 "CoffeeTable", "Desk", "Drinks", "Dumbbell", "FlowerPot", "Food", "Fridge", "Furniture",
                 "GasCooker", "GymBike", "Laptop", "Microwave", "MobilePhone", "MusicPlayer", "OfficeChair",
                 "Painting", "Photos", "PlantPot", "Plate", "PunchingBag", "Remote", "Sink", "Sofa", "Table",
                 "Televisor", "Toilet", "Treadmill", "TurnTable", "TwoDumbbells", "Wardrobe", "Watch", "TaiChiObject", "MultiAgentObject"]

    # just unknown objects (for the moment)
    OBJECT_CLASSES.remove("Bookshelf")
    OBJECT_CLASSES.remove("CoffeeTable")
    OBJECT_CLASSES.remove("FlowerPot")
    OBJECT_CLASSES.remove("Fridge")
    OBJECT_CLASSES.remove("GasCooker")
    OBJECT_CLASSES.remove("Microwave")
    OBJECT_CLASSES.remove("MusicPlayer")
    OBJECT_CLASSES.remove("Photos")
    OBJECT_CLASSES.remove("Plate")
    OBJECT_CLASSES.remove("Toilet")
    OBJECT_CLASSES.remove("Wardrobe")

    OBJECT_CLASSES.remove("Painting")
    OBJECT_CLASSES.remove("Table")
    

    objects = []
    for obj in OBJECT_CLASSES:
        objects.append(Object(obj))
    return objects

def find_obj_by_name(obj_name, objects):
    for index, obj in enumerate(objects):
        if obj_name == obj.name:
            return index
    return -1
