Created by Iridar to be amazing.

More info at: https://www.patreon.com/Iridar

[WOTC] Automated Loadout Manager

[h1]TL;DR[/h1]

This mod automatically equips last used items when you add a soldier to Squad Select screen, even if you click "Unequip Barracks". 

[h1]FEATURES[/h1]
[list][*]When you start a mission or [b][i]remove[/i][/b] a soldier from squad select screen, the mod will automatically remember the soldier's Loadout.
[*]When you [b][i]add[/i][/b] a soldier to squad select screen, the mod automatically tries to equip their remembered Loadout. [/list]
If any part of the soldier's remembered loadout is currently unavailable (e.g. their last equipped weapon is already equipped on another soldier in the squad), the mod will automatically try to replace the missing item with the next best thing. For example, if both of your Snipers have Darklance as their last used weapon, the mod will automatically equip a Beam Sniper Rifle on the second Sniper when you add them to squad.

The automatic part of the mod happens [b]only[/b] on Squad Select screen. 

Squad Select screen and individual soldier loadout screen will also have buttons to manually "SAVE LOADOUT" or "LOCK LOADOUT". 

While the soldier's loadout is "LOCKED", it will not be automatically rewritten when the soldier is removed from squad select screen. 

For example, if you equip a Darklance on a Sniper, then lock their loadout, then equip a Beam Sniper Rifle on them and then remove them from squad select, the remembered loadout will still contain the Darklance.

"SAVE LOADOUT" will save currently equipped loadout even if it's locked.
"LOCK LOADOUT" will also save the currently equipped loadout. Lock loadout [i][b]does not[/b][/i] prevent "Unequip Barracks" button from stripping the soldier's gear. It only prevents the mod from overwriting soldier's saved loadout when they are removed from squad select.

Locking the loadout will also prevent the mod from looking for superior alternatives to "unmodified" items. For example, if the saved loadout includes a Frag Grenade, and the loadout is not locked, then when loading the loadout the mod will try to find a better alternative to the Frag Grenade, like an Incendiary Grenade. If the loadout is locked, the mod will equip only the Frag Grenade on the soldier, and will look for a replacement only if there are no Frag Grenades available.

[h1]PURPOSE[/h1]

This mod is a huge time saver when playing with increased squad sizes, especially if every soldier can potentially equip a variety of primary and secondary weapons. In these scenarios, the soldiers' preferred equipment gets both hard to track and annoying to re-equip on them for every mission.

[h1]REQUIREMENTS[/h1]
[list][*] [b][url=https://steamcommunity.com/workshop/filedetails/?id=1134256495]X2WOTCCommunityHighlander[/url][/b] is required [b][i]only[/i][/b] so that the new buttons can be accessed with a controller. if you don't care about controller support, the mod will still function fine without the Highlander.[/list]

[h1]COMPATIBILITY[/h1]

Compatible with:[list]
[*][b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1122974240]WotC: robojumper's Squad Select[/url][/b]. It's HIGHLY RECOMMENDED that you disable the "autofill squad" feature.
[*][b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1529472981][WOTC] Open Squad Select at any time[/url][/b][/list]

The mod has no overrides and generally should be compatible with almost anything. Safe to add mid-campaign, but shoud not be removed.

Note: the mod heavily relies on looking for Infinite Items if it cannot find an item from the saved loadout, so the mod is [b][i]probably incompatible with any implementation of Finite Items.[/i][/b]

[h1]CONFIGURATION[/h1]

You can reposition the buttons on the soldier's individual loadout screen through:
[code]..\steamapps\workshop\content\268500\1882809714\Config\XComALS.ini[/code]
You can also enabled debug logging here. 

[h1]COMPANION MODS[/h1]

[b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1162274976]Remove Weapon Upgrades[/url][/b] - This mod adds a button to, well, remove weapon upgrades from all weapons that are not currently equipped on squad members. That would mean you have to reassing your weapon upgrades every time you go on a mission, once you have Reusable Upgrades tech / breakthrough. However, that mod can now be configured to *not* remove weapon upgrades from weapons that have a nickname. It can also be configured to remove weapon ugprades from secondary weapons as well. For, that put this code into that mod's [b]XComGame.ini[/b]:
[code][RemoveWeaponUpgradesWOTC.X2DownloadableContentInfo_RemoveWeaponUpgradesWOTC]
DLCIdentifier="RemoveWeaponUpgradesWOTC"

DontRemoveUpgradesFromNamedWeapons=true
+SlotsToRemove=eInvSlot_PrimaryWeapon
+SlotsToRemove=eInvSlot_SecondaryWeapon[/code]

[h1]TODO[/h1]

Auto-equip weapon upgrades.
Better algorithm for finding replacement equipment.
Some sort of indicator on squad select which soldiers have locked loadouts.

[h1]KNOWN ISSUES[/h1]

Currently none.

[h1]TROUBLESHOOTING[/h1]

If the mod appears to work incorrectly, please send me your Launch.log file, located at:
[code]..\Documents\my games\XCOM2 War of the Chosen\XComGame\Logs\Launch.log[/code]

This console command can be used to wipe out saved loadouts, should you need to.
[code]ALMResetSavedLoadouts[/code]

Due to some bugs in the early versions of the mod, some of your soldiers may end up with "hidden" items that are still equipped on them, but you don't see them, and can't unequip them through in-game interface. For example, you may be trying to equip a grenade on the soldier, but the game will say that this soldier already has one equipped. Use this console command to fix this issue:
[code]ALMUnequipBrokenItems[/code]

[h1]CREDITS[/h1]

Controller support implemented by Mr.Nice.

Please [b][url=https://www.patreon.com/Iridar]support me on Patreon[/url][/b] if you require tech support, have a suggestion for a feature, or simply wish to help me create more awesome mods.