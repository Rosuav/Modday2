PAYDAY 2 modding
================

Goals:

* Press to respond to pager, rather than hold??

Current features:

* Autoreload. If your current magazine is empty, and you have bullets in
  reserve, you will start reloading - no waiting for another click of the
  trigger. This can be interrupted as usual and will resume afterwards.
* When you use your last body bag, you will be notified to grab more.
* Inspect your weapon to be shown your current orientation.
  Note that, sadly, this does not always correspond to the compass
  directions given in preplanning. Compass mark zero (described as north
  by the Inspect message) often points north, but not always. Examples:
  - The Diamond: East
  - Framing Frame day 3 is unclear. "East Main Room" and "West Main Room"
    backwards. But otherwise North.
  - Golden Grin Casino: North
  - Shadow Raid: North
  - Big Bank: East
  - Hotline Miama day 1: North
  - Border Crossing - VERY confusing.
    - The US is on the left and Mexico on the right. So most likely north is left (up is east).
    - Dead drop doctor bag, "north side alley", top of map, "south side alley", bottom of map.
    - Camera access, north top.
    - Blueprints, Mexico side - warehouse north is top, warehouse south is bottom
    - But USA side, "north hallway" is bottom of map! South-east hallway is top right! WUT.
    - 0 is up on the blueprints (both USA and Mexico sides).
  - Conclusion: Preplanning is sometimes just plain wrong.
* A bunch of hacks/cheats for debugging. Enable them by uncommenting lines near the top. Some
  of their descriptions are deliberately vague so they won't get desynchronized with the code.
  CAUTION: Use of these cheats in multiplayer may be considered, well, cheating. Do not use
  any of these without the consent of every player you're with, and ensure that all players
  have the same settings. These features are NOT GUARANTEED TO WORK in multiplayer, and have
  exhibited a number of quirks, including:
  - Players getting kicked as cheater for using more_stuff
  - Additional assets simply despawning
  - Pager resets not getting synchronized, and the alarm being set off
  Recommendation: Use these cheats in offline mode only.
* These hacks can also be used to create alternate game modes. For example:
  - Kill Bill: pager_reset, more_stuff, insurance, and optionally dark_cameras.
    "I went on what the movies refer to as a Sneaking Rampage of Revenge. I snuck
    around. I rampaged. And I got bloody satisfaction."
    Pagers are still a thing, but pager count gets reset every time you bag someone. Crank
    the body bag case count way up. Remain in full stealth, and finish with the map empty.
    Necessary skills: Sixth Sense aced, Cleaner aced
    Great on maps where you just wish more people would die. First World Bank, Murky Station,
    etc, with lots more people than you can normally kill, but it's really hard to choose who
    gets to have a bullet today. Use dark_cameras on maps where you can't eliminate the
    operator, otherwise take cameras out the conventional way.
  - Biker Sniper: wireframes
    Big Oil day one. Use the Inspect key to see where everyone is. Your goal: Eliminate the
    bikers without the alarm being raised, without ever stepping inside the fence.
