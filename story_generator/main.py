import sys
import random
import copy
import Objects
import Actions
import Rooms
import json
import Actor
import Event
import networkx as nx
import matplotlib.pyplot as plt

MIN_OBJECTS = 1
MAX_OBJECTS = 3
ACTORS = 3
MIN_SYNC_EVENTS = 1
MAX_SYNC_EVENTS = 2


objects = Objects.get_obj_list()
actions = Actions.get_action_list()
rooms   = Rooms.get_room_list()[:-1]
empty_room = Rooms.get_room_list()[-1]

Rooms.associate_objects_to_rooms(rooms, objects)
# Objects.associate_actions_to_objects(objects, actions)
actions = Actions.associate_objects_to_actions(actions, objects)

def order_events(story):
    actors = get_actors_from_story(story)
    last_action_for_actor = [None for x in range(len(actors))]
    for i in range(len(story)):
        if i == len(story) - 1:
            # LAST ACTION
            actor_index = actors.index(story[i].actor)
            if last_action_for_actor[actor_index] != None:
                last_action_for_actor[actor_index].next_event = story[i]
            break
        if story[i].actor.id == story[i+1].actor.id:
            # SAME ACTOR FOR CONSECUTIVE ACTIONS
            actor_index = actors.index(story[i].actor)
            if last_action_for_actor[actor_index] != None:
                last_action_for_actor[actor_index].next_event = story[i]
            last_action_for_actor[actor_index]= story[i]
            story[i].next_event = story[i+1]
        else:
            # DIFFERENT ACTORS FOR CONSECUTIVE ACTIONS
            actor_index = actors.index(story[i].actor)
            if last_action_for_actor[actor_index] != None:
                last_action_for_actor[actor_index].next_event = story[i]
            last_action_for_actor[actor_index] = story[i]
    
    timeline = [[] for _ in range(len(actors))]
    init_found = 0
    while init_found < len(actors):
        for event in story:
            if timeline[int(event.actor.id[len("actor"):])] == []:
                init_found += 1
                timeline[int(event.actor.id[len("actor"):])] = [event]

    for t in timeline:
        crt_event = t[0]
        while True:
            next_event = crt_event.next_event
            if next_event == None:
                break
            t.append(next_event)
            crt_event = next_event

    syncs = random.randint(MIN_SYNC_EVENTS, MAX_SYNC_EVENTS)
    print("SYNCS =", syncs)
    tid = 0
    for _ in range(syncs):
        sync_type = random.choice(["starts_with", "ends_with"])
        # so far we treated actions with different actors independently
        # select two random actors
        r_actors = random.sample(actors, 2)
        a1i = actors.index(r_actors[0])
        a2i = actors.index(r_actors[1])


        # select a pair of actions to sync
        tries = 0
        while True:
            act1 = random.choice(timeline[a1i])
            act2 = random.choice(timeline[a2i])
            if len(act1.sync_events) == 1 or len(act2.sync_events) == 1:
                tries += 1
                if tries == 100:
                    print("Already tried 100 times to select action")
                    sys.exit()
                continue

            if act1.room == act2.room or act1.room.name == "" or act2.room.name == "":
                print("--------------")
                print(act1)
                print(act2)
                print(sync_type)
                act1.add_sync_event(act2, sync_type, "t{0}".format(tid))
                act2.add_sync_event(act1, sync_type, "t{0}".format(tid))
                tid += 1
                break

    return timeline


def get_objects_from_story(story):
    objects = []
    for event in story:
        if type(event.object) == list:
            # complex object
            objs = []
            for act in event.action.action_components:
                objs.append(act.targets)
            objects.extend(list(set(objs)))
        else:
            objects.append(event.object)
    return objects


def get_actors_from_story(story):

    actors = []
    for event in story:
        actors.append(event.actor)
    
    actors = list(set(actors))
    return actors


def generate_story():
    # rooms = [Kitchen, Living, BathRoom, BedRoom, Gym]
    events = []
    actors = []
    total_crt_events_per_actor = []
    crt_events_per_actor = []

    # create actors
    for actor_id in range(ACTORS):
        actor_sex = random.choice([1,2])
        actor = Actor.Actor("actor{0}".format(actor_id), actor_sex, "NAME")
        actors.append(actor)
        count_objs = random.randint(MIN_OBJECTS, MAX_OBJECTS)
        total_crt_events_per_actor.append(count_objs)
        crt_events_per_actor.append(0)
    
    print("Actions per actor:", total_crt_events_per_actor)

    total_events = sum(total_crt_events_per_actor)
    while len(events) < total_events:    

        # pick a room each time for the moment
        r_room = random.choice(rooms)

        for actor_index, actor in enumerate(actors):
            # if we have enough events for current actor just pass
            if crt_events_per_actor[actor_index] == total_crt_events_per_actor[actor_index]:
                continue
            
            # pick an action in the givem room
            possible_actions = Actions.filter_actions_by_rooms(actions, r_room)
            r_act = random.choice(possible_actions)

            r_new_act = copy.deepcopy(r_act)

            r_new_obj = copy.deepcopy(r_act.targets)
            if r_new_act.name == "TalkAtPhone" or r_new_act.name == "SmokeCigarette":
                e = Event.Event("event{0}".format(len(events)), r_new_act, r_new_obj, actor, empty_room)
            else:
                e = Event.Event("event{0}".format(len(events)), r_new_act, r_new_obj, actor, r_room)
            events.append(e)
            crt_events_per_actor[actor_index] += 1
 
    return events


