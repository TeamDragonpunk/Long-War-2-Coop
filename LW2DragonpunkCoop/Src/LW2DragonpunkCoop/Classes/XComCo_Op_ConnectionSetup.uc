//  *********   DRAGONPUNK SOURCE CODE   ******************
//  FILE:    XComCo_Op_ConnectionSetup
//  AUTHOR:  Elad Dvash
//  PURPOSE: An actor that deals with connections and movement to tactical.
//---------------------------------------------------------------------------------------

class XComCo_Op_ConnectionSetup extends Actor;


var string m_strMatchOptions;
var name m_nMatchingSessionName;
var X2MPShellManager m_kMPShellManager;
var XComOnlineGameSettings ServerGameSettings;
var bool bWaitingForHistory,bFriendJoined,bCanStartMatch,bHistoryLoaded,AllPlayersLaunched,HostJoinedAlready,CalledForHistory,ForceSuccess;
var bool GoForNetworkTiming,b_ReadyToLaunch,LoadingGame;
var array<StateObjectReference> SavedSquad;
var TDialogueBoxData DialogData;
var XCom_Co_Op_TacticalGameManager TGMCoOp;
var bool Launched;
var XComGameState_BattleData m_BattleData;
var array<StateObjectReference> ServerSquad,ClientSquad,TotalSquad;
var bool NewGSWasRecieved;
var bool UseRumble;
var bool FoundMismatchMods;
var bool SentMods;
var XComOnlineGameSearch SavedRumbleSearch;

event Tick( float DeltaTime )
{
	super.Tick(DeltaTime);
}
function InitShellManager()
{
	if(m_kMPShellManager==none)
		m_kMPShellManager=Spawn(class'X2MPShellManager', self);
}

function ChangeInviteAcceptedDelegates()
{	
	local OnlineGameInterfaceXCom GameInterface;
	local XComGameStateNetworkManager NetworkMgr;

	`log("I now have the new Delegates",,'Team Dragonpunk Co Op');
	GameInterface = OnlineGameInterfaceXCom(class'GameEngine'.static.GetOnlineSubsystem().GameInterface);
	GameInterface.ClearGameInviteAcceptedDelegate(0,`ONLINEEVENTMGR.OnGameInviteAccepted);
	GameInterface.AddGameInviteAcceptedDelegate(0,OnGameInviteAccepted);	
	GameInterface.AddJoinLobbyCompleteDelegate(OnJoinLobbyComplete);
	GameInterface.AddLobbyInviteDelegate(OnLobbyInvite);
	GameInterface.AddLobbyJoinGameDelegate(OnLobbyJoinGame);
	GameInterface.AddCreateLobbyCompleteDelegate(OnCreateLobbyComplete);
	GameInterface.AddLobbyMemberStatusUpdateDelegate(OnLobbyMemberStatusUpdate);
	GameInterface.AddJoinOnlineGameCompleteDelegate(OnInviteJoinOnlineGameComplete);
	NetworkMgr = `XCOMNETMANAGER;
	//NetworkMgr.AddReceiveHistoryDelegate(ReceiveHistory);
	NetworkMgr.AddReceiveGameStateDelegate(ReceiveGameState);
	NetworkMgr.AddReceiveMergeGameStateDelegate(ReceiveMergeGameState);
	NetworkMgr.AddReceiveRemoteCommandDelegate(OnRemoteCommand);
}

function RevertInviteAcceptedDelegates()
{	
	local OnlineGameInterfaceXCom GameInterface;
	`log("I now have the old Delegates",,'Team Dragonpunk Co Op');	
	GameInterface = OnlineGameInterfaceXCom(class'GameEngine'.static.GetOnlineSubsystem().GameInterface);
	GameInterface.ClearGameInviteAcceptedDelegate(0,OnGameInviteAccepted);
	GameInterface.AddGameInviteAcceptedDelegate(0,`ONLINEEVENTMGR.OnGameInviteAccepted);
	GameInterface.ClearJoinLobbyCompleteDelegate(OnJoinLobbyComplete);
	GameInterface.ClearLobbyInviteDelegate(OnLobbyInvite);
	GameInterface.ClearLobbyJoinGameDelegate(OnLobbyJoinGame);
	GameInterface.ClearCreateLobbyCompleteDelegate(OnCreateLobbyComplete);
	GameInterface.ClearLobbyMemberStatusUpdateDelegate(OnLobbyMemberStatusUpdate);
	GameInterface.ClearJoinOnlineGameCompleteDelegate(OnInviteJoinOnlineGameComplete);

	`XCOMNETMANAGER.ClearReceiveHistoryDelegate(ReceiveHistory);
	`XCOMNETMANAGER.ClearReceiveGameStateDelegate(ReceiveGameState);
	`XCOMNETMANAGER.ClearReceiveMergeGameStateDelegate(ReceiveMergeGameState);
	`XCOMNETMANAGER.ClearReceiveRemoteCommandDelegate(OnRemoteCommand);
}

/*
* Creates the game for the players to connect to.
*/
function CreateOnlineGame()
{
	local OnlineSubsystem OnlineSub;
	
	InitShellManager();
	OnlineSub=class'GameEngine'.static.GetOnlineSubsystem();
	m_kMPShellManager.OnlineGame_SetAutomatch(false);
	OSSCreateGameSettings(false);
	OnCreateOnlineGameComplete(m_nMatchingSessionName,true);
	OnlineSub.GameInterface.AddCreateOnlineGameCompleteDelegate(OnCreateOnlineGameComplete);
// Now kick off the async publish
	if ( !OnlineSub.GameInterface.CreateOnlineGame(LocalPlayer(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().Player).ControllerId,'Game',ServerGameSettings) )
	{
		OnlineSub.GameInterface.ClearCreateOnlineGameCompleteDelegate(OnCreateOnlineGameComplete);
	}
	PopupServerNotification();
}	

/*
* Opens the Steam UI so the server can invite players
*/
function OnCreateLobbyComplete(bool bWasSuccessful, UniqueNetId LobbyId, string Error)
{
	XComPlayerController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController()).pres.UICloseProgressDialog();
	if(!UseRumble)
	{
		OpenSteamUI();
	}
	EndDialogBox();
	PopupClientNotification("Waiting For History Transfer","Please wait for this messege to close");
}

/*
* Prevents crashing due to a lack of talkers, registers talkers. (taken from cheat manager)
*/
function RegisterLocalTalker()
{
	local OnlineSubsystem	OnlineSubsystem;

	OnlineSubsystem = class'GameEngine'.static.GetOnlineSubsystem();
	if( OnlineSubsystem != none )
	{
		OnlineSubsystem.VoiceInterface.RegisterLocalTalker( LocalPlayer(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().Player).ControllerId );
		OnlineSubsystem.VoiceInterface.StartSpeechRecognition( LocalPlayer(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().Player).ControllerId );

		OnlineSubsystem.VoiceInterface.AddRecognitionCompleteDelegate( LocalPlayer(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().Player).ControllerId, OnRecognitionComplete );
	}
}

function OnRecognitionComplete()
{
	local OnlineSubsystem	OnlineSubsystem;
	local array<SpeechRecognizedWord> Words;
	local int i;

	OnlineSubsystem = class'GameEngine'.static.GetOnlineSubsystem();
	if( OnlineSubsystem != none )
	{
		OnlineSubsystem.VoiceInterface.GetRecognitionResults( LocalPlayer(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().Player).ControllerId, Words );
		for (i = 0; i < Words.length; i++)
		{
			`Log("Speech recognition got word:" @ Words[i].WordText);
		}
	}
}

/*
* Makes the correct popup for the situation
*/
function PopupServerNotification(optional string Title="Creating Co-Op Server",optional string Text="Please Wait. This message will disappear automatically." )
{
	DialogData.eType = eDialog_Normal;
	DialogData.strTitle = Title;
	DialogData.strText = Text;
	DialogData.strAccept=" "; // If you want this to be empty dont make this a null string, it will go to default
	DialogData.strCancel=" ";
	`HQPRES.UIRaiseDialog(DialogData);
}

/*
* Makes the correct popup for the situation
*/
function PopupClientNotification(optional string Title="Waiting For Server To Generate Map",optional string Text="Please wait. This message will disappear automatically." )
{
	DialogData.eType = eDialog_Normal;
	DialogData.strTitle = Title;
	DialogData.strText = Text;
	DialogData.strAccept=" "; // If you want this to be empty dont make this a null string, it will go to default
	DialogData.strCancel=" ";
	`HQPRES.UIRaiseDialog(DialogData);
}

