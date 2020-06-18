addEventHandler ( "onClientResourceStart", resourceRoot,
	function ()
		local txd = EngineTXD("files/data/LaptopSAMP1.txd") --loads the laptop object
		local res = txd:import(7187); -- impot to model ID 19893 to 7187

		local dff = EngineDFF("files/data/LaptopSAMP1.dff")
        res = dff:replace(7187)
        
        dff = engineLoadDFF("files/data/LaptopSAMP2.dff")
        res = dff:replace(7188)
	end
);