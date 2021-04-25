local D, C, L = unpack(select(2, ...))

local ab = D['Actions']
local format = format
local NUM_ACTIONBAR_BUTTONS = NUM_ACTIONBAR_BUTTONS
local NUM_PET_ACTION_SLOTS = NUM_PET_ACTION_SLOTS
local NUM_STANCE_SLOTS = NUM_STANCE_SLOTS
local MainMenuBar, MainMenuBarArtFrame = MainMenuBar, MainMenuBarArtFrame
local ShapeshiftBarLeft, ShapeshiftBarMiddle, ShapeshiftBarRight = ShapeshiftBarLeft, ShapeshiftBarMiddle, ShapeshiftBarRight

local Frames = {
	MainMenuBar,
	MainMenuBarArtFrame, 
	OverrideActionBar,
	PossessBarFrame, 
	ShapeshiftBarLeft, 
	ShapeshiftBarMiddle, 
	ShapeshiftBarRight,
	TalentMicroButtonAlert, 
	CollectionsMicroButtonAlert, 
	EJMicroButtonAlert, 
	CharacterMicroButtonAlert
}

function ab:DisableBlizzard()
	for _, frame in pairs(Frames) do
		frame:UnregisterAllEvents()
		frame:SetParent(DuffedUIHider)
	end

	ActionBarButtonEventsFrame:UnregisterEvent('ACTIONBAR_SHOWGRID')
	ActionBarButtonEventsFrame:UnregisterEvent('ACTIONBAR_HIDEGRID')
	ActionBarButtonEventsFrame:UnregisterEvent('UPDATE_BINDINGS')
	PetActionBarFrame:UnregisterEvent('PET_BAR_SHOWGRID')
	PetActionBarFrame:UnregisterEvent('PET_BAR_HIDEGRID')
	PetActionBar_ShowGrid()
	MultiActionBar_Update = D['Dummy']
end

function ab:MovePetBar()
	local PetBar = DuffedUIPetBar
	local RightBar = DuffedUIBar5
	local Data1 = DuffedUIDataPerChar['Move']['DuffedUIPetBar']
	local Data2 = DuffedUIDataPerChar['Move']['DuffedUIBar5']

	-- Don't run if player moved bar 5 or pet bar
	if Data1 or Data2 then return end
	if RightBar:IsShown() then PetBar:SetPoint('RIGHT', RightBar, 'LEFT', -6, 0) else PetBar:SetPoint('RIGHT', UIParent, 'RIGHT', -28, 8) end
end

function ab:UpdatePetBar()
	for i=1, NUM_PET_ACTION_SLOTS, 1 do
		local ButtonName = 'PetActionButton' .. i
		local PetActionButton = _G[ButtonName]

		PetActionButton:SetNormalTexture('')
	end
end

function ab:UpdateStanceBar()
	if InCombatLockdown() then return end
	
	local NumForms = GetNumShapeshiftForms()
	local Texture, Name, IsActive, IsCastable, Button, Icon, Cooldown, Start, Duration, Enable
	local PetSize = D['petbuttonsize']
	local Spacing = D['buttonspacing']

	if NumForms == 0 then
		DuffedUIStance:SetAlpha(0)
	else
		DuffedUIStance:SetAlpha(1)
		DuffedUIStance:SetSize((PetSize * NumForms) + (Spacing * (NumForms + 1)), PetSize + (Spacing * 2))

		for i = 1, NUM_STANCE_SLOTS do
			local ButtonName = 'StanceButton'..i

			Button = _G[ButtonName]
			Icon = _G[ButtonName..'Icon']
			Button:SetNormalTexture('')

			if i <= NumForms then
				Texture, IsActive, IsCastable = GetShapeshiftFormInfo(i)

				if not Icon then return end

				Icon:SetTexture(Texture)
				Cooldown = _G[ButtonName..'Cooldown']

				if Texture then Cooldown:SetAlpha(1) else Cooldown:SetAlpha(0) end

				Start, Duration, Enable = GetShapeshiftFormCooldown(i)
				CooldownFrame_Set(Cooldown, Start, Duration, Enable)

				if IsActive then
					StanceBarFrame.lastSelected = Button:GetID()
					Button:SetChecked(true)
					if Button.Backdrop then Button.Backdrop:SetBorderColor(0, 1, 0) end
				else
					Button:SetChecked(false)
					if Button.Backdrop then Button.Backdrop:SetBorderColor(unpack(C.General.BorderColor)) end
				end

				if IsCastable then Icon:SetVertexColor(1.0, 1.0, 1.0) else Icon:SetVertexColor(0.4, 0.4, 0.4) end
			end
		end
	end
end

