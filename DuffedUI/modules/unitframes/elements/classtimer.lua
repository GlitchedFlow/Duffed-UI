local D, C, L = unpack(select(2, ...))
--[[ Configuration functions - DO NOT TOUCH
	id - spell id
	castByAnyone - show if aura wasn't created by player
	color - bar color (nil for default color)
	unitType - 0 all, 1 friendly, 2 enemy
	castSpellId - fill only if you want to see line on bar that indicates if its safe to start casting spell and not clip the last tick, also note that this can be different from aura id
]]--

--[[Configuration starts here]]--
local BAR_HEIGHT = C['classtimer']['height']
local BAR_SPACING = C['classtimer']['spacing']
local SPARK = C['classtimer']['spark']
local CAST_SEPARATOR = C['classtimer']['separator']
local CAST_SEPARATOR_COLOR = C['classtimer']['separatorcolor']
local TEXT_MARGIN = 5
local PERMANENT_AURA_VALUE = 1
local PLAYER_BAR_COLOR = C['classtimer']['playercolor']
local PLAYER_DEBUFF_COLOR = nil
local TARGET_BAR_COLOR = C['classtimer']['targetbuffcolor']
local TARGET_DEBUFF_COLOR = C['classtimer']['targetdebuffcolor']
local TRINKET_BAR_COLOR = C['classtimer']['trinketcolor']
local f, fs, ff = C['media']['font'], 11, 'THINOUTLINE'
local layout = C['unitframes']['style']['Value']
local move = D['move']

local SORT_DIRECTION = true
local TENTHS_TRESHOLD = 1

