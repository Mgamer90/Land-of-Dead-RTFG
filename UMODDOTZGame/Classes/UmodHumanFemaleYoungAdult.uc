//=============================================================================
// UmodHumanFemaleYoungAdult.
//=============================================================================
class UmodHumanFemaleYoungAdult extends UmodHumanPawn
	placeable;

simulated function String GetHumanReadableName()
{
	if ( PlayerReplicationInfo != None )
		return PlayerReplicationInfo.PlayerName;

	return "Female Young Adult";

	//return GetItemName(String(self));
}

defaultproperties
{
     HeadTextures(0)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultHeadShaderA'
     // HeadTextures(1)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultHeadShaderB'
     // HeadTextures(2)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultHeadShaderC'
     // HeadTextures(3)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultHeadShaderD'
     // HeadTextures(4)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultHeadShaderE'
     // HeadTextures(5)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultHeadShaderF'
     // HeadTextures(6)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultHeadShaderG'
     // HeadTextures(7)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultHeadShaderH'
     // HeadTextures(8)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultHeadShaderI'
     // HeadTextures(9)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultHeadShaderJ'
     BodyTextures(0)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultBodyShaderA'
     BodyTextures(1)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultBodyShaderB'
     BodyTextures(2)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultBodyShaderC'
     BodyTextures(3)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultBodyShaderD'
     BodyTextures(4)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultBodyShaderE'

     IsMale=False
	 
	Mesh=SkeletalMesh'UMODDOTZAHumans.FemaleYoungAdult'
	//Mesh=SkeletalMesh'DOTZAZombies.FemaleYoungAdult' FemalePunk

	Skins(0)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultBodyShaderE'
	Skins(1)=Shader'DOTZTZombies.FemaleYoungAdult.FemaleYoungAdultHeadShaderA'

	BotReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfoFemaleYoungAdult'
}
