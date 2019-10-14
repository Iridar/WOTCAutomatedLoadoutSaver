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

		StateObject.LoadLoadouts(ChangedUnitRefs, NewGameState);
		StateObject.OldSquad = NewSquad;
		`GAMERULES.SubmitGameState(NewGameState);
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
private static function EquipItemsOnUnit(out XComGameState_Unit NewUnitState, const array<EquipmentInfo> InventoryItems, out XComGameState NewGameState)
{
	local XComGameStateHistory				History;
	local XComGameState_HeadquartersXCom	XComHQ;
	local EquipmentInfo						EqInfo;
	local int								InvIndex;
	local XComGameState_Item				ItemState;
	local XComGameState_Item				UnequipItemState;
	local array<XComGameState_Item>			ItemStates;
	local bool								bFoundExactMatch;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

	//	First, unequip all currently equipped Multi Slot items from the soldier and put them in HQ Inventory.
	`LOG("=======================================================", default.bLog, 'IRIALM');
	foreach InventoryItems(EqInfo)
	{
		if (IsSlotMultiItem(EqInfo.eSlot))
		{
			ItemStates = NewUnitState.GetAllItemsInSlot(EqInfo.eSlot, NewGameState, , true);

			foreach ItemStates(ItemState)
			{
				//	Skip sizeless items, like XPad (hacking pad)
				if (ItemState.GetMyTemplate().iItemSize > 0)
				{
					if (NewUnitState.RemoveItemFromInventory(ItemState, NewGameState))
					{
						`LOG("SUCCESSFULLY removed item: " @ ItemState.GetMyTemplateName() @ "from Multi Slot: " @ EqInfo.eSlot, default.bLog, 'IRIALM');
						XComHQ.PutItemInInventory(NewGameState, ItemState);
					}
					else
					{
						`LOG("FAILED to removed item: " @ ItemState.GetMyTemplateName() @ "from Multi Slot: " @ EqInfo.eSlot, default.bLog, 'IRIALM');
					}
				}
			}
		}
	}
	`LOG("----------------------------------------------------------", default.bLog, 'IRIALM');

	foreach InventoryItems(EqInfo)
	{
		bFoundExactMatch = false;

		//	DEBUGGING ONLY
		ItemState = XComGameState_Item(History.GetGameStateForObjectID(EqInfo.EquipmentRef.ObjectID));
		`LOG("Begin search for equipment item: " @ ItemState.GetMyTemplateName(), default.bLog, 'IRIALM');
		//	END DEBUGGING

		//	Try to find the exact item saved in the loadout.
		InvIndex = XComHQ.Inventory.Find('ObjectID', EqInfo.EquipmentRef.ObjectID);
		if(InvIndex != INDEX_NONE)
		{
			// Found the exact item in the inventory, so it wasn't equipped by another soldier
			`LOG("SUCCESSFULLY found exact match in HQ Inventory.", default.bLog, 'IRIALM');
			XComHQ.GetItemFromInventory(NewGameState, XComHQ.Inventory[InvIndex], ItemState);
			bFoundExactMatch = true;
		}
		else
		{
			`LOG("FAILED to find exact match in HQ Inventory, looking for an unmodified instance.", default.bLog, 'IRIALM');

			// Did not find the object in the HQ inventory, it must be equipped on someone else.
			// Get the latest available state from History and ...
			ItemState = XComGameState_Item(History.GetGameStateForObjectID(EqInfo.EquipmentRef.ObjectID));
			if (ItemState == none) 
			{
				`LOG("CRITICAL ERROR, FAILED to  retrieve saved item from History! Cannot begin search for unmodified item. END.", default.bLog, 'IRIALM');
				`redscreen("ALM Error, could not retrieve saved item from History! -Iridar");
				continue;
			}

			//	Skip sizeless items
			if (ItemState.GetMyTemplate().iItemSize < 1) 
			{
				`LOG("This item is sizeless, skipping. END.", default.bLog, 'IRIALM');
				continue;
			}

			//	... and try to find an unmodified item to replace it.
			ItemState = FindUnmodifiedItem(XComHQ, ItemState.GetMyTemplateName(), NewGameState);
			if (ItemState == none)
			{
				`LOG("CRITICAL ERROR, FAILED to find unmodified version. Looking for a replacement.", default.bLog, 'IRIALM');
				ItemState = XComGameState_Item(History.GetGameStateForObjectID(EqInfo.EquipmentRef.ObjectID));
				if (ItemState == none) 
				{
					`LOG("CRITICAL ERROR, FAILED to  retrieve saved item from History! Cannot begin search for a replacement item. END.", default.bLog, 'IRIALM');
					`redscreen("ALM Error, could not retrieve saved item from History! -Iridar");
					continue;
				}
			}
			else
			{
				`LOG("SUCCESSFULLY found unmodified instance in HQ Inventory.", default.bLog, 'IRIALM');
			}
		}

		if (NewUnitState.CanAddItemToInventory(ItemState.GetMyTemplate(), EqInfo.eSlot, NewGameState, ItemState.Quantity, ItemState))
		{
			//	BEGIN COPYPASTE
			if (!bFoundExactMatch)
			{
				`LOG("Attempting to replace the unmodified item with a better version.", default.bLog, 'IRIALM');
				if (FindBestReplacementItemForUnit(NewUnitState, ItemState, EqInfo.eSlot, XComHQ, NewGameState))
				{
					`LOG("SUCCESSFULLY found a better replacement: " @ ItemState.GetMyTemplateName(), default.bLog, 'IRIALM');
				}
				else
				{
					`LOG("FAILED to find a better replacement, using the original unmodified item.", default.bLog, 'IRIALM');
				}
			}
			// END COPYPASTE

			if (NewUnitState.AddItemToInventory(ItemState, EqInfo.eSlot, NewGameState))
			{
				`LOG("SUCCESSFULLY equipped it on first attempt.", default.bLog, 'IRIALM');
			}
			else
			{
				`LOG("FAILED to equip it on first attempt, slot must be occupied.", default.bLog, 'IRIALM');
			}
		}
		else	//	If we can't add item to inventory, it must be because the slot is occupied by something else
		{
			//	Unequip it from unit and put in HQ Inventory
			UnequipItemState = NewUnitState.GetItemInSlot(EqInfo.eSlot, NewGameState);
			if (UnequipItemState == none)
			{
				`LOG("Slot was empty, must be unable to equip for some other reason. I will put the item I wanted to equip back into HQ inventory and move on. END.", default.bLog, 'IRIALM');
				XComHQ.PutItemInInventory(NewGameState, ItemState);
				continue;
			}
			else
			{
				`LOG("Slot was occupied by the item: " @ UnequipItemState.GetMyTemplateName() @ ", attempting to unequip.", default.bLog, 'IRIALM');
			
				UnequipItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', UnequipItemState.ObjectID));
				if (NewUnitState.RemoveItemFromInventory(UnequipItemState, NewGameState))
				{
					`LOG("SUCCESSFULY uneqipped the item. Putting it into HQ Inventory.", default.bLog, 'IRIALM');
					XComHQ.PutItemInInventory(NewGameState, UnequipItemState);

					//	BEGIN COPYPASTE
					if (!bFoundExactMatch)
					{
						`LOG("Attempting to replace the unmodified item with a better version.", default.bLog, 'IRIALM');
						if (FindBestReplacementItemForUnit(NewUnitState, ItemState, EqInfo.eSlot, XComHQ, NewGameState))
						{
							`LOG("SUCCESSFULLY found a better replacement: " @ ItemState.GetMyTemplateName(), default.bLog, 'IRIALM');
						}
						else
						{
							`LOG("FAILED to find a better replacement, using the original unmodified item.", default.bLog, 'IRIALM');
						}
					}
					// END COPYPASTE

					if (NewUnitState.AddItemToInventory(ItemState, EqInfo.eSlot, NewGameState))
					{
						`LOG("SUCCESSFULY eqipped the item: " @ ItemState.GetMyTemplateName() @ "on the soldier on second attempt. END.", default.bLog, 'IRIALM');
					}
					else
					{
						`LOG("CRITICAL ERROR, could not equip eqipped the item: " @ ItemState.GetMyTemplateName() @ "on the soldier. Equipping the unequipped item back on the unit and moving on.", default.bLog, 'IRIALM');
						XComHQ.GetItemFromInventory(NewGameState, UnequipItemState.GetReference(), UnequipItemState);
						NewUnitState.AddItemToInventory(UnequipItemState, EqInfo.eSlot, NewGameState);
						continue;
					}
				}
			}
		}
	}
}

