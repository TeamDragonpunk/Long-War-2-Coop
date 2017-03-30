//  *********   DRAGONPUNK SOURCE CODE   ******************
//  FILE:    UIPanel_TickActor
//  AUTHOR:  Elad Dvash
//  PURPOSE: A ticking actor to help the ConnectionSetup class to perform timed functions.
//--------------------------------------------------------------------------------------------
                                                                                         
class UIPanel_TickActor extends Actor;


/*
* Sets up the timers for the client to force connection to the server
*/
function SetupTick(float TickTime)
{
	`log(`location @"Trying to connect to server IN FUNCTION TickTime:" @TickTime,,'Team Dragonpunk Co Op');
	SetTimer(TickTime,true,'Connect');
}


function SetupCoOpTimer(float TickTime)
{
	`log(`location @"Trying to Create server IN FUNCTION TickTime:" @TickTime,,'Team Dragonpunk Co Op');
	SetTimer(TickTime,true,'OnCreateCoOpGameTimerComplete');
}
function Connect()
{
	local bool ForceSuccess;
	local array<byte> Parms;
	Parms.Length = 0; // Removes script warning.
	`log(`location @"Trying to connect to server",,'Team Dragonpunk Co Op');
	ForceSuccess=`XCOMNETMANAGER.ForceConnectionAttempt(); //Forces the connection and establises the transfer of data between the server and client
	if(ForceSuccess) `XCOMNETMANAGER.SendRemoteCommand("HostJoined",Parms);
	`log(`location @"ForceSuccess"@ForceSuccess,,'Team Dragonpunk Co Op');
	ClearTimer('Connect');
}

function OnCreateCoOpGameTimerComplete()
{
	//clear any repeat timers to prevent the multiplayer match from exiting prematurely during load
	`log("Starting Network Game Ended", true, 'Team Dragonpunk Co Op');
	//set the input state back to normal
	ClearTimer('OnCreateCoOpGameTimerComplete');
}