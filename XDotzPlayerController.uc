// Copyright (C) 2005 Brainbox Games. All Rights Reserved.
// September 27, 2005
 /**
 * XDotzPlayerController - The location for all the xbox specific crap to go!
 *
 *
 * @version $1.0$
 * @author  Jesse (Jesse@digitalextremes.com)
 * @date    May 2003
 */
class XDOTZPlayerController extends DOTZPlayerControllerBase;

var Material icon_friend_recv;
var Material icon_invite_recv;

var XboxConnectionChecker connectionCheck;
var bool was_filled;
var bool never_set;
var bool bPauseRumble;

/****************************************************************
 * PostLoad
 *
 ****************************************************************
 */

function PostLoad(){
    super.PostLoad();
}

/****************************************************************
 * PostBeginPlay
 *
 ****************************************************************
 */

function PostNetBeginPlay() {

    Log("!!!!Preloading menus!!!!");

    if(connectionCheck == none)
        connectionCheck = Spawn(class'XboxConnectionChecker');

    Super.PostNetBeginPlay();
}

/*****************************************************************
 * PostNetReceive
 * Handles the case (albiet awkwardly) of trying to close the menu
 * when the player controller doesn't have a 'player' yet.
 *****************************************************************
 */
simulated event PostNetReceive(){
    super.PostNetReceive();

    if (class'UtilsXbox'.static.Get_Reboot_Type() == 4 && GameReplicationInfo != none) {
        // CARROT: Update player join flag
        if (never_set) {
            if (GameReplicationInfo.GameFilled) {
                class'UtilsXbox'.static.Set_Player_Not_Joinable ();
            } else {
                class'UtilsXbox'.static.Set_Player_Joinable ();
            }
        } else {
            if (was_filled && !GameReplicationInfo.GameFilled) {
                class'UtilsXbox'.static.Set_Player_Joinable ();
            } else if (!was_filled && GameReplicationInfo.GameFilled) {
                class'UtilsXbox'.static.Set_Player_Not_Joinable ();
            }
        }

        never_set = false;
        was_filled = GameReplicationInfo.GameFilled;
    }

}


/****************************************************************
 * DrawToHud
 *****************************************************************
 */

function DrawToHud(Canvas c, float scaleX, float scaleY) {
    super.DrawToHud(c, scaleX, scaleY);

    if (class'UtilsXbox'.static.Has_Game_Invite_Notification()) {
        c.SetPos(c.ClipX * 0.65, c.ClipY * 0.1);
        c.DrawTile( icon_invite_recv, 64 * scaleX, 64 * scaleY, 0, 0, 64, 64 );
    } else if (class'UtilsXbox'.static.Has_Friend_Request_Notification()) {
        c.SetPos(c.ClipX * 0.65, c.ClipY * 0.1);
        c.DrawTile( icon_friend_recv, 64 * scaleX, 64 * scaleY, 0, 0, 64, 64 );
    }
}

/*****************************************************************
 * SetControllerSensitivity
 *****************************************************************
 */
function SetControllerSensitivity(float sensitivity){
   super.SetControllerSensitivity(sensitivity);
   XBoxPlayerInput(PlayerInput).SetControllerSensitivity(sensitivity);
}

/*****************************************************************
 * InvertLook
 *****************************************************************
 */
exec function InvertLook(bool bIsChecked){
   if (PlayerInput != none){
      XBoxPlayerInput(PlayerInput).InvertVLook(bIsChecked);
   }
}


event InitInputSystem()
{
   super.InitInputSystem();
   InvertLook(GetInvertLook());
}

/*****************************************************************
 * ClientFlash
 *****************************************************************
 */
function ClientFlash( float scale, vector fog )
{
   if (!bDoFade){
      super.ClientFlash(scale,fog);
      if (scale == 0.5 && fog == vect(1000,0,0)){
           if (GetUseVibration() && !bPauseRumble &&
               Level.TimeSeconds > 10) {
               Log("Vibration at " $ Level.TimeSeconds);
               class'UtilsXbox'.static.Rumble_Controller(1, 2);
           }
      }
   }
}

function bool SetPause(bool bPause){
   if (bPause == false){
      bPauseRumble = false;
   }
   return super.SetPause(bPause);
}

function Destroyed()
{
    if(connectionCheck != none)
        connectionCheck.Destroy();

    super.Destroyed();
}


/*****************************************************************
 * Default properties
 *****************************************************************
 */





