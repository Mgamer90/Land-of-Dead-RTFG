//=============================================================================
// UmodHumanFemaleTeenager.
//=============================================================================
class UmodHumanFemaleTeenager extends UmodHumanPawn
	placeable;

defaultproperties
{
     HeadTextures(0)=Shader'DOTZTZombies.FemaleTeenager.FemaleTeenagerHeadShaderA'
     HeadTextures(1)=Shader'DOTZTZombies.FemaleTeenager.FemaleTeenagerHeadShaderI'

     BodyTextures(0)=Shader'DOTZTZombies.FemaleTeenager.FemaleTeenagerBodyShaderA'
     BodyTextures(1)=Shader'DOTZTZombies.FemaleTeenager.FemaleTeenagerBodyShaderB'
     BodyTextures(2)=Shader'DOTZTZombies.FemaleTeenager.FemaleTeenagerBodyShaderC'
     BodyTextures(3)=Shader'DOTZTZombies.FemaleTeenager.FemaleTeenagerBodyShaderD'
     BodyTextures(4)=Shader'DOTZTZombies.FemaleTeenager.FemaleTeenagerBodyShaderE'

    IsMale=False

	Mesh=SkeletalMesh'UMODDOTZAHumans.FemaleTeenager'
	//Mesh=SkeletalMesh'DOTZAZombies.FemaleTeenager'
	
	Skins(0)=Shader'DOTZTZombies.FemaleTeenager.FemaleTeenagerBodyShaderA'
	Skins(1)=Shader'DOTZTZombies.FemaleTeenager.FemaleTeenagerHeadShaderA'

	BotReplicationInfoClass=Class'UMODDOTZGame.UmodBotReplicationInfoFemalePunk'
}
