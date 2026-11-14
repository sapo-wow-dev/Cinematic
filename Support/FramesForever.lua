-- Cinematic: Frames Forever (WoW Forever), unit frames of its own standing in
-- for the game's: player, pet and its target, target and its target, focus,
-- party (with you and your party's targets), raid and flag carriers. Each is
-- a named secure unit button on UIParent (FramesForever<Name>, numbered for
-- the party, raid and flag carriers), made at login and shown by the game's
-- unit watch while its unit exists. Each fades with the game frame it stands
-- in for, on that frame's Standard Frames row.
--
-- It sets its frames' alpha all the time (out of range, offline or AFK, and
-- its own fade while you're idle): its own frames, so they're hooked, ours
-- times theirs.
--
-- It hides most of the game's frames by moving them onto a hidden frame, out
-- of our reach. The pet frame it only sets to alpha 0, so our fade brought
-- it back: its alpha is followed instead (0 while Frames Forever hides it,
-- faded as usual once it's given back).
local _, ns = ...

-- Its frames, by the Standard Frames row they follow: the row, the fade
-- group, and the frames.
local ROWS = {
	{ "player", "player", "FramesForeverPlayer" },
	{ "petframe", "player", "FramesForeverPet", "FramesForeverPetTarget" },
	{ "target", "target", "FramesForeverTarget" },
	{ "tot", "target", "FramesForeverTargetTarget" },
	{ "focus", "target", "FramesForeverFocus" },
	{ "party", "party", "FramesForeverPartySelf", "FramesForeverPartySelfTarget" },
	{ "flags", "flags", "FramesForeverFlagCarrier1", "FramesForeverFlagCarrier2" },
}
local party = ROWS[6]
for i = 1, 4 do
	party[#party + 1] = "FramesForeverParty" .. i
	party[#party + 1] = "FramesForeverPartyTarget" .. i
end

-- Its raid frames, one per raid member: the Players row (found by scans).
local RAID = {}
for i = 1, 40 do
	RAID[i] = "FramesForeverRaid" .. i
end

-- Linked as the game's unit frames (Addon Frame Links: FrameLinks.lua).
local LINKS = {
	unitplayer = "FramesForeverPlayer", unitpet = "FramesForeverPet", unittarget = "FramesForeverTarget",
	unittot = "FramesForeverTargetTarget", unitfocus = "FramesForeverFocus",
}

local function IsUsable(frame)
	return type(frame) == "table" and type(frame.GetObjectType) == "function"
		and not (frame.IsForbidden and frame:IsForbidden())
end

ns.WhenAddonLoads("Frames_Forever", function()
	ns.FadeWithRows(ROWS)
	ns.FadeFoundByName("raidplayers", RAID)
	-- Its player frame stays up while you recover, and its pet frame until
	-- your pet's health is full, as the game's do (Health & Resources page).
	ns.AddPortraitFrame("FramesForeverPlayer")
	ns.AddPetFrame("FramesForeverPet")
	-- The game's pet frame, which it hides at alpha 0: followed, never forced up.
	ns.FollowOwnAlpha({ "PetFrame" })
	ns.AddScanner(function()
		for part, name in pairs(LINKS) do
			local frame = _G[name]
			if IsUsable(frame) then ns.ClaimLinkPart("Frames_Forever", part, frame) end
		end
	end)
end)