function PopupCustomNotification(optional string Title=" ",optional string Text=" ",optional string AcceptS=" ",optional string CancelS=" " )
{
	DialogData.eType = eDialog_Warning;
	DialogData.strTitle = Title;
	DialogData.strText = Text;
	DialogData.fnPreCloseCallback=HandleMissingModsCallback;
	DialogData.fnCallback=none;
	DialogData.fnCallbackEx=none;
	DialogData.strAccept=AcceptS;
	DialogData.strCancel=CancelS;
	`HQPRES.UIRaiseDialog(DialogData);
}

function EndDialogBox()
{
	`log("Ending Dialog box");
	if(UIDialogueBox(`SCREENSTACK.GetCurrentScreen().Movie.Stack.GetFirstInstanceOf(class'UIDialogueBox')).ShowingDialog())
		UIDialogueBox(`SCREENSTACK.GetCurrentScreen().Movie.Stack.GetFirstInstanceOf(class'UIDialogueBox')).RemoveDialog();
}

function OpenSteamUI()
{
	local OnlineSubsystem onlineSub;
	local int LocalUserNum;

	onlineSub = `ONLINEEVENTMGR.OnlineSub;
	if(onlineSub==none)
		return;

	LocalUserNum = `ONLINEEVENTMGR.LocalUserIndex;
	onlineSub.PlayerInterfaceEx.ShowInviteUI(LocalUserNum);	
	EndDialogBox();
}


/*
* Connects to the network game via the session name we have.
*/
function OnCreateOnlineGameComplete(name SessionName,bool bWasSuccessful)
{
	class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearCreateOnlineGameCompleteDelegate(OnCreateOnlineGameComplete);

	if(bWasSuccessful)
	{
		m_nMatchingSessionName = SessionName;
		StartNetworkGame(m_nMatchingSessionName);

		`log("Successfully created online game: Session=" $ SessionName $ ", Server=" @ "TODO: implement, i used to come from the GameReplicationInfo: WorldInfo.GRI.ServerName", true, 'Team Dragonpunk Co Op');

}
	else
	{
		`log("Failed to create online game: Session=" $ SessionName, true, 'Team Dragonpunk Co Op');
	}	
}

function OnCreateCoOpGameTimerComplete()
{
	`log("Starting Network Game Ended", true, 'Team Dragonpunk Co Op');
}

function OnJoinLobbyComplete(bool bWasSuccessful, const out array<OnlineGameInterfaceXCom_ActiveLobbyInfo> LobbyList, int LobbyIndex, UniqueNetId LobbyUID, string Error)
{
	local string LobbyUIDString;
	LobbyUIDString = class'GameEngine'.static.GetOnlineSubsystem().UniqueNetIdToHexString( LobbyUID );
	`log(`location @ `ShowVar(bWasSuccessful) @ `ShowVar(LobbyIndex) @ `ShowVar(LobbyUIDString) @ `ShowVar(Error),,'XCom_Online');

}
function OnLobbyJoinGame(const out array<OnlineGameInterfaceXCom_ActiveLobbyInfo> LobbyList, int LobbyIndex, UniqueNetId ServerId, string ServerIP)
{
	local string ServerIdString;
	ServerIdString = class'GameEngine'.static.GetOnlineSubsystem().UniqueNetIdToHexString( ServerId );
	`log(`location @ `ShowVar(LobbyIndex) @ `ShowVar(ServerIdString) @ `ShowVar(ServerIP),,'XCom_Online');
}

/*
* Changes the Launch button click delegate to one that allows us to load the co-op rather than load normal games
*/
function OnLobbyMemberStatusUpdate(const out array<OnlineGameInterfaceXCom_ActiveLobbyInfo> LobbyList, int LobbyIndex, int MemberIndex, int InstigatorIndex, string Status)
{
	local object myself;
	myself = self;
	`log(`location @ `ShowVar(LobbyIndex) @ `ShowVar(MemberIndex) @ `ShowVar(InstigatorIndex) @ `ShowVar(Status),,'XCom_Online');
	if(InStr(Status,"Joined")>-1)
	{
		`log(`location @ `ShowVar(LobbyIndex) @"LobbyList[LobbyIndex].Members"@LobbyList[LobbyIndex].Members.Length,,'Team Dragonpunk Co Op');
		RegisterLocalTalker();
	}
	else if(InStr(Status, "Exit") > -1)
	{
		DisconnectGame();
	}

	UIMission(`SCREENSTACK.GetFirstInstanceOf(class'UIMission')).ConfirmButton.OnClickedDelegate=OpenUIAssignSoldiers;
	`XEVENTMGR.RegisterForEvent( myself, 'MissionSite_OverrideLaunchTacticalBattle', OverrideLaunchTacticalBattle);
	`log(`location @"Registering Events",,'Dragonpunk Coop LW2 ');
	
}

function OpenUIAssignSoldiers(UIButton button)
{
	local UIScreen kScreen;

	kScreen = Spawn(class'UIAssignSoldiers_DragonpunkLW2Coop', self);	`SCREENSTACK.Push(kScreen);

}



function EventListenerReturn OverrideLaunchTacticalBattle(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	`log("LW Tuple is now true! Going to Coop!",,'Dragonpunk Coop LW2 ');
	XComLWTuple(EventData).Data[0].b=true;
	RealLoadTactical();
	return ELR_NoInterrupt;
}
 

function DisconnectGame()
{
	class'X2Ability_DefaultAbilitySet_CoOpHackFix'.static.UnFixHackingAbilities();
	class'X2Ability_DefaultAbilitySet_CoOpHackFix'.static.UnFixAllMPAbilities();
	//`XCOMNETMANAGER.Disconnect();
	//if(!`XCOMNETMANAGER.HasClientConnection())
	//	class'GameEngine'.static.GetOnlineSubsystem().GameInterface.DestroyOnlineGame('Game');
	`ONLINEEVENTMGR.ReturnToStartScreen(QuitReason_UserQuit);

}

function OnLobbyInvite(UniqueNetId LobbyId, UniqueNetId FriendId, bool bAccepted)
{
	`log("bAccepted:"@bAccepted ,true,'Team Dragonpunk Co Op');
}


/*
* Initializes the game settings,pretty much useless for the most part mainly important for the Hashes that track DLCs and Mods
*/
function OSSCreateGameSettings(bool bAutomatch)
{
	local XComOnlineGameSettings kGameSettings;
	local XComOnlineGameSettingsDeathmatchUnranked kUnrankedDeathmatchSettings;

	InitShellManager();
	kUnrankedDeathmatchSettings = new class'XComOnlineGameSettingsDeathmatchUnranked';
	kGameSettings = kUnrankedDeathmatchSettings;
	kGameSettings.SetIsRanked(false);
	kGameSettings.SetNetworkType(eMPNetworkType_Public);
	kGameSettings.SetGameType(eMPGameType_Deathmatch);
	kGameSettings.SetTurnTimeSeconds(1234567); 
	kGameSettings.SetMaxSquadCost(1234567); 
	kGameSettings.SetMapPlotTypeInt(m_kMPShellManager.OnlineGame_GetMapPlotInt());
	kGameSettings.SetMapBiomeTypeInt(m_kMPShellManager.OnlineGame_GetMapBiomeInt());
	kGameSettings.NumPublicConnections = 2;
	kGameSettings.NumPrivateConnections = 0;
	kGameSettings.SetMPDataINIVersion(0);
	kGameSettings.SetByteCodeHash(class'Helpers'.static.NetGetVerifyPackageHashes());
	kGameSettings.SetIsAutomatch(false);
	kGameSettings.SetInstalledDLCHash(class'Helpers'.static.NetGetInstalledMPFriendlyDLCHash());
	kGameSettings.SetInstalledModsHash(class'Helpers'.static.NetGetInstalledModsHash());
	kGameSettings.SetINIHash(class'Helpers'.static.NetGetMPINIHash());
	kGameSettings.SetIsDevConsoleEnabled(class'Helpers'.static.IsDevConsoleEnabled());
	kGameSettings.bAllowInvites=true;
	ServerGameSettings=kGameSettings;
	
}


function bool CreateOnlineGameSearch(optional int SquadCostIdentifier=1234567,optional int TurnTimeIdentifier=1234567)
{
	local OnlineSubsystem kOSS;
	local bool bSuccess;
	local XComOnlineGameSearch kGameSearch;
	local int iSquadCostMin, iSquadCostMax;
	local int iTurnTimeMin, iTurnTimeMax;
	local int iMapPlotMin, iMapPlotMax;
	local int iMapBiomeMin, iMapBiomeMax;

	PopupClientNotification("Creating New Game search","Please Remain Calm...");
	kGameSearch = new class'XComOnlineGameSearchDeathmatchCoop';

	kGameSearch.SetNetworkType(eMPNetworkType_Public);
	kGameSearch.SetGameType(eMPGameType_Deathmatch);
	kGameSearch.SetIsRanked(false);

	iSquadCostMax=MaxInt;
	iSquadCostMin=MinInt;
	kGameSearch.SetSquadCostMin(SquadCostIdentifier);
	kGameSearch.SetSquadCostMax(SquadCostIdentifier);

	iTurnTimeMax=MaxInt;
	iTurnTimeMin=MinInt;
	kGameSearch.SetTurnTimeMin(TurnTimeIdentifier);
	kGameSearch.SetTurnTimeMax(TurnTimeIdentifier);

	//
	// MAP PLOT TYPE
	iMapPlotMin = MinInt;
	iMapPlotMax = MaxInt;
	kGameSearch.SetMapPlotTypeMinMax(iMapPlotMin, iMapPlotMax);

	iMapBiomeMin = MinInt;
	iMapBiomeMax = MaxInt;
	kGameSearch.SetMapBiomeTypeMinMax(iMapBiomeMin, iMapBiomeMax);

	class'GameEngine'.static.GetOnlineSubsystem().GameInterface.FreeSearchResults(kGameSearch);
	kGameSearch.SetMPDataINIVersion(0);
	kGameSearch.SetByteCodeHash(class'Helpers'.static.NetGetVerifyPackageHashes());
	kGameSearch.SetInstalledModsHash(class'Helpers'.static.NetGetInstalledModsHash());
	kGameSearch.SetInstalledDLCHash(class'Helpers'.static.NetGetInstalledMPFriendlyDLCHash());
	kGameSearch.SetINIHash(class'Helpers'.static.NetGetMPINIHash());
	kGameSearch.SetNetworkType(eMPNetworkType_Public);
	kGameSearch.SetIsDevConsoleEnabled(class'Helpers'.static.IsDevConsoleEnabled());

	SavedRumbleSearch=kGameSearch;

	kOSS = class'GameEngine'.static.GetOnlineSubsystem();
    kOSS.GameInterface.AddFindOnlineGamesCompleteDelegate(OnFindOnlineGamesComplete);

    if( kOSS.GameInterface.FindOnlineGames( LocalPlayer( class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().Player).ControllerId, SavedRumbleSearch ) )
    {
		bSuccess = true;
        `log(`location @ "Searching for online games...", true, 'Dragonpunk Rumble App');
    }
    else
    {
		`log(`location @ "Failed to begin search", true, 'Dragonpunk Rumble App');
		kOSS.GameInterface.ClearFindOnlineGamesCompleteDelegate(OnFindOnlineGamesComplete);
		bSuccess = false;
    }

	return bSuccess;

}



