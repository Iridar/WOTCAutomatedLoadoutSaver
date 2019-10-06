class UIScreenListener_ALS extends UIScreenListener config(ALS);

const bLog = false;

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

//	================================================================================
//	================================================================================
//								EVENTS FOR UPDATING THE SQUAD
//	================================================================================
//	================================================================================

// This event is triggered after a screen is initialized
event OnInit(UIScreen Screen)
{
	local UISquadSelect SquadSelect;

	//`LOG("Init screen: " @ Screen.Class.Name, bLog, 'IRIALS');

	SquadSelect = UISquadSelect(Screen);
	
	if (SquadSelect != none)
	{
		LoadoutLocked = false;
		`LOG("## UISquadSelect initialized.", bLog, 'IRIALS');			
		UpdateSquad(SquadSelect);
		AddHelp();
	}

	AddButtons(UIArmory_Loadout(Screen));
}

// This event is triggered after a screen receives focus
event OnReceiveFocus(UIScreen Screen)
{
	local UISquadSelect SquadSelect;

	SquadSelect = UISquadSelect(Screen);

	if (SquadSelect != none)
	{
		`LOG("## UISquadSelect receives focus.", bLog, 'IRIALS');
		UpdateSquad(SquadSelect);
		AddHelp();
	}
	
	AddButtons(UIArmory_Loadout(Screen));
}

simulated function UpdateSquad(UISquadSelect SquadSelect)
{
	if (class'XComGameState_ALS'.static.UpdateSquad(`XCOMHQ.Squad))
	{
		//PrintSquad(`XCOMHQ.Squad);
		SquadSelect.bDirty = true;
		SquadSelect.UpdateData();
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

simulated function SaveSquadLoadout()
{
	`LOG("Save squad loadout clicked", bLog, 'IRIALS');

	class'XComGameState_ALS'.static.SaveLoadoutsForSquad(`XCOMHQ.Squad);
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
}

simulated function LockSquadLoadout()
{
	LoadoutLocked = true;
	`LOG("Lock squad loadout clicked", bLog, 'IRIALS');
	class'XComGameState_ALS'.static.LockLoadoutsForSquad(`XCOMHQ.Squad);
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	UpdateHelp();
}

simulated function UnlockSquadLoadout()
{	
	LoadoutLocked = false;
	`LOG("Unlock squad loadout clicked", bLog, 'IRIALS');
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

	if (Screen == none) return;

	Unit = Screen.GetUnit();

	if (Unit == none) return;

	SaveLoadoutButton = UIButton(Screen.GetChild('IRI_SaveLoadoutButton', false));
	SaveLoadoutButton = Screen.Spawn(class'UIButton', Screen).InitButton('IRI_SaveLoadoutButton', default.strSaveLoadout, SaveLoadoutButtonClicked);
	SaveLoadoutButton.SetPosition(default.SaveLoadout_OffsetX, default.SaveLoadout_OffsetY);
	SaveLoadoutButton.AnimateIn(0);


	ToggleLoadoutLockButton = UIButton(Screen.GetChild('IRI_ToggleLoadoutLockButton', false));
	ToggleLoadoutLockButton = Screen.Spawn(class'UIButton', Screen).InitButton('IRI_ToggleLoadoutLockButton',, ToggleLoadoutButtonClicked);

	`LOG("Looking at soldier: " @ Unit.GetFullName() @ "loadout locked: " @ class'XComGameState_ALS'.static.IsLoadoutLocked(Unit), bLog, 'IRIALS');

	if (class'XComGameState_ALS'.static.IsLoadoutLocked(Unit)) 
	{
		ToggleLoadoutLockButton.SetText(default.strUnlockLoadout);
	}
	else
	{
		ToggleLoadoutLockButton.SetText(default.strLockLoadout);
	}
	ToggleLoadoutLockButton.SetPosition(default.LockLoadout_OffsetX, default.LockLoadout_OffsetY);
	ToggleLoadoutLockButton.AnimateIn(0);
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
			`LOG("Squad member: " @ UnitState.GetFullName(), bLog, 'IRIALS');
		}
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
			`LOG("## Loses focus: ", bLog, 'IRIALS');
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
			`LOG("## UISquadSelect is removed: ", bLog, 'IRIALS');
			SquadSelect.bDirty = true;
			SquadSelect.UpdateData();
		}
	}
}
*/