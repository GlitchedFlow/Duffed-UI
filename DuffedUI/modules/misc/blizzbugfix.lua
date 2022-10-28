local D, C, L = unpack(select(2, ...))
local Module = D:NewModule('BlizzBugFixes', 'AceEvent-3.0', 'AceHook-3.0')

if not Module then return end

-- Fix Blank Tooltip
local bug = nil
local FixTooltip = CreateFrame('Frame')
FixTooltip:RegisterEvent('UPDATE_BONUS_ACTIONBAR')
FixTooltip:RegisterEvent('ACTIONBAR_PAGE_CHANGED')
FixTooltip:SetScript('OnEvent', function()
	if GameTooltip:IsShown() then bug = true end
end)

local FixTooltipBags = CreateFrame('Frame')
FixTooltipBags:RegisterEvent('BAG_UPDATE_DELAYED')
FixTooltipBags:SetScript('OnEvent', function()
	if StuffingFrameBags and StuffingFrameBags:IsShown() then
		if GameTooltip:IsShown() then bug = true end
	end
end)

GameTooltip:HookScript('OnTooltipCleared', function(self)
	if self:IsForbidden() then return end
	if bug and self:NumLines() == 0 then
		self:Hide()
		bug = false
	end
end)

function Module:MisclickPopups()
	StaticPopupDialogs.RESURRECT.hideOnEscape = nil
	StaticPopupDialogs.AREA_SPIRIT_HEAL.hideOnEscape = nil
	StaticPopupDialogs.PARTY_INVITE.hideOnEscape = nil
	StaticPopupDialogs.CONFIRM_SUMMON.hideOnEscape = nil
	StaticPopupDialogs.ADDON_ACTION_FORBIDDEN.button1 = nil
	StaticPopupDialogs.TOO_MANY_LUA_ERRORS.button1 = nil

	_G.PetBattleQueueReadyFrame.hideOnEscape = nil

	if (PVPReadyDialog) then
		PVPReadyDialog.leaveButton:Hide()
		PVPReadyDialog.enterButton:ClearAllPoints()
		PVPReadyDialog.enterButton:SetPoint('BOTTOM', PVPReadyDialog, 'BOTTOM', 0, 25)
	end
end

function Module:BuyMaxStacks()
	local old_MerchantItemButton_OnModifiedClick = MerchantItemButton_OnModifiedClick
	local cache = {}
	function MerchantItemButton_OnModifiedClick(self, ...)
		if IsAltKeyDown() then
			local id = self:GetID()
			local itemLink = GetMerchantItemLink(id)
			if not itemLink then return end
			local name, _, quality, _, _, _, _, maxStack, _, texture = GetItemInfo(itemLink)
			if maxStack and maxStack > 1 then
				if not cache[itemLink] then
					StaticPopupDialogs['BUY_STACK'] = {
						text = 'Stack Buying Check',
						button1 = YES,
						button2 = NO,
						OnAccept = function()
							BuyMerchantItem(id, GetMerchantItemMaxStack(id))
							cache[itemLink] = true
						end,
						hideOnEscape = 1,
						hasItemFrame = 1,
					}

					local r, g, b = GetItemQualityColor(quality or 1)
					StaticPopup_Show('BUY_STACK', ' ', ' ', {['texture'] = texture, ['name'] = name, ['color'] = {r, g, b, 1}, ['link'] = itemLink, ['index'] = id, ['count'] = maxStack})
				else
					BuyMerchantItem(id, GetMerchantItemMaxStack(id))
				end
			end
		end

		old_MerchantItemButton_OnModifiedClick(self, ...)
	end
end