function OnFindOnlineGamesComplete( bool bWasSuccessful )
{
	local OnlineGameSearchResult TempRes;
	local int i;
	// Clean up delegate reference
	class'GameEngine'.static.GetOnlineSubsystem().GameInterface.ClearFindOnlineGamesCompleteDelegate(OnFindOnlineGamesComplete);
	`log("Result Length:" @string(SavedRumbleSearch.Results.length),,'Dragonpunk Rumble App');

	for(i=0;i< SavedRumbleSearch.Results.length;i++)
	{
		`log(`location @i @XComOnlineGameSettings(SavedRumbleSearch.Results[i].GameSettings).ToString(),,'Dragonpunk Rumble App');
	}
	if(bWasSuccessful &&SavedRumbleSearch.Results.length>0)
		OSSJoin(GetCoOpGame(),OnInviteJoinOnlineGameComplete);
}

function OnlineGameSearchResult GetCoOpGame(optional int SquadCostIdentifier=1234567,optional int TurnTimeIdentifier=1234567)
{
	local int i;
	for(i=0;i< SavedRumbleSearch.Results.length;i++)
	{
		//`log(`location @i @XComOnlineGameSettings(SavedRumbleSearch.Results[i].GameSettings).ToString(),,'Dragonpunk Rumble App');

		if(	XComOnlineGameSettings(SavedRumbleSearch.Results[i].GameSettings).GetTurnTimeSeconds()==TurnTimeIdentifier &&
			XComOnlineGameSettings(SavedRumbleSearch.Results[i].GameSettings).GetMaxSquadCost()==SquadCostIdentifier &&
			XComOnlineGameSettings(SavedRumbleSearch.Results[i].GameSettings).GetInstalledDLCHash()==class'Helpers'.static.NetGetInstalledMPFriendlyDLCHash() &&
			XComOnlineGameSettings(SavedRumbleSearch.Results[i].GameSettings).GetInstalledModsHash()==class'Helpers'.static.NetGetInstalledModsHash() )
			return SavedRumbleSearch.Results[i];
	}
	return SavedRumbleSearch.Results[i];
}

function OSSJoin(OnlineGameSearchResult kSearchResult, 
	delegate<OnlineGameInterface.OnJoinOnlineGameComplete> dOnJoinOnlineGameCompleteDelegate)
{
	local XGParamTag kTag;
	local TProgressDialogData kProgressDialogData;
	local OnlineGameInterface GameInterface;
	local string DescS;
	GameInterface = class'GameEngine'.static.GetOnlineSubsystem().GameInterface;
	if(GameInterface.GetGameSettings('Game') == none)
	{
		GameInterface.AddJoinOnlineGameCompleteDelegate(dOnJoinOnlineGameCompleteDelegate);
		if(GameInterface.JoinOnlineGame(LocalPlayer( class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().Player).ControllerId, 'Game', kSearchResult))
		{
			`log(`location @ "Attempting to join " @ kSearchResult.GameSettings.OwningPlayerName, true, 'Dragonpunk Rumble App');
			EndDialogBox();
			DescS="DONT PANIC! Connecting to:"@kSearchResult.GameSettings.OwningPlayerName;
			PopupClientNotification("Connecting to server",DescS);

			/*kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));

			`log(`location @ "- Connection successful, opening progress dialog." , true, 'XCom_Online');
			kProgressDialogData.strTitle = class'X2MPData_Shell'.default.m_strMPJoiningGameProgressDialogTitle;
			kTag.StrValue0 = kSearchResult.GameSettings.OwningPlayerName;
			kProgressDialogData.strDescription = `XEXPAND.ExpandString(class'X2MPData_Shell'.default.m_strMPJoiningGameProgressDialogText);
			UIProgressDialog(kProgressDialogData);

			// HAX: Make sure if we don't complete the connection that we close the Progress dialog and cleanup any dangling delegates.
			SetTimer(UNCANCELLABLE_PROGRESS_DIALOGUE_TIMEOUT, false, nameof(CleanupOnFindAutomatchCompleteFailed));*/
		}
		else
		{
			`log(`location @ "FAILED to start async JoinOnlineGame task: Tried to join" @ kSearchResult.GameSettings.OwningPlayerName $ "'s game", true, 'Dragonpunk Rumble App');
			EndDialogBox();
			PopupClientNotification("Failed at Connecting to server","Fine... you can panic...");
			GameInterface.ClearJoinOnlineGameCompleteDelegate(dOnJoinOnlineGameCompleteDelegate);
		}
	}
	else
	{
		`log(`location $ ": Session 'Game' already exists, tearing down and then joining...", true, 'Dragonpunk Rumble App');
		// need to clear our own game if we are going to join another game -tsmith 
		if(!GameInterface.DestroyOnlineGame('Game'))
		{
			`log(`location $ ": Failed to start async task DestroyOnlineGame", true, 'Dragonpunk Rumble App');
		}
	}
	EndDialogBox();
}

/*
* Main Function in this class. starts the game correctly for the server and connects to a specific game for a client
*/
function bool StartNetworkGame(name SessionName, optional string ResolvedURL="")
{
	local URL OnlineURL;
	local string sError, ServerURL, ServerPort;
	local int FindIndex;
	local OnlineGameSettings kGameSettings;
	local XComGameStateNetworkManager NetManager;
	local bool bSuccess;
	local float TimeForTimer;
	local UIPanel_TickActor TickA;
	TimeForTimer=1.0;
	bSuccess = true;
	kGameSettings = class'GameEngine'.static.GetOnlineSubsystem().GameInterface.GetGameSettings(SessionName);

	OnlineURL.Map = "XComShell_Multiplayer.umap";
	OnlineURL.Op.AddItem("Game=LW2DragonpunkCoop.XComCoOpTacticalGame");

	m_nMatchingSessionName = SessionName;
	m_strMatchOptions = BuildURL(OnlineURL);

	if (!kGameSettings.bIsLanMatch)
	{
		OnlineURL.Op.AddItem("steamsockets");
	}
	NetManager = `XCOMNETMANAGER;
	ChangeInviteAcceptedDelegates();
	if (ResolvedURL == "" && !`XCOMNETMANAGER.HasServerConnection())
	{
		`log(`location @ "Creating Network Server to host the Online Game.",,'Team Dragonpunk Co Op');
		NetManager.CreateServer(OnlineURL, sError); // Creates the server that will send the data over the wire
		`log("Starting Network Game Ended Created Server", true, 'Team Dragonpunk Co Op');
	}
	else if(ResolvedURL != "") // A lot of this here is just copied from other MP classes.
	{
		FindIndex = InStr(ResolvedURL, ":");
		if (FindIndex != -1)
		{
			ServerURL = Left(ResolvedURL, FindIndex);
			ServerPort = Right(ResolvedURL, Len(ResolvedURL) - (FindIndex+1));
		}
		else
		{
			ServerURL = ResolvedURL;
			ServerPort = "0";
		}
		FindIndex = InStr(ServerURL, "?");
		if(FindIndex != -1)
		{
			ServerURL = Left(ServerURL, FindIndex); // Remove everything after the first '?', which are additional URL parameters.
		}
		OnlineURL.Host = ServerURL;
		OnlineURL.Port = int(ServerPort);

		`log(`location @ "Creating Network Client to join the Online Game at '"$ServerURL$"' on port '"$ServerPort$"'.",,'Team Dragonpunk Co Op');
		NetManager.AddPlayerJoinedDelegate(OnPlayerJoined); // Wait until connected fully to the server before loading the map.
		NetManager.CreateClient(OnlineURL, sError); 
		if (sError != "")
		{
			NetManager.ClearPlayerJoinedDelegate(OnPlayerJoined);
			`warn(`location @ "Unable to Create the Online Game!" @ `ShowVar(SessionName) @ `ShowVar(ResolvedURL) @ `ShowVar(sError),,'Team Dragonpunk Co Op');
			`log(`location @ "Unable to Create the Online Game!" @ `ShowVar(SessionName) @ `ShowVar(ResolvedURL) @ `ShowVar(sError),,'Team Dragonpunk Co Op');
			bSuccess = false;
		}
		else
		{
			`log(`location @"Trying to connect to server BEFORE TIMER TimeForTimer:" @TimeForTimer,,'Team Dragonpunk Co Op');
			TickA=Spawn(class'UIPanel_TickActor',`SCREENSTACK.GetCurrentScreen());
			TickA.SetupTick(0.25);
		}
	}

	return bSuccess;
}


function ForceConnectFunction()
{
	`log(`location @"Trying to connect to server",,'Team Dragonpunk Co Op');
	ForceSuccess=`XCOMNETMANAGER.ForceConnectionAttempt();
	`log(`location @"ForceSuccess"@ForceSuccess,,'Team Dragonpunk Co Op');
}

function string BuildURL(const out URL InURL)
{
	local string strURL, strOp;
	strURL = InURL.Map;
	foreach InUrl.Op(strOp)
	{
		strURL $= "?" $ strOp;
	}
	return strURL;
}

function OnPlayerJoined(string RequestURL, string Address, const UniqueNetId UniqueId, bool bSupportsAuth)
{
	local XComGameStateNetworkManager NetManager;
	NetManager = `XCOMNETMANAGER;
	NetManager.ClearPlayerJoinedDelegate(OnPlayerJoined);
	`log("OnPlayerJoined",,'Team Dragonpunk Co Op');
	if( `XCOMNETMANAGER.HasClientConnection() )
	{
		if(!FoundMismatchMods)
		{
			`log(`location @ "Sending 'Request History' command",,'Team Dragonpunk Co Op');
			SendRemoteCommand("RequestHistory");
			PopupClientNotification("Waiting For Mission Start","Please wait for this messege to close, Please wait for the other player to start the mission");
		}
		else
		{
			`log(`location @ "Found Mismatched Mods",,'Team Dragonpunk Co Op');
			SendRemoteCommand_SwapMods();
			
		}
	}
	else if ( `XCOMNETMANAGER.HasServerConnection() )
	{
		bCanStartMatch = true;
		`log(`location @ "Sending 'Host Joined' command",,'Team Dragonpunk Co Op');
		bHistoryLoaded = true;
		SetGameSettingsAsReady();
		SendRemoteCommand("HostJoined");
	}
}

/*
* Overrides the OnlineEventManager's OnGameInviteAccepted delegate and let's us to filter out stuff and connect to the server correctly
* Mostly copied from the OEM class and the function ite overrides.
*/
function OnGameInviteAccepted(const out OnlineGameSearchResult InviteResult, bool bWasSuccessful)
{
	local bool bIsMoviePlaying;
	local UISquadSelect SquadSelectScreen;

	`log("Dragonpunk test test test NOT IN XComOnlineEventMgr",true,'Team Dragonpunk Co Op');

	//Checks if we're actually in a Co-op game
	/*if(false && XComOnlineGameSettings(InviteResult.GameSettings).GetTurnTimeSeconds()<=1000 || XComOnlineGameSettings(InviteResult.GameSettings).GetMaxSquadCost()<=100000 )
	{
		`log("Entering OnlineEventMgr, TurnTime:"@XComOnlineGameSettings(InviteResult.GameSettings).GetTurnTimeSeconds() @",Max Cost:"@XComOnlineGameSettings(InviteResult.GameSettings).GetMaxSquadCost(),,'Team Dragonpunk Co Op');
		`ONLINEEVENTMGR.OnGameInviteAccepted(InviteResult,bWasSuccessful);
	}
	else
	{*/

		if (!bWasSuccessful)
		{
			if (class'GameEngine'.static.GetOnlineSubsystem().PlayerInterface.GetLoginStatus(`ONLINEEVENTMGR.LocalUserIndex) != LS_LoggedIn)
			{
				if (class'WorldInfo'.static.IsConsoleBuild(CONSOLE_PS3))
				{
					class'GameEngine'.static.GetOnlineSubsystem().PlayerInterface.AddLoginUICompleteDelegate(`ONLINEEVENTMGR.OnLoginUIComplete);
					class'GameEngine'.static.GetOnlineSubsystem().PlayerInterface.ShowLoginUI(true); // Show Online Only
				}
				else
				{
					`ONLINEEVENTMGR.InviteFailed(SystemMessage_LostConnection,false);
					`log("InviteFailed(SystemMessage_LostConnection)",true,'Team Dragonpunk Co Op');

				}
			}
			else
			{
				`ONLINEEVENTMGR.InviteFailed(SystemMessage_BootInviteFailed,false);
				`log("InviteFailed(SystemMessage_BootInviteFailed)",true,'Team Dragonpunk Co Op');
			}
			return;
		}

		if (InviteResult.GameSettings == none)
		{
			`ONLINEEVENTMGR.InviteFailed(SystemMessage_InviteSystemError, !`ONLINEEVENTMGR.IsCurrentlyTriggeringBootInvite()); // Travel to the MP Menu only if the invite was made while in-game.
			return;
		}

		if (CheckInviteGameVersionMismatch(XComOnlineGameSettings(InviteResult.GameSettings))) // Checks mismatch of mods and DLCs on either side
		{
			//`ONLINEEVENTMGR.InviteFailed(SystemMessage_VersionMismatch, false);
			`log("InviteFailed(SystemMessage_VersionMismatch)",true,'Team Dragonpunk Co Op');
		}


		`ONLINEEVENTMGR.bAcceptedInviteDuringGameplay = true;
		class'XComOnlineEventMgr_Co_Op_Override'.static.AddItemToAcceptedInvites(InviteResult);

		if (bWasSuccessful && !`ONLINEEVENTMGR.bHasProfileSettings)
		{
			`log(`location @ " -----> Shutting down the playing movie and returning to the MP Main Menu, then accepting the invite again.",,'Team Dragonpunk Co Op');
			return;
		}

		bIsMoviePlaying = `XENGINE.IsAnyMoviePlaying();
		if (bIsMoviePlaying || `ONLINEEVENTMGR.IsPlayerReadyForInviteTrigger() )
		{
			if (bIsMoviePlaying)
			{
				`XENGINE.StopCurrentMovie();
			}
		/*	if(!`SCREENSTACK.IsCurrentScreen('UISquadSelect')) // Kicks the players into the main menu if the client isnt on the squad select screen.
			{
				`ONLINEEVENTMGR.InviteFailed(SystemMessage_VersionMismatch, false);
				//SquadSelectScreen=(`SCREENSTACK.Screens[0].Spawn(Class'UISquadSelect',none));
				//`SCREENSTACK.Push(SquadSelectScreen);
				//`log("Pushing SquadSelectUI to screen stack",true,'Team Dragonpunk Co Op');
			}
			else
			{
				`log("Already in Squad Select UI",true,'Team Dragonpunk Co Op');
			}*/
			// Fire up the delegates for the client to connect the game properly.
			OnlineGameInterfaceXCom(class'GameEngine'.static.GetOnlineSubsystem().GameInterface).AcceptGameInvite( LocalPlayer( class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().Player).ControllerId,'Game');
			OnlineGameInterfaceXCom(class'GameEngine'.static.GetOnlineSubsystem().GameInterface).JoinOnlineGame( LocalPlayer(  class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController().Player).ControllerId, 'Game',InviteResult );
		}
		else
		{
			`log(`location @ "Waiting for whatever to finish and transition to the UISquadSelect screen.",true,'Team Dragonpunk Co Op');
		}
	//}
}

