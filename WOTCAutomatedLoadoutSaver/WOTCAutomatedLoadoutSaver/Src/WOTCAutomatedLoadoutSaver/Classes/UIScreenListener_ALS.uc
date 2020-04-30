class UIScreenListener_ALS extends UIStrategyScreenListener config(ALS);

var config bool bLog;

var bool LoadoutLocked;

var config int SaveLoadout_OffsetX;
var config int SaveLoadout_OffsetY;

var config int LockLoadout_OffsetX;
var config int LockLoadout_OffsetY;

var localized string strSaveLoadout;
var localized string strLockLoadout;
var localized string strUnlockLoadout;

var localized string strSaveSquadLoadout;
var localized string strLockSquadLoadout;
var localized string strUnlockSquadLoadout;
var localized string strSaveSquadLoadoutTooltip;
var localized string strLockSquadLoadoutTooltip;
var localized string strUnlockSquadLoadoutTooltip;

var X2StrategyElementTemplate CHVersion;

//	================================================================================
//	================================================================================
//								EVENTS FOR UPDATING THE SQUAD
//	================================================================================
//	================================================================================

// This event is triggered after a screen is initialized
event OnInit(UIScreen Screen)
{
	local UISquadSelect SquadSelect;

	//`LOG("Init screen: " @ Screen.Class.Name, default.bLog, 'IRIALM');

	SquadSelect = UISquadSelect(Screen);
	
	if (SquadSelect != none)
	{
		LoadoutLocked = false;
		`LOG("## UISquadSelect initialized.", default.bLog, 'IRIALM');			
		UpdateSquad(SquadSelect);
		if(!`ISCONTROLLERACTIVE)
		{
			AddHelp();
		}
	}
	else if(UIArmory_Loadout(Screen) != none)
	{
		AddButtons(UIArmory_Loadout(Screen));
		if (CHVersion != none)
		{
			`SCREENSTACK.SubscribeToOnInput(OnArmoryLoadoutInput);
		}
		else
		{
			CHVersion = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindStrategyElementTemplate('CHXComGameVersion');
			if (CHVersion != none)
			{
				`SCREENSTACK.SubscribeToOnInput(OnArmoryLoadoutInput);
			}
		}
	}
	else if(UIManageEquipmentMenu(Screen) != none)
	{
		AddMenuItems(UIManageEquipmentMenu(Screen));
	}
}

// This event is triggered after a screen receives focus
event OnReceiveFocus(UIScreen Screen)
{
	local UISquadSelect SquadSelect;

	SquadSelect = UISquadSelect(Screen);

	if (SquadSelect != none)
	{
		`LOG("## UISquadSelect receives focus.", default.bLog, 'IRIALM');
		UpdateSquad(SquadSelect);
		if(!`ISCONTROLLERACTIVE)
		{
			AddHelp();
		}
	}
	else if(UIArmory_Loadout(Screen) != none)
	{
		AddButtons(UIArmory_Loadout(Screen)); // Mr. Nice: Not sure this is required? It's not like NavHelp which gets flushed on pratically any kind of refresh/update...
		if (CHVersion != none)
		{
			`SCREENSTACK.SubscribeToOnInput(OnArmoryLoadoutInput);
		}
	}
}

event OnLoseFocus(UIScreen Screen)
{
	if(UIArmory_Loadout(Screen) != none && CHVersion != none)
	{
		`LOG("## UISquadSelect loses focus.", default.bLog, 'IRIALM');
		`SCREENSTACK.UnsubscribeFromOnInput(OnArmoryLoadoutInput);
	}
}

event OnRemovedFocus(UIScreen Screen)
{
	if(UIArmory_Loadout(Screen) != none && CHVersion != none)
	{
		`LOG("## UISquadSelect removed focus.", default.bLog, 'IRIALM');
		`SCREENSTACK.UnsubscribeFromOnInput(OnArmoryLoadoutInput);
	}
}

simulated function UpdateSquad(UISquadSelect SquadSelect)
{
	if (IsInStrategy())
	{
		if (class'XComGameState_ALS'.static.UpdateSquad(`XCOMHQ.Squad))
		{
			//PrintSquad(`XCOMHQ.Squad);
			SquadSelect.bDirty = true;
			SquadSelect.UpdateData();
		}
	}
}

//	================================================================================
//	================================================================================
//							SQUAD SELECT BUTTONS
//	================================================================================
//	================================================================================

