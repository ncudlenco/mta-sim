MusicPlayer = class(SampStoryObjectBase, function(o, params)
    params.description = "music player"
    params.pluralTemplate = "{count} music players"
    params.type = 'MusicPlayer'

    SampStoryObjectBase.init(o, params)
end
)

MusicPlayer.eModel = {
    Unknown01 = 2225
}