/*
* Mostly copied from other classes used in MP from here to the "Send Remote Command" function
*/
function OnInviteJoinOnlineGameComplete(name SessionName, bool bWasSuccessful)
{
	local OnlineSubsystem OnlineSub;

	if(`XCOMNETMANAGER.HasServerConnection()) return;

	`log(`location @"OnInviteJoinOnlineGameComplete",,'Team Dragonpunk Co Op');
	OnlineSub=class'GameEngine'.static.GetOnlineSubsystem();
	OnlineSub.GameInterface.ClearJoinOnlineGameCompleteDelegate(OnInviteJoinOnlineGameComplete);
	OnInviteJoinComplete(SessionName, bWasSuccessful);

}

function string ModifyClientURL(string URL)
{
	return URL;
}

function SetLobbyServer(UniqueNetId LobbyIdHexString, UniqueNetId ServerIdHexString, optional string ServerIP)
{
	local OnlineGameInterfaceXCom GameInterface;
	`log("DRAGON PUNK DRAGON PUNK SET LOBBY SERVER",,'Team Dragonpunk Co Op');

	GameInterface = OnlineGameInterfaceXCom(class'GameEngine'.static.GetOnlineSubsystem().GameInterface);
	GameInterface.SetLobbyServer(LobbyIdHexString, ServerIdHexString, "0.0.0.0");
	
}

function OnInviteJoinComplete(name SessionName,bool bWasSuccessful)
{
	local string URL;
	local ESystemMessageType eSystemError;
	local OnlineSubsystem OnlineSub;
	
	OnlineSub=class'GameEngine'.static.GetOnlineSubsystem();
	`log(`location @ `ShowVar(SessionName) @ `ShowVar(bWasSuccessful), true, 'Team Dragonpunk Co Op');
	
	if (bWasSuccessful)
	{
		`ONLINEEVENTMGR.OnGameInviteComplete(SystemMessage_None, bWasSuccessful);

		`ONLINEEVENTMGR.SetOnlineStatus(OnlineStatus_MainMenu);

		if (OnlineSub != None && OnlineSub.GameInterface != None)
		{
			if (OnlineSub.GameInterface.GetResolvedConnectString(SessionName,URL))
			{
				URL $= "?bIsFromInvite";
				URL = ModifyClientURL(URL); // allow game to override

				`Log("Resulting url is ("$URL$")",true,'Team Dragonpunk Co Op');
				// Open a network connection to it
				StartNetworkGame(SessionName, URL);
				SendRemoteCommand("ChangeLaunchButton");
			}
		}
	}
	else
	{
		eSystemError = SystemMessage_InviteSystemError;
		if (SessionName == 'RoomFull' || SessionName == 'LobbyFull' || SessionName == 'GroupFull')
		{
			eSystemError = SystemMessage_GameFull;
		}

		`ONLINEEVENTMGR.OnGameInviteComplete(eSystemError, bWasSuccessful);

		// Clean-up session
		if (OnlineSub != None && OnlineSub.GameInterface != None)
		{
			OnlineSub.GameInterface.DestroyOnlineGame(SessionName);
		}
	}
}

function bool CheckInviteGameVersionMismatch(XComOnlineGameSettings InviteGameSettings)
{
	local string ByteCodeHash;
	local int InstalledDLCHash;
	local int InstalledModsHash;
	local string INIHash;
	local string TempToLog;
	local array<string> TempLog;
	
	ByteCodeHash = class'Helpers'.static.NetGetVerifyPackageHashes();
	InstalledDLCHash = class'Helpers'.static.NetGetInstalledMPFriendlyDLCHash();
	InstalledModsHash = class'Helpers'.static.NetGetInstalledModsHash();
	INIHash = class'Helpers'.static.NetGetMPINIHash();

	TempLog=class'Helpers'.static.GetInstalledModNames();
	foreach TempLog(TempToLog)
	{
		`log("Installed Mods:"@TempToLog,true,'Team Dragonpunk Co Op');
	}
	`log("Installed Mods Hash:"@InstalledModsHash @InstalledModsHash== InviteGameSettings.GetInstalledModsHash(),true,'Team Dragonpunk Co Op');

	TempLog=class'Helpers'.static.GetInstalledDLCNames();
	foreach TempLog(TempToLog)
	{
		`log("Installed DLCs:"@TempToLog,true,'Team Dragonpunk Co Op');
	}
	`log("Installed DLCs Hash:"@InstalledDLCHash @InstalledDLCHash== InviteGameSettings.GetInstalledDLCHash(),true,'Team Dragonpunk Co Op');
	`log("INI HASH:"@INIHash @INIHash== InviteGameSettings.GetINIHash() ,true,'Team Dragonpunk Co Op');
	`log("ByteCode HASH:"@ByteCodeHash @ByteCodeHash==InviteGameSettings.GetByteCodeHash(),true,'Team Dragonpunk Co Op');


	`log(`location @ "InviteGameSettings=" $ InviteGameSettings.ToString(),, 'Team Dragonpunk Co Op');
	`log(`location @ `ShowVar(ByteCodeHash) @ `ShowVar(InstalledDLCHash) @ `ShowVar(InstalledModsHash) @ `ShowVar(INIHash),, 'Team Dragonpunk Co Op');
	//Remember to re-enable the checks on the beta and the release. THIS IS NOT HOW IT SHOULD BE OUTSIDE OF ALPHA
	// DONE! We now have the stuff enabled for release! (25/11/16)
	//return false; //ByteCodeHash != InviteGameSettings.GetByteCodeHash() ||
	if(InstalledModsHash != InviteGameSettings.GetInstalledModsHash() || InstalledModsHash != InviteGameSettings.GetInstalledModsHash())
		FoundMismatchMods=True;

	return	InstalledDLCHash != InviteGameSettings.GetInstalledDLCHash() ||
			InstalledModsHash != InviteGameSettings.GetInstalledModsHash();
}

function SendRemoteCommand(string Command) //Copied from UIMPShell_Lobby
{
	local array<byte> Parms;
	Parms.Length = 0; // Removes script warning.
	`XCOMNETMANAGER.SendRemoteCommand(Command, Parms);
	if(Command~="LoadGame")
	{
		LoadingGame=true;
		SendHistory();
	}
	`log(`location @ "Sent Remote Command '"$Command$"'",,'Team Dragonpunk Co Op');
}

function SendRemoteCommand_SwapMods() //Copied from UIMPShell_Lobby
{
	local array<byte> Params;
	local XComGameStateNetworkManager NetManager;
	local String FinalOut,temp;
	local array<string> TempLog;
	NetManager=`XCOMNETMANAGER;
	TempLog=class'Helpers'.static.GetInstalledDLCNames();
	foreach TempLog(temp)
	{
		FinalOut=FinalOut $";"$temp;
	}
	TempLog=class'Helpers'.static.GetInstalledModNames();
	foreach TempLog(temp)
	{
		FinalOut=FinalOut $";"$temp;
	}
	NetManager.AddCommandParam_String(FinalOut,Params); // makes the string into a byte array and sends it with the command
	NetManager.SendRemoteCommand("SwapMods", Params);
	SentMods=true;
	`log(`location @ "Sent Remote Command Swap Mods",,'Team Dragonpunk Co Op');
}

/*
* Used for sending a string with the remote command so the other side will be synced with your saved Squads (all around,server controlled and client controlled)  
*/
function SentRemoteSquadCommand()
{
	local array<byte> Params;
	local StateObjectReference Temp;
	local XComGameStateNetworkManager NetManager;
	local String FinalOut;
	NetManager=`XCOMNETMANAGER;
	Params.Length = 0; 
	foreach TotalSquad(Temp) // Adds the Ids of everone on the squad
	{
		FinalOut$=Temp.ObjectID $"|";
	}
	NetManager.AddCommandParam_String(FinalOut,Params); // makes the string into a byte array and sends it with the command
	NetManager.SendRemoteCommand("UpdateSquad", Params);	
}

/*
* Deciphers the squad lists sent in string form from the other player.
*/
function DecipherSquads(array<byte> Params) 
{
	local string InString,TString;
	local array<string> SplitSTR;
	local int count,TempInt;
	local XComGameStateNetworkManager NetManager;

	NetManager=`XCOMNETMANAGER;
	InString=NetManager.GetCommandParam_String(Params);
	SplitSTR=SplitString(InString,"|",true);
	`log(InString,,'Dragonpunk Co Op Squads');
	foreach SplitSTR(Tstring)
	{
		TempInt=int(Tstring);

		if(TString~="-1" || TempInt==-1) // Makes it easy to know who goes where
		{
			count++;
			continue;
		}
		if(TempInt==0 ||TString~="0" )
			continue;

		switch (Count) // By counting the "-1"s you can know which squad we're adding to.
		{
			case 0:
				TotalSquad.AddItem(XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(TempInt)).GetReference());
				break;
			case 1:
				ServerSquad.AddItem(XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(TempInt)).GetReference());
				break;
			case 2:
				ClientSquad.AddItem(XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(TempInt)).GetReference());
				break;
		}
	}
}

simulated function HandleMissingModsCallback(eUIAction eAction)
{
	if(eAction==eUIAction_Accept || eAction==eUIAction_Closed)
	{
		if(`XCOMNETMANAGER.HasClientConnection())
		{
			`log(`location @ "Sending 'Request History' command",,'Team Dragonpunk Co Op');
			SendRemoteCommand("FixIgnoreSS");
			PopupClientNotification("Waiting For Mission Start","Please wait for this messege to close, Please wait for the other player to start the mission");

		}
		else
		{
			PopupClientNotification("Waiting For History Transfer","Please wait for this messege to close");
		}
	}
	else
		DisconnectGame();
}