simulated function AddHelp()
{
	local UISquadSelect Screen;
	local UINavigationHelp NavHelp;

	Screen = UISquadSelect(`SCREENSTACK.GetCurrentScreen());

	if (Screen != none)
	{
		NavHelp = `HQPRES.m_kAvengerHUD.NavHelp;

		//	These conditions prevent the buttons being added ad infinitum.
		if(	NavHelp.m_arrButtonClickDelegates.Length > 0 && (NavHelp.m_arrButtonClickDelegates.Find(SaveSquadLoadout) == INDEX_NONE && 
			(NavHelp.m_arrButtonClickDelegates.Find(LockSquadLoadout) == INDEX_NONE ||  NavHelp.m_arrButtonClickDelegates.Find(UnlockSquadLoadout) == INDEX_NONE) ))
		{
			NavHelp.AddCenterHelp(default.strSaveSquadLoadout,, SaveSquadLoadout, false, default.strSaveSquadLoadoutTooltip);
			if (LoadoutLocked)
			{
				NavHelp.AddCenterHelp(default.strUnlockSquadLoadout,, UnlockSquadLoadout, false, default.strUnlockSquadLoadoutTooltip);
			}
			else
			{
				NavHelp.AddCenterHelp(default.strLockSquadLoadout,, LockSquadLoadout, false, default.strLockSquadLoadoutTooltip);
			}
			
		}
		Screen.SetTimer(0.1f, false, nameof(AddHelp), self);
	}
}

