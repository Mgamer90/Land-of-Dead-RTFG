//=============================================================================
// UmodHumanTeenagerMale.
//=============================================================================
class UmodHumanTeenagerMale extends UmodHumanPawn
	placeable;

simulated function String GetHumanReadableName()
{
	if ( PlayerReplicationInfo != None )
		return PlayerReplicationInfo.PlayerName;

	return "BOT John Anderson";

	//return GetItemName(String(self));
}

defaultproperties
{
	OwnerName="BOT John Anderson"
	MenuName="BOT John Anderson"

	HeadTextures(0)=Texture'UMODDOTZTHumans.JohnAnderson.JohnnyAndersonHeadA'
	HeadTextures(1)=Texture'UMODDOTZTHumans.JohnAnderson.JohnnyAndersonHeadB'
	HeadTextures(2)=Texture'UMODDOTZTHumans.JohnAnderson.JohnnyAndersonHeadA'
	BodyTextures(0)=Texture'UMODDOTZTHumans.JohnAnderson.JohnnyAndersonBodyA'
	BodyTextures(1)=Texture'UMODDOTZTHumans.JohnAnderson.JohnnyAndersonBodyA'
	BodyTextures(2)=Texture'UMODDOTZTHumans.JohnAnderson.JohnnyAndersonBodyA'
	Mesh=SkeletalMesh'UMODDOTZAHumans.JohnAnderson'

	Skins(0)=Texture'UMODDOTZTHumans.JohnAnderson.JohnnyAndersonBodyA'
	Skins(1)=Texture'UMODDOTZTHumans.JohnAnderson.JohnnyAndersonHeadA'

	BotReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfoTeenagerMale'
}
