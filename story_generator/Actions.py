import sys

COMPLEX_ACTIONS = {
                    "TalkAtPhone": "AnswerPhone TalkPhone HangUp", 
                    "TreadmillJog": "GetOn JogTreadmill GetOff",
                    "SmokeCigarette": "SmokeIn Smoke SmokeOut", 
                    "SleepOnBed": "GetOn Sleep GetOff",
                    "SitAndStand": "SitDown StandUp", 
                    "DrinkBeverage": "PickUp Drink PutDown", 
                    "DanceTurnTable": "TurnOn Dance TurnOff",
                    "DumbbellsWorkOut": "PickUp DumbbellsWorkOut PutDown", 
                    "EatFood": "PickUp Eat", 
                    "PedalOnGymBike": "GetOn PedalGymBike GetOff",
                    "BenchpressWorkOut": "GetOn BenchpressWorkOut GetOff"
                    }


class Action:

    def __init__(self, name, action_type="simple", action_components=[], id = None):
        self.name = name
        # small sanity check
        if (action_type == "simple" and action_components != []) or (action_type == "complex" and action_components == []):
            print("Wrong combination of action type: {0} and action components: {1}".format(action_type, action_components))
            sys.exit()
        self.action_type = action_type
        if action_components == []:
            self.action_components = self.name
        else:
            self.action_components = action_components
        self.id = id

    def set_id(self, id):
        if self.id != None:
            print("Error when setting id {0}. Action {1} already has id {2}!".format(id, self.name, self.id))
            sys.exit()
        self.id = id


    def __str__(self):
        return str(self.name) + ": " +  str(self.id)
    
    def __repr__(self):
        return self.__str__()



def get_action_list():
    ACTIONS = ["AnswerPhone", "BarbellWorkOut", "BenchpressWorkOut", "CloseLaptop", "Cook", "Dance", "Drink", "DumbbellsWorkOut",
                 "Eat", "GetOff", "GetOn", "HandShake", "HangUp", "Hug", "JogTreadmill", "Kiss", "Laugh", "LayOnElbow", "LookAtObject",
                 "LookAtTheWatch", "Move", "OpenDoor", "OpenLaptop", "PedalGymBike", "PickUp", "Punch", "PunchSeated", "PutDown",
                 "PutIn", "Read", "SitDown", "Sleep", "Smoke", "SmokeIn", "SmokeOut", "StandUp", "TaiChi", "Talk", "TalkPhone",
                 "TurnOff", "TurnOn", "TypeOnKeyboard", "Wait", "WashHands"]

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

    

    actions = []
    for action in ACTIONS:
        if action in COMPLEX_ACTIONS:
            t = "complex"
            ac = list(COMPLEX_ACTIONS[action].split(" "))
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