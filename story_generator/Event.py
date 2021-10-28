import Actions
import Objects
import Rooms
import Actor
import sys
import random
class Event:

    def __init__(self, id, action, object, actor, room, next_event = None):
        self.id = id
        self.action = action
        self.object = object
        self.actor = actor
        self.room = room
        self.next_event = next_event
        self.sync_events = []
        
    def add_sync_event(self, event, type, tid):
        self.sync_events.append((event, type, tid))

    def __str__(self):
        return "(Event id: {0}, action {1}, object {2}, actor {3}, room {4})".format(str(self.id), str(self.action), str(self.object), str(self.actor), str(self.room))

    def __repr__(self):
        return self.__str__()

    def generate_node(self):
        
        if self.action.action_type == "complex":
            r_acts = []
            r_mandatory = []

            for inner_action in self.action.action_components:
                if inner_action.rand == True:
                    r_acts.append(inner_action)
                    r_mandatory.append("*")
                else:
                    r_mandatory.append(inner_action)

            if r_acts != []:
                r_acts = random.sample(r_acts, random.randint(1, len(r_acts)-1))
                print(r_acts)
                aux_acts = []
                ii = 0
                for a in r_mandatory:
                    if a == "*":
                        if ii < len(r_acts):                   
                            aux_acts.append(r_acts[ii])
                            ii += 1
                    else:
                        aux_acts.append(a)
                print(aux_acts)
                r_acts = aux_acts
                        
            else:
                r_acts = self.action.action_components

            inner_actions_ids = ["{0}_inner{1}".format(self.action.id,i) for i in range(len(r_acts))]
            action_dicts = []
            for i, inner_action_name in enumerate(r_acts):
                inner_action_name = inner_action_name.name
                inner_action_dict = {}
                actor_dict = {}
                actor_dict["id"] = self.actor.id
                
                obj_dict = {}
                if type(self.object) == list:
                    obj_dict["id"] = r_acts[i].targets.id
                else:        
                    obj_dict["id"] = self.object.id

                # inner_action_dict["Actor"] = actor_dict
                inner_action_dict["Action"] = inner_action_name
                inner_action_dict["Entities"] = [self.actor.id]
                if obj_dict["id"] != None:
                    inner_action_dict["Entities"].append(obj_dict["id"])


                if i == len(r_acts) - 1:
                    if self.next_event == None:
                        inner_action_dict["Next"] = "None"
                    else:
                        if self.next_event.action.action_type == "complex":
                            inner_action_dict["Next"] = self.next_event.action.id+"_inner0"
                        else:
                            inner_action_dict["Next"] = self.next_event.action.id

                else:
                    inner_action_dict["Next"] = inner_actions_ids[i+1]
                # inner_action_dict["id"] = inner_actions_ids[i]
                # inner_action_dict["Target"] = obj_dict
                inner_action_dict["Location"] = self.room.name
                inner_action_dict["Timeframe"] = None
                inner_action_dict["Properties"] = {}
                action_dicts.append((inner_actions_ids[i], inner_action_dict))
            return action_dicts
        
        else:
            action_dict = {}
            actor_dict = {}
            actor_dict["id"] = self.actor.id
            
            obj_dict = {}        
            obj_dict["id"] = self.object.id

            # action_dict["Actor"] = actor_dict
            action_dict["Action"] = self.action.name

            action_dict["Entities"] = [self.actor.id]
            if self.object.id != None:
                action_dict["Entities"].append(self.object.id)

            # if self.next_event == None:
            #     action_dict["Next"] = "None"
            # else:
            #     if self.next_event.action.action_type == "complex":
            #         action_dict["Next"] = self.next_event.action.id+"_inner0"
            #     else:
            #         action_dict["Next"] = self.next_event.action.id
            
            # action_dict["id"] = self.action.id
            # action_dict["Target"] = obj_dict
            action_dict["Location"] = [x.name for x in self.room]
            action_dict["Timeframe"] = None
            action_dict["Properties"] = {}

            return action_dict
