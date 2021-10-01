class Actor:

    def __init__(self, id, gender=None, name=None):
        self.id = id
        self.gender = gender
        self.name = name

    def __str__(self):
        return "(Actor " + self.id + ", " +  str(self.gender) + ", " + str(self.name) + ")"

    def __repr__(self):
        return self.__str__()

    def generate_node(self):

        outer_dict = {}
        actor_dict = {}
        actor_dict["id"] = self.id
        actor_dict["Gender"] = self.gender
        actor_dict["Name"] = self.name
        

        outer_dict["Actor"] = actor_dict
        outer_dict["Action"] = "Exists"
        outer_dict["id"] = self.id
        return outer_dict

def find_actor_by_name(actor_name, actors):
    for index, actor in enumerate(actors):
        if actor_name == actor.name:
            return index
    return -1
