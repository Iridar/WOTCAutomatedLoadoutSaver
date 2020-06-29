class XComGameState_ALS extends XComGameState_BaseObject config(ALS);

var config bool bLog;

//	We store the previously used `XCOMHQ.Squad to know whether a soldier was added or removed from squad.
var array<StateObjectReference> OldSquad;

struct LoadoutStruct
{
	var array<EquipmentInfo>	InventoryItems;
	var StateObjectReference	UnitRef;
	var bool bLocked;			//	Whether this loadout has been "locked" through in-game UI and therefore cannot be overwritten.
};
//	Here we store all the inventory items equipped by the soldier
var array<LoadoutStruct> Loadouts;
/*
struct native EquipmentInfo
{
	var StateObjectReference EquipmentRef;
	var EInventorySlot		 eSlot;
};*/

var config array<EInventorySlot> IgnoredSlots;

var config array<name> AllowedPrimaryWeaponCategoriesWithShield;


//	================================================================================
//	================================================================================
//								INTERFACE FUNCTIONS
//	================================================================================
//	================================================================================

public static function bool UpdateSquad(const array<StateObjectReference> NewSquad)
{
	local XComGameState_ALS				StateObject;
	local XComGameState					NewGameState;
	local array<StateObjectReference>	ChangedUnitRefs;
	local int NewSquadSize;
	local int OldSquadSize;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Saving/Loading Loadouts For Units");
	StateObject = GetOrCreate(NewGameState);

	OldSquadSize = GetSquadSize(StateObject.OldSquad);
	NewSquadSize = GetSquadSize(NewSquad);

	if (OldSquadSize > NewSquadSize)
	{
		// Old Squad is bigger, means squad members were removed.
		ChangedUnitRefs = FindChangedUnits(StateObject.OldSquad, NewSquad);

		StateObject.SaveLoadouts(ChangedUnitRefs);
		StateObject.OldSquad = NewSquad;
		`GAMERULES.SubmitGameState(NewGameState);
		return true;
	}

	if (OldSquadSize < NewSquadSize)
	{
		//	New Squad is bigger, means squad members were added.
		ChangedUnitRefs = FindChangedUnits(NewSquad, StateObject.OldSquad);
		StateObject.OldSquad = NewSquad;
		`GAMERULES.SubmitGameState(NewGameState);
		
		StateObject.LoadLoadouts(ChangedUnitRefs);
		
		return true;
	}

	if (OldSquadSize == NewSquadSize)
	{
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
		//	Squad Sizes are the same, nothing has changed, no need to do anything.
		return false;
	}
}

public static function SaveLoadoutsForSquad(const array<StateObjectReference> Squad)
{
	local XComGameState_ALS				StateObject;
	local XComGameState					NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Saving/Loading Loadouts For Units");
	StateObject = GetOrCreate(NewGameState);

	StateObject.SaveLoadouts(Squad, true);
	`GAMERULES.SubmitGameState(NewGameState);
}

public static function LockLoadoutsForSquad(const array<StateObjectReference> Squad)
{
	local XComGameState_ALS				StateObject;
	local XComGameState					NewGameState;
	local XComGameStateHistory			History;
	local XComGameState_Unit			UnitState;
	local int i;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Locking Loadouts For Units");
	StateObject = GetOrCreate(NewGameState);

	History = `XCOMHISTORY;

	for (i = 0; i < Squad.Length; i++)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(Squad[i].ObjectID));

		if (UnitState != none)
		{
			StateObject.SaveLoadoutForUnit(UnitState.GetReference(), true, true);
		}
	}

	`GAMERULES.SubmitGameState(NewGameState);
}

public static function UnlockLoadoutsForSquad(const array<StateObjectReference> Squad)
{
	local XComGameState_Unit			UnitState;
	local XComGameStateHistory			History;
	local int i;

	History = `XCOMHISTORY;

	for (i = 0; i < Squad.Length; i++)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(Squad[i].ObjectID));

		if (UnitState != none)
		{
			UnlockLoadoutForUnitState(UnitState);
		}
	}
}

public static function SaveLoadoutForUnitState(const XComGameState_Unit UnitState)
{
	local XComGameState_ALS				StateObject;
	local XComGameState					NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Saving/Loading Loadouts For Units");
	StateObject = GetOrCreate(NewGameState);

	//	Save current loadout, even if it is locked.
	StateObject.SaveLoadoutForUnit(UnitState.GetReference(), true);

	`GAMERULES.SubmitGameState(NewGameState);
}

public static function LockLoadoutForUnitState(const XComGameState_Unit UnitState)
{
	local XComGameState_ALS				StateObject;
	local XComGameState					NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Saving/Loading Loadouts For Units");
	StateObject = GetOrCreate(NewGameState);

	//	Save current loadout, even if it was already locked, and lock it.
	StateObject.SaveLoadoutForUnit(UnitState.GetReference(), true, true);

	`GAMERULES.SubmitGameState(NewGameState);
}

