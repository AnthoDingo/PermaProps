/*
	PermaProps
	Created by Entoros, June 2010
	Facepunch: http://www.facepunch.com/member.php?u=180808
	Modified By Malboro 28 / 12 / 2012
	
	Ideas:
		Make permaprops cleanup-able
		
	Errors:
		Errors on die

	Remake:
		By Malboro the 28/12/2012
		By Janus   the 12/07/2015 <- adding mysql support, to install mysql http://facepunch.com/showthread.php?t=1220537

	Last Update 14/07/2015 <- Add migration command, server side only

*/

Perma = Perma or {} -- Init table

TOOL.Category		=	"SaveProps"
TOOL.Name			=	"PermaProps"
TOOL.Command		=	nil
TOOL.ConfigName		=	""

if CLIENT then
	language.Add("Tool.permaprops.name", "PermaProps")
	language.Add("Tool.permaprops.desc", "Save a props permanently")
	language.Add("Tool.permaprops.0", "LeftClick: Add RightClick: Remove Reload: Update")
end



function init()
	
	if CLIENT then return end
	
	local querys = 0
	Perma.DoQuery("CREATE TABLE IF NOT EXISTS permaprops(id INT(32) NOT NULL AUTO_INCREMENT, map TEXT NOT NULL, content TEXT NOT NULL, PRIMARY KEY(id));",
		function() querys = querys + 1 end,
		function( q, e )
			MsgN("[PermaPros] -> Init -> Failed to create permaprops table.\n\tReason: " .. q .. ".\n\tQuery: " .. e .. ".")
		end
	)
	CreateConVar( "pp_phys_admin", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE }, "Admin can touch permaprops" )
	CreateConVar( "pp_phys_sadmin", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE }, "Only Super Admin can touch permaprops" )
end

local SpecialENTSSpawn = {}
SpecialENTSSpawn["gmod_lamp"] = function( ent, data)

	ent:SetFlashlightTexture( data["Texture"] )
	ent:SetLightFOV( data["fov"] )
	ent:SetColor( Color( data["r"], data["g"], data["b"], 255 ) )
	ent:SetDistance( data["distance"] )
	ent:SetBrightness( data["brightness"] )
	ent:Switch( true )

	ent:Spawn()

	ent.Texture = data["Texture"]
	ent.KeyDown = data["KeyDown"]
	ent.fov = data["fov"]
	ent.distance = data["distance"]
	ent.r = data["r"]
	ent.g = data["g"]
	ent.b = data["b"]
	ent.brightness = data["brightness"]

	return true

end

SpecialENTSSpawn["prop_vehicle_jeep"] = function( ent, data)

	if ( ent:GetModel() == "models/buggy.mdl" ) then ent:SetKeyValue( "vehiclescript", "scripts/vehicles/jeep_test.txt" ) end
	if ( ent:GetModel() == "models/vehicle.mdl" ) then ent:SetKeyValue( "vehiclescript", "scripts/vehicles/jalopy.txt" ) end

	if ( data["VehicleTable"] && data["VehicleTable"].KeyValues ) then
		for k, v in pairs( data["VehicleTable"].KeyValues ) do
			ent:SetKeyValue( k, v )
		end
	end

	ent:Spawn()
	ent:Activate()

	ent:SetVehicleClass( data["VehicleName"] )
	ent.VehicleName = data["VehicleName"]
	ent.VehicleTable = data["VehicleTable"]
	ent.ClassOverride = data["Class"]

	return true

end
SpecialENTSSpawn["prop_vehicle_jeep_old"] = SpecialENTSSpawn["prop_vehicle_jeep"]
SpecialENTSSpawn["prop_vehicle_airboat"] = SpecialENTSSpawn["prop_vehicle_jeep"]
SpecialENTSSpawn["prop_vehicle_prisoner_pod"] = SpecialENTSSpawn["prop_vehicle_jeep"]

local SpecialENTSSave = {}
SpecialENTSSave["gmod_lamp"] = function( ent )

	local content = {}
	content.Other = {}
	content.Other["Texture"] = ent.Texture
	content.Other["KeyDown"] = ent.KeyDown
	content.Other["fov"] = ent.fov
	content.Other["distance"] = ent.distance
	content.Other["r"] = ent.r
	content.Other["g"] = ent.g
	content.Other["b"] = ent.b
	content.Other["brightness"] = ent.brightness

	return content

