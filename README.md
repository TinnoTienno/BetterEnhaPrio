### BETTER ENHA PRIO (3.3.5a) ###

# Goal : 
To provide an extensive priority management on the enhancement shaman.

#What is already there : 
- simple icon list interface
- right click to switch between AOE and Single-Target modes
- variety of options settings
- good priority management for StormStrike, LavaLash, FireShock, EarthShock, Lightning Shield

#What still needs to be done : 
- Better AOE-Single target Modes with the addition of Chain lightning in the interface - done
    - Adding a switch between modes using Lightning Bold and Chain Lightning to track what mode we're using - WIP
    - Building different prio when in AOE and in Single target mode
- A predictive management using GCD to anticipate on the next priority for spells priorities that rely on cd and duration
- precisely track both hands swings
- Add Lightning Bolt weaving mechanics -> add Lightning bolts to priority if it fits between auto-attacks

Priority list : 

in single target (Real Time)
WF == 0 -> WF
FT == 0 -> FT
mana < 20 % & SR'cd <= 0 -> SR
MW == 5 -> LB
noFireTotem == true -> MT
noSS == true & SS'cd <= 0 -> SSb
MW > 3 && time between swings > LB's casttime -> LBb
noFS == true & FS'cd <= 0 -> FS
noLS == true -> LS
SS'cd <= 0 -> SS
FS > 6 sec & ES'cd <= 0 -> ES
mana > 20% & FN'cd <= 0 -> FN
LL'cd <= 0 -> LL
FireTotem duration < 3 sec -> MT
filler -> LS

in AOE (Real Time)
WF == 0 -> WF
FT == 0 -> FT
mana < 20 % & SR'cd <= 0 -> SR
noFireTotem == true -> MT
mana > 20 % & FN'cd <= 0 -> FN
MW == 5 -> CL
MW > 3 && time between swings > LB's casttime -> CLb
noSS == true & SS'cd <= 0 -> SSb
noFS == true & FS'cd <= 0 -> FS
noLS == true -> LS
SS'cd <= 0 -> SS
FS > 6 sec & ES'cd <= 0 -> ES
FireTotem duration < 3 sec -> MT
LL'cd <= 0 -> LL
filler -> LS

in single target (GCDduration) -- GCDduration being the time before the GCD is over
safety = 15ms
local _, _, latencyHome, latencyWorld = GetNetStats()
local latency = math.max(latencyHome, latencyWorld) / 1000 + 0.05
WF == 0 -> WF
FT == 0 -> FT
mana < 20 % & SR'cd - GCDduration <= 0 -> SR
MW == 5 -> LB
noFireTotem == true -> MT
noSS == true & SS'cd - GCDduration <= 0 -> SSb
MW > 3 && NextMeleeHitTimeStamp - currentTimeStamp + GCDduration > LB's casttime + latency + safety -> LBb
noFS == true & FS'cd - GCDduration <= 0 -> FS
noLS == true -> LS
SS'cd - GCDduration <= 0 -> SS
FS > 6 sec & ES'cd - GCDduration <= 0 -> ES
mana > 20% & FN'cd - GCDduration <= 0 -> FN
LL'cd - GCDduration <= 0 -> LL
FireTotem duration - GCDduration < 3 sec -> MT
filler -> LS

in AOE (GCDduration) -- GCDduration being the time before the GCD is over
safety = 15ms
local _, _, latencyHome, latencyWorld = GetNetStats()
local latency = math.max(latencyHome, latencyWorld) / 1000 + 0.05
WF == 0 -> WF
FT == 0 -> FT
mana < 20 % & SR'cd - GCDduration <= 0 -> SR
noFireTotem == true -> MT
mana > 20 % & FN'cd - GCDduration <= 0 -> FN
MW == 5 -> CL
MW > 3 && NextMeleeHitTimeStamp - currentTimeStamp + GCDduration > LB's casttime + latency + safety -> CLb
noSS == true & SS'cd - GCDduration <= 0 -> SSb
noFS == true & FS'cd - GCDduration <= 0 -> FS
noLS == true -> LS
SS'cd <= 0 - GCDduration -> SS
FS > 6 sec & ES'cd <= 0 - GCDduration -> ES
FireTotem duration - GCDduration < 3 sec -> MT
LL'cd - GCDduration<= 0 -> LL
filler -> LS