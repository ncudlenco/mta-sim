from re import sub
from Objects import find_obj_by_name
import sys
from spacy import displacy
import spacy
import os
from collections import Counter
import Actor
import Event
from Objects import Object
import Objects
from Actions import Action
import Rooms
from Rooms import Room
from main import get_actors_from_story, get_objects_from_story, generate_graph, get_last_actor_location, get_syncs_from_story
import json
import copy


empty_room = Rooms.get_room_list()[-1]
OBJECTS = Objects.get_obj_list()

convert_entities_for_video = True


# change with first in entry
moving_actions = ["Move", "went", "travelled", "journeyed", "moved", "went back"]
picking_actions = ["PickUp", "grabbed there", "got there", "took", "took there", "picked there", "picked up", "got", "grabbed"]
# TODO: handle dropping with another action
discarding_actions = ["PutDown", "discarded", "put down", "dropped", "dropped there", "put there", "left there", "discarded there", "left"]

# change objects
objects_converted = {"milk": "Drinks", "football": "Food", "apple": "Remote"}

read_from = "babi" # "babi_corpus-train/valid/test"
babi_folder = "en-valid"

considered_indexes = [1,2,3,5,6,7,8,9]
considered_indexes = [12]

# 11 coreference
# 13 (and/or) + coreference
# 14 is not done! temporal ordering!

# intermediate function
def get_last_actor_location_parsed(story, actor_name):
    loc = get_last_actor_location(story, actor_name)
    return loc

# use this function to determine location of actor
# def compute_location_for_actor(story, actor_name):


def extract_stories(lines):

    stories = []
    crt_story = []

    for line in lines:
        line_index = int(line.split(" ")[0])
        line_story = line[len(str(line_index))+1:]
        if line_index == 1:
            if crt_story != []:
                story = [crt_story]
                stories.append(story)
                crt_story = []
        # ignore questions for the moment
        if "?" in line_story:
            continue
        crt_story.append(line_story)

    return stories


def parse_line(line, nlp):
    doc = nlp(line)

    subj = None
    obj = None
    aobj = None
    loc = None
    advmod = None
    time = None

    root_token = list(doc.sents)[0].root

    for child in root_token.children:
        if child.dep_ == 'nsubj':
            subj = child
        if child.dep_ == 'dobj':
            obj = child
        
        # for "north of X"
        if child.dep_ == 'attr' or child.dep_ == "acomp":
            for prep in child.children:
                if prep.dep_ == 'prep':
                    # get prep
                    for o in prep.children:
                        if o.dep_ == 'pobj':
                            # get obj
                            loc = child.text + " " + prep.text
                            obj = o

        # how about advmod?
        if child.dep_ == "advmod":
            advmod = child

        # for giving to
        if (child.dep_ == "dative" or child.dep_ == "prep") and child.text != "in":
            for p in child.children:
                if p.dep_ == "pobj":
                    aobj = p


    if advmod != None:
        # hack for longer
        # if advmod.text == "longer":
        #     new_root_token = advmod#root_token
        # else:
        new_root_token = advmod
    else:
        new_root_token = root_token

    # search for location
    if obj == None:
        for child in new_root_token.children:
            if child.dep_ == "prep" and (child.text == "to" or child.text == "in"):
                loc = list(child.children)[0].text

    # search for timeframe
    for child in root_token.children:
        if child.dep_ == "npadvmod":
            time = child.text
            if len(list(child.children)) > 0 and list(child.children)[0].dep_ == "det":
                time = list(child.children)[0].text + " " + time

    # check if multiple
    multiple_actors = False
    for child in subj.children:
        if child.dep_ == "cc" and (child.text == "and" or child.text == "or"):
            for searched in subj.children:
                if searched.dep_ == "conj":
                    multiple_actors = True
                    actor = [subj.text+"-"+child.text.upper(), searched.text+"-"+child.text.upper()]

    if multiple_actors == False:            
        actor = [subj.text]

    # TODO: how to handle ACTOR1 and/or ACTOR2 do something; multiple events linked by and/or?
    # print(subj, subj.pos_)
    # actor = subj.text
    action = root_token.text
    object = None
    location = None
    timeframe = None

    if obj != None:
        object = obj.text
    
    if loc != None:
        location = loc.lower()

    if time != None:
        timeframe = time.lower()
    
    for child in new_root_token.children:
        # print(new_root_token, child, child.dep_)
        if child.dep_ == "prt":
            action += " " + child.text
        if child.dep_ == "neg":
            action = "NOT " + action
    
    # how about advmod?
    if advmod != None:
        action += " " + advmod.text
    
    entities = actor
    if object != None:
        entities.append(object)
    if aobj != None and aobj.text != loc:
        entities.append(aobj.text)
    
    # print(line)
    # print(action, entities, location, "|", timeframe)
    # print(root_token, new_root_token)
    # print()
    # displacy.serve(doc, style='dep')
    # sys.exit()
    if convert_entities_for_video == True:
        if action in moving_actions:
            action = moving_actions[0]
        if action in picking_actions:
            action = picking_actions[0]
        if action in discarding_actions:
            action = discarding_actions[0]

        # print(entities)
        for i in range(len(entities)):
            if entities[i] in objects_converted:
                entities[i] = objects_converted[entities[i]]
        # print(entities)
        # sys.exit()

    # print(line, action, entities, location)   
    return action, entities, location, timeframe