end

SpecialENTSSave["prop_vehicle_jeep"] = function( ent )

	if not ent.VehicleTable then return false end

	local content = {}
	content.Other = {}
	content.Other["VehicleName"] = ent.VehicleName
	content.Other["VehicleTable"] = ent.VehicleTable
	content.Other["ClassOverride"] = ent.ClassOverride

	return content

end
SpecialENTSSave["prop_vehicle_jeep_old"] = SpecialENTSSave["prop_vehicle_jeep"]
SpecialENTSSave["prop_vehicle_airboat"] = SpecialENTSSave["prop_vehicle_jeep"]
SpecialENTSSave["prop_vehicle_prisoner_pod"] = SpecialENTSSave["prop_vehicle_jeep"]

local function PPGetEntTable( ent )

	if CLIENT then return end

	if !ent or !ent:IsValid() then return false end

	local content = {}
	content.Class = ent:GetClass()
	content.Pos = ent:GetPos()
	content.Angle = ent:GetAngles()
	content.Model = ent:GetModel()
	content.Skin = ent:GetSkin()
	content.Mins, content.Maxs = ent:GetCollisionBounds()
	content.ColGroup = ent:GetCollisionGroup()
	content.Name = ent:GetName()
	content.ModelScale = ent:GetModelScale()
	content.Color = ent:GetColor()
	content.Material = ent:GetMaterial()
	content.Solid = ent:GetSolid()
	
	if SpecialENTSSave[ent:GetClass()] != nil and isfunction(SpecialENTSSave[ent:GetClass()]) then

		local othercontent = SpecialENTSSave[ent:GetClass()](ent)
		if not othercontent then return false end
		if othercontent != nil and istable(othercontent) then
			table.Merge(content, othercontent)
		end

	end

	if ( ent.GetNetworkVars ) then
		content.DT = ent:GetNetworkVars()
	end

	if ent:GetPhysicsObject() and ent:GetPhysicsObject():IsValid() then
		content.Frozen = !ent:GetPhysicsObject():IsMoveable()
	end

	return content

end

local function PPEntityFromTable( data, id )

	if CLIENT then return end

	if not id or not isnumber(id) then return false end

	local ent = ents.Create( data.Class )
	if !ent or !ent:IsValid() then return false end
	ent:SetPos( data.Pos or Vector(0, 0, 0) )
	ent:SetAngles( data.Angle or Angle(0, 0, 0) )
	ent:SetModel( data.Model or "models/error.mdl" )
	ent:SetSkin( data.Skin or 0 )
	ent:SetCollisionBounds( ( data.Mins or 0 ), ( data.Maxs or 0 ) )
	ent:SetCollisionGroup( data.ColGroup or 0 )
	ent:SetName( data.Name or "" )
	ent:SetModelScale( data.ModelScale or 1 )
	ent:SetMaterial( data.Material or "" )
	ent:SetSolid( data.Solid or 6 )

	if SpecialENTSSpawn[ent:GetClass()] != nil and isfunction(SpecialENTSSpawn[ent:GetClass()]) then

		SpecialENTSSpawn[ent:GetClass()](ent, data.Other)

	else

		ent:Spawn()

	end

	ent:SetRenderMode( RENDERMODE_TRANSALPHA )
	ent:SetColor( data.Color or Color(255, 255, 255, 255) )

	if data.EntityMods != nil and istable(data.EntityMods) then -- OLD DATA

		if data.EntityMods.material then
			ent:SetMaterial( data.EntityMods.material["MaterialOverride"] or "")
		end
		
		if data.EntityMods.colour then
			ent:SetColor( data.EntityMods.colour.Color or Color(255, 255, 255, 255))
		end

	end

	if ( ent.RestoreNetworkVars and data.DT ) then
		ent:RestoreNetworkVars( data.DT )
	end

	ent.PermaProps_ID = id
	ent.PermaProps = true

	if data.Frozen != nil and data.Frozen == false then
		
		local phys = ent:GetPhysicsObject()
		if phys and phys:IsValid() then
			phys:EnableMotion(true)
		end

	else

		local phys = ent:GetPhysicsObject()
		if phys and phys:IsValid() then
			phys:EnableMotion(false)
		end

	end

	return ent

end