function string HandleMissingMods(string InMods)
{
	local string MString,temp,TString,outString;
	local array<string> SplitSTR,AllMods,AllDLCs;
	local XComGameStateNetworkManager NetManager;
	local int i;
	local bool Found;
	AllDLCs=class'Helpers'.static.GetInstalledDLCNames();
	AllMods=class'Helpers'.static.GetInstalledModNames();
	foreach AllDLCs(temp)
	{
		AllMods.AddItem(temp);
	}
	NetManager=`XCOMNETMANAGER;
	SplitSTR=SplitString(InMods,";",true);
	`log(InMods,,'Dragonpunk Co Op');
	outString="The Following Mods/DLCs are only present on the other player's game:";
	foreach SplitSTR(Tstring)
	{
		`log("Current Mod Check" @Tstring,,'Dragonpunk Co Op');
		Found=false;
		for(i=0; i<AllMods.length;i++)
		{
			if(Tstring~=AllMods[i])
			{
				Found=true;
				i=AllMods.length;
				AllMods.RemoveItem(AllMods[i]);
			}
		}
		if(!Found)
		{
			outString=outString @Tstring $",";
		}
	}
	outString=outString @". Warning- this may cause bugs and crashes we recommend disconnecting and fixing the problem!";
	`log("outString" @outString,,'Dragonpunk Co Op');
	return outString;
}

function LoadPlayersFromClient()
{
	local XComGameStateHistory TempH;
	local XComGameState SearchState,NewGameState;
	local XComGameState_Unit UnitState,TempUnitState;
	local SCATProgression ProgressAbility;
	local int i;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Add Client Soldiers");
	SearchState=`ONLINEEVENTMGR.LatestSaveState(TempH);
	foreach SearchState.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if(UnitState.IsASoldier() && UnitState.IsAlive()) //Only soldiers... that are alive
		{
			`log("Unit Name Test:"@UnitState.GetFullName(),,'Dragonpunk Co Op Unit Load Test');
			TempUnitState=UnitState.GetMyTemplate().CreateInstanceFromTemplate(NewGameState);
			TempUnitState.SetTAppearance(UnitState.kAppearance);
			TempUnitState.SetCharacterName( UnitState.GetFirstName() , UnitState.GetLastName() @"(Client Unit)" , UnitState.GetNickName(false) );
			TempUnitState.SetCountry( UnitState.GetCountry() );
			TempUnitState.SetBackground( UnitState.GetBackground() );

			for(i = 0 ; i < UnitState.GetRank() ; i++ )
			{
				TempUnitState.RankUpSoldier( NewGameState , UnitState.GetSoldierClassTemplateName() );
			}
			foreach UnitState.m_SoldierProgressionAbilties(ProgressAbility)
			{
				TempUnitState.BuySoldierProgressionAbility( NewGameState , ProgressAbility.iRank ,  ProgressAbility.iBranch );
			}
			for(i = 0 ; i < eStat_MAX ; i++)
			{
				TempUnitState.SetBaseMaxStat( ECharStatType(i) , UnitState.GetMaxStat( ECharStatType(i) ) );
				TempUnitState.SetCurrentStat( ECharStatType(i) , UnitState.GetCurrentStat( ECharStatType(i) ) );
			}
			TempUnitState.SetXPForRank( UnitState.GetRank() );
			NewGameState.AddStateObject(TempUnitState);
			TempUnitState.ApplyBestGearLoadout(NewGameState);
			`XCOMHQ.AddToCrew( NewGameState , TempUnitState );
			`XCOMHQ.HandlePowerOrStaffingChange(NewGameState);
		}
	}
	`XCOMHISTORY.AddGameStateToHistory(NewGameState);	
	SendRemoteCommand("SyncClientUnits");
}



/*
* Handels a lot of the back and forth logic between the server and client
*/
function OnRemoteCommand(string Command, array<byte> RawParams)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local float listWidth,listX;
	local UISquadSelect UISS;
	local XComGameState_Unit UnitState;
	local StateObjectReference UnitRef;
//	`log(`location @"Dragonpunk Command" @ Command,,'Team Dragonpunk Co Op');

	if (Command ~= "RequestHistory")
	{
		`XCOMNETMANAGER.SendHistory(`XCOMHISTORY, `XEVENTMGR);
		`XCOMHISTORY.RegisterOnNewGameStateDelegate(OnNewGameState_SquadWatcher);
	}
	else if(Command ~= "SyncClientUnits")
	{
		`XCOMHISTORY.UnRegisterOnNewGameStateDelegate(OnNewGameState_SquadWatcher);
		`log(`location @ "Sending 'Request History' command",,'Team Dragonpunk Co Op');
		SendRemoteCommand("RequestHistory");
	}
	else if(Command ~= "FixIgnoreSS")
	{
		SendRemoteCommand("FixIgnoreSS_Fix");
	}
	else if(Command ~= "HistoryReceived")
	{
		if(LoadingGame==false)
		{
			EndDialogBox();
			EndDialogBox();
			EndDialogBox();
			EndDialogBox();
			EndDialogBox();
			EndDialogBox();
			EndDialogBox();
			EndDialogBox();
			EndDialogBox();
			EndDialogBox();
			EndDialogBox();
			EndDialogBox(); // for some reason there are a few that get initialized...

			SendRemoteCommand("HistoryConfirmed");
			UISS=UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect'));
			listWidth =( UISS.GetTotalSlots()+(int(UISS.ShowExtraSlot1())*-2) )* (class'UISquadSelect_ListItem'.default.width + UISS.LIST_ITEM_PADDING);
			listX =(UISS.Movie.UI_RES_X / 2) - (listWidth/2);
			//UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).m_kSlotList.OriginTopCenter();
			//UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).m_kSlotList.SetX(UISS.Movie.UI_RES_X / 2); //fixes the x position of the list on the screen
			//UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).m_kSlotList.RealizeLocation(); //fixes the x position of the list on the screen
			
		}
		else if(!Launched)
		{
			SendRemoteCommand("HistoryConfirmedPopUp");		
			`log(Command);
			Launched=true;
			LoadTacticalMap();	//When the other side recieved the history and we're not yet launched and we already loaded the game 
								//(so the second time we get the history) load the tactical game
		}	
	}
	else if(Command ~= "SwapMods")
	{
		if(!SentMods)
			SendRemoteCommand_SwapMods();

		PopupCustomNotification("Missing Mods Found",HandleMissingMods(`XCOMNETMANAGER.GetCommandParam_String(RawParams)),"Connect","Disconnect");
	}
	
	else if(Command~="HistoryConfirmedPopUp")
	{
		PopupClientNotification();
	}
	else if(Command~= "HistoryConfirmedLoadGame")
	{
		`log(Command);
		if(`XCOMNETMANAGER.HasClientConnection()) 
		{
			if(UIDialogueBox(UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).Movie.Stack.GetFirstInstanceOf(class'UIDialogueBox')).ShowingDialog())
				UIDialogueBox(UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).Movie.Stack.GetFirstInstanceOf(class'UIDialogueBox')).RemoveDialog();
			SendRemoteCommand("ImComingBaby");
			LoadTacticalMap(); //when the tactical game was loaded on the server that makes the client load the tactical game
		}
	}
	else if(Command~= "HistoryConfirmed")
	{
		XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	
		if( `XCOMNETMANAGER.HasClientConnection() )
			//LoadPlayersFromClient(); //Should work, see if we get the history transfered.
		
		foreach XComHQ.Squad(UnitRef)
		{
			`log("Unit in squad HistoryConfirmed:"@XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID)).GetFullName(),,'Team Dragonpunk Co Op');
		}
		UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).UpdateData(false); // Updates the list of soldier and the slots, also updates the pawns
		UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).UpdateMissionInfo(); // Updates the mission in case something changed
		SavedSquad=XComHQ.Squad;
		`log("Updating Squad Select HistoryConfirmed",,'Team Dragonpunk Co Op');
		UISS=UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect'));
		listWidth =( UISS.GetTotalSlots()+(int(UISS.ShowExtraSlot1())*-2) )* (class'UISquadSelect_ListItem'.default.width + UISS.LIST_ITEM_PADDING);
		listX =(UISS.Movie.UI_RES_X / 2) - (listWidth/2);
		//UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).m_kSlotList.OriginTopCenter();
		//UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).m_kSlotList.SetX(UISS.Movie.UI_RES_X / 2); //fixes the x position of the list on the screen
		//UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).m_kSlotList.RealizeLocation(); //fixes the x position of the list on the screen
		
		UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).UpdateData(false);
			
	
		`XCOMHISTORY.RegisterOnNewGameStateDelegate(OnNewGameState_SquadWatcher); // Register for a Gamestate delegate so we can send new states over the net when they are submitted
	}
	else if (Command~= "HistoryRegisteredConfirmed")
	{
		XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		foreach XComHQ.Squad(UnitRef)
		{
			`log("Unit in squad RegisteredConfirmed:"@XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID)).GetFullName(),,'Team Dragonpunk Co Op');
		}
		SavedSquad=XComHQ.Squad;
		`XCOMHISTORY.RegisterOnNewGameStateDelegate(OnNewGameState_SquadWatcher);
		UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).UpdateData(false);
		UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).UpdateMissionInfo();
		UISS=UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect'));
		listWidth =( UISS.GetTotalSlots()+(int(UISS.ShowExtraSlot1())*-2) )* (class'UISquadSelect_ListItem'.default.width + UISS.LIST_ITEM_PADDING);
		listX =(UISS.Movie.UI_RES_X / 2) - (listWidth/2);
		//UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).m_kSlotList.OriginTopCenter();
		//UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).m_kSlotList.SetX(UISS.Movie.UI_RES_X / 2); //fixes the x position of the list on the screen
		//UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).m_kSlotList.RealizeLocation(); //fixes the x position of the list on the screen
		
		UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).UpdateData(false);
		`log("Updating Squad Select RegisteredConfirmed",,'Team Dragonpunk Co Op');
	}
	else if (Command~="LoadGame")
	{
		`XCOMHISTORY.UnRegisterOnNewGameStateDelegate(OnNewGameState_SquadWatcher);
		`log("Client:"@`XCOMNETMANAGER.HasClientConnection() @", Server:"@`XCOMNETMANAGER.HasServerConnection() @"Launched:"@Launched ,,'Team Dragonpunk Co Op');		
		`log(Command);
		LoadingGame=true;
	}
	else if(Command~="MergeStateReceived")
	{
		`XCOMHISTORY.RegisterOnNewGameStateDelegate(OnNewGameState_SquadWatcher);		
		SendRemoteCommand("RegisterGameStateWatcher");
	}
	else if(Command~="RegisterGameStateWatcher")
	{
		`XCOMHISTORY.RegisterOnNewGameStateDelegate(OnNewGameState_SquadWatcher);		
	}
	else if(Command~="UnRegisterONGSD")
	{
		`XCOMHISTORY.UnRegisterOnNewGameStateDelegate(OnNewGameState_SquadWatcher);
	}
	else if (Command~="UpdateSquad")
	{
		TotalSquad.Length=0;
		ServerSquad.Length=0;
		ClientSquad.Length=0;
		DecipherSquads(RawParams);
	}
}

simulated function XComGameState_MissionSite GetMission()
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom HQ;

	HQ = class'UIUtilities_Strategy'.static.GetXComHQ();
	History = `XCOMHISTORY;
	return XComGameState_MissionSite(History.GetGameStateForObjectID(HQ.MissionRef.ObjectID));
}

