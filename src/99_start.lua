
local Controller = UIWController.new()
Controller.Version = tostring(Controller.Version) .. "+streamtarget+carry10+healer4"

getgenv().UIW = Controller
getgenv().UNDERWORLD_AI = Controller

print("[UIW] NavigationV2-v44.20 loaded | persistent mob combos + safe-spot hold")

Controller:Start()
