Generator = class(function(o, params)
    for i, key in params do
        o.key = params.key
    end
end)
--Graph generator without running the game simulation
function Generator.getOne()
    --I should first generate a graph of events
    --an event is defined by an action perfomed by an actor
        --in a location
        --with an object / other actor
    --RANDOMLY GENERATED GRAPHS

    --note: this is just like running random simulations but instead of executing actions I will just add nodes in a graph
    --Algorithm:
    --choose a random episode
    --internally create players with random names in random locations
    --from those locations select random actions for players
    --when first executing an action, create the exists nodes for the actor performing the action
    --when executing an action, create nodes for the actions performed
    --voila -> graph
end