public static function UnlockLoadoutForUnitState(const XComGameState_Unit UnitState)
{
	local XComGameState_ALS				StateObject;
	local XComGameState					NewGameState;
	local StateObjectReference			UnitRef;
	local int i;

	UnitRef = UnitState.GetReference();
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Saving/Loading Loadouts For Units");
	StateObject = GetOrCreate(NewGameState);

	for (i = 0; i < StateObject.Loadouts.Length; i++)
	{
		if (StateObject.Loadouts[i].UnitRef == UnitRef)
		{
			StateObject.Loadouts[i].bLocked = false;

			`GAMERULES.SubmitGameState(NewGameState);
			return;
		}
	}
	//	If we don't exit earlier, it means we were trying to unlock a loadout that does not exist.
	`XCOMHISTORY.CleanupPendingGameState(NewGameState);
}

public static function bool IsLoadoutLocked(const XComGameState_Unit UnitState)
{
	local StateObjectReference	UnitRef;
	local XComGameState_ALS		StateObject;
	local int i;

	StateObject = XComGameState_ALS(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_ALS', true));

	//	If state object doesn't exist in history, then no loadouts have been saved yet, hence no locked loadouts exist.
	if (StateObject == none) return false;

	UnitRef = UnitState.GetReference();
	for (i = 0; i < StateObject.Loadouts.Length; i++)
	{
		if (StateObject.Loadouts[i].UnitRef == UnitRef)
		{
			//	We found a saved loadout for this unit. 
			return StateObject.Loadouts[i].bLocked;
		}
	}
	//	This unit does not have a saved loadout yet, so it can't be locked.
	return false;
}


//	================================================================================
//	================================================================================
//								INTERNAL STATIC FUNCTIONS
//	================================================================================
//	================================================================================

//	Get the State Object from History and prep it for modification, if it exists, or create a new State Object.
private static function XComGameState_ALS GetOrCreate(out XComGameState NewGameState)
{
	local XComGameStateHistory	History;
	local XComGameState_ALS		StateObject;

	History = `XCOMHISTORY;

	//`LOG("Get or create XComGameState_ALS", default.bLog, 'IRIALS');
	
	StateObject = XComGameState_ALS(History.GetSingleGameStateObjectForClass(class'XComGameState_ALS', true));

	if (StateObject == none)
	{
		//`LOG("State object doesn't exist, creating new one.", default.bLog, 'IRIALS');
		StateObject = XComGameState_ALS(NewGameState.CreateNewStateObject(class'XComGameState_ALS'));
	}
	else 
	{
		//`LOG("State object already exists, returning reference.", default.bLog, 'IRIALS');
		StateObject = XComGameState_ALS(NewGameState.ModifyStateObject(class'XComGameState_ALS', StateObject.ObjectID));		
	}
	return StateObject; 
}

//	Adjusted from XComGameState_Unit::EquipOldItems
//	Attempts to equip the given Unit State with given Inventory Items. Items that are not currently available are automatically replaced with the next best thing.
private static function EquipItemsOnUnit(const StateObjectReference UnitRef, out array<EquipmentInfo> InventoryItems, const bool bLoadoutLocked)
{
	local XComGameStateHistory				History;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_Unit				NewUnitState;
	local EquipmentInfo						EqInfo;
	local int								InvIndex;
	local XComGameState_Item				ItemState;
	local XComGameState_Item				HistoryItemState;
	local XComGameState_Item				EquippedItemState;
	local XComGameState_Item				UnmodifiedItemState;
	local array<XComGameState_Item>			ItemStates;
	local XComGameState						NewGameState;
	local bool								bChangedSomething;
	local int i;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Loading Loadout For Unit");

	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

	NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));

	if (NewUnitState == none) return;

	`LOG("=================== BEGIN EQUIP ITEMS ON UNIT ===================", default.bLog, 'IRIALM');
	`LOG("------------------- BEGIN LOADOUT TRIM --------------------------------", default.bLog, 'IRIALM');
	//	InventoryItems array is the list of items that should be equipped on the soldier once this function is done.
	//	First, let's trim this list of items that are already equipped on the soldier.
	//	And if the soldier has any items equipped that are not a part of the saved loadout in the slots from the saved loadout, remove these items and put them into HQ inventory.
	for (i = InventoryItems.Length - 1; i >= 0; i--)
	{
		if (IsSlotMultiItem(InventoryItems[i].eSlot))
		{
			//	If this loadout slot is a multi item slot, then grab all items from it
			ItemStates = NewUnitState.GetAllItemsInSlot(InventoryItems[i].eSlot,,, true);
			foreach ItemStates(ItemState)
			{
				if (IsItemInLoadout(ItemState, InventoryItems))
				{
					`LOG("Soldier already has the item we want: " @ ItemState.GetMyTemplateName() @ "in" @ ItemState.InventorySlot @ ", skipping. END.", default.bLog, 'IRIALM');
					if (ItemState.GetReference() == InventoryItems[i].EquipmentRef)
					{
						//	This item currently equipped in the multi slot is listed in the loadout, and in THIS list item, so we trim this list item from the list.
						InventoryItems.Remove(i, 1);
						i--;
					}
					//else
					//{	
						//	This item currently equipped in the multi slot is listed in the loadout, but not in THIS list item, so we do nothing for now.
					//}
					continue;
				}
				else
				{
					//	This item currently equipped in the multi slot is NOT listed in the loadout, so we remove it from the soldier.
					ItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', ItemState.ObjectID));
					if (NewUnitState.RemoveItemFromInventory(ItemState, NewGameState))
					{
						`LOG("SUCCESSFULLY removed item: " @ ItemState.GetMyTemplateName() @ "from Multi Slot: " @ InventoryItems[i].eSlot, default.bLog, 'IRIALM');
						XComHQ.PutItemInInventory(NewGameState, ItemState);
						bChangedSomething = true;
					}
					else
					{
						//	We weren't able to remove this item from the multi slot, but since this is a multi slot, we don't remove the loadout list item from the list,
						//	as it may still be potentially equipped later.
						`LOG("FAILED to remove item: " @ ItemState.GetMyTemplateName() @ "from Multi Slot: " @ InventoryItems[i].eSlot, default.bLog, 'IRIALM');
					}
				}
			}
		}
		else	//	Not a Multi Slot item
		{
			EquippedItemState = NewUnitState.GetItemInSlot(InventoryItems[i].eSlot);

			//	If this slot contains no item, then we don't need to do anything for now.
			if (EquippedItemState == none) 
			{
				`LOG(EqInfo.eSlot @ "is currently empty, proceeding.", default.bLog, 'IRIALM');
				continue;
			}

			if (EquippedItemState.GetReference() == InventoryItems[i].EquipmentRef)
			{
				//	This item is already a part of the loadout and it is in the right place. So the ALM doesn't need to process it, and we remove it from the list of items-to-equip.
				`LOG("Soldier already has the item we want: " @ EquippedItemState.GetMyTemplateName() @ "in" @ EquippedItemState.InventorySlot @ ", skipping. END.", default.bLog, 'IRIALM');
				InventoryItems.Remove(i, 1);
				i--;
				continue;
			}
			else
			{
				//	This item is not in the loadout, yet it is equipped on the soldier, taking the slot we want for the loadout item. What herecy! 
				//	Remove the item from the soldier to free the slot so that the item from the saved loadout can be equipped.
				`LOG(EqInfo.eSlot @ "is occupied by: " @ EquippedItemState.GetMyTemplateName() @", attempting to unequip.", default.bLog, 'IRIALM');
				EquippedItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', EquippedItemState.ObjectID));
				
				if (NewUnitState.RemoveItemFromInventory(EquippedItemState, NewGameState))
				{
					`LOG("SUCCESSFULY uneqipped the item. Putting it into HQ Inventory and proceeding.", default.bLog, 'IRIALM');
					XComHQ.PutItemInInventory(NewGameState, EquippedItemState);
					bChangedSomething = true;
					continue;
				}
				else
				{
					ItemState = XComGameState_Item(History.GetGameStateForObjectID(InventoryItems[i].EquipmentRef.ObjectID));
					`LOG("CRITICAL ERROR, FAILED to uneqip the item. REMOVING loadout item:" @ (ItemState != none ? ItemState.GetMyTemplateName() : 'NO_LOADOUT_ITEM_STATE') @ " so we don't try to equip something into this slot later. END.", default.bLog, 'IRIALM');
					InventoryItems.Remove(i, 1);
					i--;
					continue;
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
	ItemState = none;
	`LOG("------------------- END LOADOUT TRIM --------------------------------", default.bLog, 'IRIALM');
	if (InventoryItems.Length == 0) 
	{
		`LOG("=================== ALL LOADOUT ITEMS ARE ALREADY EQUIPPED, EXITING ===================", default.bLog, 'IRIALM');
		return;
	}

	//	Cycle through the trimmed loadout list. At this point in time, the list should be trimmed from all items that are already equipped on the soldier,
	//	and other slots mentioned in the loadout list should be empty.
	foreach InventoryItems(EqInfo)
	{
		//	Prep gamestates for changes. Equipping each item is done in a separate NewGameState, so that OnEquippedFns can do their thing properly.
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Loading Loadout For Unit");
		NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));

		//	If this loadout item is meant for a multi item slot, and that multi item slot is already at full capacity, then we skip it.
		if (IsSlotMultiItem(EqInfo.eSlot) && !DoesMultiItemSlotHaveFreeSpace(EqInfo.eSlot, NewUnitState))
		{
			`LOG("ERROR, Multi Item Slot:" @ EqInfo.eSlot @ "is already at full capacity, CANNOT equip new items into it. END.", default.bLog, 'IRIALM');
			History.CleanupPendingGameState(NewGameState);
			continue;
		}

		//	Begin
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		HistoryItemState = XComGameState_Item(History.GetGameStateForObjectID(EqInfo.EquipmentRef.ObjectID));
		if (HistoryItemState == none)
		{
			`LOG("CRITICAL ERROR, FAILED to  retrieve saved item from History! Cannot attempt to equip this part of the loadout. END.", default.bLog, 'IRIALM');
			`redscreen("ALM Error, could not retrieve saved item from History! -Iridar, ID: " @ EqInfo.EquipmentRef.ObjectID);
			History.CleanupPendingGameState(NewGameState);
			continue;
		}
		else
		{
			`LOG("Begin search for: " @ HistoryItemState.GetMyTemplateName() @ " for " @ EqInfo.eSlot, default.bLog, 'IRIALM');
			//	Skip sizeless items
			if (HistoryItemState.GetMyTemplate().iItemSize < 1) 
			{
				`LOG("This item is sizeless, skipping. END.", default.bLog, 'IRIALM');
				History.CleanupPendingGameState(NewGameState);
				continue;
			}
		}

		//	Try to find the exact item saved in the loadout in HQ Inventory.
		InvIndex = XComHQ.Inventory.Find('ObjectID', EqInfo.EquipmentRef.ObjectID);
		if(InvIndex != INDEX_NONE)
		{
			// Found the exact item in the inventory, so it wasn't equipped by another soldier
			XComHQ.GetItemFromInventory(NewGameState, XComHQ.Inventory[InvIndex], ItemState);
			//	GetItemFromInventory already sets up the Item State for modification.
			`LOG("SUCCESSFULLY found exact match in HQ Inventory: " @ ItemState.GetMyTemplateName(), default.bLog, 'IRIALM');
		}
		else
		{
			`LOG("FAILED to find exact match in HQ Inventory, looking for an unmodified instance of the same item.", default.bLog, 'IRIALM');

			// Did not find the object in the HQ inventory, it must be equipped on someone else. Try to find an unmodified item to replace it.
			UnmodifiedItemState = FindUnmodifiedItem(XComHQ, HistoryItemState.GetMyTemplate(), NewGameState);
			//	FindUnmodifiedItem already sets up the Item State for modification, cuz it's calling GetItemFromInventory
			if (UnmodifiedItemState == none)
			{
				`LOG("CRITICAL ERROR, FAILED to find unmodified version. Looking for a replacement.", default.bLog, 'IRIALM');
				
				ItemState = FindBestReplacementItemForUnit(NewUnitState, HistoryItemState.GetMyTemplate(), EqInfo.eSlot, XComHQ, NewGameState);

				if (ItemState == none)
				{
					`LOG("CRITICAL ERROR, FAILED to find a replacement for a missing unmodified item. CANNOT proceed with this part of the loadout. END.", default.bLog, 'IRIALM');
					History.CleanupPendingGameState(NewGameState);
					continue;
				}
				else
				{
					`LOG("SUCCESSFULLY found a replacement for the missing unmodified item: " @ HistoryItemState.GetMyTemplateName() @ ". Proceeding with the replacement item: " @ ItemState.GetMyTemplateName(), default.bLog, 'IRIALM');
				}
			}
			else
			{
				if (bLoadoutLocked)
				{
					`LOG("SUCCESSFULLY found unmodified instance in HQ Inventory. Loadout is locked, so proceeding with the unmodified version.", default.bLog, 'IRIALM');
					ItemState = UnmodifiedItemState;
				}
				else
				{
					`LOG("SUCCESSFULLY found unmodified instance in HQ Inventory. Loadout is not locked, so looking for a better version.", default.bLog, 'IRIALM');
					ItemState = FindBestReplacementItemForUnit(NewUnitState, UnmodifiedItemState.GetMyTemplate(), EqInfo.eSlot, XComHQ, NewGameState);
					if (ItemState == none)
					{
						`LOG("FAILED to find a better version of the unmodified item: " @ UnmodifiedItemState.GetMyTemplateName() @ ", proceeding with the unmodified item.", default.bLog, 'IRIALM');
						ItemState = UnmodifiedItemState;
					}
					else
					{
						`LOG("SUCCESSFULLY found a replacement for the existing unmodified item: " @ HistoryItemState.GetMyTemplateName() @ ". Proceeding with the replacement item: " @ ItemState.GetMyTemplateName(), default.bLog, 'IRIALM');
						XComHQ.PutItemInInventory(NewGameState, UnmodifiedItemState);
					}
				}
			}			
		}

		if (NewUnitState.AddItemToInventory(ItemState, EqInfo.eSlot, NewGameState))
		{
			`LOG("SUCCESSFULLY equipped item:" @ ItemState.GetMyTemplateName() @ "in slot: " @ EqInfo.eSlot, default.bLog, 'IRIALM');
			`GAMERULES.SubmitGameState(NewGameState);
		}
		else
		{
			`LOG("FAILED to equip item: " @ ItemState.GetMyTemplateName() @ "into slot: " @ EqInfo.eSlot @ ". END.", default.bLog, 'IRIALM');
			History.CleanupPendingGameState(NewGameState);
		}
	}
}

private static function XComGameState_Item FindUnmodifiedItem(out XComGameState_HeadquartersXCom XComHQ, const X2ItemTemplate ItemTemplate, out XComGameState NewGameState)
{
	local XComGameState_Item	ItemState;

	if (XComHQ.HasUnModifiedItem(NewGameState, ItemTemplate, ItemState))
	{
		//	This will prep the Item State for modification and remove it from HQ inventory
		XComHQ.GetItemFromInventory(NewGameState, ItemState.GetReference(), ItemState);
		return ItemState;
	}
	return none;	
}

private static function bool IsItemInLoadout(const XComGameState_Item EquippedItemState, const array<EquipmentInfo> InventoryItems)
{
    local XComGameState_Item		LoadoutItemState;
    local XComGameStateHistory		History;
    local EquipmentInfo				EqInfo;
    local name						EquippedItemName;

    History = `XCOMHISTORY;
    EquippedItemName = EquippedItemState.GetMyTemplateName();

    foreach InventoryItems(EqInfo)
    {
        LoadoutItemState = XComGameState_Item(History.GetGameStateForObjectID(EqInfo.EquipmentRef.ObjectID));

        if (LoadoutItemState != none && LoadoutItemState.GetMyTemplateName() == EquippedItemName) return true;
    }
    return false;
}

private static function bool DoesMultiItemSlotHaveFreeSpace(EInventorySlot Slot, const XComGameState_Unit UnitState)
{
	local X2StrategyElementTemplate CHVersion;
	local array<XComGameState_Item> ItemStates;

	ItemStates = UnitState.GetAllItemsInSlot(Slot,,, true);
	CHVersion = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindStrategyElementTemplate('CHXComGameVersion');

	if (CHVersion != none)
	{
		return ItemStates.Length < class'CHItemSlot'.static.SlotGetMaxItemCount(Slot, UnitState);
	}
	else
	{
		switch (Slot)
		{
			case eInvSlot_Utility:
				return ItemStates.Length < int(UnitState.GetCurrentStat(eStat_UtilityItems));
			case eInvSlot_CombatSim:
				return ItemStates.Length < int(UnitState.GetCurrentStat(eStat_CombatSims));
			case eInvSlot_Backpack:
				return false;
			case eInvSlot_HeavyWeapon:
				return ItemStates.Length < UnitState.GetNumHeavyWeapons();
			default:
				`LOG("WARNING, DoesMultiItemSlotHaveFreeSpace called with unknown, untemplated inventory slot:" @ Slot @ "on unit:" @ UnitState.GetFullName(), default.bLog, 'IRIALM');
				return false;
		}
	}
}

/*
{
	local XComGameStateHistory	History;
	local XComGameState_Item	ItemState;
	local int i;

	History = `XCOMHISTORY;

	for(i = 0; i < XComHQ.Inventory.Length; i++)
	{
		ItemState = XComGameState_Item(History.GetGameStateForObjectID(XComHQ.Inventory[i].ObjectID));

		if(ItemState != none && !ItemState.HasBeenModified() && ItemState.GetMyTemplateName() == TemplateName)
		{
			//	This will prep the Item State for modification and remove it from HQ inventory
			XComHQ.GetItemFromInventory(NewGameState, XComHQ.Inventory[i], ItemState);
			return ItemState;
		}
	}
	return none;
}
*/

private static function bool IsSlotMultiItem(EInventorySlot Slot)
{
	local X2StrategyElementTemplate CHVersion;

	CHVersion = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindStrategyElementTemplate('CHXComGameVersion');

	if (CHVersion != none)
	{
		return class'CHItemSlot'.static.SlotIsMultiItem(Slot);
	}
	else
	{
		//	Thanks for cool syntax, MrNice
		switch (Slot)
		{
			case eInvSlot_Backpack:
			case eInvSlot_Utility:
			case eInvSlot_HeavyWeapon:
			case eInvSlot_CombatSim:
				return true;
			default:
				return false;
		}
	}
}

/*
{
	local XComGameStateHistory				History;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_Item				ItemState, InvItemState;
	local array<XComGameState_Item>			UtilityItems;
	local X2EquipmentTemplate				ItemTemplate;
	local int idx, InvIndex;

	History = `XCOMHISTORY;

	// Grab HQ Object
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

	// Try to find old items
	for(idx = 0; idx < InventoryItems.Length; idx++)
	{
		ItemState = none;
		InvIndex = XComHQ.Inventory.Find('ObjectID', InventoryItems[idx].EquipmentRef.ObjectID);

		`LOG("Attempting to equip item: #" @ idx, default.bLog, 'IRIALS');

		if(InvIndex != INDEX_NONE)
		{
			// Found the exact item in the inventory, so it wasn't equipped by another soldier
			XComHQ.GetItemFromInventory(NewGameState, XComHQ.Inventory[InvIndex], InvItemState);
			`LOG("Found it in HQ inventory: " @ InvItemState.GetMyTemplate().FriendlyName, default.bLog, 'IRIALS');
		}
		else
		{
			`LOG("Did not find it in HQ inventory, looking for the next best thing.", default.bLog, 'IRIALS');
			ItemState = XComGameState_Item(History.GetGameStateForObjectID(InventoryItems[idx].EquipmentRef.ObjectID));

			// Try to find an unmodified item with the same template
			for(InvIndex = 0; InvIndex < XComHQ.Inventory.Length; InvIndex++)
			{
				InvItemState = XComGameState_Item(History.GetGameStateForObjectID(XComHQ.Inventory[InvIndex].ObjectID));

				if(InvItemState != none && !InvItemState.HasBeenModified() && InvItemState.GetMyTemplateName() == ItemState.GetMyTemplateName())
				{
					`LOG("Did not find it in HQ inventory, looking for the next best thing: " @ InvItemState.GetMyTemplateName(), default.bLog, 'IRIALS');
					XComHQ.GetItemFromInventory(NewGameState, XComHQ.Inventory[InvIndex], InvItemState);
					break;
				}

				InvItemState = none;
			}
		}

		//	INSERT IRIDAR
		//	So, we didn't find the original item, and we did not find an unmodified version of the same item (e.g. a weapon without weapon upgrades)
		if (InvItemState == none)
		{
			InvItemState = FindReplacementItemForUnit(NewUnitState, InventoryItems[idx], XComHQ);
			`LOG("Replacement item: " @ InvItemState.GetMyTemplateName(), default.bLog, 'IRIALS');
		}
		//	END INSERT

		// We found a version of the old item available to equip
		if(InvItemState != none)
		{
			InvItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', InvItemState.ObjectID));
			
			ItemTemplate = X2EquipmentTemplate(InvItemState.GetMyTemplate());
			if(ItemTemplate != none)
			{
				ItemState = none;


				//  If we can't add an item, there's probably one occupying the slot already, so find it so we can remove it.
				//start issue #114: pass along item state in case there's a reason the soldier should be unable to re-equip from a mod
				if(!NewUnitState.CanAddItemToInventory(ItemTemplate, InventoryItems[idx].eSlot, NewGameState, InvItemState.Quantity, InvItemState))
				{
				//end issue #114
					
					`LOG("Was unable to equip it on first attempt.", default.bLog, 'IRIALS');
					// Issue #118 Start: change hardcoded check for utility item
					if (class'CHItemSlot'.static.SlotIsMultiItem(InventoryItems[idx].eSlot))
					{
						// If there are multiple utility items, grab the last one to try and replace it with the restored item
						UtilityItems = NewUnitState.GetAllItemsInSlot(InventoryItems[idx].eSlot, NewGameState, , true);
						ItemState = UtilityItems[UtilityItems.Length - 1];
					}
					else
					{
						// Otherwise just look for an item in the slot we want to restore
						ItemState = NewUnitState.GetItemInSlot(InventoryItems[idx].eSlot, NewGameState);
					}
				}
				else
				{
					`LOG("Equipped it on first attempt.", default.bLog, 'IRIALS');
				}

        
				// If we found an item to replace with the restored equipment, it will be stored in ItemState, and we need to put it back into the inventory
				if(ItemState != none)
				{
					ItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', ItemState.ObjectID));
					
					// Try to remove the item we want to replace from our inventory
					if(!NewUnitState.RemoveItemFromInventory(ItemState, NewGameState))
					{
						// Removing the item failed, so add our restored item back to the HQ inventory
						XComHQ.PutItemInInventory(NewGameState, InvItemState);
						continue;
					}

					// Otherwise we successfully removed the item, so add it to HQ's inventory
					XComHQ.PutItemInInventory(NewGameState, ItemState);
				}

				// If we still can't add the restored item to our inventory, put it back into the HQ inventory where we found it and move on
				//issue #114: pass along item state in case a mod has a reason to prevent this from being equipped
				if(!NewUnitState.CanAddItemToInventory(ItemTemplate, InventoryItems[idx].eSlot, NewGameState, InvItemState.Quantity, InvItemState))
				{
				//end issue #114
					XComHQ.PutItemInInventory(NewGameState, InvItemState);
					continue;
				}

				if(ItemTemplate.IsA('X2WeaponTemplate'))
				{
					if(ItemTemplate.InventorySlot == eInvSlot_PrimaryWeapon)
						InvItemState.ItemLocation = eSlot_RightHand;
					else
						InvItemState.ItemLocation = X2WeaponTemplate(ItemTemplate).StowedLocation;
				}

				// Add the restored item to our inventory
				NewUnitState.AddItemToInventory(InvItemState, InventoryItems[idx].eSlot, NewGameState);
			}
		}
	}
	//NewUnitState.ApplyBestGearLoadout(NewGameState);
}*/

//	Find the next best thing to the item that is not currently available for equipping

private static function XComGameState_Item FindBestReplacementItemForUnit(const XComGameState_Unit UnitState, const X2ItemTemplate OrigItemTemplate, const EInventorySlot eSlot, out XComGameState_HeadquartersXCom XComHQ, out XComGameState NewGameState)
{
	local X2WeaponTemplate		OrigWeaponTemplate;
	local X2WeaponTemplate		WeaponTemplate;
	local X2ArmorTemplate		OrigArmorTemplate;
	local X2ArmorTemplate		ArmorTemplate;
	local X2EquipmentTemplate	OrigEquipmentTemplate;
	local X2EquipmentTemplate	EquipmentTemplate;
	local XComGameStateHistory	History;
	local int					HighestTier;
	local XComGameState_Item	ItemState;
	local XComGameState_Item	BestItemState;
	local StateObjectReference	ItemRef;

	HighestTier = -999;
	History = `XCOMHISTORY;

	OrigWeaponTemplate = X2WeaponTemplate(OrigItemTemplate);
	if (OrigWeaponTemplate != none)
	{
		foreach XComHQ.Inventory(ItemRef)
		{
			ItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemRef.ObjectID));
			WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());

			if (WeaponTemplate != none)
			{
				if (WeaponTemplate.WeaponCat == OrigWeaponTemplate.WeaponCat && /*WeaponTemplate.InventorySlot == OrigWeaponTemplate.InventorySlot && */	//	Removing this for the sake of compatibility with new PS. CanAddItemToInventory should handle this, in theory.
					WeaponTemplate.bInfiniteItem &&
					UnitState.CanAddItemToInventory(WeaponTemplate, eSlot, NewGameState, ItemState.Quantity, ItemState))
				{
					if (WeaponTemplate.Tier > HighestTier)
					{
						HighestTier = WeaponTemplate.Tier;
						BestItemState = ItemState;
					}
				}
			}
		}
	}
	OrigArmorTemplate = X2ArmorTemplate(OrigItemTemplate);
	if (OrigArmorTemplate != none)
	{
		foreach XComHQ.Inventory(ItemRef)
		{
			ItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemRef.ObjectID));
			ArmorTemplate = X2ArmorTemplate(ItemState.GetMyTemplate());

			if (ArmorTemplate != none)
			{
				if (ArmorTemplate.ArmorCat == OrigArmorTemplate.ArmorCat && ArmorTemplate.ArmorClass == OrigArmorTemplate.ArmorClass &&
					ArmorTemplate.bInfiniteItem &&
					UnitState.CanAddItemToInventory(ArmorTemplate, eSlot, NewGameState, ItemState.Quantity, ItemState))
				{
					if (ArmorTemplate.Tier > HighestTier)
					{
						HighestTier = ArmorTemplate.Tier;
						BestItemState = ItemState;
					}
				}
			}
		}
	}
	OrigEquipmentTemplate = X2EquipmentTemplate(OrigItemTemplate);
	if (OrigEquipmentTemplate != none)
	{
		foreach XComHQ.Inventory(ItemRef)
		{
			ItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemRef.ObjectID));
			EquipmentTemplate = X2EquipmentTemplate(ItemState.GetMyTemplate());

			if (EquipmentTemplate != none)
			{
				if (EquipmentTemplate.ItemCat == OrigEquipmentTemplate.ItemCat && EquipmentTemplate.bInfiniteItem &&
					UnitState.CanAddItemToInventory(ArmorTemplate, eSlot, NewGameState, ItemState.Quantity, ItemState))
				{
					if (EquipmentTemplate.Tier > HighestTier)
					{
						HighestTier = EquipmentTemplate.Tier;
						BestItemState = ItemState;
					}
				}
			}
		}
	}
	if (HighestTier != -999)
	{
		//	This will set up the Item State for modification automatically, or create a new Item State in the NewGameState if the template is infinite.
		XComHQ.GetItemFromInventory(NewGameState, BestItemState.GetReference(), BestItemState);
		return BestItemState;
	}
	else
	{
		return none;
	}
}


/*
private static function XComGameState_Item GetBestWeaponForUnit(const XComGameState_Unit UnitState, const X2WeaponTemplate OrigWeaponTemplate, const XComGameState_HeadquartersXCom XComHQ)
{
	local XComGameStateHistory			History;
	local XComGameState_Item			ItemState;
	local StateObjectReference			ItemRef;
	local X2WeaponTemplate				WeaponTemplate;
	local X2WeaponTemplate				BestWeaponTemplate;
	local int							HighestTier;

	HighestTier = -999;
	History = `XCOMHISTORY;
	foreach XComHQ.Inventory(ItemRef)
	{
		ItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemRef.ObjectID));
		WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());

		if (WeaponTemplate != none)
		{
			if (WeaponTemplate.WeaponCat == OrigWeaponTemplate.WeaponCat && WeaponTemplate.InventorySlot == OrigWeaponTemplate.InventorySlot && 
				UnitState.CanAddItemToInventory(WeaponTemplate, WeaponTemplate.eSlot, NewGameState, ItemState.Quantity, ItemState))
			{
				if (WeaponTemplate.Tier > HighestTier)
				{
					HighestTier = WeaponTemplate.Tier;
					BestWeaponTemplate = WeaponTemplate;
				}
			}
		}
	}
	return BestWeaponTemplate;
}*/
/*
private static function X2ArmorTemplate GetBestArmorTemplateForUnit(const XComGameState_Unit UnitState, const X2ArmorTemplate OrigArmorTemplate, const XComGameState_HeadquartersXCom XComHQ)
{
	local XComGameStateHistory			History;
	local XComGameState_Item			ItemState;
	local StateObjectReference			ItemRef;
	local X2ArmorTemplate				ArmorTemplate;
	local X2ArmorTemplate				BestArmorTemplate;
	local int							HighestTier;

	HighestTier = -999;
	History = `XCOMHISTORY;
	foreach XComHQ.Inventory(ItemRef)
	{
		ItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemRef.ObjectID));
		ArmorTemplate = X2ArmorTemplate(ItemState.GetMyTemplate());

		if (ArmorTemplate != none)
		{
			if (ArmorTemplate.ArmorCat == OrigArmorTemplate.ArmorCat && ArmorTemplate.ArmorClass == OrigArmorTemplate.ArmorClass)
			{
				if (ArmorTemplate.Tier > HighestTier)
				{
					HighestTier = ArmorTemplate.Tier;
					BestArmorTemplate = ArmorTemplate;
				}
			}
		}
	}
	return BestArmorTemplate;
}*/

//	Record given Item States into given Loadout struct. Just a helper method to save space.
private static function FillOutLoadoutItems(out LoadoutStruct Loadout, const array<XComGameState_Item> AllItems, XComGameState_Unit UnitState)
{
	local XComGameState_Item		ItemState;
	local X2StrategyElementTemplate CHVersion;
	local EquipmentInfo EqInfo, EmptyEqInfo;
	local int i;

	`LOG("Filling out loadout, items: " @ AllItems.Length, default.bLog, 'IRIALS');

	CHVersion = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindStrategyElementTemplate('CHXComGameVersion');

	//	Make sure InventoryItems array has enough space to fit all loadout items
	Loadout.InventoryItems.Length = AllItems.Length;
	foreach AllItems(ItemState)
	{
		//	If the item is in a blacklisted slot, 
		if (default.IgnoredSlots.Find(ItemState.InventorySlot) != INDEX_NONE) 
		{
			`LOG("IGNORING " @ ItemState.GetMyTemplate().FriendlyName @ "because it's in a blacklisted slot: " @ ItemState.InventorySlot, default.bLog, 'IRIALS');
			continue;
		}
		else if(ItemState.GetMyTemplate().iItemSize == 0)
		{
			`LOG("IGNORING " @ ItemState.GetMyTemplateName() @ "because it's sizeless.", default.bLog, 'IRIALS');
			continue;
		}
		else if (CHVersion != none && !class'CHItemSlot'.static.SlotShouldBeShown(ItemState.InventorySlot, UnitState))
		{
			`LOG("IGNORING " @ ItemState.GetMyTemplateName() @ "because it's in a hidden slot: " @ ItemState.InventorySlot, default.bLog, 'IRIALS');
			continue;
		}
		else
		{
			`LOG("Saving into loadout: " @ ItemState.GetMyTemplate().FriendlyName, default.bLog, 'IRIALS');
		}

		//	For some reason have to store all the values in a temporary struct 
		//	instead of assigning it to Loadout.InventoryItems[i].EquipmentRef directly. I don't understand why.

		EqInfo = EmptyEqInfo;
		EqInfo.EquipmentRef = ItemState.GetReference();
		EqInfo.eSlot = ItemState.InventorySlot;
		Loadout.InventoryItems[i] = EqInfo;
		i++;
	}

	//	Make sure InventoryItems array doesn't have any empty or irrelevant members
	Loadout.InventoryItems.Length = i;
	
	// Sort the loadout before saving it (armors need to be equipped first)
	Loadout.InventoryItems.Sort(SortLoadoutItems);
}

//	Quite simply, calculates the number of actually existing Units in any given squad.
//	We can't use Squad.Length, because the game likes to keep StateObjectReferences inside with invalid ObjectIDs.
//	They are likely just all set to zero, but I don't wanna risk, even if it's less efficient.
private static function int GetSquadSize(const array<StateObjectReference> Squad)
{
	local XComGameStateHistory	History;
	local XComGameState_Unit	UnitState;
	local int					SquadSize;
	local int i;

	History = `XCOMHISTORY;

	for (i = 0; i < Squad.Length; i++)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(Squad[i].ObjectID));

		if (UnitState != none)
		{
			SquadSize++;
		}
	}
	return SquadSize;
}

//	Returns the array of members that are pressent in BiggerSquad array, but not present in the SmallerSquad array. Cuz it's smaller. Duh.
//	Used to find out which units have been added or removed to squad.
private static function array<StateObjectReference> FindChangedUnits(const array<StateObjectReference> BiggerSquad, const array<StateObjectReference> SmallerSquad)
{
	local array<StateObjectReference>	LocalArray;
	local int i;

	LocalArray = BiggerSquad;

	for (i = 0; i < SmallerSquad.Length; i++)
	{
		LocalArray.RemoveItem(SmallerSquad[i]);
	}
	return LocalArray;
}

//	Used to sort loadout items just before a loadout is saved so that Armor is equipped first.
private static function int SortLoadoutItems(EquipmentInfo OldEquipA, EquipmentInfo OldEquipB)
{
	return (int(OldEquipB.eSlot) - int(OldEquipA.eSlot));
}

//	Outputs a loadout into Launch.log in a convenient form.
//	Used for debugging only.
private static function PrintLoadout(const array<EquipmentInfo> InventoryItems)
{
	local XComGameState_Item	ItemState;
	local XComGameStateHistory	History;
	local int i;

	History = `XCOMHISTORY;

	for (i = 0; i < InventoryItems.Length; i++)
	{
		ItemState = XComGameState_Item(History.GetGameStateForObjectID(InventoryItems[i].EquipmentRef.ObjectID));
		if (ItemState != none)
		{
			`LOG("-- " @ ItemState.GetMyTemplate().FriendlyName @ " in " @ InventoryItems[i].eSlot,, 'IRIALS');
		}
		else
		{
			`LOG("--NO ITEM STATE in " @ InventoryItems[i].eSlot,, 'IRIALS');
		}
	}
}

private static function ValidateSavedLoadoutItemList(out array<EquipmentInfo> InventoryItems)
{
	local XComGameState_Item	ItemState;
	local XComGameStateHistory	History;
	local int i;

	//	I've been seeing loadouts that contain entries that reference objects that don't appear to exist anymore, and reference eInvSlot_Unknown.
	//	Not sure how they got there, but let's trim them out just in case.
	History = `XCOMHISTORY;
	for (i = InventoryItems.Length - 1; i >= 0; i--)
	{
		if (InventoryItems[i].eSlot == eInvSlot_Unknown)
		{
			`LOG("Removed item from loadout because it referenced eInvSlot_Unknown.", default.bLog, 'IRIALS');
			InventoryItems.Remove(i, 1);
		}
		else
		{
			ItemState = XComGameState_Item(History.GetGameStateForObjectID(InventoryItems[i].EquipmentRef.ObjectID));
			if (ItemState == none)
			{
				`LOG("Removed item from loadout because its Item State doesn't exist.", default.bLog, 'IRIALS');
				InventoryItems.Remove(i, 1);
			}
		}
	}
}

//	================================================================================
//	================================================================================
//								INTERNAL PRIVATE METHODS. 
//	================================================================================
//	================================================================================
//	For calling only from inside a state object!

private function LoadLoadouts(const array<StateObjectReference> UnitRefs)
{
	local StateObjectReference UnitRef;

	foreach UnitRefs(UnitRef)
	{
		LoadLoadoutForUnit(UnitRef);
	}
}

private function LoadLoadoutForUnit(const StateObjectReference UnitRef)
{
	local int i;
	local array<EquipmentInfo>	InventoryItems;

	if (UnitRef.ObjectID != 0)
	{
		//	Update existing loadout, if it exists.
		for (i = 0; i < Loadouts.Length; i++)
		{
			if (Loadouts[i].UnitRef == UnitRef)
			{
				`LOG("Attempting to equip saved loadout on unit:" @ XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID)).GetFullName(), default.bLog, 'IRIALS');

				InventoryItems = Loadouts[i].InventoryItems;
				ValidateSavedLoadoutItemList(InventoryItems);
				if (default.bLog) 
				{
					PrintLoadout(InventoryItems);
				}
				
				EquipItemsOnUnit(UnitRef, InventoryItems, Loadouts[i].bLocked);
				return;
			}
		}
		`LOG("No saved loadout for unit:" @ XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID)).GetFullName(), default.bLog, 'IRIALS');
	}
}

private function SaveLoadouts(const array<StateObjectReference> UnitRefs, optional bool IgnoreLocked = false, optional bool SetLocked = false)
{
	local StateObjectReference UnitRef;

	foreach UnitRefs(UnitRef)
	{
		SaveLoadoutForUnit(UnitRef, IgnoreLocked, SetLocked);
	}
}

private function SaveLoadoutForUnit(const StateObjectReference UnitRef, optional bool IgnoreLocked = false, optional bool SetLocked = false)
{
	local XComGameState_Unit		UnitState;
	local array<XComGameState_Item> AllItems;
	local LoadoutStruct				Loadout;
	local int i;

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

	if (UnitState != none)
	{
		AllItems = UnitState.GetAllInventoryItems(none, true);	//	No CheckGameState, and DO exclude PCS
		Loadout.UnitRef = UnitRef;
		FillOutLoadoutItems(Loadout, AllItems, UnitState);
		
		//	Update existing loadout, if it exists.
		for (i = 0; i < Loadouts.Length; i++)
		{
			if (Loadouts[i].UnitRef == UnitRef)
			{
				if (Loadouts[i].bLocked && !IgnoreLocked)
				{
					`LOG("Loadout is locked, doing nothing.", default.bLog, 'IRIALS');
				}
				else
				{
					//	Lock loadout, if necessary
					if (SetLocked) 
					{
						Loadout.bLocked = true;
					}

					`LOG("Updating loadout for unit:" @ UnitState.GetFullName() @ "saved items:" @ Loadout.InventoryItems.Length @ "is locked: " @ Loadout.bLocked, default.bLog, 'IRIALS');

					//	Remove existing loadout
					Loadouts.Remove(i, 1);
					//	Add new loadout to replace it.
					Loadouts.AddItem(Loadout);
					PrintLoadout(Loadout.InventoryItems);
				}
				return;
			}
		}
		//	If the code reaches this point it means the Loadout for this unit has not been saved yet.
		//	So set up a new loadout and add it to the array.
		`LOG("Creating and saving loadout for unit:" @ UnitState.GetFullName() @ "saved items:" @ Loadout.InventoryItems.Length, default.bLog, 'IRIALS');

		if (SetLocked) 
		{
			Loadout.bLocked = true;
		}
		Loadouts.AddItem(Loadout);

		PrintLoadout(Loadout.InventoryItems);
	}
}