addEventHandler ( "onClientResourceStart", resourceRoot,
	function ()
		local txd = EngineTXD("files/data/LaptopSAMP1.txd") --loads the laptop object
		local res = txd:import(7187); -- impot to model ID 19893 to 7187

		local dff = EngineDFF("files/data/LaptopSAMP1.dff")
        res = dff:replace(7187)
        
        dff = engineLoadDFF("files/data/LaptopSAMP2.dff")
		res = dff:replace(7188)
		
		-- replace food with military objects - https://dev.prineside.com/en/gtasa_samp_model_id/tag/131-military-equipment/
		local txd = EngineTXD("files/data/SAMPFruits.txd")
		local res = txd:import(1252)

		local dff = engineLoadDFF("files/data/Apple1.dff")
		local res = dff:replace(1252)

		local txd = EngineTXD("files/data/SAMPFruits.txd")
		local res = txd:import(2036)
		
		local dff = EngineDFF("files/data/Apple2.dff")
		local res = dff:replace(2036)
		
		local txd = EngineTXD("files/data/MarcosStuff1.txd")
		local res = txd:import(2040)
		
		local dff = EngineDFF("files/data/MCakeSlice1.dff")
        local res = dff:replace(2040)
	end
);