--- Holds single toggleable actions (like a tool system)
-- @classmod ActionManager

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine"))

local ContextActionService = game:GetService("ContextActionService")

local BaseAction = require("BaseAction")
local ValueObject = require("ValueObject")
local Signal = require("Signal")
local EnabledMixin = require("EnabledMixin")
local Maid = require("Maid")

local ActionManager = setmetatable({}, {})
ActionManager.__index = ActionManager
ActionManager.ClassName = "ActionManager"

EnabledMixin:Add(ActionManager)

function ActionManager.new()
	local self = setmetatable({}, ActionManager)
	
	self._maid = Maid.new()
	self._actions = {}

	self.ActiveAction = ValueObject.new()
	self._maid:GiveTask(self.ActiveAction)
	
	self.ActionAdded = Signal.new() -- :Fire(Action)
	
	self:InitEnableChanged()

	self._maid.ToolEquipped = ContextActionService.LocalToolEquipped:Connect(function(Tool)
		self:StopCurrentAction()
	end)
	
	self._maid:GiveTask(self.EnabledChanged:Connect(function(isEnabled)
		self:StopCurrentAction()
		
		for _, action in pairs(self._actions) do
			action:SetEnabled(isEnabled)
		end
	end))
	
	self._maid:GiveTask(self.ActiveAction.Changed:Connect(function(value, oldValue)
		local maid = Maid.new()
		if value then
			maid:GiveTask(function()
				value:Deactivate()
			end)
			maid:GiveTask(value.Deactivated:Connect(function()
				if self.ActiveAction == value then
					self.ActiveAction.Value = nil
				end
			end))
		end
		self._maid._activeActionMaid = maid
		
		-- Immediately deactivate
		if value and not value.IsActivatedValue.Value then
			warn("Immediate deactiation")
			self.ActiveAction.Value = nil
		end
	end))
	
	return self
end

function ActionManager:StopCurrentAction()
	self.ActiveAction.Value = nil
end

function ActionManager:ActivateAction(name, ...)
	local action = self:GetAction(name)
	if action then
		action:Activate(...)
	else
		error(("[ActionManager] - No action with name '%s'"):format(tostring(name)))
	end
end

function ActionManager:GetAction(name)
	return self._actions[name]
end

function ActionManager:CreateAction(name, actionData)
	local action = BaseAction.new(name)
	
	if actionData then
		action:WithActionData(actionData)
	end
	
	self:AddAction(action)
	
	return action
end

function ActionManager:GetActions()
	local list = {}
	
	for _, action in pairs(self._actions) do
		table.insert(list, action)
	end
	
	return list
end

function ActionManager:AddAction(action)
	local name = action:GetName()
	
	if self._actions[name] then
		error(("[ActionManager] - action with name '%s' already exists"):format(tostring(name)))
		return
	end
	
	self._actions[name] = action
	
	action:SetEnabled(self:IsEnabled())
	
	self._maid:GiveTask(action.Activated:Connect(function()
		self.ActiveAction.Value = action
	end))
	
	self._maid:GiveTask(action.Deactivated:Connect(function()
		if self.ActiveAction.Value == action then
			self.ActiveAction.Value = nil
		end
	end))
	
	self.ActionAdded:Fire(action)
	
	return self
end

return ActionManager