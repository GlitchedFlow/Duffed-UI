local D, C, L = unpack(select(2, ...))

-- /console cameraDistanceMaxFactor 2.6
-- local f = CreateFrame('Frame')
-- function f:OnEvent(event, addon)
-- 	hooksecurefunc('BlizzardOptionsPanel_SetupControl', function(control)
-- 		if control == InterfaceOptionsCameraPanelMaxDistanceSlider then SetCVar('cameraDistanceMaxFactor', 2.6) end
-- 	end)
-- 	self:UnregisterEvent(event)
-- end
-- f:RegisterEvent('ADDON_LOADED')
-- f:SetScript('OnEvent', f.OnEvent)

-- Quest Rewards
local QuestReward = CreateFrame('Frame')
QuestReward:SetScript('OnEvent', function(self, event, ...) self[event](...) end)

local metatable = {
	__call = function(methods, ...)
		for _, method in next, methods do method(...) end
	end
}

local modifier = false
function QuestReward:Register(event, method, override)
	local newmethod
	local methods = self[event]

	if methods then
		self[event] = setmetatable({methods, newmethod or method}, metatable)
	else
		self[event] = newmethod or method
		self:RegisterEvent(event)
	end
end

local cashRewards = {
	[45724] = 1e5, -- Champion's Purse
	[64491] = 2e6, -- Royal Reward
}

QuestReward:Register('QUEST_COMPLETE', function()
	local choices = GetNumQuestChoices()
	if choices > 1 then
		local bestValue, bestIndex = 0

		for index = 1, choices do
			local link = GetQuestItemLink('choice', index)
			if link then
				local _, _, _, _, _, _, _, _, _, _, value = GetItemInfo(link)
				value = cashRewards[tonumber(string.match(link, 'item:(%d+):'))] or value

				if value > bestValue then bestValue, bestIndex = value, index end
			else
				choiceQueue = 'QUEST_COMPLETE'
				return GetQuestItemInfo('choice', index)
			end
		end

		if bestIndex then QuestInfoItem_OnClick(QuestInfoRewardsFrame.RewardButtons[bestIndex]) end
	end
end, true)

-- Fixes for Blizzard issues
hooksecurefunc('StaticPopup_Show', function(which)
	if which == 'DEATH' and not UnitIsDeadOrGhost('player') then StaticPopup_Hide('DEATH') end
end)

-- Blizzard taint fixes for 5.4.1
setfenv(FriendsFrame_OnShow, setmetatable({ UpdateMicroButtons = function() end }, { __index = _G }))

-- Taintfix for Talents & gylphs
local function hook()
	PlayerTalentFrame_Toggle = function()
	if not PlayerTalentFrame:IsShown() then ShowUIPanel(PlayerTalentFrame) else PlayerTalentFrame_Close() end 
end

for i = 1, 10 do
	local tab = _G['PlayerTalentFrameTab'..i]
	if not tab then break end
		tab:SetScript('PreClick', function()
			for index = 1, STATICPOPUP_NUMDIALOGS, 1 do
				local frame = _G['StaticPopup'..index]
				if not issecurevariable(frame, 'which') then
					local info = StaticPopupDialogs[frame.which]
					if (frame:IsShown() and info) and not issecurevariable(info, 'OnCancel') then info.OnCancel() end
					frame:Hide()
					frame.which = nil
				end
			end
		end)
	end
end

if IsAddOnLoaded('Blizzard_TalentUI') then
	hook()
else
	local f = CreateFrame('Frame')
	f:RegisterEvent('ADDON_LOADED')
	f:SetScript('OnEvent', function(self, event, addon)
		if addon=='Blizzard_TalentUI' then 
			self:UnregisterEvent('ADDON_LOADED')
			hook()
		end
	end)
end

-- Automatic achievement screenshot
if C['misc']['acm_screen'] then
	local function TakeScreen(delay, func, ...)
		local waitTable = {}
		local waitFrame = CreateFrame('Frame', 'WaitFrame', UIParent)
		waitFrame:SetScript('onUpdate', function (self, elapse)
			local count = #waitTable
			local i = 1
			while (i <= count) do
				local waitRecord = tremove(waitTable, i)
				local d = tremove(waitRecord, 1)
				local f = tremove(waitRecord, 1)
				local p = tremove(waitRecord, 1)
				if d > elapse then
					tinsert(waitTable, i, {d-elapse, f, p})
					i = i + 1
				else
					count = count - 1
					f(unpack(p))
				end
			end
		end)
		tinsert(waitTable, {delay, func, {...}})
	end

	local function OnEvent(...) TakeScreen(1, Screenshot) end

	local frame = CreateFrame('Frame')
	frame:RegisterEvent('ACHIEVEMENT_EARNED')
	frame:SetScript('OnEvent', OnEvent)
end

-- Shorten gold display
if C['misc']['gold'] then
	local frame = CreateFrame('FRAME', 'DuffedGold')
	frame:RegisterEvent('PLAYER_ENTERING_WORLD')
	frame:RegisterEvent('MAIL_SHOW')
	frame:RegisterEvent('MAIL_CLOSED')

	local function eventHandler(self, event, ...)
		if event == 'MAIL_SHOW' then
			COPPER_AMOUNT = '%d Copper'
			SILVER_AMOUNT = '%d Silver'
			GOLD_AMOUNT = '%d Gold'
		else
			COPPER_AMOUNT = '%d|cFF954F28'..COPPER_AMOUNT_SYMBOL..'|r'
			SILVER_AMOUNT = '%d|cFFC0C0C0'..SILVER_AMOUNT_SYMBOL..'|r'
			GOLD_AMOUNT = '%d|cFFF0D440'..GOLD_AMOUNT_SYMBOL..'|r'
		end
		YOU_LOOT_MONEY = '+%s'
		LOOT_MONEY_SPLIT = '+%s'
		LOOT_ITEM_PUSHED_SELF = '+ %s'
		LOOT_ITEM_PUSHED_SELF_MULTIPLE = '+ %s x %d'
		LOOT_ITEM_SELF = '+ %s'
		LOOT_ITEM_SELF_MULTIPLE = '+ %s x %d'
		LOOT_ITEM_BONUS_ROLL_SELF = '+ %s'
		LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE = '+ %s x %d (Bonus)'
		LOOT_ITEM_CREATED_SELF = '+ %s'
		LOOT_ITEM_CREATED_SELF_MULTIPLE = '+ %s x %d'
		LOOT_ITEM_REFUND = '+ %s'
		LOOT_ITEM_REFUND_MULTIPLE = '+ %s x %d'
		ERR_QUEST_REWARD_ITEM_S = '+ %s'
		CURRENCY_GAINED = '+ %s'
		CURRENCY_GAINED_MULTIPLE = '+ %s x %d'
		CURRENCY_GAINED_MULTIPLE_BONUS = '+ %s x %d (Bonus Objective)'
		LOOT_ITEM = '+ %s => %s'
		LOOT_ITEM_BONUS_ROLL = '+ %s => %s (Bonus)'
		LOOT_ITEM_BONUS_ROLL_MULTIPLE = '+ %s => %s x %d'
		LOOT_ITEM_MULTIPLE = '+ %s => %s x %d'
		LOOT_ITEM_PUSHED = '+ %s => %s'
		LOOT_ITEM_PUSHED_MULTIPLE = '+ %s => %s x %d'
	end
	frame:SetScript('OnEvent', eventHandler)
end