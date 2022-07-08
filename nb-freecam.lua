local _M_ = {}
do 

    local totalThread = 0
    local debugMode = false
    local e = {} setmetatable(e,{__call = function(t,...) end})
    local newLoopThread = function(t,k)  
        CreateThread(function()
            totalThread = totalThread + 1
            local o = t[k]
            repeat 
                local tasks = (o or e)
                local n = #tasks
                if n==0 then 
                    goto end_loop 
                end 
                for i=1,n do 
                    (tasks[i] or e)()
                end 
            until n == 0 or Wait(k) 
            ::end_loop::
            totalThread = totalThread - 1
            t[k] = nil

            return 
        end)
    end   

    local Loops = setmetatable({[e]=e}, {__newindex = function(t, k, v)
        rawset(t, k, v)
        newLoopThread(t, k)
    end})

    local newLoopObject = function(t,selff,f)
        local fns = t.fns
        local fnsbreak = t.fnsbreak
        local f = f 
        local selff = selff
        local ref = function(act,val)
            if act == "break" or act == "kill" then 
                local n = fns and #fns or 0
                if n > 0 then 
                    for i=1,n do 
                        if fns[i] == f then 
                            table.remove(fns,i)
                            if fnsbreak and fnsbreak[i] then fnsbreak[i]() end
                            table.remove(fnsbreak,i)
                            if #fns == 0 then 
                                table.remove(Loops[t.duration],i)
                            end
                            break
                        end
                    end
                else 
                    return t:delete(fbreak)
                end
            elseif act == "set" or act == "transfer" then 
                return t:transfer(val) 
            elseif act == "get" then 
                return t.duration
            end 
        end
        local aliveDelay = nil 
        return function(action,...)
            if not action then
                if aliveDelay and GetGameTimer() < aliveDelay then 
                    return e()
                else 
                    aliveDelay = nil 
                    return selff(ref)
                end
            elseif action == "setalivedelay" then 
                local delay = ...
                aliveDelay = GetGameTimer() + delay
            else 
                ref(action,...)
            end
        end 
    end 

    local PepareLoop = function(duration,init)
        if not Loops[duration] then Loops[duration] = {} end 
        local self = {}
        self.duration = duration
        self.fns = {}
        self.fnsbreak = {}
        local selff
        if init then 
            selff = function(ref)
                local fns = self.fns
                local n = #fns
                if init() then 
                    for i=1,n do 
                        fns[i](ref)
                    end 
                end 
            end 
        else 
            selff = function(ref)
                local fns = self.fns
                local n = #fns
                for i=1,n do 
                    fns[i](ref)
                end 
            end 
        end 
        setmetatable(self, {__index = Loops[duration],__call = function(t,f,...)
            if type(f) ~= "string" then 
                local fbreak = ...
                table.insert(t.fns, f)
                if fbreak then table.insert(self.fnsbreak, fbreak) end
                local obj = newLoopObject(self,selff,f)
                table.insert(Loops[duration], obj)
                self.obj = obj
                return self
            elseif self.obj then  
                return self.obj(f,...)
            end 
        end,__tostring = function(t)
            return "Loop("..t.duration.."), Total Thread: "..totalThread
        end})
        self.found = function(self,f)
            for i,v in ipairs(Loops[self.duration]) do
                if v == self.obj then
                    return i
                end 
            end 
            return false
        end
        self.delay = nil 
        self.delete = function(s,delay,cb)
            local delay = delay
            local cb = cb 
            if type(delay) ~= "number" then 
                cb = delay
                delay = nil 
            end 
            local del = function(instant)
                if self.delay == delay or instant == "negbook" then 
                    if Loops[duration] then 
                        local i = s.found(s)
                        if i then
                            local fns = self.fns
                            local fnsbreak = self.fnsbreak
                            local n = fns and #fns or 0
                            if n > 0 then 
                                table.remove(fns,n)
                                if fnsbreak and fnsbreak[n] then fnsbreak[n]() end
                                table.remove(fnsbreak,n)
                                if #fns == 0 then 
                                    table.remove(Loops[duration],i)
                                end
                                if cb then cb() end
                            elseif debugMode then  
                                error("It should be deleted")
                            end 
                            
                        elseif debugMode then  
                            error('Task deleteing not found',2)
                        end
                    elseif debugMode then  
                        error('Task deleteing not found',2)
                    end 
                end 
            end 
            if delay and delay>0 then 
                SetTimeout(delay,del)
                self.delay = delay 
            else
                self.delay = nil 
                del("negbook")
            end 
        end
        self.transfer = function(s,newduration)
            if s.duration == newduration then return end
            local i = s.found(s) 
            if i then
                table.remove(Loops[s.duration],i)
                s.obj("setalivedelay",newduration)
                if not Loops[newduration] then Loops[newduration] = {} end 
                table.insert(Loops[newduration],s.obj)
                s.duration = newduration
            end
        end
        self.set = self.transfer 
        return self
    end 
    _M_.PepareLoop = PepareLoop