local function PPRebuildOldTable( data )

	if CLIENT then return end

	local e = ents.Create( data.class )
	if !e or !e:IsValid() then return end
	e:SetRenderMode( RENDERMODE_TRANSALPHA )
	e:SetPos( data.pos )
	e:SetAngles( data.ang )
	e:SetColor( data.color )
	e:SetModel( data.model )
	e:SetMaterial( data.material )
	e:SetSkin( data.skin )
	e:SetSolid( data.solid )
	e:SetCollisionGroup( data.collision or 0)
	e:Spawn()

	local content = PPGetEntTable( e )
	if not content then return end

	e:Remove()

	local max
	Perma.DoQuery("SELECT MAX(id) FROM permaprops;", function( data )
		max = tonumber(data[1])
	end)
	if not max then max = 1 else max = max + 1 end

	local new_ent = PPEntityFromTable(content, max)
	if !new_ent or !new_ent:IsValid() then return end
	
	Perma.DoQuery("INSERT INTO permaprops (map, content) VALUES('".. Perma.MySQL:escape(game.GetMap()) .."', '".. Perma.MySQL:escape(util.TableToJSON(content)) .."');")
end

function Perma.DoQuery(query, func, err)
	
	if CLIENT then return end
	
	if !mysqloo then MsgN("[PermaProps] -> Failed to load mysqloo module.\n\tPlease recheck your version to make sure it's installed correctly.\n\tAlso check to see if you have the right version.") return end
	if !Perma.MySQLConnected then return end
	if string.GetChar(query, query:len()) != ";" then query = query .. ";" end
	
	local query1 = Perma.MySQL:query(query)
	query1.onAborted = function( q )
		MsgN("[PermaProps] Query Aborted:", q)
		
		file.Append("query_aborted.txt", q .. "\n")
	end
	query1.onError = function( q, e, s )
		MsgN("[PermaProps] Query Failure:", e)
		
		file.Append("query_failure.txt", q .. "\t" .. e .. "\n")
		
		if err then
			err(q, e)
		end
	end
	query1.onSuccess = function(q)
		if func then
			func(q:getData())
		end
	end
	
	query1:start()
end

function ReloadPermaProps()

	if CLIENT then return end
	
	for k, v in pairs( ents.GetAll() ) do

		if v.PermaProps == true then

			v:Remove()

		end

	end

	Perma.DoQuery("SELECT * FROM permaprops;", function( data )
		if data == nil then return end
		for k, v in pairs(data) do
			if game.GetMap() == v['map'] then
				
				local content = util.JSONToTable(tostring(v['content']))
				
				if content.pos != nil then
					
					PPRebuildOldTable(content)
					Perma.DoQuery("DELETE FROM permaprops WHERE id = ".. v['id'] ..";")
					continue
				end
				
				local e = PPEntityFromTable(content, tonumber(v['id']))
				if !e or !e:IsValid() then continue end
									
			end
		end
	end)


end
hook.Add("InitPostEntity", "InitializePermaProps", ReloadPermaProps)
timer.Simple(5, function() ReloadPermaProps() end) -- When the hook isn't call ...

hook.Add("PostCleanupMap", "PostCleanUpMapPermaProp", ReloadPermaProps)

function TOOL:LeftClick(trace)

	if CLIENT then return end

	if not trace.Entity:IsValid() or not self:GetOwner():IsAdmin() then return end

	local ent = trace.Entity
	local ply = self:GetOwner()

	if not ent:IsValid() then ply:ChatPrint( "That is not a valid entity !" ) return end
	if ent:IsPlayer() then ply:ChatPrint( "That is a player !" ) return end
	if ent.PermaProps then ply:ChatPrint( "That entity is already permanent !" ) return end

	local content = PPGetEntTable(ent)
	if not content then return end

	local max
	Perma.DoQuery("SELECT MAX(id) FROM permaprops;", function( data )
		max = tonumber(data[1])
	end)
	if not max then max = 1 else max = max + 1 end

	local new_ent = PPEntityFromTable(content, max)
	if !new_ent or !new_ent:IsValid() then return end

	local effectdata = EffectData()
	effectdata:SetOrigin(ent:GetPos())
	effectdata:SetMagnitude(2)
	effectdata:SetScale(2)
	effectdata:SetRadius(3)
	util.Effect("Sparks", effectdata)

	Perma.DoQuery("INSERT INTO permaprops (map, content) VALUES('".. Perma.MySQL:escape(game.GetMap()) .."', '".. Perma.MySQL:escape(util.TableToJSON(content)) .."');")
	ply:ChatPrint("You saved " .. ent:GetClass() .. " with model ".. ent:GetModel() .. " to the database.")

	ent:Remove()

	return true

