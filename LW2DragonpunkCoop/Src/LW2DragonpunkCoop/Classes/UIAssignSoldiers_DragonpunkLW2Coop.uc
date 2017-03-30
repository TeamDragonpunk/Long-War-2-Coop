// This is an Unreal Script

class UIAssignSoldiers_DragonpunkLW2Coop extends UIRecruitSoldiers;

var array<int> ClientSoldiersObjectIDs;
var array<int> ServerSoldiersObjectIDs;
var StateObjectReference MissionRef;

var UILargeButton LaunchButton;

simulated function OnStartMissionClicked(UIButton button) //When clicking on the button to go to squad select.
{
	local StateObjectReference MissionRef;
	local int i,k;
	local XComGameState_Unit Unit;
	local XComGameState NewGameState;
	local XComGameState_LWPersistentSquad InfiltratingSquad;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState UpdateState;
	local XComGameState_LWSquadManager SquadMgr;	
	local StateObjectReference TempSoldierRef;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Soldiers On LW2 Coop");
	button.SetDisabled(true,"");
	foreach ClientSoldiersObjectIDs(i)
	{
		Unit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', i));
		NewGameState.AddStateObject(Unit);
		Unit.SetBaseMaxStat(eStat_FlightFuel,10);
		`log("Changed Unit to Client:" @i);
	}	
	
	SquadMgr = class'XComGameState_LWSquadManager'.static.GetSquadManager();
	InfiltratingSquad = SquadMgr.GetSquadOnMission(UIMission_LWLaunchDelayedMission(`SCREENSTACK.GetFirstInstanceOf(class'UIMission_LWLaunchDelayedMission')).MissionRef);
	if(InfiltratingSquad == none)
	{
		`log("SQUAD IS EMPTY!");
		return;
	}
	
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	`log("Submitted GameState");
	if(UIMission_LWLaunchDelayedMission(`SCREENSTACK.GetFirstInstanceOf(class'UIMission_LWLaunchDelayedMission')) != none )
	{
		`log("Found Delayed Mission");

		// update the XComHQ mission ref first, so that it is available when setting the squad
		XComHQ = `XCOMHQ;
		UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update XComHQ for current mission being started");
		XComHQ = XComGameState_HeadquartersXCom(UpdateState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		XComHQ.MissionRef = InfiltratingSquad.CurrentMission;
		UpdateState.AddStateObject(XComHQ);
		`GAMERULES.SubmitGameState(UpdateState);

		InfiltratingSquad.SetSquadCrew();

		XComHQ.PauseProjectsForFlight();
		XComHQ.ResumeProjectsPostFlight();
		`log("Before Confirm Mission");
		//TODO : handle black transition screen
		(UIMission_LWLaunchDelayedMission(`SCREENSTACK.GetFirstInstanceOf(class'UIMission_LWLaunchDelayedMission'))).GetMission().ConfirmMission();
	}
	else
		UIMission(`SCREENSTACK.GetFirstInstanceOf(class'UIMission')).OnLaunchClicked;
		
}

simulated function string GetSoldierStatsString( XComGameState_Unit Unit , optional XComGameState CheckGameState )
{

	local int  WillBonus, AimBonus, HealthBonus, MobilityBonus, TechBonus, PsiBonus, ArmorBonus, DodgeBonus;
	local string Will, Aim, Health, Mobility, Tech, Psi, Armor, Dodge, ToRet;
	
	// Get Unit base stats and any stat modifications from abilities
	Will = string(int(Unit.GetCurrentStat(eStat_Will)) + Unit.GetUIStatFromAbilities(eStat_Will));
	Aim = string(int(Unit.GetCurrentStat(eStat_Offense)) + Unit.GetUIStatFromAbilities(eStat_Offense));
	Health = string(int(Unit.GetCurrentStat(eStat_HP)) + Unit.GetUIStatFromAbilities(eStat_HP));
	Mobility = string(int(Unit.GetCurrentStat(eStat_Mobility)) + Unit.GetUIStatFromAbilities(eStat_Mobility));
	Tech = string(int(Unit.GetCurrentStat(eStat_Hacking)) + Unit.GetUIStatFromAbilities(eStat_Hacking));
	Armor = string(int(Unit.GetCurrentStat(eStat_ArmorMitigation)) + Unit.GetUIStatFromAbilities(eStat_ArmorMitigation));
	Dodge = string(int(Unit.GetCurrentStat(eStat_Dodge)) + Unit.GetUIStatFromAbilities(eStat_Dodge));

	if (Unit.bIsShaken)
	{
		Will = class'UIUtilities_Text'.static.GetColoredText(Will, eUIState_Bad);
	}

	// Get bonus stats for the Unit from items
	WillBonus = Unit.GetUIStatFromInventory(eStat_Will, CheckGameState);
	AimBonus = Unit.GetUIStatFromInventory(eStat_Offense, CheckGameState);
	HealthBonus = Unit.GetUIStatFromInventory(eStat_HP, CheckGameState);
	MobilityBonus = Unit.GetUIStatFromInventory(eStat_Mobility, CheckGameState);
	TechBonus = Unit.GetUIStatFromInventory(eStat_Hacking, CheckGameState);
	ArmorBonus = Unit.GetUIStatFromInventory(eStat_ArmorMitigation, CheckGameState);
	DodgeBonus = Unit.GetUIStatFromInventory(eStat_Dodge, CheckGameState);


	if( WillBonus > 0 )
		 Will $= class'UIUtilities_Text'.static.GetColoredText("+"$WillBonus,	eUIState_Good);
	else if (WillBonus < 0)
		Will $= class'UIUtilities_Text'.static.GetColoredText(""$WillBonus,	eUIState_Bad);

	if( AimBonus > 0 )
		Aim $= class'UIUtilities_Text'.static.GetColoredText("+"$AimBonus, eUIState_Good);
	else if (AimBonus < 0)
		Aim $= class'UIUtilities_Text'.static.GetColoredText(""$AimBonus, eUIState_Bad);

	if( HealthBonus > 0 )
		Health $= class'UIUtilities_Text'.static.GetColoredText("+"$HealthBonus, eUIState_Good);
	else if (HealthBonus < 0)
		Health $= class'UIUtilities_Text'.static.GetColoredText(""$HealthBonus, eUIState_Bad);

	if( MobilityBonus > 0 )
		Mobility $= class'UIUtilities_Text'.static.GetColoredText("+"$MobilityBonus, eUIState_Good);
	else if (MobilityBonus < 0)
		Mobility $= class'UIUtilities_Text'.static.GetColoredText(""$MobilityBonus, eUIState_Bad);

	if( TechBonus > 0 )
		Tech $= class'UIUtilities_Text'.static.GetColoredText("+"$TechBonus, eUIState_Good);
	else if (TechBonus < 0)
		Tech $= class'UIUtilities_Text'.static.GetColoredText(""$TechBonus, eUIState_Bad);
	
	if( ArmorBonus > 0 )
		Armor $= class'UIUtilities_Text'.static.GetColoredText("+"$ArmorBonus, eUIState_Good);
	else if (ArmorBonus < 0)
		Armor $= class'UIUtilities_Text'.static.GetColoredText(""$ArmorBonus, eUIState_Bad);

	if( DodgeBonus > 0 )
		Dodge $= class'UIUtilities_Text'.static.GetColoredText("+"$DodgeBonus, eUIState_Good);
	else if (DodgeBonus < 0)
		Dodge $= class'UIUtilities_Text'.static.GetColoredText(""$DodgeBonus, eUIState_Bad);

	if( PsiBonus > 0 )
		Psi $= class'UIUtilities_Text'.static.GetColoredText("+"$PsiBonus, eUIState_Good);
	else if (PsiBonus < 0)
		Psi $= class'UIUtilities_Text'.static.GetColoredText(""$PsiBonus, eUIState_Bad);

	ToRet = (Health @"," @Aim @"," @Mobility @"," @Will @"," @Tech @"," @Armor @"," @Dodge @"," @Psi);
	return ToRet;
}

simulated function OnRecruitChanged( UIList kList, int itemIndex )
{
	local XGParamTag LocTag;
	local StateObjectReference UnitRef;
	local XComGameState_Unit Unit;
	local X2ImageCaptureManager CapMan;		
	local Texture2D StaffPicture;
	local string ImageString,SoldierStatsString;

	if(itemIndex == INDEX_NONE) return;

	Unit = m_arrRecruits[itemIndex];
	UnitRef = Unit.GetReference();

	SoldierStatsString = GetSoldierStatsString(Unit);

	AS_SetCost( ( string( Unit.GetSoldierClassTemplateName() ) @"," @( class'LWUtilities_Ranks'.static.GetRankName(Unit.GetRank(), Unit.GetSoldierClassTemplateName(), Unit) ) ), Unit.GetFullName() );
	AS_SetDescription(" ");
	AS_SetTime(" "," ");
	AS_SetPicture(); // hide picture until character portrait is loaded
	
	CapMan = X2ImageCaptureManager(`XENGINE.GetImageCaptureManager());	
	ImageString = "UnitPicture"$UnitRef.ObjectID;
	StaffPicture = CapMan.GetStoredImage(UnitRef, name(ImageString));
	if(StaffPicture == none)
	{
		DeferredSoldierPictureListIndex = itemIndex;
		ClearTimer(nameof(DeferredUpdateSoldierPicture));
		SetTimer(0.1f, false, nameof(DeferredUpdateSoldierPicture));
	}	
	else
	{
		AS_SetPicture("img:///"$PathName(StaffPicture));
	}
}

