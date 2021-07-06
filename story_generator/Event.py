import Actions
import Objects
import Rooms
import Actor
import sys

class Event:

    def __init__(self, id, action, object, actor, room, next_event = None):
        self.id = id
        self.action = action
        self.object = object
        self.actor = actor
        self.room = room
        self.next_event = next_event
        

    def __str__(self):
        return "(Event id: {0}, action {1}, object {2}, actor {3}, room {4})".format(str(self.id), str(self.action), str(self.object), str(self.actor), str(self.room))

    def __repr__(self):
        return self.__str__()

    def generate_node(self):

        if self.action.action_type == "complex":
            inner_actions_ids = ["{0}_inner{1}".format(self.action.id,i) for i in range(len(self.action.action_components))]
            action_dicts = []
            for i, inner_action_name in enumerate(self.action.action_components):
                inner_action_name = inner_action_name.name
                inner_action_dict = {}
                actor_dict = {}
                actor_dict["id"] = self.actor.id
                
                obj_dict = {}
                if type(self.object) == list:
                    obj_dict["id"] = self.action.action_components[i].targets.id
                else:        
                    obj_dict["id"] = self.object.id

                inner_action_dict["Actor"] = actor_dict
                inner_action_dict["Action"] = inner_action_name
                if i == len(self.action.action_components) - 1:
                    if self.next_event == None:
                        inner_action_dict["Next"] = "None"
                    else:
                        if self.next_event.action.action_type == "complex":
                            inner_action_dict["Next"] = self.next_event.action.id+"_inner0"
                        else:
                            inner_action_dict["Next"] = self.next_event.action.id

                else:
                    inner_action_dict["Next"] = inner_actions_ids[i+1]
                inner_action_dict["id"] = inner_actions_ids[i]
                inner_action_dict["Target"] = obj_dict
                inner_action_dict["Location"] = self.room.name
                action_dicts.append((inner_actions_ids[i], inner_action_dict))
            return action_dicts
        else:
            action_dict = {}
            actor_dict = {}
            actor_dict["id"] = self.actor.id
            
            obj_dict = {}        
            obj_dict["id"] = self.object.id

            action_dict["Actor"] = actor_dict
            action_dict["Action"] = self.action.name
            if self.next_event == None:
                action_dict["Next"] = "None"
            else:
                if self.next_event.action.action_type == "complex":
                    action_dict["Next"] = self.next_event.action.id+"_inner0"
                else:
                    action_dict["Next"] = self.next_event.action.id
            
            action_dict["id"] = self.action.id
            action_dict["Target"] = obj_dict
            action_dict["Location"] = self.room.name

        return action_dict