end

function TOOL:RightClick(trace)

	if CLIENT then return end

	if (not trace.Entity:IsValid()) then return end

	local ent = trace.Entity
	local ply = self:GetOwner()

	if not ply:IsAdmin() or not ply:GetNWString("usergroup") == "superadmin" then return end
	if not ent:IsValid() then ply:ChatPrint( "That is not a valid entity !" ) return end
	if ent:IsPlayer() then ply:ChatPrint( "That is a player !" ) return end
	if not ent.PermaProps then ply:ChatPrint( "That is not a PermaProp !" ) return end
	if not ent.PermaProps_ID then ply:ChatPrint( "ERROR: ID not found" ) return end

	Perma.DoQuery("DELETE FROM permaprops WHERE id = ".. ent.PermaProps_ID ..";");

	ply:ChatPrint("You erased " .. ent:GetClass() .. " with a model of " .. ent:GetModel() .. " from the database.")

	ent:Remove()

	return true

end

function TOOL:Reload(trace)

	if CLIENT then return end

	if (not trace.Entity:IsValid()) then self:GetOwner():ChatPrint( "You have reload all PermaProps !" ) ReloadPermaProps() return false end

	if trace.Entity.PermaProps then

		local ent = trace.Entity
		local ply = self:GetOwner()

		if not ply:IsAdmin() or not ply:GetNWString("usergroup") == "superadmin" then return end
		if ent:IsPlayer() then ply:ChatPrint( "That is a player !" ) return end
		
		local content = PPGetEntTable(ent)
		if not content then return end

		Perma.DoQuery("UPDATE permaprops set content = '".. Perma.MySQL:escape(util.TableToJSON(content)) .."' WHERE id = ".. Perma.MySQL:escape(ent.PermaProps_ID) .." AND map = '".. Perma.MySQL:escape(game.GetMap()) .. "';")

		local new_ent = PPEntityFromTable(content, ent.PermaProps_ID)
		if !new_ent or !new_ent:IsValid() then return end

		local effectdata = EffectData()
		effectdata:SetOrigin(ent:GetPos())
		effectdata:SetMagnitude(2)
		effectdata:SetScale(2)
		effectdata:SetRadius(3)
		util.Effect("Sparks", effectdata)

		ply:ChatPrint("You updated the " .. ent:GetClass() .. " you selected in the database.")

		ent:Remove()


	else

		return false

	end

	return true

end

function TOOL.BuildCPanel(panel)

	panel:AddControl("Header",{Text = "PermaProps", Description = "Save a props for server restarts\nBy Malboro"})
	panel:AddControl("Label",{Text = "------ Configuration ------"})
	panel:AddControl("Button",{Label = "Admin can touch PermaProps", Command = "pp_phys_change_admin"})
	panel:AddControl("Button",{Label = "SuperAdmin can touch PermaProps", Command = "pp_phys_change_sadmin"})
	panel:AddControl("Label",{Text = "-------- Functions --------"})
	panel:AddControl("Button", {Text = "Remove all PermaProps", Command = "perma_remove_all"})

end

//////////////////////////////////// REPLACE THIS ////////////////////////////////////

local function PermaRemoveAll( ply )

	if CLIENT then return end

	if not ply:IsAdmin() or not ply:GetNWString("usergroup") == "superadmin" then return end

	Perma.DoQuery("DELETE FROM permaprops WHERE map = '".. Perma.MySQL:escape(game.GetMap()) .."';")

	ply:ChatPrint("You erased all props from the map")

	ReloadPermaProps()

end
concommand.Add("perma_remove_all", PermaRemoveAll)

local function pp_phys_change_admin( ply ) -- Shit but work !!

	if CLIENT then return end

	if not ply:IsSuperAdmin() or not ply:GetNWString("usergroup") == "superadmin" then return end

	local Value = (GetConVarNumber("pp_phys_admin") or 0)

	if Value == 1 then

		game.ConsoleCommand("pp_phys_admin 0\n")
		ply:ChatPrint("Admin can't touch permaprops !")

	elseif Value == 0 then

		game.ConsoleCommand("pp_phys_admin 1\n")
		ply:ChatPrint("Admin can touch permaprops !")
		
	end

