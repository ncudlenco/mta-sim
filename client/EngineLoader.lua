addEventHandler ( "onClientResourceStart", resourceRoot,
	function ()
		local txd = EngineTXD("files/data/LaptopSAMP1.txd") --loads the laptop object
		local res = txd:import(7187); -- impot to model ID 19893 to 7187

		local dff = EngineDFF("files/data/LaptopSAMP1.dff")
        res = dff:replace(7187)
        
        dff = engineLoadDFF("files/data/LaptopSAMP2.dff")
		res = dff:replace(7188)
		
		-- replace food/drinks with military objects - https://dev.prineside.com/en/gtasa_samp_model_id/tag/131-military-equipment/
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

		local txd = EngineTXD("files/data/SAMPFruits.txd")
		local res = txd:import(3082)
		local dff = EngineDFF("files/data/Banana1.dff")
		local res = dff:replace(3082)

		local txd = EngineTXD("files/data/cj_ss_1.txd")
		local res = txd:import(3113)
		local dff = EngineDFF("files/data/JuiceBox2.dff")
		local res = dff:replace(3113)

		local txd = EngineTXD("files/data/cj_ss_1.txd")
		local res = txd:import(3788)
		local dff = EngineDFF("files/data/JuiceBox1.dff")
		local res = dff:replace(3788)

		local txd = EngineTXD("files/data/cj_ss_2.txd")
		local res = txd:import(3789)
		local dff = EngineDFF("files/data/MilkCarton1.dff")
		local res = dff:replace(3789)

		local txd = EngineTXD("files/data/d_s.txd")
		local res = txd:import(3013)
		local dff = EngineDFF("files/data/CoffeeCup1.dff")
		local res = dff:replace(3013)

		local txd = EngineTXD("files/data/cj_ss_2.txd")
		local res = txd:import(3016)
		local dff = EngineDFF("files/data/MilkBottle1.dff")
		local res = dff:replace(3016)

		-- replace drinks with icons models (house, heart, start etc.)
		local txd = EngineTXD("files/data/lee_strip2_1.txd")
		local res = txd:import(1239)
		local dff = EngineDFF("files/data/AlcoholBottle1.dff")
		local res = dff:replace(1239)

		local txd = EngineTXD("files/data/lee_strip2_1.txd")
		local res = txd:import(1240)
		local dff = EngineDFF("files/data/AlcoholBottle2.dff")
		local res = dff:replace(1240)

		local txd = EngineTXD("files/data/lee_strip2_1.txd")
		local res = txd:import(1241)
		local dff = EngineDFF("files/data/AlcoholBottle3.dff")
		local res = dff:replace(1241)

		local txd = EngineTXD("files/data/lee_strip2_1.txd")
		local res = txd:import(1247)
		local dff = EngineDFF("files/data/AlcoholBottle4.dff")
		local res = dff:replace(1247)

		local txd = EngineTXD("files/data/lee_strip2_1.txd")
		local res = txd:import(1254)
		local dff = EngineDFF("files/data/AlcoholBottle5.dff")
		local res = dff:replace(1254)

		local txd = EngineTXD("files/data/lee_strip2_1.txd")
		local res = txd:import(1253)
		local dff = EngineDFF("files/data/WineGlass1.dff")
		local res = dff:replace(1253)

		local txd = EngineTXD("files/data/lee_strip2_1.txd")
		local res = txd:import(1248)
		local dff = EngineDFF("files/data/CocktailGlass1.dff")
		local res = dff:replace(1248)
	end
);