-- Instant drop domi gems, choose domigems per click *** Siweia you rock!***
function Module:DomiExtractor()
	local EXTRACTOR_ID = 187532
	local Module_Tooltip = D:GetModule('TooltipDomiRanks')

	local function TryOnShard(self)
		if not self.itemLink then return end

		PickupContainerItem(self.bagID, self.slotID)
		ClickSocketButton(1)
		ClearCursor()
	end

	local function ShowShardTooltip(self)
		if not self.itemLink then return end

		GameTooltip:ClearLines()
		GameTooltip:SetOwner(self, 'ANCHOR_TOPLEFT')
		GameTooltip:SetHyperlink(self.itemLink)
		GameTooltip:Show()
	end

	local foundShards = {}
	local function RefreshShardsList()
		wipe(foundShards)

		for bagID = 0, 4 do
			for slotID = 1, GetContainerNumSlots(bagID) do
				local _, _, _, _, _, _, itemLink, _, _, itemID = GetContainerItemInfo(bagID, slotID)
				local rank = itemID and Module_Tooltip.DomiRankData[itemID]
				if rank then
					local index = Module_Tooltip.DomiIndexData[itemID]
					if not index then break end

					local button = Module.DomiShardsFrame.icons[index]
					button.bagID = bagID
					button.slotID = slotID
					button.itemLink = itemLink
					button.count:SetText(rank)
					button.Icon:SetDesaturated(false)

					foundShards[index] = true
				end
			end
		end

		for index, button in pairs(Module.DomiShardsFrame.icons) do
			if not foundShards[index] then
				button.itemLink = nil
				button.count:SetText('')
				button.Icon:SetDesaturated(true)
			end
		end
	end

	local iconSize = 28
	local frameSize = iconSize * 3

	local function CreateDomiShards()
		local frame = CreateFrame('Frame', 'DuffedUI_DomiShards', ItemSocketingFrame)
		frame:SetSize(frameSize, frameSize)
		frame:SetPoint("BOTTOMLEFT", 22, 3)
		frame.icons = {}

		Module.DomiShardsFrame = frame

		for index, value in pairs(Module_Tooltip.DomiDataByGroup) do
			for itemID in pairs(value) do
				local button = CreateFrame('Button', nil, frame)
				button:SetSize(iconSize, iconSize)
				button:SetPoint("TOPLEFT", mod(index - 1, 3) * iconSize, - floor((index - 1) / 3) * iconSize)
				
				if not button.IsSkinned then
					button:CreateBackdrop()
					button:StyleButton()
					button.backdrop:SetFrameLevel(button:GetFrameLevel() - 1)				
					button.Icon = button:CreateTexture(nil, 'ARTWORK')
					button.Icon:SetTexture(GetItemIcon(itemID))
					button.Icon:SetAllPoints()
					button.Icon:SetTexCoord(unpack(D['IconCoord']))
					button.Icon:SetInside(button.Backdrop)
					button.IsSkinned = true
				end

				button:SetScript('OnClick', TryOnShard)
				button:SetScript('OnLeave', D['HideTooltip'])
				button:SetScript('OnEnter', ShowShardTooltip)

				button.count = D['SetFontString'](button, C['media']['font'], 11, 'THINOUTLINE', 'system', 'BOTTOMRIGHT', 0, -0) 

				frame.icons[index] = button
				break
			end
		end

		RefreshShardsList()
		D:RegisterEvent('BAG_UPDATE', RefreshShardsList)
	end

	local function CreateExtractButton()
		if not ItemSocketingFrame then return end
		if Module.DomiExtButton then return end
		if GetItemCount(EXTRACTOR_ID) == 0 then return end
		if IsAddOnLoaded('Aurora') then F = unpack(Aurora) end

		ItemSocketingSocketButton:SetWidth(80)

		if InCombatLockdown() then return end

		local button = CreateFrame('Button', 'DuffedUI_ExtractorButton', ItemSocketingFrame, 'UIPanelButtonTemplate, SecureActionButtonTemplate')
		button:SetSize(80, 22)
		button:SetText(REMOVE)
		button:SetPoint('RIGHT', ItemSocketingSocketButton, 'LEFT', -2, 0)
		button:SetAttribute('type', 'macro')
		button:SetAttribute('macrotext', '/use item:'..EXTRACTOR_ID..'\n/click ItemSocketingSocket1')
		
		if IsAddOnLoaded('Aurora') then F.Reskin(button) end

		CreateDomiShards()

		Module.DomiExtButton = button
	end

	hooksecurefunc('ItemSocketingFrame_LoadUI', function()
		CreateExtractButton()

		if Module.DomiExtButton then
			Module.DomiExtButton:SetAlpha(GetSocketTypes(1) == 'Domination' and GetExistingSocketInfo(1) and 1 or 0)
		end

		if Module.DomiShardsFrame then
			Module.DomiShardsFrame:SetShown(GetSocketTypes(1) == 'Domination' and not GetExistingSocketInfo(1))
		end
	end)
end

function Module:OnEnable()
	-- Fix Spellbook Taint
	ShowUIPanel(SpellBookFrame)
	HideUIPanel(SpellBookFrame)
	
	self:BuyMaxStacks()
	self:DomiExtractor()
	self:MisclickPopups()
	
	hooksecurefunc(StaticPopupDialogs['DELETE_GOOD_ITEM'], 'OnShow', function(self) self.editBox:SetText(DELETE_ITEM_CONFIRM_STRING) end)

	for i = 0, 3 do
		local bagSlot = _G['CharacterBag'..i..'Slot']
		bagSlot:UnregisterEvent('ITEM_PUSH') -- Gets Rid Of The Animation
	end

	-- Make It Only Split Stacks With Shift-RightClick If The Tradeskillframe Is Open
	-- Shift-LeftClick Should Be Reserved For The Search Box
	local function hideSplitFrame(_, button)
		if TradeSkillFrame and TradeSkillFrame:IsShown() then
			if button == 'LeftButton' then
				StackSplitFrame:Hide()
			end
		end
	end

	hooksecurefunc('ContainerFrameItemButton_OnClick', hideSplitFrame)
	hooksecurefunc('MerchantItemButton_OnModifiedClick', hideSplitFrame)
end