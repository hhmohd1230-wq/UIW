
local Controller = UIWController.new()
Controller.Version = tostring(Controller.Version) .. "+streamtarget+carry12+route5+healer10"

getgenv().UIW = Controller
getgenv().UNDERWORLD_AI = Controller

print("[UIW] NavigationV2-v44.20 loaded | persistent mob combos + safe-spot hold")

Controller:Start()
