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
                    "OpenAndCloseLaptop": "OpenLaptop CloseLaptop",
                    "WorkAtLaptop": "SitDown OpenLaptop WriteOnLaptop* PunchDesk* LayOnElbow* LookAtWatch* CloseLaptop StandUp"
                    }

class Action:

    def __init__(self, name, action_type="simple", action_components=[], id = None, multiagent = False, rand=False):
        if name[-1] == "*":
            self.name = name[:-1]
            self.rand = True
        else:
            self.name = name
            self.rand = False
        self.targets = []
        
        # small sanity check
        if (action_type == "simple" and action_components != []) or (action_type == "complex" and action_components == []):
            print("Wrong combination of action type: {0} and action components: {1}".format(action_type, action_components))
            sys.exit()
        self.action_type = action_type
        self.action_components = action_components
        self.id = id
        self.possible_locations = []
        self.multiagent = multiagent

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
            
            self.possible_locations.extend(list(set.intersection(*rss)))
            self.possible_locations = list(set(self.possible_locations))
            
        else:
            rs = target.get_obj_rooms(Rooms.DROP)
            
            self.targets = target
            # self.possible_locations = rs
            self.possible_locations.extend(rs)
            self.possible_locations = list(set(self.possible_locations))
    
    def __str__(self):
        return str(self.name)# + ": " +  str(self.id) + " " + str(self.action_components) + " " + str(self.targets) + " " + str(self.possible_locations)
    
    def __repr__(self):
        return self.__str__()


def get_action_list():
    ACTIONS = ["AnswerPhone", "BarbellWorkOut", "BenchpressWorkOut", "CloseLaptop", "Cook", "Dance", "Drink", "DumbbellsWorkOut",
                 "Eat", "GetOff", "GetOn", "HangUp",  "JogTreadmill", "Laugh", "LayOnElbow", "LookAtObject",
                 "LookAtTheWatch", "Move", "OpenDoor", "OpenLaptop", "PedalGymBike", "PickUp", "Punch", "PunchSeated", "PutDown",
                 "PutIn", "Read", "SitDown", "Sleep", "Smoke", "SmokeIn", "SmokeOut", "StandUp", "TaiChi", "TalkPhone",
                 "TurnOff", "TurnOn", "TypeOnKeyboard", "Wait", "WashHands", "WorkAtLaptop",
    #multi-agent
                 "Handshake", "Hug", "Talk", "Joke", "Kiss"
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

    # ACTIONS.append("OpenAndCloseLaptop")
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
        mta = False
        if action == "Handshake" or action == "Hug" or action == "Talk" or action == "Joke" or action == "Kiss":
            mta = True

        act = Action(action, t, ac, multiagent=mta)
        actions.append(act)

    # clear complex action *s
    for k,v in COMPLEX_ACTIONS.items():
        COMPLEX_ACTIONS[k] = v.replace("*", "")
    return actions


def find_action_by_name(act_name, actions):
    for index, act in enumerate(actions):
        if act_name == act.name:
            return index
    return -1


def associate_objects_to_actions(actions, objects):
    DAOP = {
            "TalkAtPhone": "MobilePhone",
            "OpenAndCloseLaptop": "Laptop",
            "TreadmillJog": "Treadmill", 
            "SmokeCigarette": "Cigarette",
            "SleepOnBed": "Bed",
            "SitAndStand": "Sofa ArmChair OfficeChair Chair Desk",
            "Punch": "PunchingBag",
            "DanceTurnTable": "TurnTable",
            "DumbbellsWorkOut": "TwoDumbbells",
            "DrinkBeverage": "Drink",
            "EatFood": "Chair|Food|Food|Chair",
            "WashHands": "Sink",
            "PedalOnGymBike":"GymBike", 
            "BenchpressWorkOut": "BenchPress",
            "TaiChi": "TaiChiObject",
            "HandleRemote": "Remote|Sofa|Sofa|Remote",
            "WorkAtLaptop": "Desk|Laptop|Laptop|Laptop|Laptop|Laptop|Laptop|Desk",
            "Handshake": "MultiAgentObject",
            "Hug": "MultiAgentObject",
            "Talk": "MultiAgentObject",
            "Kiss": "MultiAgentObject",
            "Joke": "MultiAgentObject"
            }
    
    actions = list(filter(lambda x: x.name in DAOP, actions))
    for action in actions:
        for objn in DAOP[action.name].split(" "):
            if "|" in objn:
                iobjns = objn.split("|")
                targets = []
                for iobjn in iobjns:
                    index = Objects.find_obj_by_name(iobjn, objects)
                    if index == -1:
                        print("Object {0} for action {1} not found in the list of objects.".format(iobjn, action.name))
                        sys.exit()
                    targets.append(objects[index])
                action.add_target(targets)
            else:                      
                index = Objects.find_obj_by_name(objn, objects)
                if index == -1:
                    print("Object {0} for action {1} not found in the list of objects.".format(objn, action.name))
                    sys.exit()
                action.add_target(objects[index])
        
    actions = list(filter(lambda x: len(x.possible_locations) > 0, actions))
    return actions


def filter_actions_by_rooms(actions, room):
    acts = []
    for act in actions:
        if room.name in act.possible_locations:
            acts.append(act)
    return acts

def get_nonspecific_actions(actions):
    nonspecific_objects = "MobilePhone Cigarette MultiAgentObject"
    nonspecific_actions = []
    for action in actions:
        if action.targets != []:
            if action.targets.name in nonspecific_objects:
                nonspecific_actions.append(action)
    return nonspecific_actions
    