private static function XComGameState_Item FindUnmodifiedItem(const XComGameState_HeadquartersXCom XComHQ, name TemplateName, out XComGameState NewGameState)
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

private static function bool FindBestReplacementItemForUnit(const XComGameState_Unit UnitState, out XComGameState_Item OutItemState, const EInventorySlot eSlot, out XComGameState_HeadquartersXCom XComHQ, out XComGameState NewGameState)
{
	local X2WeaponTemplate		OrigWeaponTemplate;
	local X2WeaponTemplate		WeaponTemplate;
	local X2ArmorTemplate		OrigArmorTemplate;
	local X2ArmorTemplate		ArmorTemplate;
	local XComGameStateHistory	History;
	local int					HighestTier;
	local XComGameState_Item	ItemState;
	local XComGameState_Item	BestItemState;
	local StateObjectReference	ItemRef;

	HighestTier = -999;
	History = `XCOMHISTORY;

	OrigWeaponTemplate = X2WeaponTemplate(OutItemState.GetMyTemplate());
	if (OrigWeaponTemplate != none)
	{
		foreach XComHQ.Inventory(ItemRef)
		{
			ItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemRef.ObjectID));
			WeaponTemplate = X2WeaponTemplate(ItemState.GetMyTemplate());

			if (WeaponTemplate != none)
			{
				if (WeaponTemplate.WeaponCat == OrigWeaponTemplate.WeaponCat && WeaponTemplate.InventorySlot == OrigWeaponTemplate.InventorySlot && 
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
		if (HighestTier != -999)
		{
			XComHQ.GetItemFromInventory(NewGameState, BestItemState.GetReference(), OutItemState);
			return true;
		}
		return false;
	}
	OrigArmorTemplate = X2ArmorTemplate(OutItemState.GetMyTemplate());
	if (OrigArmorTemplate != none)
	{
		foreach XComHQ.Inventory(ItemRef)
		{
			ItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemRef.ObjectID));
			ArmorTemplate = X2ArmorTemplate(ItemState.GetMyTemplate());

			if (ArmorTemplate != none)
			{
				if (ArmorTemplate.ArmorCat == OrigArmorTemplate.ArmorCat && ArmorTemplate.ArmorClass == OrigArmorTemplate.ArmorClass &&
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
		if (HighestTier != -999)
		{
			XComHQ.GetItemFromInventory(NewGameState, BestItemState.GetReference(), OutItemState);
			return true;
		}
		return false;
	}
	//	Not a Weapon or Armor template, don't do anything.
	`LOG("FAILED to find a better replacement because the item was not a Weapon or Armor template.", default.bLog, 'IRIALM');
	return false;
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

//	Record give Item States into given Loadout struct. Just a helper method to save space.
private static function FillOutLoadoutItems(out LoadoutStruct Loadout, const array<XComGameState_Item> AllItems)
{
	local EquipmentInfo				EqInfo, EmptyEqInfo;
	local int i;

	`LOG("Filling out loadout, items: " @ AllItems.Length, default.bLog, 'IRIALS');

	for (i = 0; i < AllItems.Length; i++)
	{
		`LOG("Saving into loadout: " @ AllItems[i].GetMyTemplate().FriendlyName, default.bLog, 'IRIALS');

		//	For some reason have to store all the values in a temporary struct 
		//	instead of assigning it to Loadout.InventoryItems[i].EquipmentRef directly. I don't understand why.
		EqInfo = EmptyEqInfo;
		EqInfo.EquipmentRef = AllItems[i].GetReference();
		EqInfo.eSlot = AllItems[i].InventorySlot;
		Loadout.InventoryItems[i] = EqInfo;
	}

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
private static function PrintLoadout(const LoadoutStruct Loadout)
{
	local XComGameState_Item	ItemState;
	local XComGameStateHistory	History;
	local int i;

	History = `XCOMHISTORY;

	for (i = 0; i < Loadout.InventoryItems.Length; i++)
	{
		ItemState = XComGameState_Item(History.GetGameStateForObjectID(Loadout.InventoryItems[i].EquipmentRef.ObjectID));

		`LOG("-- " @ ItemState.GetMyTemplate().FriendlyName @ " in " @ Loadout.InventoryItems[i].eSlot,, 'IRIALS');
	}
}