//Joy 9 D-Pad Up
//Joy 10 D-Pad Down
//Joy 11 D-Pad Left
//Joy 12 D-Pad Right
// Copyright (C) 2005 Brainbox Games. All Rights Reserved.
// September 27, 2005
 /**
 * XDotzPlayerController - The location for all the xbox specific crap to go!
 *
 *
 * @version $1.0$
 * @author  Jesse (Jesse@digitalextremes.com)
 * @date    May 2003
 */
class XDOTZPlayerController extends DOTZPlayerControllerBase;

var Material icon_friend_recv;
var Material icon_invite_recv;

var XboxConnectionChecker connectionCheck;
var bool was_filled;
var bool never_set;
var bool bPauseRumble;

/****************************************************************
 * PostLoad
 *
 ****************************************************************
 */

function PostLoad(){
    super.PostLoad();
}

/****************************************************************
 * PostBeginPlay
 *
 ****************************************************************
 */

function PostNetBeginPlay() {

    Log("!!!!Preloading menus!!!!");

    if(connectionCheck == none)
        connectionCheck = Spawn(class'XboxConnectionChecker');

    Super.PostNetBeginPlay();
}

/*****************************************************************
 * PostNetReceive
 * Handles the case (albiet awkwardly) of trying to close the menu
 * when the player controller doesn't have a 'player' yet.
 *****************************************************************
 */
simulated event PostNetReceive(){
    super.PostNetReceive();

    if (class'UtilsXbox'.static.Get_Reboot_Type() == 4 && GameReplicationInfo != none) {
        // CARROT: Update player join flag
        if (never_set) {
            if (GameReplicationInfo.GameFilled) {
                class'UtilsXbox'.static.Set_Player_Not_Joinable ();
            } else {
                class'UtilsXbox'.static.Set_Player_Joinable ();
            }
        } else {
            if (was_filled && !GameReplicationInfo.GameFilled) {
                class'UtilsXbox'.static.Set_Player_Joinable ();
            } else if (!was_filled && GameReplicationInfo.GameFilled) {
                class'UtilsXbox'.static.Set_Player_Not_Joinable ();
            }
        }

        never_set = false;
        was_filled = GameReplicationInfo.GameFilled;
    }

}


/****************************************************************
 * DrawToHud
 *****************************************************************
 */

function DrawToHud(Canvas c, float scaleX, float scaleY) {
    super.DrawToHud(c, scaleX, scaleY);

    if (class'UtilsXbox'.static.Has_Game_Invite_Notification()) {
        c.SetPos(c.ClipX * 0.65, c.ClipY * 0.1);
        c.DrawTile( icon_invite_recv, 64 * scaleX, 64 * scaleY, 0, 0, 64, 64 );
    } else if (class'UtilsXbox'.static.Has_Friend_Request_Notification()) {
        c.SetPos(c.ClipX * 0.65, c.ClipY * 0.1);
        c.DrawTile( icon_friend_recv, 64 * scaleX, 64 * scaleY, 0, 0, 64, 64 );
    }
}

/*****************************************************************
 * SetControllerSensitivity
 *****************************************************************
 */
function SetControllerSensitivity(float sensitivity){
   super.SetControllerSensitivity(sensitivity);
   XBoxPlayerInput(PlayerInput).SetControllerSensitivity(sensitivity);
}

/*****************************************************************
 * InvertLook
 *****************************************************************
 */
exec function InvertLook(bool bIsChecked){
   if (PlayerInput != none){
      XBoxPlayerInput(PlayerInput).InvertVLook(bIsChecked);
   }
}


event InitInputSystem()
{
   super.InitInputSystem();
   InvertLook(GetInvertLook());
}

/*****************************************************************
 * ClientFlash
 *****************************************************************
 */
function ClientFlash( float scale, vector fog )
{
   if (!bDoFade){
      super.ClientFlash(scale,fog);
      if (scale == 0.5 && fog == vect(1000,0,0)){
           if (GetUseVibration() && !bPauseRumble &&
               Level.TimeSeconds > 10) {
               Log("Vibration at " $ Level.TimeSeconds);
               class'UtilsXbox'.static.Rumble_Controller(1, 2);
           }
      }
   }
}

function bool SetPause(bool bPause){
   if (bPause == false){
      bPauseRumble = false;
   }
   return super.SetPause(bPause);
}

function Destroyed()
{
    if(connectionCheck != none)
        connectionCheck.Destroy();

    super.Destroyed();
}


/*****************************************************************
 * Default properties
 *****************************************************************
 */





//Joy 9 D-Pad Up
//Joy 10 D-Pad Down
//Joy 11 D-Pad Left
//Joy 12 D-Pad Right