simulated function AddMenuItems(UIManageEquipmentMenu EquipmentMenu)
{
	local UIList List;
	
	// Mr. Nice: Despite the specific classname, UIManageEquipmentMenu is very generic for producing any popupmenu
	// So might well be repurposed by a mod somewhere, so should check it's really the Equipment Menu,
	// Check if UISquadSelect is in the stack... (not strictly perfect but probably good enough)
	if (!`SCREENSTACK.HasInstanceOf(class'UISquadSelect')) return;

	List = EquipmentMenu.List;
	
	// Mr. Nice: Horizontal padding precisely derived from flash position of the fixed background and the list width set in UC
	List.BGPaddingLeft = 19;
	List.BGPaddingRight = 16;
	List.BGPaddingTop = 19;
	List.BGPaddingBottom = 19;
	List.SetPosition(754, 393.3); // In flash, it's X is 753.75, but since the padding properties are ints not floats, that makes it impossible
					// To match the new BG horizontal position/size to the existing BG, hence slightly moving it.
	List.bShrinkToFit = true;
	List.BG = List.Spawn(class'UIBGBox', List);
	List.BG.bAnimateOnInit = List.bAnimateOnInit;
	List.BG.LibID = class'UIUtilities_Controls'.const.MC_X2Background;
	List.BG.InitBG('BGBox', -List.BGPaddingLeft, -List.BGPaddingTop);
	List.BG.Spawn(class'UIPanel', List.BG).InitPanel('topLines').Remove();
	// Mr. Nice: Since the BG wasn't added back in Init, have to bring the container forward so that the background is drawn behind it
	List.ItemContainer.MoveToHighestDepth();
	
	EquipmentMenu.AddItem(default.strSaveSquadLoadout, SaveSquadLoadout);
	if(LoadoutLocked)
	{
		EquipmentMenu.AddItem(default.strUnlockSquadLoadout, UnlockSquadLoadout);
	}
	else
	{
		EquipmentMenu.AddItem(default.strLockSquadLoadout, LockSquadLoadout);
	}
}

simulated function SaveSquadLoadout()
{
	`LOG("Save squad loadout clicked", default.bLog, 'IRIALM');

	class'XComGameState_ALS'.static.SaveLoadoutsForSquad(`XCOMHQ.Squad);
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
}

simulated function LockSquadLoadout()
{
	LoadoutLocked = true;
	`LOG("Lock squad loadout clicked", default.bLog, 'IRIALM');
	class'XComGameState_ALS'.static.LockLoadoutsForSquad(`XCOMHQ.Squad);
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	UpdateHelp();
}

simulated function UnlockSquadLoadout()
{	
	LoadoutLocked = false;
	`LOG("Unlock squad loadout clicked", default.bLog, 'IRIALM');
	class'XComGameState_ALS'.static.UnlockLoadoutsForSquad(`XCOMHQ.Squad);
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	UpdateHelp();
}

simulated function UpdateHelp()
{
	local UISquadSelect Screen;

	Screen = UISquadSelect(`SCREENSTACK.GetCurrentScreen());
	if (Screen != none)
	{
		Screen.UpdateNavHelp();
	}
}

//	================================================================================
//	================================================================================
//							ARMORY BUTTONS
//	================================================================================
//	================================================================================

//	UIArmory_MainMenu -> soldier with buttons like customize and loadout
//	UIArmory_Loadout -> all equipment slots after clicking "loadout".

simulated function AddButtons(UIArmory_Loadout Screen)
{
	local XComGameState_Unit	Unit;
	local UIButton				SaveLoadoutButton;
	local UIButton				ToggleLoadoutLockButton;
	local UIPanel ListContainer;
	local UIList List;

	Unit = Screen.GetUnit();

	if (Unit == none) return;

	ListContainer = Screen.EquippedListContainer;

	SaveLoadoutButton = UIButton(ListContainer.GetChild('IRI_SaveLoadoutButton', false));
	SaveLoadoutButton = ListContainer.Spawn(class'UIButton', ListContainer).InitButton('IRI_SaveLoadoutButton', default.strSaveLoadout, SaveLoadoutButtonClicked, eUIButtonStyle_NONE);
	SaveLoadoutButton.SetPosition(default.SaveLoadout_OffsetX - 108.65, default.SaveLoadout_OffsetY - 121);
	SaveLoadoutButton.AnimateIn(0);


	ToggleLoadoutLockButton = UIButton(ListContainer.GetChild('IRI_ToggleLoadoutLockButton', false));
	ToggleLoadoutLockButton = ListContainer.Spawn(class'UIButton', ListContainer).InitButton('IRI_ToggleLoadoutLockButton',, ToggleLoadoutButtonClicked, eUIButtonStyle_NONE);

	`LOG("Looking at soldier: " @ Unit.GetFullName() @ "loadout locked: " @ class'XComGameState_ALS'.static.IsLoadoutLocked(Unit), default.bLog, 'IRIALM');

	if (class'XComGameState_ALS'.static.IsLoadoutLocked(Unit)) 
	{
		ToggleLoadoutLockButton.SetText(default.strUnlockLoadout);
	}
	else
	{
		ToggleLoadoutLockButton.SetText(default.strLockLoadout);
	}
	ToggleLoadoutLockButton.SetPosition(default.LockLoadout_OffsetX - 108.65, default.LockLoadout_OffsetY - 121);
	ToggleLoadoutLockButton.AnimateIn(0);

	// The screen disables navigations for the list, which now forces selection to the buttons, when it flips between the two lists
	// This is redundant, since navigation is flipped on the list container as well. So, just do this brilliant fudge...
	// This is done not just for controllers, since it messes up keyboard navigation as well, and even for mouse only
	// highlights one of the buttons when it shouldn't.
	ListContainer.Navigator.OnRemoved = EnableNavigation;
	// Stops it highlighting both buttons when you go from item selection back to the slot list, regardless of input method.
	ListContainer.bCascadeFocus = false;

	// Mr. Nice: Allows navigation to leave the slot list, to get to the new buttons (which as UIButtons, are navigable by default)
	// Only if controller active, ie leave keyboard navigation as is.
	if (`ISCONTROLLERACTIVE && ListContainer.GetChild('IRI_DummyList', false) == none)
	{
		List = Screen.EquippedList;

		// Fiddle with a few flags on the list, it's navigator and container to get the behaviour we want
		List.bLoopSelection = false; 
		List.Navigator.LoopSelection = false;
		List.bPermitNavigatorToDefocus = true;
		List.Navigator.LoopOnReceiveFocus = true;
		ListContainer.Navigator.LoopSelection = true;

		// Mr. Nice: bumping it to the end of the navigation list makes the top/bottom stops for autorepeat intuitive
		// (Even if 'LoopSelection' is set, auto-repeat input still stops at the ends without looping). Also why this section is last, so the buttons are already in the array
		// Sneakily take advantage of the fact that we had to add in an OnRemoved delegate to reverse disabling navigation, so that simply disabling it effectively just bumps it to the end!
		List.DisableNavigation();

		// Just a bit of polish so can get between the two buttons with left/right, not just up/down, given their relative positions on screen
		SaveLoadoutButton.Navigator.AddNavTargetRight(ToggleLoadoutLockButton);
		ToggleLoadoutLockButton.Navigator.AddNavTargetLeft(SaveLoadoutButton);
	}
}

function EnableNavigation(UIPanel Control)
{
	Control.EnableNavigation();
	//  For no obvious reason, directly setting selected navigation doesn't call OnLoseFocus for the existing selection?
	Control.ParentPanel.Navigator.GetSelected().OnLoseFocus();
	// When UIArmory_Loadout disables navigation for the list, it was by definition the selected navigation. So make it so again...
	Control.SetSelectedNavigation();
}

simulated function SaveLoadoutButtonClicked(UIButton btn_clicked)
{
	local UIArmory_Loadout		Screen;
	local XComGameState_Unit	Unit;

	Screen = UIArmory_Loadout(btn_clicked.Screen);

	if (Screen != none)
	{
		Unit = Screen.GetUnit();
		if (Unit != none)
		{
			class'XComGameState_ALS'.static.SaveLoadoutForUnitState(Unit);
			`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
		}
	}
}

simulated function ToggleLoadoutButtonClicked(UIButton btn_clicked)
{
	local UIArmory_Loadout		Screen;
	local XComGameState_Unit	Unit;

	Screen = UIArmory_Loadout(btn_clicked.Screen);

	if (Screen != none)
	{
		Unit = Screen.GetUnit();
		if (Unit != none)
		{
			if (btn_clicked.Text == default.strUnlockLoadout)
			{
				class'XComGameState_ALS'.static.UnlockLoadoutForUnitState(Unit);
				btn_clicked.SetText(default.strLockLoadout);
			}
			else
			{
				class'XComGameState_ALS'.static.LockLoadoutForUnitState(Unit);
				btn_clicked.SetText(default.strUnlockLoadout);
			}
			`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
		}
	}
}


//	================================================================================
//							HELPERS
//	================================================================================

static function PrintSquad(array<StateObjectReference> Squad)
{
	local XComGameStateHistory	History;
	local XComGameState_Unit	UnitState;
	local int i;

	History = `XCOMHISTORY;

	for (i = 0; i < Squad.Length; i++)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(Squad[i].ObjectID));

		if (UnitState != none)
		{
			`LOG("Squad member: " @ UnitState.GetFullName(), default.bLog, 'IRIALM');
		}
	}
}

