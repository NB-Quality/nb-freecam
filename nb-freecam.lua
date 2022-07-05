local _M_ = {}
do 
local Tasksync = _M_
local Loops = {}
local e = {}
local totalthreads = 0
setmetatable(Loops,{__newindex=function(t,k,v) rawset(t,tostring(k),v) end,__index=function(t,k) return rawget(t,tostring(k)) end})
setmetatable(e,{__call=function()end})
local GetDurationAndIndex = function(obj,cb) for duration,names in pairs(Loops) do for i=1,#names do local v = names[i] if v == obj then local duration_tonumber = tonumber(duration) if cb then cb(duration_tonumber,i) end return duration_tonumber,i end end end end
local remove_manual = function(duration,index) local indexs = Loops[duration] table.remove(indexs,index) if #indexs == 0 then Loops[duration] = nil end end 
local remove = function(obj,cb) GetDurationAndIndex(obj,function(duration,index) remove_manual(duration,index) if cb then cb() end end) end 
local init = function(duration,obj,cb) if Loops[duration] == nil then Loops[duration] = {}; if cb then cb() end end table.insert(Loops[duration],obj) end 
local newloopobject = function(duration,onaction,ondelete)
    local onaction = onaction 
    local ondelete = ondelete 
    local duration = duration 
    local releaseobject = nil 
    local ref = nil 
    if onaction and ondelete then 
        return function (action,value)
            if not action or action == "onaction" then 
                return onaction(ref)
            elseif action == "ondelete" then 
                return ondelete()
            elseif action == "setduration" then 
                duration = value 
            elseif action == "getduration" then 
                return duration 
            elseif action == "getfn" then 
                return onaction 
            elseif action == "setref" then 
                ref = value
            elseif action == "setreleasetimerobject" then 
                releaseobject = value 
            elseif action == "getreleasetimerobject" then 
                return releaseobject
            elseif action == "set" then 
                duration = value 
            elseif action == "get" then 
                return duration 
            end 
        end 
    elseif onaction and not ondelete then 
        return function (action,value)
            if not action or action == "onaction" then 
                return onaction(ref)
            elseif action == "setduration" then 
                duration = value 
            elseif action == "getduration" then 
                return duration 
            elseif action == "getfn" then 
                return onaction 
            elseif action == "setref" then 
                ref = value
            elseif action == "setreleasetimerobject" then 
                releaseobject = value 
            elseif action == "getreleasetimerobject" then 
                return releaseobject
            elseif action == "set" then 
                duration = value 
            elseif action == "get" then 
                return duration 
            end 
        end 
    end 
end 
local updateloop = function(obj,new_duration,cb)
    remove(obj,function()
        init(new_duration,obj,function()
            Tasksync.__createNewThreadForNewDurationLoopFunctionsGroup(new_duration,cb)
        end)
    end)
end 
local ref = function (default,obj)
    return function(action,v) 
        if action == 'get' then 
            return obj("getduration") 
        elseif action == 'set' then 
            return Tasksync.transferobject(obj,v)  
        elseif action == 'kill' or action == 'break' then 
            Tasksync.deleteloop(obj)
        end 
    end 
end 
Tasksync.__createNewThreadForNewDurationLoopFunctionsGroup = function(duration,init)
    local init = init   
    CreateThread(function()
        totalthreads = totalthreads + 1
        local loop = Loops[duration]
        if init then init() init = nil end
        repeat 
            local Objects = (loop or e)
            local n = #Objects
            for i=1,n do 
                (Objects[i] or e)()
            end 
            Wait(duration)
        until n == 0 
        --print("Deleted thread",duration)
        totalthreads = totalthreads - 1
        return 
    end)
end     
Tasksync.__createNewThreadForNewDurationLoopFunctionsGroupDebug = function(duration,init)
    local init = init   
    CreateThread(function()
        local loop = Loops[duration]
        if init then init() init = nil end
        repeat 
            local Objects = (loop or e)
            local n = #Objects
            for i=1,n do 
                (Objects[i] or e)()
            end 
        until n == 0 
        --print("Deleted thread",duration)
        return 
    end)
end     
Tasksync.addloop = function(duration,fn,fnondelete,isreplace)
    local obj = newloopobject(duration,fn,fnondelete)
    obj("setref",ref(duration,obj))
    local indexs = Loops[duration]
    if isreplace and Loops[duration] then 
        for i=1,#indexs do 
            if indexs[i]("getfn") == fn then 
                remove(indexs[i])
            end 
        end 
    end 
    init(duration,obj,function()
        if duration < 0 then Tasksync.__createNewThreadForNewDurationLoopFunctionsGroupDebug(duration) else 
            Tasksync.__createNewThreadForNewDurationLoopFunctionsGroup(duration)
        end 
    end)
    return obj
end 
Tasksync.insertloop = Tasksync.addloop
Tasksync.deleteloop = function(obj,cb)
    remove(obj,function()
        obj("ondelete")
        if cb then cb() end 
    end)
end 
Tasksync.removeloop = Tasksync.deleteloop
Tasksync.transferobject = function(obj,duration)
    local old_duration = obj("getduration")
    if duration ~= old_duration then 
        updateloop(obj,duration,function()
            obj("setduration",duration)
            Wait(old_duration)
        end)
    end 
