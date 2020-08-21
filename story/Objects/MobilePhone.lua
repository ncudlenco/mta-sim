MobilePhone = class(SampStoryObjectBase, function(o, params)
    params.description = "mobile phone"
    params.type = 'MobilePhone'

    SampStoryObjectBase.init(o, params)

    o:updatePositionOffsetStandUp()
    o:updateRotOffsetStandUp()
end
)

function MobilePhone:updatePositionOffsetStandUp()
    if self.modelid == MobilePhone.eModel.MobilePhone1 then
        self.PosOffset = self.PosOffset or Vector3(-0.01999999955296516,-0.009999999776482582,0)
    end

    return self.Description
end

function MobilePhone:updateRotOffsetStandUp()
    if self.modelid == MobilePhone.eModel.MobilePhone1 then
        self.RotOffset = self.RotOffset or Vector3(-90, 0, 0)
    end

    return self.Description
end

MobilePhone.eModel = 
{
    MobilePhone1 = 330
}