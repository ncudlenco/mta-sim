from re import sub
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
from main import get_actors_from_story, get_objects_from_story, generate_graph, get_last_actor_location
import json

empty_room = Rooms.get_room_list()[-1]


read_from = "babi"
babi_folder = "en-valid"

considered_indexes = [1,2,3,5,6,7,8,9]
considered_indexes = [1,2,3,6,8,9]
considered_indexes = [9]

# 5 and 7 have multiple actors
# milk -> drinks
# football -> food
# apple -> food

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

    actor = subj.text            
    action = root_token.text
    object = None
    location = None
    if obj != None:
        object = obj.text
    
    if loc != None:
        location = loc
    
    for child in new_root_token.children:
        # print(new_root_token, child, child.dep_)
        if child.dep_ == "prt":
            action += " " + child.text
        if child.dep_ == "neg":
            action = "NOT " + action
    
    # how about advmod?
    if advmod != None:
        action += " " + advmod.text
    
    entities = [actor]
    if object != None:
        entities.append(object)
    if aobj != None and aobj.text != loc:
        entities.append(aobj.text)
    
    # print(line)
    # print(action, entities, location)
    # print()
    # displacy.serve(doc, style='dep')
    return action, entities, location

def add_storyline(story, line):
    actors = get_actors_from_story(story)
    # print("ACTORS = ", actors)

    objects = get_objects_from_story(story)
    # print("OBJECTS =", objects)

    action, entities, location = line
    # TODO: handle multiple actors/objects
    # find actors in entities
    for entity in entities:
        if entity[0].isupper():
            index = Actor.find_actor_by_name(entity, actors)
            if index != -1:
                actor = actors[index]
            else:
                # TODO: handle sex here
                if entity == "John" or entity == "Daniel":
                    actor_sex = 1
                elif entity == "Sandra" or entity == "Mary":
                    actor_sex = 2
                else:
                    print("{0} neither male of female on current rules", entity)
                    sys.exit()
                actor = Actor.Actor("actor{0}".format(len(actors)), actor_sex, entity)
    
    # find objects in entities
    obj = Object("EmptyObject")
    for entity in entities:
        if entity[0].islower():
            index = Objects.find_obj_by_name(entity, objects)
            if index != -1:
                obj = objects[index]
            else:
                obj = Object(entity)

    # print(actor)
    # print(obj)
    act = Action(action)
    if location == None:
        loc = get_last_actor_location(story, actor.name)
        if loc == None:
            loc = empty_room
    else:
        loc = Room(location)

    e = Event.Event("event{0}".format(len(story)), act, obj, actor, loc)
    # print(e)
    story.append(e)
    # print() 
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
        lines = lines[:2]

        # filter out questions for the moment
        lines = list(filter(lambda x: "?" not in x, lines))
        stories = [[lines]]
    

    print(len(stories))
    all_locations = []
    all_actors = []
    all_events = []
    all_lines = 0

    
    graph_stories = []
    
    for story in stories:
        graph_story = []
        for line in story[0]:
            all_lines += 1
            # print(line)
            action, entities, location = parse_line(line, nlp)
            # print("Event: {0}. Involved entities: {1}. Location: {2}".format(action, entities, location))
            graph_story, location = add_storyline(graph_story, [action, entities, location])

            
            
            all_events.append(action)
            all_actors.extend(entities)
            if len(entities) > 2:
                print(line, action, entities, location)
                sys.exit()
            if location != None:
                all_locations.append(location)
            else:
                all_locations.append("None")
        
        # print()
        # print(graph_story)
        print(story)
        graph_dict = generate_graph(graph_story)
        json.dump(graph_dict, open("samples_babi/example_graph{0}".format(considered_indexes[0]), "w"), sort_keys=False, indent = 4)

        sys.exit()


    print(len(all_events), len(all_actors), len(all_locations), all_lines)
    print(Counter(all_events))
    print(Counter(all_actors))
    print(Counter(all_locations))
