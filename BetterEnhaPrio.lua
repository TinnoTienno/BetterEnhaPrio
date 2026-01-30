--[[

    BetterEnhaPrio by Noda
    Simple addon to display Enhance Shamans spellcasting/abilities priorities
    depending on the situation.
    Inspired and based on EnhaPrio by Stormcast

    Legend:

    SS - Stormstrike
    LB - Lightning Bolt
    FS - Flame Shock
    LS - Lightning Shield
    MT - Magma Totem
    ES - Earth Shock
    LL - Lava Lash
    MS - Maelstrom
    WF - Windfury weapon
    FT - Flame Tongue
    SR - Shamanistic Rage
    FN - Fire Nova
    FE - Fire Elemental Totem
    SR - Shamanistic Rage

    This addon doesn't take long cooldown abilities like Feral Spirit or
    Fire Elemental into account. Usage of those skills is up to you (they
    are still an important part of enhance shamans skillset during bosses).

    Shamanistic Rage will be suggested when you are low on mana. And if you
    are missing weapon buffs, they will be suggested too.

This is the priority. You can change the order of these, if you think it necessary
or comment out with "--" if not wanted. ]]
Priority = {
	"WF", -- weapon buffs (windfury)
	"FT", -- weapon buffs (flametongue)
	
	"SR", -- Shamanistic Rage when you have less than 20% mana
	
	"LB", -- Lightning Bolt if there are 5 Maelstrom stacks
	"FS", -- Flame Shock if there's less than 1.5 sec left on the dot
	"SSb", -- Stormstrike if there's no ss buff on the target
	"LS", -- Lightning Shield if it isn't active on you
	"MT", -- Magma Totem if you don't have one down
	"ES", -- Earth Shock
	"SS", -- Stormstrike even if there's a ss buff on the target
	"LL", -- Lava Lash
	"FN"  -- Fire Nova
}


--[[ Ok, don't mess with anything below this (unless you know what you're doing ofc) ]]--


-- initialize the variables (make them globals)
local EnhaPrio = LibStub( "AceAddon-3.0" ):NewAddon( "EnhaPrio", "AceConsole-3.0", "AceEvent-3.0" );
local LBF = LibStub("LibButtonFacade", true);
if LBF then
    Group = LBF:Group("EnhaPrio");
end
local mainFrame, target, skins;
local maxQueueSize = 8;
local queue = {};
local cdqueue = {};
hasMS = false;
hasLS = false;
hasMT = false;
melee = false;
ranged = false;
fsLeft = 0;
noSS = false;
noLS = false;
hostile = false;
lowMana = false;
hasMH = false;
hasOH = false;
timeLeft = 0;
mwAmount = 0;
isEnha = false;




-- button facade
-- Save the settings to the appropriate section in the saved variables file.
function EnhaPrio:SkinCallback(SkinID, Gloss, Backdrop, grp, Button, Colors)
        self.db.char.bf.SkinID = SkinID
        self.db.char.bf.Gloss = Gloss
        self.db.char.bf.Backdrop = Backdrop
        self.db.char.bf.Colors = Colors
end

-- configs (default values)
local defaults = {
	char = {
		x = 0,
		y = 0,
		relativePoint = "CENTER",
		size = 50,
		spacing = 0,
		locked = false,
		updateFrequency = .2,
		manaThreshold = 20,
		maxQueue = 4,
		displayMW = true,
		queueDirection = "RIGHT",
		displayGCD = true,
		enableAOE = true,
		enableLongCD = true,
        bf = {
            SkinID = "Blizzard",
            Gloss = 0,
            Backdrop = true,
            Colors = {}
        }
	}
};


