MobilePhone = class(SampStoryObjectBase, function(o, params)
    params.description = "mobile phone"
    params.pluralTemplate = "{count} mobile phones"
    params.type = 'MobilePhone'

    SampStoryObjectBase.init(o, params)

    o:updatePositionOffsetStandUp()
    o:updateRotOffsetStandUp()
end
)

function MobilePhone:updatePositionOffsetStandUp()
    if self.modelid == MobilePhone.eModel.MobilePhone1 then
        self.PosOffset = Vector3(0.02999996580183506, 0, -0.009999999776482582)
    end

    return self.Description
end

function MobilePhone:updateRotOffsetStandUp()
    if self.modelid == MobilePhone.eModel.MobilePhone1 then
        self.RotOffset = Vector3(0, 273, 0)
    end

    return self.Description
end

MobilePhone.eModel = 
{
    MobilePhone1 = 330
}