end 
local newreleasetimer = function(obj,timer,cb)
    local releasetimer = timer   + GetGameTimer()
    local obj = obj 
    local tempcheck = Tasksync.PepareLoop(250)  
    tempcheck(function(duration)
        if GetGameTimer() > releasetimer then 
            tempcheck:delete()
            Tasksync.deleteloop(obj,cb)
        end 
    end)
    return function(action,value)
        if action == "get" then 
            return releasetimer
        elseif action == "set" then 
            releasetimer = timer + GetGameTimer()
        end 
    end 
end  
Tasksync.setreleasetimer = function(obj,releasetimer,cb)
    if not obj("getreleasetimerobject") then 
        obj("setreleasetimerobject",newreleasetimer(obj,releasetimer,function()
            obj("setreleasetimerobject",nil)
            if cb then cb() end 
        end))
    else 
        obj("getreleasetimerobject")("set",releasetimer)
    end 
end 
Tasksync.PepareLoop = function(duration,releasecb)
    local self = {}
    local obj = nil 
    self.add = function(self,_fn,_fnondelete)
        local ontaskdelete = nil
        if not _fnondelete then 
            if releasecb then 
                ontaskdelete = function()
                    releasecb(obj)
                end 
            end
        else 
            if releasecb then 
                ontaskdelete = function()
                    releasecb(obj)
                    _fnondelete(obj)
                end 
            else 
                ontaskdelete = function()
                    _fnondelete(obj)
                end 
            end
        end
        obj = Tasksync.addloop(duration,_fn,ontaskdelete)
        return obj
    end
    self.delete = function(self,duration,cb)
        local cb = type(duration) ~= "number" and duration or cb 
        local duration = type(duration) == "number" and duration or nil
        if obj then 
            if duration then 
                Tasksync.setreleasetimer(obj,duration,cb) 
            else 
                Tasksync.deleteloop(obj,cb) 
            end 
        end
    end
    self.release = self.delete
    self.remove = self.delete
    self.kill = self.delete
    self.set = function(self,newduration)
        if obj then Tasksync.transferobject(obj,newduration) end 
    end
    self.get = function(self)
        if obj then return obj("getduration") end 
    end
    return setmetatable(self,{__call = function(self,...)
        return self:add(...)
    end,__tostring = function()
        return "This duration:"..self.get().."Total loop threads:"..totalthreads
    end})
end
end 


local PepareLoop = PepareLoop
if not PepareLoop then 
    local try = LoadResourceFile("nb-libs","shared/loop.lua") or LoadResourceFile("nb-loop","nb-loop.lua")
    PepareLoop = PepareLoop or load(try.." return PepareLoop(...)") or _M_.PepareLoop
end 


local e,cam = {},-1
ResetLocalCam = function() 
    if DoesCamExist(cam) then 
        SetCamActive(cam,false) 
        DestroyCam(cam, false) 
    end 
    cam = -1