simulated function GetSoldierPressed(UIButton button)
{
 	OnRecruitSelected( List,List.itemContainer.GetChildIndex(button.ParentPanel) );
}

simulated function OnRecruitSelected( UIList kList, int itemIndex )
{
	local XComGameState_Unit Soldier;

	Soldier = m_arrRecruits[itemIndex];
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("StrategyUI_Recruit_Soldier");
	
	if( ClientSoldiersObjectIDs.Find(Soldier.ObjectID) == -1 )
	{
		ClientSoldiersObjectIDs.AddItem(Soldier.ObjectID);
		ServerSoldiersObjectIDs.RemoveItem(Soldier.ObjectID);
		UIRecruitmentListItem(kList.itemContainer.GetChildAt(itemIndex)).ConfirmButton.SetBad(True,"This Unit Will Be Controller By The Other Player.");
		UIRecruitmentListItem(kList.itemContainer.GetChildAt(itemIndex)).ConfirmButton.SetText("Not Controlling");
	}
	else
	{
		ClientSoldiersObjectIDs.RemoveItem(Soldier.ObjectID);
		ServerSoldiersObjectIDs.AddItem(Soldier.ObjectID);
		UIRecruitmentListItem(kList.itemContainer.GetChildAt(itemIndex)).ConfirmButton.SetBad(False,"");
		UIRecruitmentListItem(kList.itemContainer.GetChildAt(itemIndex)).ConfirmButton.SetText("Controlling");

	}
}