D['ClassTimer'] = function(self)
	local CreateUnitAuraDataSource
	do
		local auraTypes = { 'HELPFUL', 'HARMFUL' }

		-- private
		local CheckUnit = function(self, unit, result)
			if (not UnitExists(unit)) then return 0 end
			auraType = auraTypes[1]
			if not self.isBuffsSource then
				auraType = auraTypes[2]
			end

			index = 1
			AuraUtil.ForEachAura(unit, auraType, 40, function(name, texture, stacks, _, duration, expirationTime, caster, _, _, spellId)
				local aura = {}
				aura.castSpellId = spellId
				aura.name = name
				aura.texture = texture
				aura.duration = duration
				aura.expirationTime = expirationTime
				aura.stacks = stacks
				aura.unit = unit
				aura.isDebuff = not self.isBuffsSource
				aura.defaultColor = self.defaultColor
				aura.debuffColor = self.debuffColor
				aura.caster = caster
				aura.id = index
				index = index + 1
				table.insert(result, aura)
			end)
		end

		-- public
		local Update = function(self)
			if isBuffsSource then
				-- update buffs
				local buffs = self.buffs
				for index = 1, #buffs do table.remove(buffs) end
				CheckUnit(self, self.unit, buffs, true)
				self.buffs = buffs
			else
				-- update debuffs
				local debuffs = self.debuffs
				for index = 1, #debuffs do table.remove(debuffs) end
				CheckUnit(self, self.unit, debuffs, false)
				self.debuffs = debuffs
			end
		end

		local SetSortDirection = function(self, descending) self.sortDirection = descending end
		local GetSortDirection = function(self) return self.sortDirection end

		local Sort = function(self)
			local direction = self.sortDirection
			local time = GetTime()
			local table = self.GetTable(self)
			local sorted
			repeat
				sorted = true
				for key, value in pairs(table) do
					local nextKey = key + 1
					local nextValue = table[ nextKey ]
					if (nextValue == nil) then break end
					local currentRemaining = value.expirationTime == 0 and 4294967295 or math.max(value.expirationTime - time, 0)
					local nextRemaining = nextValue.expirationTime == 0 and 4294967295 or math.max(nextValue.expirationTime - time, 0)
					if ((direction and currentRemaining < nextRemaining) or (not direction and currentRemaining > nextRemaining)) then
						table[ key ] = nextValue
						table[ nextKey ] = value
						sorted = false
					end
				end
			until (sorted == true)
		end

		local Get = function(self) 
			return self.GetTable(self)
		end

		local Count = function(self) 
			return #self.GetTable(self)
		end

		local GetUnit = function(self) return self.unit end

		local GetTable = function(self) 
			if isBuffsSource then 
				return self.buffs 
			else 
				return self.debuffs
			end
		end

		-- constructor
		CreateUnitAuraDataSource = function(unit, defaultColor, debuffColor, isBuffsSource)
			local result = {}
			result.Sort = Sort
			result.Update = Update
			result.Get = Get
			result.Count = Count
			result.SetSortDirection = SetSortDirection
			result.GetSortDirection = GetSortDirection
			result.GetUnit = GetUnit
			result.unit = unit
			result.buffs = {}
			result.debuffs = {}
			result.defaultColor = defaultColor
			result.debuffColor = debuffColor
			result.isBuffsSource = isBuffsSource
			result.GetTable = GetTable
			return result
		end
	end

	local CreateFramedTexture
	do
		--public
		local SetTexture = function(self, ...) return self.texture:SetTexture(...) end
		local GetTexture = function(self) return self.texture:GetTexture() end
		local GetTexCoord = function(self) return self.texture:GetTexCoord() end
		local SetTexCoord = function(self, ...) return self.texture:SetTexCoord(...) end
		local SetBorderColor = function(self, ...) return self.border:SetVertexColor(...) end

		-- constructor
		CreateFramedTexture = function(parent)
			local result = parent:CreateTexture(nil, 'BACKGROUND', nil)
			local texture = parent:CreateTexture(nil, 'OVERLAY', nil)
			texture:Point('TOPLEFT', result, 'TOPLEFT', 3, -3)
			texture:Point('BOTTOMRIGHT', result, 'BOTTOMRIGHT', -3, 3)
			result.texture = texture
			result.SetTexture = SetTexture
			result.GetTexture = GetTexture
			result.SetTexCoord = SetTexCoord
			result.GetTexCoord = GetTexCoord
			return result
		end
	end

	local CreateAuraBarFrame
	do
		-- classes
		local CreateAuraBar
		do
			-- private
			local OnUpdate = function(self, elapsed)
				local time = GetTime()
				if (time > self.expirationTime) then
					self.bar:SetScript('OnUpdate', nil)
					self.bar:SetValue(0)
					self.time:SetText('')
					local spark = self.spark
					if (spark) then spark:Hide() end
				else
					local remaining = self.expirationTime - time
					self.bar:SetValue(remaining)
					local timeText = ''
					if (remaining >= 3600) then
						timeText = tostring(math.floor(remaining / 3600)) .. D['PanelColor'] .. 'h'
					elseif (remaining >= 60) then
						timeText = tostring(math.floor(remaining / 60)) .. D['PanelColor'] .. 'm'
					elseif (remaining > TENTHS_TRESHOLD) then
						timeText = tostring(math.floor(remaining)) .. D['PanelColor'] .. 's'
					elseif (remaining > 0) then
						timeText = tostring(math.floor(remaining * 10) / 10) .. D['PanelColor'] .. 's'
					end
					self.time:SetText(timeText)
					local barWidth = self.bar:GetWidth()
					local spark = self.spark
					if (spark) then spark:Point('CENTER', self.bar, 'LEFT', barWidth * remaining / self.duration, 0) end

					local castSeparator = self.castSeparator
					if (castSeparator and self.castSpellId) then
						local _, _, _, castTime, _, _ = GetSpellInfo(self.castSpellId)
						castTime = castTime / 1000
						if (castTime and remaining > castTime) then castSeparator:Point('CENTER', self.bar, 'LEFT', barWidth * (remaining - castTime) / self.duration, 0) else castSeparator:Hide() end
					end
				end
			end

			-- public
			local SetIcon = function(self, icon)
				if (not self.icon) then return end
				self.icon:SetTexture(icon)
			end

			local SetTime = function(self, expirationTime, duration)
				self.expirationTime = expirationTime
				self.duration = duration
				if (expirationTime > 0 and duration > 0) then
					self.bar:SetMinMaxValues(0, duration)
					OnUpdate(self, 0)
					local spark = self.spark
					if (spark) then spark:Show() end
					self:SetScript('OnUpdate', OnUpdate)
				else
					self.bar:SetMinMaxValues(0, 1)
					self.bar:SetValue(PERMANENT_AURA_VALUE)
					self.time:SetText('')
					local spark = self.spark
					if (spark) then spark:Hide() end
					self:SetScript('OnUpdate', nil)
				end
			end

			local SetName = function(self, name) self.name:SetText(name) end
			local SetStacks = function(self, stacks)
				if (not self.stacks) then
					if (stacks ~= nil and stacks > 1) then
						local name = self.name
						name:SetText(tostring(stacks) .. '  ' .. name:GetText())
					end
				else
					if (stacks ~= nil and stacks > 1) then self.stacks:SetText(stacks) else self.stacks:SetText('') end
				end
			end

			local SetColor = function(self, color) self.bar:SetStatusBarColor(unpack(color)) end
			local SetCastSpellId = function(self, id)
				self.castSpellId = id
				local castSeparator = self.castSeparator
				if (castSeparator) then
					if (id) then self.castSeparator:Show() else self.castSeparator:Hide() end
				end
			end

			local SetUnit = function(self, unit) self.unit = unit end
			local SetAuraId = function(self, auraId) self.auraId = auraId end

			local SetAuraInfo = function(self, auraInfo)
				self:SetName(auraInfo.name)
				self:SetIcon(auraInfo.texture)
				self:SetTime(auraInfo.expirationTime, auraInfo.duration)
				self:SetStacks(auraInfo.stacks)
				self:SetCastSpellId(auraInfo.castSpellId)
				self:SetUnit(auraInfo.unit)
				self:SetAuraId(auraInfo.id)
			end

			local function UpdateTooltip(self)
				if(GameTooltip:IsForbidden()) then return end
			
				if self.isBuff then
					GameTooltip:SetUnitBuff(self.unit, self.auraId)
				else
					GameTooltip:SetUnitDebuff(self.unit, self.auraId)
				end
			end
			
			local function onEnter(self)
				if(GameTooltip:IsForbidden() or not self:IsVisible()) then return end
			
				GameTooltip:SetOwner(self, 'ANCHOR_CURSOR')
				self:UpdateTooltip()
			end
			
			local function onLeave()
				if(GameTooltip:IsForbidden()) then return end
			
				GameTooltip:Hide()
			end

			-- constructor
			CreateAuraBar = function(parent, isBuffAura)
				local result = CreateFrame('Frame', nil, parent, nil)
				local icon = CreateFramedTexture(result, 'ARTWORK')
				icon:SetTexCoord(.15, .85, .15, .85)

				local iconAnchor1
				local iconAnchor2
				local iconOffset
				iconAnchor1 = 'TOPRIGHT'
				iconAnchor2 = 'TOPLEFT'
				iconOffset = -1
				icon:Point(iconAnchor1, result, iconAnchor2, iconOffset * -5, 3)
				icon:SetWidth(BAR_HEIGHT + 6)
				icon:SetHeight(BAR_HEIGHT + 6)
				result.icon = icon

				local stacks = result:CreateFontString(nil, 'OVERLAY', nil)
				stacks:SetFont(f, fs, ff)
				stacks:SetShadowColor(0, 0, 0)
				stacks:SetShadowOffset(1.25, -1.25)
				stacks:SetJustifyH('RIGHT')
				stacks:SetJustifyV('BOTTOM')
				stacks:Point('TOPLEFT', icon, 'TOPLEFT', 0, 0)
				stacks:Point('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', -1, 3)
				result.stacks = stacks

				local bar = CreateFrame('StatusBar', nil, result, nil)
				bar:SetStatusBarTexture(C['media']['normTex'])
				bar:Point('TOPLEFT', result, 'TOPLEFT', 9, 0)
				bar:Point('BOTTOMRIGHT', result, 'BOTTOMRIGHT', 0, 0)
				result.bar = bar

				if (SPARK) then
					local spark = bar:CreateTexture(nil, 'OVERLAY', nil)
					spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
					spark:SetWidth(12)
					spark:SetBlendMode('ADD')
					spark:Show()
					result.spark = spark
				end

				if (CAST_SEPARATOR) then
					local castSeparator = bar:CreateTexture(nil, 'OVERLAY', nil)
					castSeparator:SetTexture(unpack(CAST_SEPARATOR_COLOR))
					castSeparator:SetWidth(1)
					castSeparator:SetHeight(BAR_HEIGHT)
					castSeparator:Show()
					result.castSeparator = castSeparator
				end

				local name = bar:CreateFontString(nil, 'OVERLAY', nil)
				name:SetFont(f, fs, ff)
				name:SetShadowColor(0, 0, 0)
				name:SetShadowOffset(1.25, -1.25)
				name:SetJustifyH('LEFT')
				name:Point('TOPLEFT', bar, 'TOPLEFT', TEXT_MARGIN, 0)
				name:Point('BOTTOMRIGHT', bar, 'BOTTOMRIGHT', -45, 0)
				result.name = name

				local time = bar:CreateFontString(nil, 'OVERLAY', nil)
				time:SetFont(f, fs, ff)
				time:SetJustifyH('RIGHT')
				time:Point('LEFT', name, 'RIGHT', 0, 0)
				time:Point('RIGHT', bar, 'RIGHT', -TEXT_MARGIN, 0)
				result.time = time

				result.SetIcon = SetIcon
				result.SetTime = SetTime
				result.SetName = SetName
				result.SetStacks = SetStacks
				result.SetUnit = SetUnit
				result.SetAuraId = SetAuraId
				result.SetAuraInfo = SetAuraInfo
				result.SetColor = SetColor
				result.SetCastSpellId = SetCastSpellId

				result.UpdateTooltip = UpdateTooltip

				result.unit = {}
				result.auraId = {}
				result.isBuff = isBuffAura

				result:SetScript('OnEnter', onEnter)
				result:SetScript('OnLeave', onLeave)

				return result
			end
		end

		-- private
		local SetAuraBar = function(self, index, auraInfo)
			local line = self.lines[ index ]
			if (line == nil) then
				line = CreateAuraBar(self, self.dataSource.isBuffsSource)
				if (index == 1) then
					line:Point('TOPLEFT', self, 'BOTTOMLEFT', 13, BAR_HEIGHT)
					line:Point('BOTTOMRIGHT', self, 'BOTTOMRIGHT', 0, 0)
				else
					local anchor = self.lines[ index - 1 ]
					line:Point('TOPLEFT', anchor, 'TOPLEFT', 0, BAR_HEIGHT + BAR_SPACING)
					line:Point('BOTTOMRIGHT', anchor, 'TOPRIGHT', 0, BAR_SPACING)
				end
				tinsert(self.lines, index, line)
			end
			line:SetAuraInfo(auraInfo)
			if (auraInfo.color) then
				line:SetColor(auraInfo.color)
			elseif (auraInfo.debuffColor and auraInfo.isDebuff) then
				line:SetColor(auraInfo.debuffColor)
			elseif (auraInfo.defaultColor) then
				line:SetColor(auraInfo.defaultColor)
			end
			line:Show()
		end

		local function OnUnitAura(self, unit)
			if (unit ~= self.unit) then return end
			self:Render()
		end

		local function OnPlayerTargetChanged(self, method) self:Render() end
		local function OnPlayerEnteringWorld(self) self:Render() end
		local function OnEvent(self, event, ...)
			if (event == 'UNIT_AURA') then
				OnUnitAura(self, ...)
			elseif (event == 'PLAYER_TARGET_CHANGED') then
				OnPlayerTargetChanged(self, ...)
			elseif (event == 'PLAYER_ENTERING_WORLD') then
				OnPlayerEnteringWorld(self)
			else
				error('Unhandled event ' .. event)
			end
		end

		-- public
		local function Render(self)
			local dataSource = self.dataSource

			dataSource:Update()
			dataSource:Sort()
			local count = dataSource:Count()
			local runningCount = 0
			for index, auraInfo in ipairs(dataSource:Get()) do 
				if (not C['classtimer']['showpermabuffs'] and (auraInfo.expirationTime > 0 and auraInfo.duration > 0)) then
					runningCount = runningCount + 1
					SetAuraBar(self, runningCount, auraInfo) 
				elseif (C['classtimer']['showpermabuffs']) then
					runningCount = runningCount + 1
					SetAuraBar(self, runningCount, auraInfo) 
				end
			end
			for index = runningCount + 1, 80 do
				local line = self.lines[ index ]
				if (line == nil or not line:IsShown()) then break end
				line:Hide()
			end
			if (runningCount > 0) then
				self:SetHeight((BAR_HEIGHT + BAR_SPACING) * runningCount - BAR_SPACING)
				self:Show()
			else
				self:Hide()
				self:SetHeight(self.hiddenHeight or 1)
			end
		end

		-- constructor
		CreateAuraBarFrame = function(dataSource, parent)
			local result = CreateFrame('Frame', nil, parent, nil)
			local unit = dataSource:GetUnit()

			result.unit = unit
			result.lines = {}
			result.dataSource = dataSource

			local background = CreateFrame('Frame', nil, result, nil)
			background:SetFrameStrata('BACKGROUND')
			background:Point('TOPLEFT', result, 'TOPLEFT', 20, 2)
			background:Point('BOTTOMRIGHT', result, 'BOTTOMRIGHT', 2, -2)
			background:SetTemplate('Transparent')
			result.background = background

			local border = CreateFrame('Frame', nil, result, nil, 'BackdropTemplate')
			border:SetFrameStrata('BACKGROUND')
			border:Point('TOPLEFT', result, 'TOPLEFT', 21, 1)
			border:Point('BOTTOMRIGHT', result, 'BOTTOMRIGHT', 1, -1)
			border:SetTemplate('Default')
			border:SetBackdropColor(0, 0, 0, 0)
			border:SetBackdropBorderColor(unpack(C['media']['backdropcolor']))
			result.border = border

			iconborder = CreateFrame('Frame', nil, result)
			iconborder:SetTemplate('Default')
			iconborder:Size(1, 1)
			iconborder:Point('TOPLEFT', result, 'TOPLEFT', -2, 2)
			iconborder:Point('BOTTOMRIGHT', result, 'BOTTOMLEFT', BAR_HEIGHT + 2, -2)

			result:RegisterEvent('PLAYER_ENTERING_WORLD')
			result:RegisterEvent('UNIT_AURA')
			if (unit == 'target') then result:RegisterEvent('PLAYER_TARGET_CHANGED') end
			result:SetScript('OnEvent', OnEvent)
			result.Render = Render
			return result
		end
	end

	if C['classtimer']['buffsenable'] then
		local playerDataSource = CreateUnitAuraDataSource('player', PLAYER_BAR_COLOR, PLAYER_DEBUFF_COLOR, true)

		playerDataSource:SetSortDirection(SORT_DIRECTION)

		local playerFrame = CreateAuraBarFrame(playerDataSource, self.Health)
		local playerBuffMover = CreateFrame('Frame', 'PlayerBuffMover', UIParent)
		playerBuffMover:SetSize(218, 15)
		
		if layout == 3 then
			playerBuffMover:SetPoint('BOTTOM', self.Health, 'BOTTOM', 0, 25)
			playerFrame:Point('BOTTOMLEFT', playerBuffMover, 'TOPLEFT', 0, 25)
			playerFrame:Point('BOTTOMRIGHT', playerBuffMover, 'TOPRIGHT', 0, 25)
		else
			playerBuffMover:SetPoint('BOTTOM', self.Health, 'BOTTOM', 0, 7)
			playerFrame:Point('BOTTOMLEFT', playerBuffMover, 'TOPLEFT', 0, 7)
			playerFrame:Point('BOTTOMRIGHT', playerBuffMover, 'TOPRIGHT', 0, 7)
		end

		move:RegisterFrame(playerBuffMover)
	end
	if C['classtimer']['debuffsenable'] then
		local playerDebuffDataSource = CreateUnitAuraDataSource('player', TARGET_BAR_COLOR, TARGET_DEBUFF_COLOR, false)
		playerDebuffDataSource:SetSortDirection(SORT_DIRECTION)

		local playerDebuffFrame = CreateAuraBarFrame(playerDebuffDataSource, self.Health)
		local playerDebuffMover = CreateFrame('Frame', 'PlayerDebuffMover', UIParent)
		playerDebuffMover:SetSize(218, 15)

		if layout == 3 then
			playerDebuffMover:SetPoint('BOTTOM', self.Health, 'BOTTOM', 0, 25)
			playerDebuffFrame:Point('TOPLEFT', playerDebuffMover, 'BOTTOMLEFT', 0, 25)
			playerDebuffFrame:Point('TOPRIGHT', playerDebuffMover, 'BOTTOMRIGHT', 0, 25)
		else
			playerDebuffMover:SetPoint('BOTTOM', self.Health, 'BOTTOM', 0, 7)
			playerDebuffFrame:Point('TOPLEFT', playerDebuffMover, 'BOTTOMLEFT', 0, 7)
			playerDebuffFrame:Point('TOPRIGHT', playerDebuffMover, 'BOTTOMRIGHT', 0, 7)
		end

		move:RegisterFrame(playerDebuffMover)
	end
	if C['classtimer']['targetdebuff'] then
		local targetDataSource = CreateUnitAuraDataSource('target', TARGET_BAR_COLOR, TARGET_DEBUFF_COLOR, false)
		targetDataSource:SetSortDirection(SORT_DIRECTION)

		local targetFrame = CreateAuraBarFrame(targetDataSource, self.Health)
		local debuffMover = CreateFrame('Frame', 'DebuffMover', UIParent)
		debuffMover:SetSize(218, 15)
		debuffMover:SetPoint('BOTTOM', UIParent, 'BOTTOM', 340, 380)
		move:RegisterFrame(debuffMover)

		targetFrame:Point('BOTTOMLEFT', DebuffMover, 'TOPLEFT', 0, 5)
		targetFrame:Point('BOTTOMRIGHT', DebuffMover, 'TOPRIGHT', 0, 5)
	end
end
