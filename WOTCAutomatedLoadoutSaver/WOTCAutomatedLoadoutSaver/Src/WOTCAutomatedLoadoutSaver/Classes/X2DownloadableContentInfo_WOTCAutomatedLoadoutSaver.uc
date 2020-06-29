class X2DownloadableContentInfo_WOTCAutomatedLoadoutSaver extends X2DownloadableContentInfo;

//	Current issues:
// 1. Cannot find better version of an equipped infinite item if it's in a multi slot
// 2. Cannot find better version of an equipped infinite item if it's already in the loadout
// Both are fixed by clicking "unequip barracks" first, so whatevs. This (probably?) happens because of CanAddItemToInventory checks and multi slot capacity check.

exec function ALMResetSavedLoadouts()
{
	local XComGameState_ALS				StateObject;
	local XComGameState					NewGameState;

	StateObject = XComGameState_ALS(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_ALS', true));

	if (StateObject == none)
	{
		`LOG("Could not retrieve State Object from history.",, 'IRIALM');
	}
	else
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Wiping Saved Loadouts For Units");

		StateObject = XComGameState_ALS(NewGameState.ModifyStateObject(class'XComGameState_ALS', StateObject.ObjectID));
		StateObject.Loadouts.Length = 0;

		`GAMERULES.SubmitGameState(NewGameState);

		`LOG("Wiping out state object.",, 'IRIALM');

		StateObject = XComGameState_ALS(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_ALS', true));
		if (StateObject.Loadouts.Length == 0)
		{
			`LOG("Confirm deletion of state object.",, 'IRIALM');
		}
		else
		{
			`LOG("Could not delete state object.",, 'IRIALM');
		}
	}
}

exec function ALMUnequipBrokenItems()
{
	local XComGameState						NewGameState;
	local XComGameStateHistory				History;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_Unit				UnitState;
	local StateObjectReference				UnitRef;
	local XComGameState_Item				ItemState;
	local bool								bChangedSomething;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Wiping Unknown Items For Units");

	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

	`LOG("Looking for broke items...",, 'IRIALM');
	foreach XComHQ.Crew(UnitRef)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		
		if (UnitState != none && UnitState.IsSoldier())
		{
			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
			ItemState = UnitState.GetItemInSlot(eInvSlot_Unknown, NewGameState);

			if (ItemState != none)
			{
				`LOG("Found item: " @ ItemState.GetMyTemplateName() @ "on unit: " @ UnitState.GetFullName(),, 'IRIALM');
				if (UnitState.RemoveItemFromInventory(ItemState, NewGameState))
				{
					XComHQ.PutItemInInventory(NewGameState, ItemState);
					bChangedSomething = true;
					`LOG("Removed it.",, 'IRIALM');
				}
			}
		}
	}
	if (bChangedSomething)
	{	
		`GAMERULES.SubmitGameState(NewGameState);
	}
	else
	{
		History.CleanupPendingGameState(NewGameState);
	}
	`LOG("Finished.",, 'IRIALM');
}

static event OnLoadedSavedGameToStrategy() 
{
	local XComGameState						NewGameState;
	local XComGameStateHistory				History;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_Unit				UnitState;
	local StateObjectReference				UnitRef;
	local XComGameState_Item				ItemState;
	local bool								bChangedSomething;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Wiping Unknown Items For Units");

	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

	`LOG("Looking for broke items...",, 'IRIALM');
	foreach XComHQ.Crew(UnitRef)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		
		if (UnitState != none && UnitState.IsSoldier())
		{
			UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
			ItemState = UnitState.GetItemInSlot(eInvSlot_Unknown, NewGameState);

			if (ItemState != none)
			{
				`LOG("Found item: " @ ItemState.GetMyTemplateName() @ "on unit: " @ UnitState.GetFullName(),, 'IRIALM');
				if (UnitState.RemoveItemFromInventory(ItemState, NewGameState))
				{
					XComHQ.PutItemInInventory(NewGameState, ItemState);
					bChangedSomething = true;
					`LOG("Removed it.",, 'IRIALM');
				}
			}
		}
	}
	if (bChangedSomething)
	{	
		`GAMERULES.SubmitGameState(NewGameState);
	}
	else
	{
		History.CleanupPendingGameState(NewGameState);
	}
	`LOG("Finished.",, 'IRIALM');
}