def visualize_graph(graph, save=False):
    # G = nx.Graph()
    G = nx.DiGraph()

    for k, v in graph.items():
        # exists nodes
        if "actor" in k:
            G.add_node(k, det = "{0}".format(k), shape="o", type="actor")
        if "object" in k:
            G.add_node(k, det = "{0}".format(v["Target"]["Name"]), shape="o", type="object")

        if "action" in k:
            G.add_node(k, det = "{0}".format(v["Action"]), shape="s", type="action")

    for k, v in graph.items():
        if "action" in k:
            G.add_edge(k, v["Actor"]["id"], color='r', type="actor")
            G.add_edge(k, v["Target"]["id"], color='b', type="object")
            if v["Next"] != "None":
                G.add_edge(k, v["Next"], color='g', type="action")

    nodePos = nx.layout.spring_layout(G, k = 0.99)
    nodeShapes = set((aShape[1]["shape"] for aShape in G.nodes(data = True)))
    node_shapes = nx.get_node_attributes(G, 'shape')
    node_labels = nx.get_node_attributes(G, 'det')
    node_sizes = {'actor': 750, 'object': 500, 'action': 1000}
    for shape in nodeShapes:
        nodes_with_shape = dict(filter(lambda x: x[1] == shape, nx.get_node_attributes(G, 'shape').items()))
        nodelist = list(map(lambda x: x[0], nodes_with_shape.items()))
        sizes = [node_sizes[nx.get_node_attributes(G, 'type')[x]] for x in nodelist] 
        labels = {x:node_labels[x] for x in nodelist}
        nx.draw_networkx_nodes(G, nodePos, node_shape=shape, nodelist=nodelist, node_size=sizes, node_color="green")
        nx.draw_networkx_labels(G, nodePos, labels)

    colors = nx.get_edge_attributes(G,'color')
    arrows = {"actor": False, "object": False, "action": True}
    edge_colors = {"actor": 'r', "object": 'b', "action": 'g'}
    edges = G.edges(data=True)
    edgesTypes = set((edge[2]["type"] for edge in G.edges(data = True)))
    for edgeType in edgesTypes:
        edges_with_type = dict(filter(lambda x: x[1] == edgeType, nx.get_edge_attributes(G, 'type').items()))
        nx.draw_networkx_edges(G, nodePos, edgelist=edges_with_type, arrows=arrows[edgeType], edge_color=edge_colors[edgeType], arrowsize=35)
    
    if save == False:
        plt.show()
    else:
        plt.savefig(save)
        plt.clf()