function UpdateSS()
{
	local float listWidth,listX;
	local UISquadSelect UISS;
	local XComGameState_HeadquartersXCom XComHQ;
	local StateObjectReference UnitRef;	
	//Updates the squad select screen
	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	foreach XComHQ.Squad(UnitRef)
	{
		`log("Unit in squad RegisteredConfirmed:"@XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID)).GetFullName(),,'Team Dragonpunk Co Op');
	}

	SavedSquad=XComHQ.Squad;
	`XCOMHISTORY.RegisterOnNewGameStateDelegate(OnNewGameState_SquadWatcher);
	UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).UpdateData(false);
	UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).UpdateMissionInfo();
	UISS=UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect'));
	listWidth =( UISS.GetTotalSlots()+(int(UISS.ShowExtraSlot1())*-2) )* (class'UISquadSelect_ListItem'.default.width + UISS.LIST_ITEM_PADDING);
	listX =(UISS.Movie.UI_RES_X / 2) - (listWidth/2);
	//UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).m_kSlotList.OriginTopCenter();
	//UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).m_kSlotList.SetX(UISS.Movie.UI_RES_X / 2); //fixes the x position of the list on the screen
	//UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).m_kSlotList.RealizeLocation(); //fixes the x position of the list on the screen
	
	UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).UpdateData(false);
	`log("Updating Squad Select RegisteredConfirmed",,'Team Dragonpunk Co Op');	
}

/*
* A Game State watcher that send the submitted gamestates over the network when it sees one. 
*/
static function OnNewGameState_SquadWatcher(XComGameState GameState) //Thank you Amineri and LWS! 
{
	local int StateObjectIndex;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_BaseObject StateObjectCurrent;
	local bool Send;
	if(!`XCOMNETMANAGER.HasConnections())return;

    for( StateObjectIndex = 0; StateObjectIndex < GameState.GetNumGameStateObjects(); ++StateObjectIndex )
	{
		StateObjectCurrent = GameState.GetGameStateForObjectIndex(StateObjectIndex);		
		XComHQ = XComGameState_HeadquartersXCom(StateObjectCurrent);
		if(XComHQ != none) 
		{
			`log("XComHQ:False");
			Send=true;
		}
	}
	if(Send)
	{
		SendRemoteUnregister();
		`XCOMNETMANAGER.SendMergeGameState(GameState);
		`XCOMHISTORY.UnRegisterOnNewGameStateDelegate(OnNewGameState_SquadWatcher);
	}	
}

static function SendRemoteUnregister()
{
	local array<byte> Parms;
	Parms.Length = 0; // Removes script warning.
	`XCOMNETMANAGER.SendRemoteCommand("UnRegisterONGSD", Parms);	
}

function bool SquadCheck(array<StateObjectReference> arrOne, array<StateObjectReference> arrTwo) 
{
	local int i,j;
	local array<bool> CheckArray;

	if(arrOne.Length!=arrTwo.Length) 
		return False;

	for(i=0;i<arrOne.Length;i++) //Loop galore! n^2 is fine when squads are rarely over 12 people
	{
		for(j=0;j<arrTwo.Length;j++)
		{
			if(arrOne[i]==arrTwo[j] && arrOne[i].ObjectID>0)
				CheckArray.AddItem(true);
		}
	}
	if(CheckArray.Length==arrOne.Length)
		return true;

	return false;
}
 
/*
* Checks if the units inside the input game state are different to the latest history state in the game.
*/
function bool PerSoldierSquadCheck(XComGameState InGS) 
{
	local int i;
	local XComGameState_Unit Unit,UnitPrev;


	for(i=0;i<InGS.GetNumGameStateObjects();i++)
	{
		Unit=XComGameState_Unit(InGS.GetGameStateForObjectIndex(i));
		if(Unit!=none &&Unit.ObjectID>0)
		{
			UnitPrev=XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(Unit.ObjectID,,InGS.HistoryIndex - 1));
			if(UnitPrev !=none && UnitPrev.ObjectID>0)
			{
				if(UnitPrev!=Unit)
					return false;
			}
		}
	}
	return true;
}

/*
* Used when getting the unit changes in co-op, updates all the units and control lists.
*/
function ReceiveMergeGameState(XComGameState InGameState) 
{
 	local XComGameState_HeadquartersXCom XComHQ;
	local StateObjectReference UnitRef; 
	local float listWidth,listX;
	local UISquadSelect UISS;
	local Object myself;
	myself = self;
	`log(`location @"Received Merge GameState",,'Team Dragonpunk Co Op');
	NewGSWasRecieved=true;
	//SendRemoteCommand("HistoryRegisteredConfirmed");
	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom')); //Update the HQ, will ensure the squads are updated.
	foreach XComHQ.Squad(UnitRef)
	{
		if(UnitRef.ObjectID>0)
			`log("Unit in squad ReceiveMergeGameState:"@XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID)).GetFullName(),,'Team Dragonpunk Co Op');
	}
	//`XCOMHISTORY.RegisterOnNewGameStateDelegate(OnNewGameState_SquadWatcher);
	if(!SquadCheck(XComHQ.Squad,SavedSquad) ||!PerSoldierSquadCheck(InGameState)) //Check if we have any changes. Without checking you'll get a T-pose on the units and the UI becomes unresponsive.
	{
		`log("SquadCheck"@SquadCheck(XComHQ.Squad,SavedSquad) @"PerSoldierSquadCheck:"@PerSoldierSquadCheck(InGameState));
		UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).UpdateData(false);
		UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).UpdateMissionInfo();
		GetNewSquadChanges(SavedSquad,XComHQ.Squad);
		SavedSquad=XComHQ.Squad; // Save the squad again
		UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect')).UpdateData(false);
		SentRemoteSquadCommand();
		//CalcAllPlayersReady();
	}
	SendRemoteCommand("MergeStateReceived");
	UIMission(`SCREENSTACK.GetFirstInstanceOf(class'UIMission')).ConfirmButton.OnClickedDelegate=OpenUIAssignSoldiers;
	`XEVENTMGR.RegisterForEvent( myself, 'MissionSite_OverrideLaunchTacticalBattle', OverrideLaunchTacticalBattle);
	`log(`location @"Registering Events",,'Dragonpunk Coop LW2 ');

}
 

/*
* syncs up changes in the new squad relative to the old one.
*/
function GetNewSquadChanges(array<StateObjectReference> AOldSquad, array<StateObjectReference> ANewSquad)
{
	local int i,j;
	local bool Found;
	local StateObjectReference TempRef;
	local array<StateObjectReference> OldSquad,NewSquad;
	
	OldSquad=AOldSquad;
	NewSquad=ANewSquad;
	foreach OldSquad(TempRef)
	{
		if(TempRef.ObjectID==0)
			OldSquad.RemoveItem(TempRef);
	}
	foreach NewSquad(TempRef)
	{
		if(TempRef.ObjectID==0)
			NewSquad.RemoveItem(TempRef);
	}
	if(OldSquad.length==NewSquad.Length)
		return;
	else if(OldSquad.Length>NewSquad.Length)
	{
		
		for(i=0;i<OldSquad.Length;i++)
		{
			Found=false;
			for(j=0;j<NewSquad.Length;j++)
			{
				if(OldSquad[i]==NewSquad[j])
					Found=true;
			}
			if(!Found)
			{
				if(`XCOMNETMANAGER.HasServerConnection())
					ClientSquad.RemoveItem(OldSquad[i]);
				else if(`XCOMNETMANAGER.HasClientConnection())
					ServerSquad.RemoveItem(OldSquad[i]);
			}
		}
	}
	else
	{
		for(i=0;i<NewSquad.Length;i++)
		{
			Found=false;
			for(j=0;j<OldSquad.Length;j++)
			{
				if(NewSquad[i].ObjectID==OldSquad[j].ObjectID)
					Found=true;
			}
			if(!Found)
			{
				if(`XCOMNETMANAGER.HasServerConnection())
					ClientSquad.AddItem(NewSquad[i]);
				else if(`XCOMNETMANAGER.HasClientConnection())
					ServerSquad.AddItem(NewSquad[i]);
			}
		}	
	}
			
}


function SendHistory()
{
	local Object myself;
	myself=self;
	`log(`location,,'XCom_Online');

	class'X2Ability_DefaultAbilitySet_CoOpHackFix'.static.FixHackingAbilities();
	class'X2Ability_DefaultAbilitySet_CoOpHackFix'.static.FixAllMPAbilities();

	`XCOMNETMANAGER.SendHistory(`XCOMHISTORY, `XEVENTMGR);
	UIMission(`SCREENSTACK.GetFirstInstanceOf(class'UIMission')).ConfirmButton.OnClickedDelegate=OpenUIAssignSoldiers;
	`XEVENTMGR.RegisterForEvent( myself, 'MissionSite_OverrideLaunchTacticalBattle', OverrideLaunchTacticalBattle);
	`log(`location @"Registering Events",,'Dragonpunk Coop LW2 ');
}

function bool SendOrMergeGamestate(XComGameState GameState)
{
	local bool bGameStateSubmitted;
	bGameStateSubmitted = false;
	if (`XCOMNETMANAGER.HasConnections())
	{
		if (`XCOMHISTORY.GetStartState() != none)
		{
			`XCOMNETMANAGER.SendMergeGameState(GameState);
		}
		else
		{
			`TACTICALRULES.BuildLocalStateObjectCache();
			`TACTICALRULES.SubmitGameState(GameState);
			bGameStateSubmitted = true;
		}
	}
	return bGameStateSubmitted;
}

function ReceiveHistory(XComGameStateHistory InHistory, X2EventManager EventManager)
{
	local XComGameStateNetworkManager NetworkMgr;
	
	class'X2Ability_DefaultAbilitySet_CoOpHackFix'.static.FixHackingAbilities();
	class'X2Ability_DefaultAbilitySet_CoOpHackFix'.static.FixAllMPAbilities();

	if(!bHistoryLoaded)
	{
		NetworkMgr = `XCOMNETMANAGER;
		NetworkMgr.ClearReceiveHistoryDelegate(ReceiveHistory);
		`log(`location,,'XCom_Online');
		`log(`location @"Dragonpunk Recieved History",,'Team Dragonpunk Co Op');
		bHistoryLoaded = true;
		Global.ReceiveHistory(InHistory, EventManager);
		SendRemoteCommand("HistoryReceived");
		SendRemoteCommand("ClientJoined");
	}
	
}

