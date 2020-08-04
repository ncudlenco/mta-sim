MusicPlayer = class(SampStoryObjectBase, function(o, params)
    params.description = "the music player"
    params.type = 'MusicPlayer'

    SampStoryObjectBase.init(o, params)
end
)

MusicPlayer.eModel = {
    Unknown01 = 2225
}