-- the spells we'll be using
local Spells = {
	SS = {id = 17364, name = GetSpellInfo(17364)},
	LL = {id = 60103, name = GetSpellInfo(60103)},
	ES = {id = 49231, name = GetSpellInfo(49231)},
	MS = {id = 51532, name = GetSpellInfo(51532)},
	WF = {id = 25505, name = GetSpellInfo(58804)},
	FT = {id = 25489, name = GetSpellInfo(58790)},
	LB = {id = 49238, name = GetSpellInfo(49238)},
	LS = {id = 49281, name = GetSpellInfo(49281)},
	SR = {id = 30823, name = GetSpellInfo(30823)},
	FE = {id = 2894, name = GetSpellInfo(2894)},
	FS = {id = 49233, name = GetSpellInfo(49233)},
	MT = {id = 58734, name = GetSpellInfo(58734)},
	FN = {id = 61654, name = GetSpellInfo(61654)},
}


-- here are the different actions (adding stuff to queue according to the situation)
local Actions = {

	WF = function ()
		if not hasMH then
			addToQueue(Spells.WF.name);
		end
	end,
	
	FT = function ()
		if not hasOH then
			addToQueue(Spells.FT.name);
		end
	end,

	SR = function ()
		-- do shamanistic rage
		if isCastable(Spells.SR.name) and lowMana and melee then
			addToQueue(Spells.SR.name);
		end
	end,

	LB = function ()
		-- do lb, if 5 buffs
		if hasMS and ranged then
			addToQueue(Spells.LB.name);
		end
	end,
	
	FS = function ()
		-- if there is under 1.5sec left on flame shock on the target
		if isCastable(Spells.FS.name) and ranged and fsLeft <= 3 then
			addToQueue(Spells.FS.name);
		end
	end,
	
	SSb = function ()
		-- if the target doesn't have your ss buff on, do it
		if noSS and isCastable(Spells.SS.name) and melee then
			addToQueue(Spells.SS.name);
		end
	end,
	
	LS = function ()
		-- lightningshield
		if noLS then
			addToQueue(Spells.LS.name);
		end
	end,
	
	MT = function ()
		-- magma totem
		if not hasMT and melee and EnhaPrio.db.char.enableAOE then
			addToQueue(Spells.MT.name);
		end
	end, 
	
	ES = function ()
		-- earth shock
		if isCastable(Spells.ES.name) and ranged and fsLeft > 3 then
			addToQueue(Spells.ES.name);
		end
	end,
	
	SS = function () 
		-- Stormstrike
		if not noSS and isCastable(Spells.SS.name) and melee then
			addToQueue(Spells.SS.name);
		end
	end,
	
	LL = function ()
		-- lava lash
		if isCastable(Spells.LL.name) and melee then
			addToQueue(Spells.LL.name);
		end	
	end,
	
	FN = function ()
		-- fire nova
		if isCastable(Spells.FN.name) and hasMT and EnhaPrio.db.char.enableAOE then
			addToQueue(Spells.FN.name);
		end
	end		
}

local Cooldowns = {	
	"FS", "LS", "MT", "ES", "SS", "LL", "FN"
}


-- makes a queue of cooldowns
function makeCDQueue()
	local cdq = {};
	for i, n in pairs(Cooldowns) do
		if getCD(n) > 0 then
		    if (n ~= "MT" and n ~= "FN") or ((n == "MT" or n == "FN") and EnhaPrio.db.char.enableAOE) then
				table.insert(cdq, n);
			end
		end
	end
	
	local ssDebuff = UnitDebuff("target", "Stormstrike", _, "PLAYER");

	local sorter = function (a, b)
		-- if the difference between cooldowns is less than a second,
		-- treat them as having the same cd (so priority should come
		-- from the priority list)
		if math.abs(getCD(a) - getCD(b)) < 0.5 then
		
			if a == "SS" and ssDebuff then a = "SSb" end
			if b == "SS" and ssDebuff then b = "SSb" end
			
		  	for i, v in ipairs(Priority) do
		  		if v == a then av = i end
		  		if v == b then bv = i end
		  	end
		  	return av < bv;
		else
			return getCD(a) < getCD(b);
		end
	end
	
	table.sort(cdq, sorter);
	cdqueue = {};
	for i, n in ipairs(cdq) do
		table.insert(cdqueue, Spells[n].name);
	end
end

