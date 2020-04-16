using System;
using System.Collections.Generic;
using System.Text;

namespace SyntheticVideo2language.Story.Api
{
    public interface IStoryActor : IStoryItem
    {
        //Nothing specific to add here yet. Consider adding a list of special actions which can all be performed during multiple transitions while also performing other simple actions.
        //Ex. The actor is in the kitchen. He picks up his phone. He lights up a cigaret. He goes to the living room. He smokes. He sits on the sofa. He smokes. He hangs up the phone.
        //He throws out the cigaret. All the actions whith the cigaret and the phone are valid at any location / time if they are initiated. Other simple actions might
        //not be valid while the special actions are active. (ex: can't swim while smoking, can't swim while talking on the phone.)
        //**Note: I haven't tested in SAMP if the player is able to do all these things at the same time.
    }
}