def generate_graph(story):
    graph_dict = {}

    # generate nodes for actors    
    actors = get_actors_from_story(story)
    for actor in actors:
        d = actor.generate_node()
        graph_dict[actor.id] = d

    # generate nodes for objects
    objects = get_objects_from_story(story)
    for i, object in enumerate(objects):
        object_id = "object{0}".format(i)
        # what to to with 
        object.set_id(object_id)
        d = object.generate_node()
        graph_dict[object.id] = d


    for i, event in enumerate(story):
        # what to do with same action multiple times? talk at same phone? smoke same cigarette?
        # currently this is handled by giving new id to each action from copy.deepcopy in story generation
        action_id = "action{0}".format(i)
        event.action.set_id(action_id)
    
    # apply temporal logic
    abs_timeline = order_events(story)
    timeline = [[] for _ in range(len(abs_timeline))]

    for ti, time in enumerate(abs_timeline):
        aux_time = []
        for event in time:
            if event.action.action_type == "complex":
                a = [("{0}_inner{1}".format(event.action.id, i),x) for i,x in enumerate(event.action.action_components)]
                aux_time.extend(a)
            else:
                aux_time.append((event.action.id, event.action))
        timeline[ti] = aux_time
    # for ti, t in enumerate(abs_timeline):
    #     print(t)
    #     abs_timeline[ti] = list(map(lambda x: (x.action.id, x.action.name), t))
    #     print(abs_timeline[ti])
    #     sys.exit()
    
    for ti, t in enumerate(timeline):
        timeline[ti] = list(map(lambda x: (x[0], x[1].name), t))

    for event in story:
        d = event.generate_node()
        if type(d) == list:
            for innner_action_id, inner_dict in d:
                graph_dict[innner_action_id] = inner_dict
        else:
            graph_dict[event.action.id] = d
    
    # write timelines
    auxda = {}
    auxd = {}
    for ti, t in enumerate(timeline):
        auxd["actor{0}".format(ti)] = str(t)
        at = list(map(lambda x: (x.action.id, x.action.name), abs_timeline[ti]))
        auxda["actor{0}".format(ti)] = str(at)

    temporal_dict = {}
    temporal_dict["timeline"] = auxd
    temporal_dict["starting_actions"] = {}
    for ti, t in enumerate(timeline):
        temporal_dict["starting_actions"]["actor{0}".format(ti)] = t[0][0]
        for ati in range(len(t)):
            dd = {}
            dd["relations"] = None

            inner_id = None
            if "inner" in t[ati][0]:
                inner_id = int(t[ati][0].split("inner")[1])
            outer_id = t[ati][0].split("_")[0]
            last_id = None
            # search in crt timeline for last with outer id
            if "inner" in t[ati][0]:
                for x in t:
                    if x[0].split("_")[0] == outer_id:
                        last_id = int(x[0].split("inner")[1])
            searched_ev = None
            for ev in abs_timeline[ti]:
                if ev.action.id == outer_id:
                    searched_ev = ev
                    break
            if searched_ev == None:
                print("Not found ev")
                sys.exit()
            # print(searched_ev)
            if len(searched_ev.sync_events) > 0:
                if dd["relations"] == None:
                    dd["relations"] = []
        
                for sync_ev, sync_type, sync_id in searched_ev.sync_events:
                    print(sync_type, inner_id)
                    if sync_type == "starts_with" and (inner_id != 0 and inner_id != None):
                        break
                    if sync_type == "ends_with" and (inner_id != last_id and inner_id != None):
                        break
                    if sync_id in temporal_dict:
                        print(sync_id, "already in temporal dicta")
                    else:
                        x = {}
                        x["type"] = sync_type
                        temporal_dict[sync_id] = x
                    dd["relations"].append(sync_id)
    
            # dd["id"] = t[ati][0]
            dd["next"] = None
            if ati != len(t) - 1:
                dd["next"] = t[ati+1][0]
            temporal_dict[t[ati][0]] = dd


    temporal_dicta = {}
    temporal_dicta["timeline"] = auxda

    temporal_dicta["starting_actions"] = {}
    for ti, t in enumerate(abs_timeline):
        at = list(map(lambda x: (x.action.id, x.action.name), t))
        temporal_dicta["starting_actions"]["actor{0}".format(ti)] = at[0][0]
        for ati in range(len(at)):
            dd = {}
            dd["relations"] = None
            if len(t[ati].sync_events) > 0:
                if dd["relations"] == None:
                    dd["relations"] = []
                for sync_ev, sync_type, sync_id in t[ati].sync_events:
                    # create new node if needed
                    if sync_id in temporal_dicta:
                        print(sync_id, "already in temporal dicta")
                    else:
                        x = {}
                        x["type"] = sync_type
                        temporal_dicta[sync_id] = x
                    dd["relations"].append(sync_id)
            dd["next"] = None
            if ati != len(at) - 1:
                dd["next"] = at[ati+1][0]
            temporal_dicta[at[ati][0]] = dd

    graph_dict["temporal"] = temporal_dict
    graph_dict["temporal_abs"] = temporal_dicta

    print()
    print(abs_timeline)
    print(timeline)
    return graph_dict