-- get the time when the spell should be cast again (used for cd queue)
function getCD(n)
	local start, duration;
	
	-- gcd control
	gcdstart, gcdduration = GetSpellCooldown(Spells.LB.name);
	gcdtime = gcdstart + gcdduration;
	
	if n == "FE" or n == "MT" then
		_, _, start, duration = GetTotemInfo(1);
	else
		start, duration = GetSpellCooldown(Spells[n].name);
	end
	
	local left = start + duration - GetTime();
	
	if n == "ES" and left >= (fsLeft - 3) then
		duration = 0;
	end
	if n == "FS" and left < (fsLeft - 3) then
		duration = 0;
	end
	
	if n == "FN" and not hasMT then
		duration = 0;
	end
	
	if duration > 0 and (start + duration) > gcdtime then
		return start + duration;
	else
		return 0;
	end
end


-- can you cast that spell
function isCastable(spellName)
	-- check if you can cast that spell in one gcd
	local _, GCD = GetSpellCooldown(Spells.LB.name);
	local _, duration = GetSpellCooldown(spellName);
	return duration == GCD;
end

-- add a spell to the queue
function addToQueue(spell)
	queue[#queue+1] = spell;
end

-- round a number (odd that lua doesn't have that in standard classes)
function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end


-- refreshes the queue according to the priorities
-- check stuff and then run the queue
function refreshQueue() 
	
	-- players buffs (maelstrom, lightning shield)
	noLS = true;
	hasMS = false;
	mwAmount = 0;
	for i=1,40 do
		local name, _, _, count = UnitBuff("player", i);
		if not name then
			break; -- end of buffs
		end
		if name == Spells.MS.name then
		    mwAmount = count;
			if count == 5 then
				hasMS = true;
			end
		elseif name == Spells.LS.name then
			noLS = false;
		end
	end
	
	-- targets debuffs (fire shock)
	noSS = true;
	fsLeft = 0;
	for i=1,40 do
		local name, _, _, _, _, _, expirationTime, caster = UnitDebuff("target", i);
		if not name then
			break; -- end of debuffs
		end
		if caster == "player" and name == Spells.FS.name then
			fsLeft = expirationTime - GetTime();
		elseif caster == "player" and name == Spells.SS.name then
			noSS = false;
		end
	end
	
	-- totems (magma or elemental)
	local _, totemName = GetTotemInfo(1);	
	if totemName == "Magma Totem VII" or totemName == Spells.FE.name then
		hasMT = true;
	else
		hasMT = false;
	end
	
	-- weapon buffs
	hasMH, _, _, hasOH = GetWeaponEnchantInfo();
	
	-- mana situation
	local mana = UnitPower('player');
  	local maxMana = UnitPowerMax('player');
  	if mana < ((EnhaPrio.db.char.manaThreshold / 100) * maxMana) then
  		lowMana = true;
  	else
  		lowMana = false;
  	end 
	
	-- ranges
	melee = IsSpellInRange(Spells.LB.name, 'target') == 1; -- if you are in range of melee attacks (using flame shock here too... )
	ranged = IsSpellInRange(Spells.LB.name, 'target') == 1; -- if you are in range of flame shock

  	-- now loop through the actions
	for i, v in ipairs(Priority) do
		Actions[v]();
	end
end

function EnhaPrio:reCalculate()
	-- check if the target is hostile and you are not mounted or on a vehicle or dead
	queue = {};
	hostile = UnitName("target") and UnitCanAttack("player","target") and UnitHealth("target") > 0;
	mounted = false; --- make it work!!!
	dead = UnitHealth("target") < 1;
	yourdead = UnitHealth("player") < 1;
	local maxQueueSize = self.db.char.maxQueue;
	isEnha = GetSpellCooldown(Spells.SS.name) ~= nil;

	if hostile and not yourdead and isEnha then
	    timeLeft = self.db.char.updateFrequency;
		refreshQueue();
		makeCDQueue();
	
	    -- show maelstrom wep
	    if self.db.char.displayMW and mwAmount > 0 and ranged then
	        mainFrame.text:SetText(mwAmount);
	        if mwAmount == 1 then
	        	mainFrame.text:SetTextColor(1, 1, 1, 1);
			elseif mwAmount == 2 then
			    mainFrame.text:SetTextColor(1, 1, 0, 1);
			elseif mwAmount == 3 then
			    mainFrame.text:SetTextColor(1, 1, 0, 1);
			elseif mwAmount == 4 then
			    mainFrame.text:SetTextColor(1, .5, 0, 1);
			elseif mwAmount == 5 then
			    mainFrame.text:SetTextColor(1, 0, 0, 1);
			end
		else
		    mainFrame.text:SetText("");
	    end
	    
	    if not self.db.char.enableAOE and ranged then
			mainFrame.AOEtext:SetText("AOE");
		else
            mainFrame.AOEtext:SetText("");
		end
	    
	    
	    -- wolf and ele
	    if self.db.char.enableLongCD then
	    	if isCastable(mainFrame.wolf.id) and ranged then
	    		mainFrame.wolf.texture:SetTexture(GetSpellTexture("Feral Spirit"));
				mainFrame.wolf:Show();
			else
				mainFrame.wolf.texture:SetTexture(nil);
				mainFrame.wolf:Hide();
			end
			if isCastable(mainFrame.elemental.id) and ranged then
				mainFrame.elemental.texture:SetTexture(GetSpellTexture("Fire Elemental Totem"));
				mainFrame.elemental:Show();
			else
				mainFrame.elemental.texture:SetTexture(nil);
				mainFrame.elemental:Hide();
			end
	    end
	    
	    
	    
	    -- merge the normal and cd queues
	    local tillcd = #queue;
	    for i, n in ipairs(cdqueue) do table.insert(queue, n) end

		-- let's draw the queue
		for i=1, maxQueueSize do
			local spell = queue[i];
			local f = spellQueueFrames[i];
			f.spell = spell;
			if spell then
			
				if i <= tillcd then
					-- normal skills
					f.spellTexture:SetTexture(GetSpellTexture(spell));
					check(f, spell);
					if i > 1 then CooldownFrame_SetTimer(f.cooldown, 0, 0, 0) end
					f.cooldownText:SetText("");
					f:SetAlpha(1);
	    			f:Show();
    			else
    				-- normal queue ended, going on cooldowns
					f.spellTexture:SetTexture(GetSpellTexture(spell));
					local start, duration;
					if spell == Spells.MT.name then
						_, _, start, duration = GetTotemInfo(1);
					else
						start, duration = GetSpellCooldown(spell);
					end
					check(f, spell);
				    CooldownFrame_SetTimer(f.cooldown, start, duration, 1);
				    local left = round(start + duration - GetTime());
				    if left > 0 then f.cooldownText:SetText(left) else f.cooldownText:SetText("") end
				    f:SetAlpha(0.7);
					f:Show();
				end
    			
			else
				-- nothing left in the queues
				f.spellTexture:SetTexture(nil);
				f.cooldownText:SetText("");
				f:SetAlpha(1);
    			f:Hide();
			end
		end
	else
		-- clear the icons
		for i=maxQueueSize,1,-1 do
			local spell = queue[i];
			local f = spellQueueFrames[i];
			f.spellTexture:SetTexture(nil);
			f:Hide();
		end
		
		mainFrame.text:SetText("");
		mainFrame.AOEtext:SetText("");
		mainFrame.wolf:Hide();
		mainFrame.elemental:Hide();
	end
end

-- check for out of mana or out of range
function check(f, spell)
	name, _, _, cost = GetSpellInfo(spell);
	if IsSpellInRange(spell, 'target') == 0 then
	    f.spellTexture:SetVertexColor(1, 0, 0);
	elseif cost and UnitPower('player') < cost then
	    f.spellTexture:SetVertexColor(0.4, 0.4, 0.4);
	else
	    f.spellTexture:SetVertexColor(1, 1, 1);
	end
end

-- functions to take care of the addon (visuals and saving etc)
function EnhaPrio:SaveLocation()
	point, relativeTo, relativePoint, xOfs, yOfs = mainFrame:GetPoint();
	self.db.char.x = xOfs;
	self.db.char.y = yOfs;
	self.db.char.relativePoint = relativePoint;
end

-- change the aoe setting
function EnhaPrio:ChangeAOE()
	self.db.char.enableAOE = not self.db.char.enableAOE;
	if not self.db.char.enableAOE and ranged then
		mainFrame.AOEtext:SetText("AOE");
	else 
		mainFrame.AOEtext:SetText("");
	end
end

function EnhaPrio:RepositionFrames(queue)
    local maxQueueSize = self.db.char.maxQueue;
    local spacing = self.db.char.spacing;

	if queue then
	    for i, f in ipairs(spellQueueFrames) do
	  		f:Hide();
		end
		mainFrame.wolf:Hide();
		mainFrame.elemental:Hide();
	end
	
	-- text
	mainFrame.text:SetTextHeight(self.db.char.size / 2);
	mainFrame.text:ClearAllPoints();
	if self.db.char.queueDirection == "LEFT" then
		mainFrame.text:SetPoint("LEFT", mainFrame, "RIGHT", spacing, 0);
	else
	    mainFrame.text:SetPoint("RIGHT", mainFrame, "LEFT", (spacing * -1), 0);
	end
	
	-- aoe text
	mainFrame.AOEtext:SetFont("Fonts\\FRIZQT__.TTF", self.db.char.size * 0.25, "OUTLINE");
	mainFrame.AOEtext:ClearAllPoints();
	if self.db.char.queueDirection == "UP" then
		mainFrame.AOEtext:SetPoint("TOP", mainFrame, "BOTTOM", 0, spacing);
	else
		mainFrame.AOEtext:SetPoint("BOTTOM", mainFrame, "TOP", 0, spacing);
	end
    	
	-- wolf and elemental frames
	mainFrame.wolf:SetWidth(self.db.char.size / 2)
	mainFrame.wolf:SetHeight(self.db.char.size / 2)
	mainFrame.wolf:ClearAllPoints();
	mainFrame.elemental:SetWidth(self.db.char.size / 2)
	mainFrame.elemental:SetHeight(self.db.char.size / 2)
	mainFrame.elemental:ClearAllPoints();
	if self.db.char.queueDirection == "DOWN" or self.db.char.queueDirection == "UP" then
		mainFrame.wolf:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", spacing, 0);
	    mainFrame.elemental:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMRIGHT", spacing, 0);
	else
	    mainFrame.wolf:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT", 0, (spacing * -1));
	    mainFrame.elemental:SetPoint("TOPRIGHT", mainFrame, "BOTTOMRIGHT", 0, (spacing * -1));
	end
    	
    	
	-- buttons
	for i=1,maxQueueSize do
		local f = spellQueueFrames[i];
		local size = self.db.char.size;
		if i > 1 then
			size = 0.8 * size;
		end
		f:SetWidth(size)
		f:SetHeight(size)
		f:ClearAllPoints();
		if i == 1 then
			f:SetPoint("CENTER", mainFrame, "CENTER");
		else
		    if self.db.char.queueDirection == "RIGHT" then
		    	f:SetPoint("LEFT", spellQueueFrames[i-1], "RIGHT", spacing, 0);
            elseif self.db.char.queueDirection == "UP" then
			    f:SetPoint("BOTTOM", spellQueueFrames[i-1], "TOP", 0, spacing);
			elseif self.db.char.queueDirection == "LEFT" then
			    f:SetPoint("RIGHT", spellQueueFrames[i-1], "LEFT", (spacing * -1), 0);
            elseif self.db.char.queueDirection == "DOWN" then
			    f:SetPoint("TOP", spellQueueFrames[i-1], "BOTTOM", 0, (spacing * -1));
			end
		end
	end
	
	-- and reskin them
	if LBF then
	Group:Skin(self.db.char.bf.SkinID or "Blizzard", self.db.char.bf.Gloss, self.db.char.bf.Backdrop, self.db.char.bf.Colors);
	end
end

-- print something to window
function swPrint(s)
    DEFAULT_CHAT_FRAME:AddMessage("EnhaPrio: ".. tostring(s));
end


--- on initialize
function EnhaPrio:OnInitialize()
	local AceConfigReg = LibStub("AceConfigRegistry-3.0")
	local AceConfigDialog = LibStub("AceConfigDialog-3.0")
	
	-- register shit
	self.db = LibStub("AceDB-3.0"):New("EnhaPrioDB", defaults, "char")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("EnhaPrio", self:GetOptions(), {"EnhaPrio", "fin"} )
	self.optionsFrame = AceConfigDialog:AddToBlizOptions("EnhaPrio","EnhaPrio")
	self.db:RegisterDefaults(defaults);

	-- create the main frame and configure it
	mainFrame = CreateFrame("Frame","EnhaPrioDisplayFrame",UIParent)
	mainFrame:SetFrameStrata("BACKGROUND")
	mainFrame:SetWidth(self.db.char.size)
	mainFrame:SetHeight(self.db.char.size)
	mainFrame:EnableMouse(true)
	mainFrame:SetMovable(true)
	mainFrame:SetClampedToScreen(true)
	-- add scripts for mouse events on the frame
	mainFrame:SetScript("OnMouseDown", function(self, button)
		if not EnhaPrio.db.char.locked and button == "LeftButton" then
			self:StartMoving();
		elseif button == "RightButton" then
			EnhaPrio:ChangeAOE();
		end
	end);
	mainFrame:SetScript("OnMouseUp", function(self) 
		self:StopMovingOrSizing(); 
		EnhaPrio:SaveLocation(); 
	end);
	mainFrame:SetScript("OnDragStop", function(self) 
		self:StopMovingOrSizing(); 
		EnhaPrio:SaveLocation(); 
	end);
	mainFrame:ClearAllPoints();
	mainFrame:SetPoint(self.db.char.relativePoint, self.db.char.x, self.db.char.y);
	
	if LBF then skins = LBF:GetSkins() end

	-- let's create the individual frames for the icons
	spellQueueFrames = {};
	for i=maxQueueSize,1,-1 do
		local parentFrame = mainFrame;
		local f = CreateFrame("Button","EnhaPrioButton" .. i, parentFrame)
		f:SetFrameStrata("BACKGROUND")
		f:SetWidth(self.db.char.size)
		f:SetHeight(self.db.char.size)
		f:EnableMouse(false)
		f:SetMovable(false)
		f:SetClampedToScreen(true)
		f:ClearAllPoints();
		local spacing = self.db.char.spacing;
		f.spellTexture = f:CreateTexture(nil,"BACKGROUND");
		f.spellTexture:SetAllPoints(f);
		f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate");
		f.cooldown:SetAllPoints(f);
		f.cooldownText = f:CreateFontString(nil, "OVERLAY");
		f.cooldownText:SetFont("Fonts\\FRIZQT__.TTF", 42, "OUTLINE");
		f.cooldownText:SetTextHeight(self.db.char.size / 3);
		f.cooldownText:SetAllPoints();
		f.cooldownText:SetTextColor(1, 1, 1, 1);
		spellQueueFrames[i] = f;

        if LBF then Group:AddButton(f, {Icon = f.spellTexture, Cooldown = f.cooldown}) end
	end
	
	-- frames for wolf and elemental
	mainFrame.wolf = CreateFrame("Button", "EnhaPrioFeralSpiritButton", mainFrame);
	mainFrame.wolf.id = 51533;
	mainFrame.wolf.texture = mainFrame.wolf:CreateTexture(nil,"BACKGROUND");
	mainFrame.wolf.texture:SetAllPoints(mainFrame.wolf);
	--mainFrame.wolf.texture:SetTexture(GetSpellTexture("Feral Spirit"));
	mainFrame.wolf:SetWidth(self.db.char.size / 2);
	mainFrame.wolf:SetHeight(self.db.char.size / 2);
	mainFrame.wolf:EnableMouse(false);
	mainFrame.wolf:SetMovable(false);
	mainFrame.wolf:SetClampedToScreen(true);
	mainFrame.wolf:ClearAllPoints();
	
	mainFrame.elemental = CreateFrame("Button", "EnhaPrioFireElementalButton", mainFrame);
	mainFrame.elemental.id = 2894;
	mainFrame.elemental.texture = mainFrame.elemental:CreateTexture(nil,"BACKGROUND");
	mainFrame.elemental.texture:SetAllPoints(mainFrame.elemental);
	--mainFrame.elemental.texture:SetTexture(GetSpellTexture("Fire Elemental Totem"));
	mainFrame.elemental:SetWidth(self.db.char.size / 2);
	mainFrame.elemental:SetHeight(self.db.char.size / 2);
	mainFrame.elemental:EnableMouse(false);
	mainFrame.elemental:SetMovable(false);
	mainFrame.elemental:SetClampedToScreen(true);
	mainFrame.elemental:ClearAllPoints();
	
	if LBF then 
		Group:AddButton(mainFrame.wolf, {Icon = mainFrame.wolf.texture});
		Group:AddButton(mainFrame.elemental, {Icon = mainFrame.elemental.texture}); 
	end
	
	
	-- text for maelstrom
	mainFrame.text = mainFrame:CreateFontString(nil,"OVERLAY")
	mainFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 42, "THICKOUTLINE");
	mainFrame.text:SetTextHeight(self.db.char.size / 2);
	mainFrame.text:ClearAllPoints();
	mainFrame.text:SetTextColor(1, 1, 1, 1);
	
	-- no aoe text
	mainFrame.AOEtext = mainFrame:CreateFontString(nil,"OVERLAY")
	mainFrame.AOEtext:SetFont("Fonts\\FRIZQT__.TTF", self.db.char.size * 0.2, "OUTLINE");
	mainFrame.AOEtext:ClearAllPoints();
	mainFrame.AOEtext:SetTextColor(1, 0, 0, 1);
end

function EnhaPrio:OnEnable()
	local playerClass, englishClass = UnitClass("player");
	if UnitLevel('player') < 80 then
	    swPrint('Only lvl80 characters are supported.');
		mainFrame:Hide();
	elseif englishClass ~= 'SHAMAN' then
		swPrint('You are not a shaman. Please reroll a shaman.');
		mainFrame:Hide();
	else
		playerId = UnitGUID("player");
		
		self:PLAYER_TARGET_CHANGED(); -- check target self:RecalcMode();
		
		-- Register for Function Events
		self:UnregisterAllEvents();
		self:RegisterEvent("PLAYER_TARGET_CHANGED");
		self:RegisterEvent("SPELL_UPDATE_COOLDOWN");
		mainFrame:SetScript('OnUpdate', function(self, timeSinceLast)
			timeLeft = timeLeft - timeSinceLast;
			if timeLeft <= 0 then
				EnhaPrio:reCalculate();
			end
		end);
		
        if LBF then
        LBF:RegisterSkinCallback("EnhaPrio", self.SkinCallback, self);
        end

		-- Register chat commands.
		self:RegisterChatCommand("ep", function() self:OpenOptions() end);
		self:RegisterChatCommand("enhaprio", function() self:OpenOptions() end);
		
		-- move the frames side by side
		self:RepositionFrames();
		 
		swPrint('Enabled');
	end
end

-- :OpenOptions(): Opens the options window.
function EnhaPrio:OpenOptions()
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame);
end