def add_storyline(story, line):
    actors = get_actors_from_story(story)
    # print("ACTORS = ", actors)

    objects = get_objects_from_story(story)
    # print("OBJECTS =", objects, line)

    crt_syncs = get_syncs_from_story(story)
    # print("crt_parse", crt_syncs)

    action, entities, location, timeframe = line
    # TODO: handle multiple actors/objects in one line!
    # find actors in entities
    aux_actors = []
    k = 0

    multiple_actors_logical = False

    for entity in entities:
        if "-AND" in entity:
            multiple_actors_logical = True
            entity = entity[:-len("-AND")]
        if find_obj_by_name(entity, OBJECTS) == -1:
            index = Actor.find_actor_by_name(entity, actors)
            if index != -1:
                actor = actors[index]
                aux_actors.append(actor)
                k += 1
            else:
                if entity == "John" or entity == "Daniel" or entity == "Fred" or entity == "Jeff" or entity == "Bill":
                    actor_sex = 1
                elif entity == "Sandra" or entity == "Mary" or entity == "Julie":
                    actor_sex = 2
                else:
                    print("{0} neither male or female on current rules", entity)
                    sys.exit()
                actor = Actor.Actor("actor{0}".format(len(actors)+len(aux_actors)-k), actor_sex, entity)
                aux_actors.append(actor)
    
    # find objects in entities
    obj = Object("EmptyObject")
    aux_objs = []

    for entity in entities:
        if find_obj_by_name(entity, OBJECTS) != -1:
            index = Objects.find_obj_by_name(entity, objects)
            if index != -1:
                obj = objects[index]
                aux_objs.append(obj)
            else:
                obj = Object(entity)
                aux_objs.append(obj)

    actor = aux_actors[0]
    act = Action(action)
    if location == None:
        loc = get_last_actor_location_parsed(story, actor.name)
        if loc == None:
            loc = empty_room
    else:
        loc = get_last_actor_location_parsed(story, actor.name)
        if loc != None and loc != empty_room and (act.name == "Move"):
            loc = [Room(loc.name), Room(location)]
        else:
            loc = [empty_room, Room(location)]
            

    if not (isinstance(loc, list)):
        loc = [loc]

    if len(aux_actors) > 1 and multiple_actors_logical == False:
        if len(aux_actors) != 2:
            print("ACTION WITH MORE THAN 2 ACTORS!", act, obj, aux_actors, loc)
            sys.exit()
        # we have multiagent action
        act = Action(action, multiagent=True)

        act1 = copy.deepcopy(act)
        act2 = copy.deepcopy(act)
        act2.name = "INV-{0}".format(act2.name)
    
        e1 = Event.Event("event{0}".format(len(story)), act1, obj, aux_actors, loc, timeframe)
        story.append(e1)
        e2 = Event.Event("event{0}".format(len(story)), act2, obj, aux_actors[::-1], loc, timeframe)
        story.append(e2)

        e1.add_sync_event(e2, "starts_with", "tm{0}".format(crt_syncs))
        e2.add_sync_event(e1, "starts_with", "tm{0}".format(crt_syncs))

    if len(aux_actors) > 1 and multiple_actors_logical == True:

        act = Action(action, multiagent=True)

        act1 = copy.deepcopy(act)
        act2 = copy.deepcopy(act)



        if location == None:
            loc2 = get_last_actor_location_parsed(story, aux_actors[1].name)
            if loc2 == None:
                loc2 = empty_room
        else:
            loc2 = get_last_actor_location_parsed(story, aux_actors[1].name)
            if loc2 != None and loc2 != empty_room and (act.name == "Move"):
                loc2 = [Room(loc2.name), Room(location)]
            else:
                loc2 = [empty_room, Room(location)]

        e1 = Event.Event("event{0}".format(len(story)), act1, obj, [aux_actors[0]], loc, timeframe)
        story.append(e1)
        e2 = Event.Event("event{0}".format(len(story)), act2, obj, [aux_actors[1]], loc2, timeframe)
        story.append(e2)

        e1.add_sync_event(e2, "starts_with", "tm{0}".format(crt_syncs))
        e2.add_sync_event(e1, "starts_with", "tm{0}".format(crt_syncs))


    else:
        e = Event.Event("event{0}".format(len(story)), act, obj, aux_actors, loc, timeframe)
        story.append(e)


    return story, location
    