end 
local Keymapactions = {}
local Keyhandles = nil
CreateFreeCamera = function()
    local cam_offset,cam_rotoffset = vector3(0,0,0),vector3(0,0,0)
    local cam_offset_speed_level = 1
    local cam_offset_speed_slowscale = 1.0
    if not DoesCamExist(cam) then
        local originalpos = GetGameplayCamCoord()
        local rot = GetGameplayCamRot(2)
        cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", false);
		SetCamCoord(cam, originalpos);
		SetCamRot(cam, rot, 2);
		SetCamFov(cam, fov or 50.0);
		SetCamActive(cam, true);
		RenderScriptCams(true, false, 3000, true, false, 0);
        if not Keyhandles then 
            KeyHandles = {
                KeyEvent('KEYBOARD', 'W',function(on)
                    local pos_temp = nil 
                    on("justpressed",function()
                        Keymapactions["+camWWW"] = function(rightVec,forwardVec,upVec,pos)
                            if DoesCamExist(cam) then 
                                local rot = GetCamRot(cam,2)
                                cam_offset = cam_offset + forwardVec*0.1
                                pos_temp = pos
                            end 
                        end
                    end)
                    on("justreleased",function()
                        Keymapactions["+camWWW"] = nil
                        if pos_temp then SetEntityCoords(PlayerPedId(),pos) RequestCollisionAtCoord(pos_temp.x, pos_temp.y, pos_temp.z) end 
                        if cam ~= GetRenderingCam() then 
                            cam = -1
                        end 
                    end)
                end),
                KeyEvent('KEYBOARD', 'S',function(on)
                    on("justpressed",function()
                        Keymapactions["+camS"] = function(rightVec,forwardVec,upVec,pos)
                            if DoesCamExist(cam) then 
                                local rot = GetCamRot(cam,2)
                                cam_offset = cam_offset - forwardVec*0.1
                                pos_temp = pos
                            end 
                        end
                    end)
                    on("justreleased",function()
                        Keymapactions["+camS"] = nil
                        if pos_temp then SetEntityCoords(PlayerPedId(),pos) RequestCollisionAtCoord(pos_temp.x, pos_temp.y, pos_temp.z) end 
                        if cam ~= GetRenderingCam() then 
                            cam = -1
                        end 
                    end)
                end),
                KeyEvent('KEYBOARD', 'A',function(on)
                    on("justpressed",function()
                        Keymapactions["+camA"] = function(rightVec,forwardVec,upVec,pos)
                            if DoesCamExist(cam) then 
                                local rot = GetCamRot(cam,2)
                                cam_offset = cam_offset - rightVec*0.1
                                pos_temp = pos
                            end 
                        end
                    end)
                    on("justreleased",function()
                        Keymapactions["+camA"] = nil
                        if pos_temp then SetEntityCoords(PlayerPedId(),pos) RequestCollisionAtCoord(pos_temp.x, pos_temp.y, pos_temp.z) end
                        if cam ~= GetRenderingCam() then 
                            cam = -1
                        end                         
                    end)
                end),
                KeyEvent('KEYBOARD', 'D',function(on)
                    on("justpressed",function()
                        Keymapactions["+camD"] = function(rightVec,forwardVec,upVec,pos)
                            if DoesCamExist(cam) then 
                                local rot = GetCamRot(cam,2)
                                cam_offset = cam_offset + rightVec*0.1
                                pos_temp = pos
                            end 
                        end
                    end)
                    on("justreleased",function()
                        Keymapactions["+camD"] = nil
                        if pos_temp then SetEntityCoords(PlayerPedId(),pos) RequestCollisionAtCoord(pos_temp.x, pos_temp.y, pos_temp.z) end 
                        if cam ~= GetRenderingCam() then 
                            cam = -1
                        end 
                    end)
                end),
                KeyEvent('KEYBOARD', 'SPACE',function(on)
                    on("justpressed",function()
                        Keymapactions["+camSPACE"] = function()
                            if DoesCamExist(cam) then 
                                cam_offset_speed_slowscale = 0.1
                            end 
                        end
                    end)
                    on("justreleased",function()
                        cam_offset_speed_slowscale = 1.0
                        Keymapactions["+camSPACE"] = nil
                    end)
                end),
                KeyEvent('KEYBOARD', 'LSHIFT',function(on)
                    on("justpressed",function()
                        if DoesCamExist(cam) then 
                            if cam_offset_speed_level < 25 then 
                                cam_offset_speed_level = cam_offset_speed_level + 5
                            else 
                                cam_offset_speed_level = 1
                            end
                        end 
                    end)
                end),
            }
        end 
        
        if not Loop then
            Loop = PepareLoop(0)
            local playerEntity = PlayerPedId()
            SetEntityCollision(playerEntity, false, false)
            SetEntityVisible(playerEntity, false, false)
            FreezeEntityPosition(playerEntity, true)
            SetPlayerCanUseCover (PlayerId(), false)
            Loop(function()
                local rightVec,forwardVec,upVec,pos = GetCamMatrix(cam)
                if cam == -1 and Loop then 
                    Loop:delete(function()
                        local coords = pos
                        local x,y,z = coords.x,coords.y,coords.z 
                        local bottom,top = GetHeightmapBottomZForPosition(x,y), GetHeightmapTopZForPosition(x,y)
                        local steps = (top-bottom)/100
                        local foundGround
                        local height = bottom + 0.0
                        while not foundGround and height < top  do 
                            SetPedCoordsKeepVehicle(PlayerPedId(), x,y, height )
                            foundGround, zPos = GetGroundZFor_3dCoord(x,y, height )
                            height = height + steps
                            Wait(0)
                        end 
                        SetPedCoordsKeepVehicle(PlayerPedId(), x,y, height )
                    end) 
                end 
                local rot = GetGameplayCamRot(2) 
                SetCamRot(cam, rot, 2)
                for i, v in pairs(Keymapactions) do 
                    v(rightVec,forwardVec,upVec,pos)
                end 
                SetCamCoord(cam,pos + cam_offset*cam_offset_speed_level*cam_offset_speed_slowscale)
                cam_offset = vector3(0,0,0)
                cam_rotoffset = vector3(0,0,0)
            end,function()
                SetEntityCollision(playerEntity, true, true)
                FreezeEntityPosition(playerEntity, false)
                SetEntityVisible(playerEntity, true, false)
                SetPlayerCanUseCover (PlayerId(), true)
                if Loop then Loop = nil end 
                if KeyHandles and #KeyHandles > 0 then 
                    for i=1,#KeyHandles do 
                        RemoveKeyEvent(KeyHandles[i])
                    end 
                    KeyHandles = nil
                end 
                DestoryFreeCamera()
            end)
        end
    end
end 

DestoryFreeCamera = function()
    if DoesCamExist(cam) then 
        RenderScriptCams (false, false, 0, true, false)
        ResetLocalCam()
    end 
end 

local triggered = false 
exports("TriggerFreeCamera",function(b) 
    local b = b 
    if b == nil then b = not triggered end  
    if b and not triggered then 
        CreateFreeCamera(50.0)
    elseif triggered then 
        DestoryFreeCamera()  
    end 
    triggered = b
end)