def get_abstract_graph(graph):
    # print(json.dumps(graph, sort_keys = False, indent = 4))
    abstract_graph = {}
    crt_action_id = -1
    acts = []
    full_actions = []

    for k, v in graph.items():
        # print(k)

        if "actor" in k or "object" in k:
            abstract_graph[k] = v

        elif "_inner" in k:
            # print("---inner", v["Action"])
            big_action_id = int(k[len("action"):].split("_")[0])
            actor_id = int(v["Actor"]["id"][len("actor"):])
            if len(acts) == 0:
                acts.insert(actor_id, 0)
                acts.insert(big_action_id, 0)
            acts.append(v["Action"])
            
            if crt_action_id == -1:
                # set new action
                crt_action_id = big_action_id
                # acts.insert(big_action_id, 0)
                
            elif big_action_id != crt_action_id:
                # new action
                # print("Action so far", acts)
                last = acts.pop()
                full_actions.append(acts)
                # abstract_graph["action{0}".format(acts[0])] = d
                crt_action_id = big_action_id
                acts = [big_action_id, actor_id, last]
            
            
        elif "action" in k:
            if acts != []:
                full_actions.append(acts)
            # print("Action so far", acts)

            # abstract_graph[k] = v
            crt_action_id = int(k[len("action"):])
            actor_id = int(v["Actor"]["id"][len("actor"):])
            acts = [crt_action_id, actor_id, v["Action"]]
            
    if acts != []:
        full_actions.append(acts)
    

    prev_action_actor = []
    # print(full_actions)
    actors = len(set(list(map(lambda x: x[1], full_actions))))
    prev_action_actor = [None for _ in range(actors)]
    prev_key = [None for _ in range(actors)]
    for action_id, action in enumerate(full_actions):
        if len(action) > 3:
            # print(action)
            # complex action
            node = copy.deepcopy(graph["action{}_inner0".format(action[0])])
            node["id"] = "action{0}".format(action[0])
            if action_id == len(full_actions) - 1:
                if prev_action_actor[action[1]] != None:
                    # print("Settting previous at last", prev_action_actor[action[1]])
                    # print(prev_action_actor, prev_key, "action{0}".format(full_actions[action_id][0]))
                    # node["Next"] = "action{0}".format(prev_action_actor[action[1]][0])
                    pr = action[1]
                    abstract_graph[prev_key[pr]]["Next"] = "action{0}".format(full_actions[action_id][0])

                    node["Next"] = "None"
                else:
                    node["Next"] = "None"
                
            else:
                if full_actions[action_id][1] != full_actions[action_id+1][1]:
                    # print("Different actors", full_actions[action_id][1], full_actions[action_id+1][1])
                    # print(prev_action_actor, prev_key, "action{0}".format(full_actions[action_id][0]))
                    if prev_action_actor[action[1]] != None:
                        # print("Settting previous", prev_action_actor[action[1]])
                        pr = action[1]
                        abstract_graph[prev_key[pr]]["Next"] = "action{0}".format(full_actions[action_id][0])
                        # node["Next"] = "action{0}".format(prev_action_actor[action[1]][0])
                        node["Next"] = "None"
                    else:
                        node["Next"] = "None"
                    prev_action_actor[action[1]] = action
                    prev_key[action[1]] = "action{0}".format(action[0])

                else:
                    # print("SAME ACTOR",  full_actions[action_id][1], full_actions[action_id+1][1])
                    # print(prev_action_actor, prev_key, "action{0}".format(full_actions[action_id][0]))
                    pr = action[1]
                    if prev_key[pr] != None:
                        abstract_graph[prev_key[pr]]["Next"] = "action{0}".format(full_actions[action_id][0])
                    prev_action_actor[action[1]] = action
                    prev_key[action[1]] = "action{0}".format(action[0])
                    node["Next"] = "action{0}".format(full_actions[action_id+1][0])
            # print()
            searched_actions = ' '.join(action[2:])
            action_name = None
            for kk, vv in Actions.COMPLEX_ACTIONS.items():
                if vv == searched_actions:
                    action_name = kk
                    break
            if action_name == None:
                print(searched_actions, "not found in list of complex actions")
                sys.exit()
            node["Action"] = action_name
            abstract_graph["action{0}".format(action[0])] = node
            prev_action_actor[action[1]] = action

        else:
            # print("SIMPLE ACTION", action)
            # print()
            node = copy.deepcopy(graph["action{}".format(action[0])])
            pr = action[1]
            if prev_key[pr] != None:
                abstract_graph[prev_key[pr]]["Next"] = "action{0}".format(full_actions[action_id][0])
            prev_action_actor[action[1]] = action
            prev_key[action[1]] = "action{0}".format(action[0])

            if "_inner" in node["Next"]:
                node["Next"] = node["Next"].split("_")[0]
            abstract_graph["action{0}".format(action[0])] = node

    return abstract_graph


def generate_files(samples, folder):
    
    index = 0
    for _ in range(samples):
        story = generate_story()
        graph = generate_graph(story)
        abstract_graph = get_abstract_graph(graph)
        
        json.dump(graph, open("{1}/g{0}".format(index, folder), "w"), sort_keys=False, indent = 4)
        json.dump(abstract_graph, open("{1}/g{0}.a".format(index, folder), "w"), sort_keys=False, indent = 4)

        # visualize_graph(graph)
        visualize_graph(abstract_graph, "{1}/g{0}".format(index, folder))
        index += 1

if __name__ == "__main__":

    print("#objects:", len(objects))
    print("#actions:", len(actions))

    # generate_files(20, "story_generator/samples")
    generate_files(5, "story_generator/samples_test")


    # d = json.load(open("story_generator/samples_test/g0", "r"))
    # # print(d)
    # a = get_abstract_graph(d)
    # json.dump(a, open("story_generator/samples_test/g0.a", "w"), sort_keys=False, indent = 4)


    
    