end 



local PepareLoop = PepareLoop
if not PepareLoop then 
    local try = LoadResourceFile("nb-libs","shared/loop.lua") or LoadResourceFile("nb-loop","nb-loop.lua")
    PepareLoop = PepareLoop or (try and load(try.." return PepareLoop(...)")) or _M_.PepareLoop
end 

local sin = math.sin
local cos = math.cos
local torad = math.pi / 180
function GetCoordsFromGamePlayCameraPointAtSynced(ingoredEntity) 
    local action = 0
    local distance = 300
    local coordsVector =  GetFinalRenderedCamCoord() ;
    local rotationVectorUnrad = GetFinalRenderedCamRot(2);
    local rotationVector = rotationVectorUnrad * torad
    local directionVector =  vector3(-sin(rotationVector.z) * cos(rotationVector.x), (cos(rotationVector.z) * cos(rotationVector.x)), sin(rotationVector.x));
    local destination =  coordsVector + directionVector * distance ;
    local playerPed = PlayerPedId()
    local destination_temp = coordsVector + directionVector * 1 ;
    local getentitytype = function(entity)
       local type = GetEntityType(entity)
       local result = "solid"
       if type == 0 then 
          result = "solid"
       elseif type == 1 then 
          result = "ped"
       elseif type == 2 then 
          result = "vehicle"
       elseif type == 3 then 
          result = "object"
       end 
       return result
    end 
    if StartExpensiveSynchronousShapeTestLosProbe then 
        local shapeTestId = StartExpensiveSynchronousShapeTestLosProbe(destination_temp, destination, 511, ingoredEntity or playerPed, 1)
        local shapeTestResult , hit , endCoords , surfaceNormal , entityHit = GetShapeTestResult(shapeTestId)
        return hit and endCoords
    end 
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
                        if pos_temp then SetEntityCoords(PlayerPedId(),pos_temp) RequestCollisionAtCoord(pos_temp.x, pos_temp.y, pos_temp.z) end 
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
                        if pos_temp then SetEntityCoords(PlayerPedId(),pos_temp) RequestCollisionAtCoord(pos_temp.x, pos_temp.y, pos_temp.z) end 
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
                        if pos_temp then SetEntityCoords(PlayerPedId(),pos_temp) RequestCollisionAtCoord(pos_temp.x, pos_temp.y, pos_temp.z) end
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
                        if pos_temp then SetEntityCoords(PlayerPedId(),pos_temp) RequestCollisionAtCoord(pos_temp.x, pos_temp.y, pos_temp.z) end 
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
            local game = GetGameName()
            if game == "redm" then 
                GetCamMatrix = function(cam)
                    local pos = GetCamCoord(cam)
                    local rot = GetCamRot(cam, 2)
                    local rotationVector = rot * torad
                    local forwardVec = vector3(-sin(rotationVector.z) * cos(rotationVector.x), (cos(rotationVector.z) * cos(rotationVector.x)), sin(rotationVector.x));
                    local rightVec = vector3(cos(rotationVector.z) * cos(rotationVector.y), (sin(rotationVector.z) * cos(rotationVector.y)), -sin(rotationVector.y));
                    local upVec = vector3(sin(rotationVector.y) * cos(rotationVector.z), -sin(rotationVector.y) * sin(rotationVector.z), cos(rotationVector.y) * cos(rotationVector.z));
                    
                    
                    return rightVec, forwardVec, upVec, pos
                end 
            end 
            Loop(function()
                local rightVec,forwardVec,upVec,pos = GetCamMatrix(cam)
                
                if cam == -1 and Loop then 
                    Loop:delete(function()
                        local coords = GetCoordsFromGamePlayCameraPointAtSynced(PlayerPedId())
                        if coords then 
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
                        end 
                    end) 
                end 
                local rot = GetGameplayCamRot(2) 
                
                SetCamRot(cam, rot+0.1, 2)
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