function ab:RangeUpdate(hasrange, inrange)
	local Icon = self.icon
	local NormalTexture = self.NormalTexture
	local ID = self.action

	if not ID then return end
	
	local IsUsable, NotEnoughPower = IsUsableAction(ID)
	local HasRange = hasrange
	local InRange = inrange

	if IsUsable then
		if (HasRange and InRange == false) then
			Icon:SetVertexColor(0.8, 0.1, 0.1)
			NormalTexture:SetVertexColor(0.8, 0.1, 0.1)
		else
			Icon:SetVertexColor(1.0, 1.0, 1.0)
			NormalTexture:SetVertexColor(1.0, 1.0, 1.0)
		end
	elseif NotEnoughPower then
		Icon:SetVertexColor(0.1, 0.3, 1.0)
		NormalTexture:SetVertexColor(0.1, 0.3, 1.0)
	else
		Icon:SetVertexColor(0.3, 0.3, 0.3)
		NormalTexture:SetVertexColor(0.3, 0.3, 0.3)
	end
end

function ab:StartHighlight()
	if not self.Animation then
		self.Animation = self:CreateAnimationGroup()
		self.Animation:SetLooping('BOUNCE')

		self.Animation.FadeOut = self.Animation:CreateAnimation('Alpha')
		self.Animation.FadeOut:SetFromAlpha(1)
		self.Animation.FadeOut:SetToAlpha(.3)
		self.Animation.FadeOut:SetDuration(.3)
		self.Animation.FadeOut:SetSmoothing('IN_OUT')
	end
	
	-- Hide Blizard Proc
	if self.overlay and self.overlay:GetParent() ~= DuffedUIHider then self.overlay:SetParent(DuffedUIHider) end
	
	if not self.Animation:IsPlaying() then
		self.Animation:Play()
		if self.Backdrop then self.Backdrop:SetBorderColor(1, 1, 0) end
	end
end

function ab:StopHightlight()
	if self.Animation and self.Animation:IsPlaying() then
		self.Animation:Stop()
		if self.Backdrop then self.Backdrop:SetBorderColor(unpack(C['general']['bordercolor'])) end
	end
end

function ab:Cooldown(start, duration, enable, charges, maxcharges, forceShowdrawedge)
	local Enabled = GetCVar('countdownForCooldowns')
	if not Enabled == 1 then SetCVar('countdownForCooldowns', 1) end

	if (Enabled) then
		if not self:IsForbidden() then
			if not self.IsCooldownTextEdited then
				local NumRegions = self:GetNumRegions()

				for i = 1, NumRegions do
					local Region = select(i, self:GetRegions())

					if Region.GetText then
						local Font = C['media']['font']
						
						Region:SetFont(Font, 12, 'OUTLINE')
						Region:SetPoint('CENTER', 1, 0)
						Region:SetTextColor(1, 1, 0)
					end
				end

				self.IsCooldownTextEdited = true
			end
		end
	end
end

function ab:AddHooks()
	hooksecurefunc('ActionButton_UpdateFlyout', self.StyleFlyout)
	hooksecurefunc('SpellButton_OnClick', self.StyleFlyout)
	hooksecurefunc('ActionButton_UpdateRangeIndicator', ab.RangeUpdate)
	if C['actionbar']['borderhighlight'] then
		hooksecurefunc('ActionButton_ShowOverlayGlow', ab.StartHighlight)
		hooksecurefunc('ActionButton_HideOverlayGlow', ab.StopHightlight)
	end
	if (not IsAddOnLoaded('OmniCC') or IsAddOnLoaded('ncCooldown') or C['cooldown']['enable']) then
		hooksecurefunc('CooldownFrame_Set', ab.Cooldown)
	end
end

function ab:OnEvent() self:UpdateHotKeys() end

function ab:FixMBBR()
	for i = 1, 6 do
		local Button = _G['MultiBarBottomRightButton'..i]

		Button:SetAttribute('showgrid', 1)
		Button.noGrid = nil
		Button:ShowGrid(ACTION_BUTTON_SHOW_GRID_REASON_CVAR)
		Button:Show()
	end
end

function ab:Enable()
	if not C['actionbar']['enable'] then return end
	
	SetCVar('alwaysShowActionBars', 1)

	self:DisableBlizzard()
	self:CreateBar1()
	self:CreateBar2()
	if not C['actionbar']['LeftSideBarDisable'] then self:CreateBar3() end
	if not C['actionbar']['RightSideBarDisable'] then self:CreateBar4() end
	if not C['actionbar']['rightbarDisable'] then self:CreateBar5() end
	self:CreatePetBar()
	self:CreateStanceBar()
	self:SetupExtraButton()
	self:AddHooks()
	self:FixMBBR()
	MainMenuMicroButton_SetAlertsEnabled(false, "not needed")
	
	self:RegisterEvent('UPDATE_BINDINGS')
	self:RegisterEvent('PLAYER_ENTERING_WORLD')
	self:SetScript('OnEvent', self.OnEvent)
end

ab:RegisterEvent('ADDON_LOADED')
ab:RegisterEvent('PLAYER_LOGIN')
ab:RegisterEvent('PLAYER_ENTERING_WORLD')
ab:SetScript('OnEvent', function(self, event, ...)
	if event == 'PLAYER_LOGIN' then ab:Enable() elseif event == 'PLAYER_ENTERING_WORLD' then ab:FixMBBR() end
end)