//	================================================================================
//	================================================================================
//								INTERNAL PRIVATE METHODS. 
//	================================================================================
//	================================================================================
//	For calling only from inside a state object!

private function LoadLoadouts(const array<StateObjectReference> UnitRefs, out XComGameState NewGameState)
{
	local StateObjectReference UnitRef;

	foreach UnitRefs(UnitRef)
	{
		LoadLoadoutForUnit(UnitRef, NewGameState);
	}
}

private function LoadLoadoutForUnit(const StateObjectReference UnitRef, out XComGameState NewGameState)
{
	local XComGameState_Unit NewUnitState;
	local int i;

	NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitRef.ObjectID));

	if (NewUnitState != none)
	{
		//	Update existing loadout, if it exists.
		for (i = 0; i < Loadouts.Length; i++)
		{
			if (Loadouts[i].UnitRef == UnitRef)
			{
				`LOG("Attempting to equip saved loadout on unit:" @ NewUnitState.GetFullName(), default.bLog, 'IRIALS');
				PrintLoadout(Loadouts[i]);
				EquipItemsOnUnit(NewUnitState, Loadouts[i].InventoryItems, NewGameState);
				return;
			}
		}
		`LOG("No saved loadout for unit:" @ NewUnitState.GetFullName(), default.bLog, 'IRIALS');
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
		AllItems = UnitState.GetAllInventoryItems(none, false);	//	No CheckGameState, and DO NOT exclude PCS
		Loadout.UnitRef = UnitRef;
		FillOutLoadoutItems(Loadout, AllItems);
		
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
					`LOG("Updating loadout for unit:" @ UnitState.GetFullName() @ "saved items:" @ Loadout.InventoryItems.Length, default.bLog, 'IRIALS');
					Loadouts[i] = Loadout;

					if (SetLocked) 
					{
						Loadouts[i].bLocked = true;
					}

					PrintLoadout(Loadout);
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

		PrintLoadout(Loadout);
	}
}