simulated function UpdateNavHelp()
{
	local UINavigationHelp NavHelp;

	NavHelp = `HQPRES.m_kAvengerHUD.NavHelp;

	NavHelp.ClearButtonHelp();
	NavHelp.bIsVerticalHelp = `ISCONTROLLERACTIVE;
	NavHelp.AddBackButton(CloseScreen);

	LaunchButton = Spawn(class'UILargeButton', self);
	LaunchButton.bAnimateOnInit = false;
	LaunchButton.InitLargeButton(,"LAUNCH" , "MISSION", OnStartMissionClicked);
	LaunchButton.AnchorTopCenter();

}

simulated function UpdateData()
{
	local XComGameState_LWSquadManager SquadMgr;
	local XComGameStateHistory History;
	local StateObjectReference TempSoldierRef;
	local XComGameState_Unit   TempSoldierUnit;
	local XComGameState_LWPersistentSquad Squad;
	local UIRecruitmentListItem TempListItem;

	AS_SetTitle(m_strListTitle);

	List.ClearItems();
	m_arrRecruits.Length = 0;

	History = `XCOMHISTORY;
	
	MissionRef = UIMission(`SCREENSTACK.GetFirstInstanceOf(class'UIMission')).MissionRef;

	SquadMgr = class'XComGameState_LWSquadManager'.static.GetSquadManager();
	Squad = SquadMgr.GetSquadOnMission(MissionRef);
	`log(MissionRef.ObjectID);
	foreach Squad.SquadSoldiersOnMission(TempSoldierRef)
	{
		TempSoldierUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(TempSoldierRef.ObjectID));
		`log("Found Unit: "@TempSoldierUnit.GetFullName());
		if(TempSoldierUnit.GetFullName() != "")
		{
			m_arrRecruits.AddItem(TempSoldierUnit);
			TempListItem = UIRecruitmentListItem(List.CreateItem(class'UIRecruitmentListItem') );
			TempListItem.InitRecruitItem(TempSoldierUnit);
			class'UIRecruitmentListItem_LW'.static.AddRecruitStats(TempSoldierUnit, TempListItem);
			TempListItem.ConfirmButton.OnClickedDelegate = GetSoldierPressed;
			TempListItem.ConfirmButton.OnDoubleClickedDelegate = GetSoldierPressed;
			TempListItem.ConfirmButton.SetText("Controlling");
		}
	}
	if(m_arrRecruits.Length > 0)
	{
		List.SetSelectedIndex(0, true);
		List.Navigator.SelectFirstAvailable();
		if(ServerSoldiersObjectIDs.Length == 0 && ClientSoldiersObjectIDs.Length == 0)
		{
			foreach m_arrRecruits(TempSoldierUnit)
			{
				if(TempSoldierUnit.ObjectID != 0)
					ServerSoldiersObjectIDs.AddItem(TempSoldierUnit.ObjectID);
			}
		}
	}
	else
	{
		List.SetSelectedIndex(-1, true);
		AS_SetEmpty(m_strNoRecruits);
	}
}