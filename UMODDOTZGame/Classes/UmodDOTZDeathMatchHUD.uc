// Copyright (C) 2005 Brainbox Games. All Rights Reserved.
// September 27, 2005
//-----------------------------------------------------------
//
//-----------------------------------------------------------
class UmodDOTZDeathMatchHUD extends DOTZMPHudBase;

var localized string PressFireTxt;

//personal stats
var array<Material> TeamKillsMat;
var array<Material> TeamRankMat;
var Material KillsMat;
var Material RankMat;

//team crap
var array<Material> TeamScoreMat;

var array<Material> TeamHeadShotMat;
var Material HeadShotMat;

//===========================================================================
// Editable properties
//===========================================================================

// HUD mockup

//===========================================================================
// Internal data
//===========================================================================


//===========================================================================
// Hud Hooks
//===========================================================================

function drawToHUD( Canvas c, float scaleX, float scaleY ) {

   local int LocalStat;

   super.drawToHUD(c,scaleX,scaleY);
   LocalStat = StatLocation;

    if (DOTZPlayerControllerBase(Player).PlayerReplicationInfo.Team != none)
        DOTZPlayerControllerBase(Player).RefreshPRI(2);
    else
        DOTZPlayerControllerBase(Player).RefreshPRI(1);


   //Draw Rank
   if (Player.PlayerReplicationInfo.Team != none){
      C.SetPos(LeftMargin,StatLocation);
      C.DrawTile(TeamRankMat[TeamNum],128*scaleX,64*scaleY,0,0,128,64);
      C.SetPos(LeftMarginPlus,StatLocation + (5*scaleY));
      C.DrawText(string(DOTZPlayerControllerBase(Player).pris[DOTZPlayerControllerBase(Player).myPRIIndex].Ranking));
      StatLocation += StatSpace;
   } else {
      C.SetPos(LeftMargin,StatLocation);
      C.DrawTile(RankMat,128*scaleX,64*scaleY,0,0,128,64);
      C.SetPos(LeftMarginPlus,StatLocation + (5*scaleY));
      C.DrawText(string(DOTZPlayerControllerBase(Player).pris[DOTZPlayerControllerBase(Player).myPRIIndex].Ranking));
      StatLocation += StatSpace;
   }

   //Draw Kills
   if (Player.PlayerReplicationInfo.Team != none){
      C.SetPos(LeftMargin,StatLocation);
      C.DrawTile(TeamKillsMat[TeamNum],128*scaleX,64*scaleY,0,0,128,64);
      C.SetPos(LeftMarginPlus,StatLocation + (5*scaleY));
      C.DrawText(string(DOTZPlayerControllerBase(Player).pris[DOTZPlayerControllerBase(Player).myPRIIndex].Kills));
      StatLocation += StatSpace;
   } else {
      C.SetPos(LeftMargin,StatLocation);
      C.DrawTile(KillsMat,128*scaleX,64*scaleY,0,0,128,64);
      C.SetPos(LeftMarginPlus, StatLocation + (5*scaleY));
      C.DrawText(string(DOTZPlayerControllerBase(Player).pris[DOTZPlayerControllerBase(Player).myPRIIndex].Kills));
      StatLocation += StatSpace;
   }

   //Draw Rank
   if (Player.PlayerReplicationInfo.Team != none){
      C.SetPos(LeftMargin,StatLocation);
      C.DrawTile(TeamHeadShotMat[TeamNum],128*scaleX,64*scaleY,0,0,128,64);
      C.SetPos(LeftMarginPlus,StatLocation + (5*scaleY));
      C.DrawText(string(DOTZPlayerControllerBase(Player).pris[DOTZPlayerControllerBase(Player).myPRIIndex].Score));
      StatLocation += StatSpace;
   } else {
      C.SetPos(LeftMargin,StatLocation);
      C.DrawTile(HeadShotMat,128*scaleX,64*scaleY,0,0,128,64);
      C.SetPos(LeftMarginPlus,StatLocation + (5*scaleY));
      C.DrawText(string(DOTZPlayerControllerBase(Player).pris[DOTZPlayerControllerBase(Player).myPRIIndex].Score));
      StatLocation += StatSpace;
   }


   //Team statistics
   if (Player.PlayerReplicationInfo.Team != none){
      //your team
      C.SetPos(TeamLeftMargin,LocalStat);
      C.DrawTile(TeamScoreMat[TeamNum],64*scaleX,128*scaleY,0,0,64,128);
      //C.SetPos(TeamLeftMargin+ (15 * scaleX),LocalStat+(65*scaleY));
      //C.DrawText(string(int(Player.GameReplicationInfo.Teams[TeamNum].Score)));

      C.DrawTextJustified(  string(int(Player.GameReplicationInfo.Teams[TeamNum].Score)),
                            1,
                            TeamLeftMargin,
                            LocalStat + (65*scaleY),
                            TeamLeftMargin + 64*scaleX,
                            LocalStat + (65*scaleY) + 32*scaleY    );

      //enemy team
      C.SetPos(TeamLeftMargin + (70 * scaleX),LocalStat);
      C.DrawTile(TeamScoreMat[EnemyTeamNum],64*scaleX,128*scaleY,0,0,64,128);
      //C.SetPos(TeamLeftMargin + (85 * scaleX), LocalStat+ (65 * scaleY));
      //C.DrawText(string(int(Player.GameReplicationInfo.Teams[EnemyTeamNum].Score)));

      C.DrawTextJustified(  string(int(Player.GameReplicationInfo.Teams[EnemyTeamNum].Score)),
                            1,
                            TeamLeftMargin + (70 * scaleX),
                            LocalStat + (65*scaleY),
                            TeamLeftMargin  + (70 * scaleX) + 64*scaleX,
                            LocalStat + (65*scaleY) + 32*scaleY    );
   }

    //Press fire to start
    if (Player.PlayerReplicationInfo.bIsSpectator == true){
       if (Player.GameReplicationInfo.bMatchHasBegun == true ||
           Level.NetMode == NM_ListenServer ){

          C.bCenter = true;
          c.SetPos( scaleX, 375 * scaleY );
          C.DrawText(PressFireTxt);
          C.bCenter = false;
       }
    }
}


//===========================================================================
// default Properties
//===========================================================================

defaultproperties
{
     PressFireTxt="Press fire to continue"
     TeamKillsMat(0)=Texture'DOTZTInterface.HUD.HudIconRedKills'
     TeamKillsMat(1)=Texture'DOTZTInterface.HUD.HudIconBlueKills'
     TeamRankMat(0)=Texture'DOTZTInterface.HUD.HudIconRedPlayerRank'
     TeamRankMat(1)=Texture'DOTZTInterface.HUD.HudIconBluePlayerRank'
     KillsMat=Texture'DOTZTInterface.HUD.HudIconNoTeamKills'
     RankMat=Texture'DOTZTInterface.HUD.HudIconNoTeamPlayerRank'
     TeamScoreMat(0)=Texture'DOTZTInterface.HUD.HudIconTDMTeamRed'
     TeamScoreMat(1)=Texture'DOTZTInterface.HUD.HudIconTDMTeamBlue'

     TeamHeadShotMat(0)=Texture'DOTZTInterface.HUD.HudIconINRedWaves'
     TeamHeadShotMat(1)=Texture'DOTZTInterface.HUD.HudIconINBlueWaves'

     HeadShotMat=Texture'DOTZTInterface.HUD.HudIconINNoTeamWaves'

}

