// Copyright (C) 2005 Brainbox Games. All Rights Reserved.
// September 27, 2005
//-----------------------------------------------------------
//
//-----------------------------------------------------------
class UmodPCCheatManager extends PCCheatManager;

function DoCheat(int CheatNumber){
   switch CheatNumber {
   case 0:
      AdvancedPlayerController(Level.GetLocalPlayerController()).Weapons();
      Log("I am doing cheat 0");
      break;
   case 1:
      DOTZPlayerControllerBase(Level.GetLocalPlayerController()).KungFu();
      Log("I am doing cheat 1");
      break;
   case 2:
      DOTZPlayerControllerBase(Level.GetLocalPlayerController()).MiniGun();
      Log("I am doing cheat 2");
      break;
   case 3:
      DOTZGameInfoBase(Level.Game).bNameCheat = !DOTZGameInfoBase(Level.Game).bNameCheat;
      Log("I am doing cheat 3");
      break;
   case 4:
      DOTZPlayerControllerBase(Level.GetLocalPlayerController()).Nuke();
      Log("I am doing cheat 4");
      break;
   case 5:
      DOTZPlayerControllerBase(Level.GetLocalPlayerController()).NoFall();
      Log("I am doing cheat 5");
      break;
    case 6:
      DOTZPlayerControllerBase(Level.GetLocalPlayerController()).ConsoleCommand( "AllAmmo" );
      Log("I am doing cheat 6");
    case 7:
      DOTZPlayerControllerBase(Level.GetLocalPlayerController()).bGodMode = true;
      Log("I am doing cheat 7");


   default:

   }
}

defaultproperties
{
     Cheats(0)=(Cmd=(1,1,1))
}
