MusicPlayer = class(SampStoryObjectBase, function(o, params)
    params.description = "the music player"
    SampStoryObjectBase.init(o, params)
end
)

MusicPlayer.eModel = {
    Unknown01 = 2225
}