function ReceiveGameState(XComGameState InGameState)
{
	`log(`location,,'XCom_Online');
}


function GetAllPlayersLaunched()
{
	local XComGameState_Player PlayerState;

	AllPlayersLaunched=true;
	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		if(!PlayerState.bPlayerReady)
		{
			AllPlayersLaunched = false;
			break;
		}
	}
		
} 

function SetGameSettingsAsReady()
{
	local XComOnlineGameSettings GameSettings;
	local OnlineGameInterface GameInterface;;
	GameInterface = class'GameEngine'.static.GetOnlineSubsystem().GameInterface;
	GameSettings = XComOnlineGameSettings(GameInterface.GetGameSettings('Game'));
	GameSettings.SetServerReady(true);
	GameInterface.UpdateOnlineGame('Game', GameSettings, true);
}

function LoadTacticalMapDelegate(UIButton Button)
{
	Button.SetDisabled(true);
	RealLoadTactical();
}

function RealLoadTactical()
{
	SetupStartState();
	SetupMission();
	LoadTacticalMap();	
	if(`XCOMNETMANAGER.HasServerConnection() && !LoadingGame) SendRemoteCommand("LoadGame");
}

function LoadTacticalMap()
{
	local XComGameState_BattleData BattleDataState;
	`log(`location,,'XCom_Online');
//	ConsoleCommand("unsuppress XCom_GameStates");
	`XCOMHISTORY.UnRegisterOnNewGameStateDelegate(OnNewGameState_SquadWatcher);

	class'X2Ability_DefaultAbilitySet_CoOpHackFix'.static.FixHackingAbilities();
	class'X2Ability_DefaultAbilitySet_CoOpHackFix'.static.FixAllMPAbilities();
	
	BattleDataState = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if(BattleDataState==none)
	{
		BattleDataState =m_BattleData;
	}
	
	`log(`location @ "'" $ BattleDataState.m_strMapCommand $ "'",,'Dragonpunk Co Op');
	if(LoadingGame)
	{
		Launched=true;
		RevertInviteAcceptedDelegates();
		ConsoleCommand(BattleDataState.m_strMapCommand); // The command loads the new game and ruleset
	}
}

/*
* Copied from Other classes, these few functions are used to make the new game initialized and launched.
*/
function SetupMission()
{
	local XComGameState                     TacticalStartState;
	local XComTacticalMissionManager		MissionManager;
	local XComGameState_MissionSite			MPMission;

	TacticalStartState = `XCOMHISTORY.GetStartState();

	// There should only be one Mission Site for MP in the Tactical Start State
	foreach TacticalStartState.IterateByClassType(class'XComGameState_MissionSite', MPMission)
	{
		`log(`location @ MPMission.ToString(),,'XCom_Online');
		break;
	}

	// Setup the Mission Data
	MissionManager = `TACTICALMISSIONMGR;
	MissionManager.ForceMission = MPMission.GeneratedMission.Mission;
	MissionManager.MissionQuestItemTemplate = MPMission.GeneratedMission.MissionQuestItemTemplate;
}

function InitListeners()
{
	local object myself;
	myself=self;
	`XEVENTMGR.RegisterForEvent( myself, 'OnTacticalBeginPlay', OnTacticalBeginPlay);
	`log(`location @"InitListeners",,'Dragonpunk Co Op');
}
function EventListenerReturn OnTacticalBeginPlay(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	TGMCoOp=Spawn(class'XCom_Co_Op_TacticalGameManager',self);
	TGMCoOp.InitManager();
	return ELR_NoInterrupt;
}

function SetupStartState()
{
	local XComGameState StrategyStartState, TacticalStartState;
	local XGTacticalGameCore GameCore;
	local XComGameStateHistory	History;

	`log(`location,,'XCom_Online');

	`ONLINEEVENTMGR.ReadProfileSettings();
	History=`XCOMHISTORY;

	///
	/// Setup the Strategy side ...
	///

	// Create the basic strategy objects
	if((XComGameStateContext_StrategyGameRule(History.GetGameStateFromHistory(History.FindStartStateIndex()).GetContext()) == None))
	{
		// Fix to BITFIELD_GAMEAREA_Tactical ?
		//StrategyStartState = class'XComGameStateContext_StrategyGameRule'.static.CreateStrategyGameStart(, , , , , , false, , class'X2DataTemplate'.const.BITFIELD_GAMEAREA_Multiplayer, false /*SetupDLCContent*/);
		StrategyStartState = class'XComGameStateContext_StrategyGameRule'.static.CreateStrategyGameStart(, , true, `ONLINEEVENTMGR.CampaignDifficultySetting, true);
		`log("Creating New Stategy State",,'Dragonpunk Co Op');
	}
	else
	{
		StrategyStartState=History.GetGameStateFromHistory(History.FindStartStateIndex());
	}
	///
	/// Setup the Tactical side ...
	///

	// Setup the GameCore
	GameCore = `GAMECORE;
	if(GameCore == none)
	{
		GameCore = Spawn(class'XGTacticalGameCore', self);
		GameCore.Init();
		`GAMECORE = GameCore;
	}

	// Create the basic objects
	TacticalStartState = CreateDefaultTacticalStartState_Coop(m_BattleData);

	///
	/// Setup the Map
	///

	// Configure the map from the current strategy start state
	SetupMapData(StrategyStartState, TacticalStartState);

	//Add the start state to the history
	`XCOMHISTORY.AddGameStateToHistory(TacticalStartState);	
}

/*
* Creates the Battle Data gamestate for the new mission in co-op
*/
simulated function CreateBD(XComGameState NewGameState,optional out XComGameState_BattleData BD )
{
	local XComGameStateHistory				History;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_HeadquartersAlien	AlienHQ;
	local XComGameState_MissionSite			MissionState;
	local GeneratedMissionData				MissionData;
	local XComGameState_BattleData			BattleData;
	local XComTacticalMissionManager		TacticalMissionManager;
	local X2SelectedMissionData				EmptyMissionData;
	local XComGameState_GameTime			TimeState;
	local X2MissionTemplate					MissionTemplate;
	local X2MissionTemplateManager			MissionTemplateManager;
	local String							MissionBriefing;
	local XComGameState_Unit				NewUnitState;
	local XComGameState_Item				ItemReference;
	local StateObjectReference				StateRef;

	History = `XCOMHISTORY;
	TacticalMissionManager = `TACTICALMISSIONMGR;
	MissionTemplateManager = class'X2MissionTemplateManager'.static.GetMissionTemplateManager();

	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	MissionState = XComGameState_MissionSite(NewGameState.CreateStateObject(class'XComGameState_MissionSite', GetMission().ObjectID));
	MissionData = XComHQ.GetGeneratedMissionData(XComHQ.MissionRef.ObjectID);


	//NewGameState.AddStateObject(MissionState);
	//NewGameState.AddStateObject(XComHQ);

	MissionState.m_strEnemyUnknown$=" ";
	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	if(MissionState.SelectedMissionData == EmptyMissionData)
	{
		MissionState.CacheSelectedMissionData(AlienHQ.GetForceLevel(), MissionState.GetMissionDifficulty());
	}

	TimeState = XComGameState_GameTime(History.GetSingleGameStateObjectForClass(class'XComGameState_GameTime'));
	if(BD==none) BattleData = XComGameState_BattleData(NewGameState.CreateStateObject(class'XComGameState_BattleData'));
	else	BattleData=BD;
	//NewGameState.AddStateObject(BattleData);
	BattleData.m_iMissionID = MissionState.ObjectID;
	BattleData.m_strOpName = MissionData.BattleOpName;
	BattleData.LocalTime = TimeState.CurrentTime;	
	foreach XComHQ.Squad(StateRef)
	{
		NewUnitState=XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit',StateRef.ObjectID));
		NewGameState.AddStateObject(NewUnitState);		
		NewUnitState.SetControllingPlayer(BattleData.PlayerTurnOrder[0]);
		//if(GetSoldierController(StateRef))
		//	NewUnitState.SetBaseMaxStat(eStat_FlightFuel,10);
		`log("UNIT AT TOTAL SQUAD"@NewUnitState.ObjectID @NewUnitState.GetFullName());

		foreach NewUnitState.InventoryItems(StateRef)
		{
			ItemReference = XComGameState_Item(NewGameState.CreateStateObject(Class'XComGameState_Item',StateRef.ObjectID));
			NewGameState.AddStateObject(ItemReference);	
		}
		`log("Adding unit to StartState");
	}
	MissionTemplate = MissionTemplateManager.FindMissionTemplate(MissionData.Mission.MissionName);
	if (MissionTemplate != none)
	{
		MissionBriefing = MissionTemplate.Briefing;
	}
	else
	{
		MissionBriefing  = "NO LOCALIZED BRIEFING TEXT!";
	}
	BattleData.m_iMissionType = TacticalMissionManager.arrMissions.Find('sType', MissionData.Mission.sType);
	BattleData.m_bIsFirstMission = false;
	BattleData.iLevelSeed = MissionData.LevelSeed;
	BattleData.m_strDesc    = MissionBriefing;
	BattleData.m_strOpName  = MissionData.BattleOpName;
	BattleData.MapData.PlotMapName = MissionData.Plot.MapName;
	BattleData.MapData.Biome = MissionData.Biome.strType;	
	BattleData.m_iMissionID = XComHQ.MissionRef.ObjectID;
	BattleData.bUseFirstStartTurnSeed = false;
//	BattleData.GameSettings = XComOnlineGameSettings(class'GameEngine'.static.GetOnlineSubsystem().GameInterface.GetGameSettings('Game'));

	// Force Level
	BattleData.SetForceLevel( AlienHQ.GetForceLevel() );

	// Alert Level
	BattleData.SetAlertLevel(MissionState.GetMissionDifficulty());
	BattleData.m_strLocation = MissionState.GetLocationDescription();
	TacticalMissionManager.ForceMission = MissionData.Mission;
	TacticalMissionManager.MissionQuestItemTemplate = MissionData.MissionQuestItemTemplate;
	BattleData.m_strMapCommand = "open"@BattleData.MapData.PlotMapName$"?game=LW2DragonpunkCoop.XComCoOpTacticalGame";	//Have the game be the XCom Coop tactical game
}

/*
* Figures out who controls who and puts a little marker on client controlled soldiers.
*/
function bool GetSoldierController(StateObjectReference UnitRef)
{
	local bool FoundAtServer,FoundAtClient,Found;
	local StateObjectReference Temp;
	foreach TotalSquad(Temp)
	{
		if(Temp.ObjectID==UnitRef.ObjectID)
		{
			Found=true;
			break;
		}
	}
	foreach ServerSquad(Temp)
	{
		if(Temp.ObjectID==UnitRef.ObjectID)
		{
			FoundAtServer=true;
			break;
		}
	}
	foreach ClientSquad(Temp)
	{
		if(Temp.ObjectID==UnitRef.ObjectID)
		{
			FoundAtClient=true;
			break;
		}
	}
	
	if(!Found)
		`log("DIDNT FIND UNIT AT TOTAL SQUAD"@UnitRef.ObjectID);
	if(!(Found||FoundAtClient||FoundAtServer))
		`log("DIDNT FIND UNIT AT ANY SQUAD"@UnitRef.ObjectID);
	if(FoundAtClient&&FoundAtServer)
		`log("FOUND UNIT AT 2 SQUADS"@UnitRef.ObjectID);

	`log("FOUND UNIT Returning"@FoundAtClient @UnitRef.ObjectID);

	if(FoundAtServer&&!FoundAtClient)
	{
		`log("FOUND UNIT AT 1 SQUAD Returning"@FoundAtClient @UnitRef.ObjectID);
		return false;
	}
	else if(!FoundAtServer&&FoundAtClient)
	{
		`log("FOUND UNIT AT 1 SQUAD Returning"@FoundAtClient @UnitRef.ObjectID);
		return true;
	}
	return true;
	
}

function SetupMapData(XComGameState StrategyStartState, XComGameState TacticalStartState)
{
	local XComGameState_MissionSite			MPMission;
	local X2MissionSourceTemplate			MissionSource;
	local XComGameState_Reward				RewardState;
	local X2RewardTemplate					RewardTemplate;
	local X2StrategyElementTemplateManager	StratMgr;
	local array<XComGameState_WorldRegion>  arrRegions;
	local XComGameState_WorldRegion         RegionState;
	local string                            PlotType;
	local XComGameState_HeadquartersXCom	XComHQ;
	local string                            Biome;
	local XComParcelManager                 ParcelMgr;
	local array<PlotDefinition>             arrValidPlots;
	local array<PlotDefinition>             arrSelectedTypePlots;
	local PlotDefinition                    CheckPlot;

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	ParcelMgr = `PARCELMGR;

	PlotType = m_kMPShellManager.OnlineGame_GetMapPlotName();
	Biome = m_kMPShellManager.OnlineGame_GetMapBiomeName();
	`log(self $ "::" $ GetFuncName() @ `ShowVar(PlotType) @ `ShowVar(Biome),, 'uixcom_mp');

	// Setup the MissionRewards
	RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_None'));
	RewardState = RewardTemplate.CreateInstanceFromTemplate(StrategyStartState);
	RewardState.SetReward(,0);
	StrategyStartState.AddStateObject(RewardState);
	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

	// Setup the GeneratedMission
	MPMission = XComGameState_MissionSite(StrategyStartState.CreateStateObject(class'XComGameState_MissionSite'));
	MissionSource = X2MissionSourceTemplate(StratMgr.FindStrategyElementTemplate('MissionSource_Multiplayer'));

	// Choose a random region
	foreach StrategyStartState.IterateByClassType(class'XComGameState_WorldRegion', RegionState)
	{
		arrRegions.AddItem(RegionState);
	}
	RegionState = arrRegions[`SYNC_RAND_STATIC(arrRegions.Length)];

	// Build the mission
	MPMission = XComGameState_MissionSite(TacticalStartState.CreateStateObject(class'XComGameState_MissionSite',XComHQ.MissionRef.ObjectID));
	ParcelMgr.GetValidPlotsForMission(arrValidPlots, MPMission.GeneratedMission.Mission, Biome);
	if(PlotType == "")
	{
		MPMission.GeneratedMission.Plot = arrValidPlots[`SYNC_RAND_STATIC(arrValidPlots.Length)];
	}
	else
	{
		foreach arrValidPlots(CheckPlot)
		{
			if(CheckPlot.strType == PlotType)
				arrSelectedTypePlots.AddItem(CheckPlot);
		}

		MPMission.GeneratedMission.Plot = arrSelectedTypePlots[`SYNC_RAND_STATIC(arrSelectedTypePlots.Length)];
	}

	if(MPMission.GeneratedMission.Mission.sType == "")
	{
		`Redscreen("GetMissionDataForSourceReward() failed to generate a mission with: \n"
						$ " Source: " $ MissionSource.DataName $ "\n RewardType: " $ RewardState.GetMyTemplate().DisplayName);
	}

	if(Biome == "" && MPMission.GeneratedMission.Plot.ValidBiomes.Length > 0)
	{
		// This plot uses biomes but the user didn't select one, so pick one here
		Biome = MPMission.GeneratedMission.Plot.ValidBiomes[`SYNC_RAND(MPMission.GeneratedMission.Plot.ValidBiomes.Length)];
	}
	if(Biome != "")
	{
		MPMission.GeneratedMission.Biome = ParcelMgr.GetBiomeDefinition(Biome);
	}

	`assert(Biome == "" || MPMission.GeneratedMission.Plot.ValidBiomes.Find(Biome) != INDEX_NONE);

	// Add the mission to the start states
	StrategyStartState.AddStateObject(MPMission);
	MPMission = XComGameState_MissionSite(TacticalStartState.CreateStateObject(class'XComGameState_MissionSite', MPMission.ObjectID));
	TacticalStartState.AddStateObject(MPMission);

	CreateBD(TacticalStartState,m_BattleData);
	// Setup the Battle Data
	`log(`location @ `ShowVar(m_BattleData.MapData.PlotMapName, PlotMapName) @ `ShowVar(m_BattleData.MapData.Biome, Biome) @ `ShowVar(m_BattleData.m_strMapCommand, MapCommand),,'XCom_Online');
}

static function XComGameState CreateDefaultTacticalStartState_Coop(optional out XComGameState_BattleData CreatedBattleDataObject)
{
	local XComGameStateHistory History;
	local XComGameState StartState;
	local XComGameStateContext_TacticalGameRule TacticalStartContext;
	local XComGameState_BattleData BattleDataState;
	local XComGameState_Player XComPlayerState;
	local XComGameState_Player EnemyPlayerState;
	local XComGameState_Player CivilianPlayerState;
	local XComGameState_Cheats CheatState;

	History = `XCOMHISTORY;

	TacticalStartContext = XComGameStateContext_TacticalGameRule(class'XComGameStateContext_TacticalGameRule'.static.CreateXComGameStateContext());
	TacticalStartContext.GameRuleType = eGameRule_TacticalGameStart;
	StartState = History.CreateNewGameState(false, TacticalStartContext);

	BattleDataState = XComGameState_BattleData(StartState.CreateStateObject(class'XComGameState_BattleData'));
	BattleDataState.BizAnalyticsMissionID = `FXSLIVE.GetGUID( );
	BattleDataState = XComGameState_BattleData(StartState.AddStateObject(BattleDataState));
	BattleDataState.PlayerTurnOrder.Length=0;

	XComPlayerState = class'XComGameState_Player'.static.CreatePlayer(StartState, eTeam_XCom);
	XComPlayerState.bPlayerReady = true; 
	BattleDataState.PlayerTurnOrder.AddItem(XComPlayerState.GetReference());
//	class'XGPlayer'.static.CreateVisualizer(XComPlayerState);
	StartState.AddStateObject(XComPlayerState);

	EnemyPlayerState = class'XComGameState_Player'.static.CreatePlayer(StartState, eTeam_Alien);
	EnemyPlayerState.bPlayerReady = true; 
	BattleDataState.PlayerTurnOrder.AddItem(EnemyPlayerState.GetReference());
//	class'XGPlayer'.static.CreateVisualizer(EnemyPlayerState);
	StartState.AddStateObject(EnemyPlayerState);

	CivilianPlayerState = class'XComGameState_Player'.static.CreatePlayer(StartState, eTeam_Neutral);
	CivilianPlayerState.bPlayerReady = true; 
	BattleDataState.CivilianPlayerRef = CivilianPlayerState.GetReference();
//	class'XGPlayer'.static.CreateVisualizer(CivilianPlayerState);
	StartState.AddStateObject(CivilianPlayerState);

	CheatState = XComGameState_Cheats(StartState.CreateStateObject(class'XComGameState_Cheats'));
	StartState.AddStateObject(CheatState);

	CreatedBattleDataObject = BattleDataState;
	return StartState;
}