//	================================================================================
//							ARMOURY INPUT HANDLING
//	================================================================================
function bool OnArmoryLoadoutInput(int cmd, int arg)
{
	local UIArmory_Loadout Screen;
	
	Screen = UIArmory_Loadout(`SCREENSTACK.GetCurrentScreen());

	if (Screen==none) return false; // Shouldn't be possible, since we unsubscribe in OnLoseFocus and OnRemoved!

	if (!Screen.CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
	{
		return false;
	}

	// Mr. Nice: Just a bit of polish, since we're faffing with input handling anyway
	Screen.EquippedList.Navigator.LoopSelection = !`ISCONTROLLERACTIVE || (arg & class'UIUtilities_Input'.const.FXS_ACTION_POSTHOLD_REPEAT) != 0;

	switch( cmd )
	{
		case class'UIUtilities_Input'.const.FXS_BUTTON_A:
		case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
		case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR:
			return Screen.Navigator.OnUnrealCommand(cmd, arg); // Where the selection input should have ended up in the first place, and would have by default if not handled by the Screen!
														// Note how we don't even have to check if one of our buttons is selected, works fine for the lists too...
		default:
			return false;
	}
}
// This event is triggered after a screen loses focus
/*
event OnLoseFocus(UIScreen Screen)
{
	local UISquadSelect SquadSelect;

	SquadSelect = UISquadSelect(Screen);

	if (SquadSelect != none)
	{
		//PrintSquad(`XCOMHQ.Squad);
		if (class'XComGameState_ALS'.static.UpdateSquad(`XCOMHQ.Squad))
		{
			`LOG("## Loses focus: ", default.bLog, 'IRIALM');
			SquadSelect.bDirty = true;
			SquadSelect.UpdateData();
		}
	}
}

// This event is triggered when a screen is removed
event OnRemoved(UIScreen Screen)
{
	local UISquadSelect SquadSelect;

	SquadSelect = UISquadSelect(Screen);

	if (SquadSelect != none)
	{
		//PrintSquad(`XCOMHQ.Squad);
		if (class'XComGameState_ALS'.static.UpdateSquad(`XCOMHQ.Squad))
		{
			`LOG("## UISquadSelect is removed: ", default.bLog, 'IRIALM');
			SquadSelect.bDirty = true;
			SquadSelect.UpdateData();
		}
	}
}
*/