function EnhaPrio:OnDisable()
	mainFrame:SetScript('OnUpdate', nil);
	swPrint('Disabled');
end

function EnhaPrio:GetProperty(info)
	local propName = info[#info];
	local value = self.db.char[propName];
	return value;
end

function EnhaPrio:SetProperty(info, newValue)
	local propName = info[#info];
	self.db.char[propName] = newValue;
	if propName == 'spacing' or propName == 'size' or propName == 'queueDirection' or propName == 'displayMW' then
		self:RepositionFrames();
	elseif propName == 'maxQueue' or propName == 'enableLongCD' then
	    self:RepositionFrames(true);
	end
	if mainFrame and propName == 'size' then
		mainFrame:SetWidth(self.db.char.size);
		mainFrame:SetHeight(self.db.char.size);
	end 
end

function EnhaPrio:PLAYER_TARGET_CHANGED(...) 
  hostile = UnitName("target") and UnitCanAttack("player","target") and UnitHealth("target") > 0;
  timeLeft = 0;
end

function EnhaPrio:SPELL_UPDATE_COOLDOWN(...)
	if queue[1] then
	 	local GCDstart, GCD = GetSpellCooldown(Spells.LB.name);
	 	local start, duration = GetSpellCooldown(queue[1]);
	 	
	 	local GCDleft = GCDstart + GCD - GetTime();
	 	local left = start + duration - GetTime();
	 	
	 	if self.db.char.displayGCD and GCD == duration then
	        CooldownFrame_SetTimer(spellQueueFrames[1].cooldown, GCDstart, GCD, 1);
	 	end
	end
end

function EnhaPrio:GetOptions()
	local options = { 
		name = "EnhaPrio",
		handler = EnhaPrio,
		type = 'group',
		childGroups ='tree',
		args = {
			locked = {
				type = "toggle",
				name = "Locked",
				get = "GetProperty",
				set = "SetProperty",
				order = 0,
			},
			iconGroup = {
			    type = "group",
			    name = "Icon Settings",
			    order = 1,
			    inline = true,
			    args = {
			        size = {
						type = "range",
						name = "Icon Size",
						desc = "Size of the icons",
						min = 1,
						max = 200,
						step = 1,
						get = "GetProperty",
						set = "SetProperty",
					},
					spacing = {
						type = 'range',
						name = "Icon Spacing",
						desc = "The distance between the displayed icons.",
						min = 0,
						max = 100,
						step = 1,
						get = "GetProperty",
						set = "SetProperty",
					},
			    }
			},
			queueGroup = {
			    type = "group",
			    name = "Queue Settings",
			    order = 2,
			    inline = true,
			    args = {
			        queueDirection = {
				        type = "select",
				        name = "Queue Direction",
				        desc = "Which direction does the queue 'tail' point to.",
				        get = "GetProperty",
						set = "SetProperty",
						style = "dropdown",
						values = {
							RIGHT = "Right",
							LEFT = "Left",
							UP = "Up",
							DOWN = "Down"
						},
				    },
					maxQueue = {
					   	type = 'range',
						name = "Queue Size",
						desc = "Maximum number of spells shown in the queue.",
						min = 1,
						max = 8,
						step = 1,
						get = "GetProperty",
						set = "SetProperty",
					}
			    }
			},
			otherGroup = {
			    type = "group",
			    name = "Other Settings",
			    order = 3,
			    inline = true,
			    args = {
			        manaThreshold = {
						type = 'range',
						name = "Low Mana Threshold (%)",
						desc = "The point where Shamanistic Rage will be suggested.",
						min = 5,
						max = 100,
						step = 5,
						get = "GetProperty",
						set = "SetProperty",
						order = 1
					},
					updateFrequency = {
						type = 'range',
						name = "Update Frequency",
						desc = "The delay in seconds to wait before rechecking the next spell.",
						min = .05,
						max = .5,
						step = .05,
						get = "GetProperty",
						set = "SetProperty",
						order = 2
					},
					displayMW = {
						type = 'toggle',
						name = "Show MW Tracker",
						desc = "Show or hide the Maelstrom Weapon buff tracker.",
						get = "GetProperty",
						set = "SetProperty",
						order = 3
					},
					displayGCD = {
						type = 'toggle',
						name = "Show GCD",
						desc = "Show or hide global cooldown on the first icon.",
						get = "GetProperty",
						set = "SetProperty",
						order = 4
					},
					enableLongCD = {
						type = 'toggle',
						name = "Track Long CD Spells",
						desc = "Show or hide small icons for Feral Spirit and Fire Elemental Totem.",
						get = "GetProperty",
						set = "SetProperty",
						order = 5
					}
			    }
			}
		}
	}
	return options
end