if __name__ == "__main__":

    nlp = spacy.load("en_core_web_sm")

    
    if read_from == "babi":
        lines = []
        folder = "babi/tasks_1-20_v1-2/{0}/".format(babi_folder)
        files = [os.path.join(folder, x) for x in os.listdir(folder)]
        searched = ["qa{0}_".format(x) for x in considered_indexes]
        files = [f for f in files if any(xs in f for xs in searched)]
        for file in files:
            with open(file, "r") as f:
                crt_lines = f.readlines()
            lines.extend(crt_lines)
        lines = list(map(lambda x: x.strip(), lines))
        stories = extract_stories(lines)

    elif read_from == "test":
        with open("story.txt", "r") as f:
            lines = f.readlines()

        lines = list(map(lambda x: " ".join(x.split(" ")[1:]), lines))
        lines = list(map(lambda x: x.strip(), lines))
        lines = lines[:3]

        # filter out questiosns for the moment
        lines = list(filter(lambda x: "?" not in x, lines))
        stories = [[lines]]

    elif "babi_corpus" in read_from:
        lines = []
        folder = "babi/tasks_1-20_v1-2/{0}/".format(babi_folder)
        files = [os.path.join(folder, x) for x in os.listdir(folder)]
        searched = ["qa{0}_".format(considered_indexes[0])]
        files = [f for f in files if any(xs in f for xs in searched)]
        if "train" in read_from:
            index = 1
        elif "valid" in read_from:
            index = 2
        elif "test" in read_from:
            index = 0
        
        file = files[index]
        with open(file, "r") as f:
            crt_lines = f.readlines()
            lines.extend(crt_lines)
    
        lines = list(map(lambda x: x.strip(), lines))
        stories = extract_stories(lines)

    print(len(stories))
    all_locations = []
    all_actors = []
    all_events = []
    all_lines = 0
        
    graph_stories = []
    for story_index, story in enumerate(stories):
        graph_story = []
        for line in story[0]:
            all_lines += 1
            action, entities, location, timeframe = parse_line(line, nlp)
            graph_story, location = add_storyline(graph_story, [action, entities, location, timeframe])
            
            all_events.append(action)
            all_actors.extend(entities)

            if location != None:
                all_locations.append(location)
            else:
                all_locations.append("None")
        
        graph_dict = generate_graph(graph_story)
        if read_from == "babi":
            json.dump(graph_dict, open("samples_babi/example_graph{0}".format(considered_indexes[0]), "w"), sort_keys=False, indent = 4)
            sys.exit()

        elif read_from == "test":
            json.dump(graph_dict, open("samples_babi/0", "w"), sort_keys=False, indent = 4)
            sys.exit()

        elif "babi_corpus" in read_from:
            json.dump(graph_dict, open("samples_babi/task{0}/{1}/{2}".format(considered_indexes[0], read_from[len("babi_corpus-"):], story_index), "w"), sort_keys=False, indent=4)
            # sys.exit()


        

    print(len(all_events), len(all_actors), len(all_locations), all_lines)
    print(Counter(all_events))
    print(Counter(all_actors))
    print(Counter(all_locations))


