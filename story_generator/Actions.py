# from story_generator.main import ACTORS
# import ACTORS
import sys
import Objects
import Rooms

COMPLEX_ACTIONS = {
                    "TalkAtPhone": "AnswerPhone TalkPhone HangUp", 
                    "TreadmillJog": "GetOn JogTreadmill GetOff",
                    "SmokeCigarette": "SmokeIn Smoke SmokeOut", 
                    "SleepOnBed": "GetOn Sleep GetOff",
                    "SitAndStand": "SitDown StandUp", 
                    "DrinkBeverage": "PickUp Drink PutDown", 
                    "DanceTurnTable": "TurnOn Dance TurnOff",
                    "DumbbellsWorkOut": "PickUp DumbbellsWorkOut PutDown", 
                    "EatFood": "SitDown PickUp Eat StandUp", 
                    "PedalOnGymBike": "GetOn PedalGymBike GetOff",
                    "BenchpressWorkOut": "GetOn BenchpressWorkOut GetOff",
                    "HandleRemote": "PickUp SitDown StandUp PutDown",
                    "OpenAndCloseLaptop": "OpenLaptop CloseLaptop"
                    }

class Action:

    def __init__(self, name, action_type="simple", action_components=[], id = None):
        self.name = name
        self.targets = []
        
        # small sanity check
        if (action_type == "simple" and action_components != []) or (action_type == "complex" and action_components == []):
            print("Wrong combination of action type: {0} and action components: {1}".format(action_type, action_components))
            sys.exit()
        self.action_type = action_type
        self.action_components = action_components
        self.id = id
        self.possible_locations = []

    def set_id(self, id):
        if self.id != None:
            print("Error when setting id {0}. Action {1} already has id {2}!".format(id, self.name, self.id))
            sys.exit()
        self.id = id

    def add_target(self, target):
        if type(target) == list:
            if self.action_type != "complex":
                print("Wrong action type for target objects")
                sys.exit()
            if len(self.action_components) != len(target):
                print("Wrong number of actions {0} and objects {1} for action {3}".format(self.action_components, target, self.name))
                sys.exit()
            rss = []
            for i in range(len(self.action_components)):
                self.action_components[i].add_target(target[i])
                # self.action_components[i].possible_locations = []
                rs = target[i].get_obj_rooms(Rooms.DROP)
                rss.append(set(rs))
            self.possible_locations = list(set.intersection(*rss))

        else:
            rs = target.get_obj_rooms(Rooms.DROP)
            self.targets = target
            self.possible_locations = rs
    
    def __str__(self):
        return str(self.name)# + ": " +  str(self.id) + " " + str(self.action_components) + " " + str(self.targets) + " " + str(self.possible_locations)
    
    def __repr__(self):
        return self.__str__()


def get_action_list():
    ACTIONS = ["AnswerPhone", "BarbellWorkOut", "BenchpressWorkOut", "CloseLaptop", "Cook", "Dance", "Drink", "DumbbellsWorkOut",
                 "Eat", "GetOff", "GetOn", "HandShake", "HangUp", "Hug", "JogTreadmill", "Kiss", "Laugh", "LayOnElbow", "LookAtObject",
                 "LookAtTheWatch", "Move", "OpenDoor", "OpenLaptop", "PedalGymBike", "PickUp", "Punch", "PunchSeated", "PutDown",
                 "PutIn", "Read", "SitDown", "Sleep", "Smoke", "SmokeIn", "SmokeOut", "StandUp", "TaiChi", "Talk", "TalkPhone",
                 "TurnOff", "TurnOn", "TypeOnKeyboard", "Wait", "WashHands",
    #multi-agent
                 "HandShake"
                    ]

    ACTIONS.remove("AnswerPhone")
    ACTIONS.remove("TalkPhone")
    ACTIONS.remove("HangUp")
    ACTIONS.append("TalkAtPhone")

    ACTIONS.remove("JogTreadmill")
    ACTIONS.append("TreadmillJog")

    ACTIONS.remove("SmokeIn")
    ACTIONS.remove("Smoke")
    ACTIONS.remove("SmokeOut")
    ACTIONS.append("SmokeCigarette")

    ACTIONS.remove("Sleep") #?
    ACTIONS.append("SleepOnBed")

    ACTIONS.append("SitAndStand")

    ACTIONS.remove("Drink")
    ACTIONS.append("DrinkBeverage")

    ACTIONS.append("DanceTurnTable")

    ACTIONS.remove("Eat")
    ACTIONS.append("EatFood")

    ACTIONS.remove("PedalGymBike")
    ACTIONS.append("PedalOnGymBike")

    ACTIONS.append("OpenAndCloseLaptop")
    ACTIONS.append("HandleRemote")
    

    actions = []
    for action in ACTIONS:
        if action in COMPLEX_ACTIONS:
            t = "complex"
            ac = []
            for aux in COMPLEX_ACTIONS[action].split(" "):
                aux_act = Action(aux, "simple", [])
                ac.append(aux_act)
        else:
            t = "simple"
            ac = []
        act = Action(action, t, ac)
        actions.append(act)

    return actions

def find_action_by_name(act_name, actions):
    for index, act in enumerate(actions):
        if act_name == act.name:
            return index
    return -1

def associate_objects_to_actions(actions, objects):
    # TODO: handle laptop + desk random order and number of actions; from house8.lua line 145. specifically handle random interplayed actions between open and close laptop
    DAOP = {
            "TalkAtPhone": "MobilePhone",
            "OpenAndCloseLaptop": "Laptop",
            "TreadmillJog": "Treadmill", 
            "SmokeCigarette": "Cigarette",
            "SleepOnBed": "Bed",
            "SitAndStand": "Sofa ArmChair OfficeChair Chair Desk",
            "Punch": "PunchingBag", # not found in episode
            "DanceTurnTable": "TurnTable",
            "DumbbellsWorkOut": "TwoDumbbells",
            "DrinkBeverage": "Drink",
            "EatFood": "Chair|Food|Food|Chair",
            "WashHands": "Sink",
            "PedalOnGymBike":"GymBike", 
            "BenchpressWorkOut": "BenchPress",
            "Read": "Book",
            "HandleRemote": "Remote|Sofa|Sofa|Remote",
            # "Handshake": "Test"
            }
    actions = list(filter(lambda x: x.name in DAOP, actions))
    for action in actions:
        if action.name in DAOP:
            for objn in DAOP[action.name].split(" "):
                if "|" in objn:
                    iobjns = objn.split("|")
                    targets = []
                    for iobjn in iobjns:
                        index = Objects.find_obj_by_name(iobjn, objects)
                        if index == -1:
                            print("Object {0} for action {1} not found in the list of objects.".format(objn, action.name))
                            sys.exit()
                        targets.append(objects[index])
                    action.add_target(targets)
                else:
                    index = Objects.find_obj_by_name(objn, objects)
                    if index == -1:
                        print("Object {0} for action {1} not found in the list of objects.".format(objn, action.name))
                        sys.exit()
                    action.add_target(objects[index])
        else:
            print("Action {0} not found in DAOP".format(action.name))
    actions = list(filter(lambda x: len(x.possible_locations) > 0, actions))
    return actions


def filter_actions_by_rooms(actions, room):
    acts = []
    for act in actions:
        if room.name in act.possible_locations:
            acts.append(act)
    return acts