end
concommand.Add("pp_phys_change_admin", pp_phys_change_admin)

local function pp_phys_change_sadmin( ply ) -- Shit but work !!

	if CLIENT then return end

	if not ply:IsSuperAdmin() or not ply:GetNWString("usergroup") == "superadmin" then return end

	local Value = (GetConVarNumber("pp_phys_sadmin") or 0)

	if Value == 1 then

		game.ConsoleCommand("pp_phys_sadmin 0\n")
		ply:ChatPrint("SuperAdmin can't touch permaprops !")

	elseif Value == 0 then

		game.ConsoleCommand("pp_phys_sadmin 1\n")
		ply:ChatPrint("SuperAdmin can touch permaprops !")

	end

end
concommand.Add("pp_phys_change_sadmin", pp_phys_change_sadmin)


//////////////////////////////////////////////////////////////////////////////////////


local function PermaPropsPhys( ply, ent, phys )

	if CLIENT then return end

	if ent.PermaProps then

		if ply:IsAdmin() and GetConVarNumber("pp_phys_admin") == 1 then

			return true

		elseif ply:IsSuperAdmin() and GetConVarNumber("pp_phys_sadmin") == 1 then

			return true
		
		elseif ply:GetNWString("usergroup") == "superadmin" and GetConVarNumber("pp_phys_sadmin") == 1 then
		
			return true
		
		else

			return false

		end

	end
	
end
hook.Add("PhysgunPickup", "PermaPropsPhys", PermaPropsPhys)
hook.Add( "CanPlayerUnfreeze", "PermaPropsUnfreeze", PermaPropsPhys) -- Prevents people from pressing RELOAD on the physgun

hook.Add( "CanTool", "PermaPropsPhysTool", function( ply, tr, tool )

	if CLIENT then return end

	if IsValid(tr.Entity) and tr.Entity.PermaProps and tool ~= "permaprops" then

		if ply:IsAdmin() and GetConVarNumber("pp_phys_admin") == 1 then -- Make another convar option if you want.

			return true

		elseif ply:IsSuperAdmin() and GetConVarNumber("pp_phys_sadmin") == 1 then

			return true
			
		elseif ply:GetNWString("usergroup") == "superadmin" and GetConVarNumber("pp_phys_sadmin") then
			
			return true

		else

			return false

		end

	end

end)

hook.Add( "CanProperty", "PermaPropsProperty", function( ply, property, ent ) -- Context Menu (Right clicking on the entity)

	if CLIENT then return end

	if IsValid(ent) and ent.PermaProps and tool ~= "permaprops" then

		if ply:IsAdmin() and GetConVarNumber("pp_phys_admin") == 1 then -- Make another convar option if you want.

			return true

		elseif ply:IsSuperAdmin() and GetConVarNumber("pp_phys_sadmin") == 1 then

			return true

		elseif ply:GetNWString("usergroup") == "superadmin" and GetConVarNumber("pp_phys_sadmin") == 1 then
		
			return true

		else

			return false

		end

	end

end)

--------------------------------------------------------------------------------

--[[ Command only on server for security reason ]]--

concommand.Add("pps_sqlite_to_mysql", function(NULL, cmd, args)

	if CLIENT then return end
	
	Perma.DoQuery("DELETE FROM permaprops;")
	local content = sql.Query( "SELECT * FROM permaprops;" )
	if content == nil then return end
	
	for k, v in pairs( content ) do
		Perma.DoQuery("INSERT INTO permaprops (id, map, content) VALUES(".. v.id ..", '".. Perma.MySQL:escape(v.map) .."', '".. Perma.MySQL:escape(v.content) .."');")
	end
	
	MsgN("[PermaProps] the data was migrated from SQLite to MySQL successfully")
end)

concommand.Add("pps_mysql_to_sqlite", function(NULL, cmd, args)

	if CLIENT then return end
	
	sql.Query("DELETE FROM permaprops;")
	Perma.DoQuery("SELECT * FROM permaprops;", function( data )
		if data == nil then return end
		for k, v in pairs(data) do
			sql.Query("INSERT INTO permaprops (id, map, content) VALUES(".. v['id'] ..", ".. sql.SQLStr(v['map']) ..", ".. sql.SQLStr(v['content']) ..");")
		end
	end)
	
	MsgN("[PermaProps] the data was migrated from MySQL to SQLite successfully")
end)