
#include "raylib.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

// ─────────────────────────────────────────────
//  Constants
// ─────────────────────────────────────────────
#define SCREEN_W  960
#define SCREEN_H  640
#define TILE_SIZE  32
#define MAP_W      25
#define MAP_H      18

#define MAX_SPIRITS     6
#define DIALOG_LINES    4
#define DIALOG_LEN      80
#define BATTLE_LOG_SIZE 8

// ─────────────────────────────────────────────
//  Enums
// ─────────────────────────────────────────────
typedef enum {
    SCENE_OVERWORLD,
    SCENE_BATTLE,
    SCENE_MENU,
    SCENE_SPIRIT_LIST,
    SCENE_GAMEOVER,
    SCENE_WIN
} Scene;

typedef enum {
    BATTLE_PLAYER_TURN,
    BATTLE_SPIRIT_SELECT,
    BATTLE_SPIRIT_ACTION,
    BATTLE_ANIM,
    BATTLE_ENEMY_TURN,
    BATTLE_NEGOTIATE,
    BATTLE_RESULT,
    BATTLE_END
} BattlePhase;

typedef enum {
    ACTION_NONE,
    ACTION_STRIKE,
    ACTION_SPIRIT_ATTACK,
    ACTION_SPIRIT_SKILL,
    ACTION_BIND,
    ACTION_PLEAD,
    ACTION_BRIBE,
    ACTION_FLEE
} BattleAction;

typedef enum {
    ELEM_FIRE, ELEM_WATER, ELEM_EARTH, ELEM_WIND,
    ELEM_DARK, ELEM_HOLY, ELEM_BEAST, ELEM_GHOST,
    ELEM_COUNT
} Element;

typedef enum {
    AREA_VILLAGE,
    AREA_FOREST,
    AREA_RUINS,
    AREA_COUNT
} Area;

typedef enum {
    STATUS_NONE = 0,
    STATUS_BURN,      // lose 5% maxHp each turn
    STATUS_PARALYZE   // 35% chance to skip turn
} StatusEffect;

// Element effectiveness
static const float ELEM_EFFECT[ELEM_COUNT][ELEM_COUNT] = {
    //FIRE   WATER  EARTH  WIND   DARK   HOLY   BEAST  GHOST
    {0.5f,  2.0f,  1.0f,  1.0f,  1.0f,  1.0f,  1.5f,  1.0f}, // FIRE
    {2.0f,  0.5f,  1.0f,  1.0f,  1.0f,  1.0f,  1.0f,  1.0f}, // WATER
    {1.0f,  1.0f,  0.5f,  2.0f,  1.0f,  1.0f,  1.0f,  1.0f}, // EARTH
    {1.0f,  1.0f,  2.0f,  0.5f,  1.0f,  1.0f,  1.0f,  1.5f}, // WIND
    {1.0f,  1.0f,  1.0f,  1.0f,  0.5f,  2.0f,  1.0f,  1.5f}, // DARK
    {1.0f,  1.0f,  1.0f,  1.0f,  2.0f,  0.5f,  1.0f,  1.0f}, // HOLY
    {1.5f,  1.0f,  1.0f,  1.0f,  1.0f,  1.0f,  0.5f,  1.0f}, // BEAST
    {1.0f,  1.0f,  1.0f,  1.5f,  1.5f,  1.0f,  1.0f,  0.5f}, // GHOST
};

typedef enum {
    SKILL_NONE,
    SKILL_BASIC_ATTACK,
    SKILL_ELEMENTAL_BLAST,
    SKILL_HEAL,
    SKILL_BUFF,
    SKILL_DEBUFF,
    SKILL_DRAIN
} SkillType;

typedef struct {
    char  name[24];
    SkillType type;
    int   mpCost;
    int   power;         // damage, heal, or stage-change amount
    int   buffTarget;    // 0=atk  1=def  (BUFF/DEBUFF)
    float accuracy;
    float statusChance;  // 0=none
    StatusEffect applyStatus;
    char  description[48];
} SpiritSkill;

// ─────────────────────────────────────────────
//  Data Structures
// ─────────────────────────────────────────────
typedef struct {
    char  name[32];
    int   hp, maxHp;
    int   mp, maxMp;
    int   atk, def, spd;
    int   level;
    int   xp;
    Element elem;
    bool  alive;
    int   greed, pride, pity;
    // status & stage (zero-init safe for template initializers)
    StatusEffect status;
    int   atkStage;   // -3 to +3
    int   defStage;
    SpiritSkill skill1;
    SpiritSkill skill2;
    int   currentMp;
} Spirit;

typedef struct {
    int x, y;
    int facing;
    float animTimer;
    int   animFrame;
    Spirit party[MAX_SPIRITS];
    int   partyCount;
    int   currentSpirit;
    int   hp, maxHp;
    int   mp, maxMp;
    int   gold;
    Area  currentArea;
    bool  movedThisTick;
} Player;

typedef struct {
    char  lines[DIALOG_LINES][DIALOG_LEN];
    int   lineCount;
    int   displayedChars;
    float typeTimer;
    bool  active;
    bool  finished;
} Dialog;

typedef struct {
    Spirit  wild;
    int     wildX, wildY;
    bool    active;
} WildSpirit;

// ─────────────────────────────────────────────
//  Tile maps (0=grass/floor 1=wall/tree 2=path 3=water 4=special)
// ─────────────────────────────────────────────
static int gMaps[AREA_COUNT][MAP_H][MAP_W] = {
    // AREA_VILLAGE
    {
        {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
        {1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,1,1,0,0,0,0,0,1,0,0,1,1,1,0,0,0,0,0,1,1,0,1},
        {1,0,0,1,1,0,0,0,0,0,1,0,0,1,1,1,0,0,0,0,0,1,1,0,1},
        {1,0,0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,2,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,2,0,4,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,2,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,1,1,1,1,1,1,1,1,1,1,1,2,2,1,1,1,1,1,1,1,1,1,1,1},
    },
    // AREA_FOREST
    {
        {1,1,1,1,1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
        {1,0,0,0,0,1,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,1,1,0,1,0,0,1,0,1,0,1,0,1,1,0,0,1,1,0,0,0,0,1},
        {1,0,1,1,0,0,0,0,0,0,1,0,0,0,1,1,0,0,1,1,0,0,0,0,1},
        {1,0,0,0,0,1,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1},
        {1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,1,0,0,1,0,1,0,0,1,0,0,1,0,0,0,1,0,0,1,0,0,1,1},
        {1,0,0,0,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,3,3,3,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,1,0,0,0,0,0,0,0,1,1,0,0,0,0,0,1,0,0,0,0,1,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,4,0,1},
        {1,0,0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,1,1,1,1,1,1,1,1,1,1,1,2,2,1,1,1,1,1,1,1,1,1,1,1},
    },
    // AREA_RUINS
    {
        {1,1,1,1,1,1,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,1,1,1,0,0,0,0,0,1,1,0,0,0,0,0,0,1,0,0,0,0,0,1},
        {1,0,1,0,1,0,0,0,0,0,1,1,0,0,0,0,0,0,1,0,0,0,0,0,1},
        {1,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,1},
        {1,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,1,0,0,0,0,0,0,1,4,1,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    }
};

// ─────────────────────────────────────────────
//  Spirit templates  (status/atkStage/defStage zero-init via partial init)
// ─────────────────────────────────────────────
static const Spirit gVillageSpirits[] = {
    {"Emberkid",   18,18,8,8,  5,3,6,  3,0,ELEM_FIRE,  true,3,5,7},
    {"Mistwraith", 14,14,12,12,3,4,8,  2,0,ELEM_WATER, true,2,3,8},
    {"Stoneback",  20,20,6,6,  4,6,3,  3,0,ELEM_EARTH, true,4,7,4},
    {"Leafsoul",   12,12,14,14,4,3,9,  2,0,ELEM_WIND,  true,5,4,6},
    {"Gloomshade", 16,16,10,10,6,3,7,  4,0,ELEM_DARK,  true,6,6,5},
};
static const Spirit gForestSpirits[] = {
    {"Thornhound",  24,24,8,8,  7,5,6,  5,0,ELEM_BEAST, true,4,6,4},
    {"Willowisp",   18,18,14,14,5,3,10, 5,0,ELEM_GHOST, true,2,4,9},
    {"Bogreek",     28,28,6,6,  8,7,4,  6,0,ELEM_WATER, true,5,7,3},
    {"Cinderhawk",  22,22,10,10,9,4,8,  6,0,ELEM_FIRE,  true,3,8,5},
    {"Mosscreep",   20,20,12,12,6,6,6,  5,0,ELEM_EARTH, true,6,5,6},
    {"Shadowfang",  25,25,8,8,  8,5,7,  7,0,ELEM_DARK,  true,7,5,4},
};
static const Spirit gRuinsSpirits[] = {
    {"Ashrevenant", 32,32,12,12,10,6,7, 9,0,ELEM_GHOST, true,3,8,6},
    {"Ironbound",   38,38,8,8,  11,9,4, 9,0,ELEM_EARTH, true,5,9,3},
    {"Voidkite",    28,28,16,16,9,4,11, 8,0,ELEM_DARK,  true,2,5,9},
    {"Solarwing",   30,30,14,14,10,5,9, 10,0,ELEM_HOLY,  true,4,7,7},
    {"Dreadmaw",    40,40,10,10,12,8,5, 10,0,ELEM_BEAST, true,6,8,4},
    {"Oblivion",    35,35,18,18,11,6,8, 12,0,ELEM_DARK,  true,1,6,8},
};

// ─────────────────────────────────────────────
//  Globals
// ─────────────────────────────────────────────
static Player   gPlayer;
static Scene    gScene        = SCENE_OVERWORLD;
static Dialog   gDialog       = {0};
static Spirit   gEnemy        = {0};
static BattlePhase gPhase     = BATTLE_PLAYER_TURN;
static BattleAction gSelected = ACTION_NONE;
static int      gMenuCursor   = 0;
static int      gBattleCursor = 0;
static int      gSpiritCursor = 0;
static int      gSpiritActionCursor = 0;
static float    gBattleAnim   = 0.0f;
static bool     gBattleAnimHitPlayer = false;
static bool     gBattleAnimHitEnemy  = false;
static float    gEncounterCooldown   = 0.0f;
static bool     gCanCapture   = false;
static int      gNegotiateResult = 0;
static float    gNegotiateAnim   = 0.0f;
static char     gResultMsg[DIALOG_LEN] = {0};
static Area     gNextArea     = AREA_VILLAGE;
static bool     gAreaTransition = false;
static int      gStepCounter  = 0;

static bool     gBossDefeated[AREA_COUNT] = {false};
static bool     gBossTriggered = false;
static Spirit   gBoss = {0};

static float    gCamX = 0, gCamY = 0;

// Battle log
static char     gBattleLog[BATTLE_LOG_SIZE][DIALOG_LEN];
static int      gBattleLogHead  = 0;
static int      gBattleLogCount = 0;

// ─────────────────────────────────────────────
//  Colors
// ─────────────────────────────────────────────
#define COL_BG         (Color){12,  8, 20, 255}
#define COL_PANEL      (Color){22, 15, 38, 255}
#define COL_PANEL2     (Color){32, 22, 55, 255}
#define COL_BORDER     (Color){90, 60,140, 255}
#define COL_BORDER2    (Color){160,100,220, 255}
#define COL_TEXT       (Color){230,220,255, 255}
#define COL_TEXT_DIM   (Color){120,100,160, 255}
#define COL_ACCENT     (Color){200, 80,255, 255}
#define COL_FIRE       (Color){255,100, 40, 255}
#define COL_WATER      (Color){ 60,160,255, 255}
#define COL_EARTH      (Color){ 90,180, 60, 255}
#define COL_WIND       (Color){140,230,200, 255}
#define COL_DARK       (Color){100, 50,180, 255}
#define COL_HOLY       (Color){255,240,100, 255}
#define COL_BEAST      (Color){180,100, 60, 255}
#define COL_GHOST      (Color){160,200,220, 255}
#define COL_HP_BAR     (Color){ 80,220,120, 255}
#define COL_HP_LOW     (Color){220, 80, 60, 255}
#define COL_MP_BAR     (Color){ 80,140,255, 255}
#define COL_GRASS      (Color){ 20, 50, 25, 255}
#define COL_TREE       (Color){ 15, 35, 18, 255}
#define COL_PATH       (Color){ 70, 60, 45, 255}
#define COL_WATER_TILE (Color){ 20, 50,100, 255}
#define COL_RUIN       (Color){ 55, 45, 70, 255}
#define COL_PLAYER     (Color){255,220,100, 255}
#define COL_SPECIAL    (Color){200,150,255, 255}
#define COL_BURN       (Color){255,130, 30, 255}
#define COL_PARALYZE   (Color){200,240, 80, 255}

// ─────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────
static Color ElemColor(Element e) {
    switch(e) {
        case ELEM_FIRE:  return COL_FIRE;
        case ELEM_WATER: return COL_WATER;
        case ELEM_EARTH: return COL_EARTH;
        case ELEM_WIND:  return COL_WIND;
        case ELEM_DARK:  return COL_DARK;
        case ELEM_HOLY:  return COL_HOLY;
        case ELEM_BEAST: return COL_BEAST;
        case ELEM_GHOST: return COL_GHOST;
        default: return COL_TEXT;
    }
}
static const char* ElemName(Element e) {
    switch(e) {
        case ELEM_FIRE:  return "FIRE";
        case ELEM_WATER: return "WATER";
        case ELEM_EARTH: return "EARTH";
        case ELEM_WIND:  return "WIND";
        case ELEM_DARK:  return "DARK";
        case ELEM_HOLY:  return "HOLY";
        case ELEM_BEAST: return "BEAST";
        case ELEM_GHOST: return "GHOST";
        default: return "???";
    }
}

static float StageMultiplier(int stage) {
    static const float mults[7] = {0.50f,0.67f,0.80f,1.00f,1.25f,1.50f,2.00f};
    if (stage < -3) stage = -3;
    if (stage >  3) stage =  3;
    return mults[stage + 3];
}

static const char* StatusName(StatusEffect s) {
    switch(s) {
        case STATUS_BURN:     return "BRN";
        case STATUS_PARALYZE: return "PAR";
        default:              return "";
    }
}
static Color StatusColor(StatusEffect s) {
    switch(s) {
        case STATUS_BURN:     return COL_BURN;
        case STATUS_PARALYZE: return COL_PARALYZE;
        default:              return COL_TEXT;
    }
}

static void AddBattleLog(const char* msg) {
    strncpy(gBattleLog[gBattleLogHead], msg, DIALOG_LEN-1);
    gBattleLog[gBattleLogHead][DIALOG_LEN-1] = '\0';
    gBattleLogHead = (gBattleLogHead + 1) % BATTLE_LOG_SIZE;
    if (gBattleLogCount < BATTLE_LOG_SIZE) gBattleLogCount++;
}

static void DialogSet(const char* line1, const char* line2, const char* line3, const char* line4);

// Initialize / reinitialize a spirit's skills and battle state
static void InitSpiritSkills(Spirit* s) {
    s->currentMp = s->maxMp;
    s->status    = STATUS_NONE;
    s->atkStage  = 0;
    s->defStage  = 0;

    // skill1: always a basic attack
    strcpy(s->skill1.name, "Spirit Strike");
    s->skill1.type        = SKILL_BASIC_ATTACK;
    s->skill1.mpCost      = 0;
    s->skill1.power       = s->atk;
    s->skill1.buffTarget  = 0;
    s->skill1.accuracy    = 0.95f;
    s->skill1.statusChance = 0.0f;
    s->skill1.applyStatus  = STATUS_NONE;
    strcpy(s->skill1.description, "Basic physical attack");

    // skill2: element-specific, unlocked at level 2
    memset(&s->skill2, 0, sizeof(s->skill2));
    s->skill2.type = SKILL_NONE;

    if (s->level < 2) return;

    switch(s->elem) {
        case ELEM_FIRE:
            strcpy(s->skill2.name, "Flame Burst");
            s->skill2.type        = SKILL_ELEMENTAL_BLAST;
            s->skill2.mpCost      = 6;
            s->skill2.power       = s->atk * 2;
            s->skill2.accuracy    = 0.85f;
            s->skill2.statusChance = 0.30f;
            s->skill2.applyStatus  = STATUS_BURN;
            strcpy(s->skill2.description, "Blazing hit, 30% Burn");
            break;
        case ELEM_WATER:
            strcpy(s->skill2.name, "Healing Rain");
            s->skill2.type     = SKILL_HEAL;
            s->skill2.mpCost   = 8;
            s->skill2.power    = s->maxHp / 3 + 2;
            s->skill2.accuracy = 1.0f;
            strcpy(s->skill2.description, "Restore HP");
            break;
        case ELEM_EARTH:
            strcpy(s->skill2.name, "Rock Shield");
            s->skill2.type       = SKILL_BUFF;
            s->skill2.mpCost     = 5;
            s->skill2.power      = 1;
            s->skill2.buffTarget = 1;  // def
            s->skill2.accuracy   = 1.0f;
            strcpy(s->skill2.description, "Raise own DEF");
            break;
        case ELEM_WIND:
            strcpy(s->skill2.name, "Gust Strike");
            s->skill2.type        = SKILL_ELEMENTAL_BLAST;
            s->skill2.mpCost      = 5;
            s->skill2.power       = (int)(s->atk * 1.5f);
            s->skill2.accuracy    = 0.90f;
            s->skill2.statusChance = 0.35f;
            s->skill2.applyStatus  = STATUS_PARALYZE;
            strcpy(s->skill2.description, "Wind slash, 35% Paralyze");
            break;
        case ELEM_DARK:
            strcpy(s->skill2.name, "Life Drain");
            s->skill2.type     = SKILL_DRAIN;
            s->skill2.mpCost   = 7;
            s->skill2.power    = s->atk;
            s->skill2.accuracy = 0.80f;
            strcpy(s->skill2.description, "Steal HP from enemy");
            break;
        case ELEM_HOLY:
            strcpy(s->skill2.name, "Holy Mend");
            s->skill2.type     = SKILL_HEAL;
            s->skill2.mpCost   = 6;
            s->skill2.power    = s->maxHp / 2;
            s->skill2.accuracy = 1.0f;
            strcpy(s->skill2.description, "Major HP restore");
            break;
        case ELEM_BEAST:
            strcpy(s->skill2.name, "Feral Rage");
            s->skill2.type       = SKILL_BUFF;
            s->skill2.mpCost     = 4;
            s->skill2.power      = 1;
            s->skill2.buffTarget = 0;  // atk
            s->skill2.accuracy   = 1.0f;
            strcpy(s->skill2.description, "Raise own ATK");
            break;
        case ELEM_GHOST:
            strcpy(s->skill2.name, "Soul Curse");
            s->skill2.type        = SKILL_DEBUFF;
            s->skill2.mpCost      = 6;
            s->skill2.power       = 1;
            s->skill2.buffTarget  = 1;  // lower enemy def
            s->skill2.accuracy    = 0.80f;
            s->skill2.statusChance = 0.25f;
            s->skill2.applyStatus  = STATUS_PARALYZE;
            strcpy(s->skill2.description, "Lower enemy DEF, 25% Paralyze");
            break;
        default: break;
    }
}

static float GetElementMultiplier(Element attacker, Element defender) {
    return ELEM_EFFECT[attacker][defender];
}

static int PerformSpiritAttack(Spirit* attacker, Spirit* defender, int power) {
    float elemMult = GetElementMultiplier(attacker->elem, defender->elem);
    float atkMult  = StageMultiplier(attacker->atkStage);
    float defMult  = StageMultiplier(defender->defStage);
    int damage = (int)(power * elemMult * atkMult / defMult);
    damage += (rand() % (damage / 4 + 1)) - (damage / 8);
    if (damage < 1) damage = 1;
    defender->hp -= damage;
    if (defender->hp < 0) defender->hp = 0;
    return damage;
}

// Apply burn chip-damage; returns true if the spirit survives (always here, no KO from burn)
static void ApplyBurnDamage(Spirit* s) {
    int dmg = (s->maxHp * 5) / 100;
    if (dmg < 1) dmg = 1;
    s->hp -= dmg;
    if (s->hp < 1) s->hp = 1; // burn cannot KO
    char msg[DIALOG_LEN];
    snprintf(msg, DIALOG_LEN, "%s is hurt by burn! -%d HP", s->name, dmg);
    AddBattleLog(msg);
}

// Use skill2 of `spirit` against `target`. Sets gBattleAnimHitEnemy.
// Returns true if target was KO'd.
static bool PerformSpiritSkill(Spirit* spirit, Spirit* target, SpiritSkill* skill) {
    if (spirit->currentMp < skill->mpCost) {
        char msg[DIALOG_LEN];
        snprintf(msg, DIALOG_LEN, "%s has no MP for %s!", spirit->name, skill->name);
        DialogSet(msg, "", "", "");
        AddBattleLog(msg);
        return false;
    }

    spirit->currentMp -= skill->mpCost;
    char msg[DIALOG_LEN];

    if ((float)rand()/RAND_MAX > skill->accuracy) {
        snprintf(msg, DIALOG_LEN, "%s used %s... but missed!", spirit->name, skill->name);
        DialogSet(msg, "", "", "");
        AddBattleLog(msg);
        return false;
    }

    bool targetKO = false;

    switch(skill->type) {
        case SKILL_BASIC_ATTACK:
        case SKILL_ELEMENTAL_BLAST: {
            int damage = PerformSpiritAttack(spirit, target, skill->power);
            snprintf(msg, DIALOG_LEN, "%s: %s — %d dmg!", spirit->name, skill->name, damage);
            gBattleAnimHitEnemy = true;
            targetKO = (target->hp <= 0);
            break;
        }
        case SKILL_HEAL: {
            int heal = skill->power;
            spirit->hp += heal;
            if (spirit->hp > spirit->maxHp) spirit->hp = spirit->maxHp;
            snprintf(msg, DIALOG_LEN, "%s: %s — +%d HP!", spirit->name, skill->name, heal);
            break;
        }
        case SKILL_BUFF: {
            int* stage = (skill->buffTarget == 0) ? &spirit->atkStage : &spirit->defStage;
            *stage += skill->power;
            if (*stage >  3) *stage =  3;
            snprintf(msg, DIALOG_LEN, "%s: %s — %s rose!",
                spirit->name, skill->name, skill->buffTarget==0?"ATK":"DEF");
            break;
        }
        case SKILL_DEBUFF: {
            int* stage = (skill->buffTarget == 0) ? &target->atkStage : &target->defStage;
            *stage -= skill->power;
            if (*stage < -3) *stage = -3;
            snprintf(msg, DIALOG_LEN, "%s: %s — enemy %s fell!",
                spirit->name, skill->name, skill->buffTarget==0?"ATK":"DEF");
            break;
        }
        case SKILL_DRAIN: {
            int damage = PerformSpiritAttack(spirit, target, skill->power);
            int heal   = damage / 2;
            spirit->hp += heal;
            if (spirit->hp > spirit->maxHp) spirit->hp = spirit->maxHp;
            snprintf(msg, DIALOG_LEN, "%s drained %d HP!", spirit->name, damage);
            gBattleAnimHitEnemy = true;
            targetKO = (target->hp <= 0);
            break;
        }
        default:
            return false;
    }

    DialogSet(msg, "", "", "");
    AddBattleLog(msg);

    // Apply status effect to target
    if (skill->statusChance > 0.0f && target->status == STATUS_NONE && !targetKO) {
        if ((float)rand()/RAND_MAX < skill->statusChance) {
            target->status = skill->applyStatus;
            char s2[DIALOG_LEN];
            if (skill->applyStatus == STATUS_BURN)
                snprintf(s2, DIALOG_LEN, "%s was burned!", target->name);
            else
                snprintf(s2, DIALOG_LEN, "%s was paralyzed!", target->name);
            AddBattleLog(s2);
            DialogSet(msg, s2, "", "");
        }
    }

    return targetKO;
}

static void DialogSet(const char* line1, const char* line2, const char* line3, const char* line4) {
    gDialog.lineCount = 0;
    gDialog.displayedChars = 0;
    gDialog.typeTimer = 0.0f;
    gDialog.active = true;
    gDialog.finished = false;
    if (line1 && line1[0]) { strncpy(gDialog.lines[gDialog.lineCount++], line1, DIALOG_LEN-1); }
    if (line2 && line2[0]) { strncpy(gDialog.lines[gDialog.lineCount++], line2, DIALOG_LEN-1); }
    if (line3 && line3[0]) { strncpy(gDialog.lines[gDialog.lineCount++], line3, DIALOG_LEN-1); }
    if (line4 && line4[0]) { strncpy(gDialog.lines[gDialog.lineCount++], line4, DIALOG_LEN-1); }
}

static int TotalDialogChars(void) {
    int total = 0;
    for (int i = 0; i < gDialog.lineCount; i++)
        total += (int)strlen(gDialog.lines[i]);
    return total;
}

static bool IsWalkable(Area area, int tx, int ty) {
    if (tx < 0 || ty < 0 || tx >= MAP_W || ty >= MAP_H) return false;
    int t = gMaps[area][ty][tx];
    return (t == 0 || t == 2 || t == 4);
}

static Spirit MakeWildSpirit(Area area) {
    Spirit s;
    switch(area) {
        case AREA_VILLAGE: s = gVillageSpirits[rand() % 5]; break;
        case AREA_FOREST:  s = gForestSpirits [rand() % 6]; break;
        default:           s = gRuinsSpirits  [rand() % 6]; break;
    }
    int var = (rand() % 5) - 2;
    s.hp = s.maxHp + var; s.maxHp = s.hp;
    InitSpiritSkills(&s);
    return s;
}

static Spirit MakeBoss(Area area) {
    Spirit b = {0};
    switch(area) {
        case AREA_VILLAGE:
            strcpy(b.name, "ELDER SPECTER");
            b.hp=b.maxHp=60; b.mp=b.maxMp=20;
            b.atk=10; b.def=5; b.spd=7; b.level=8;
            b.elem=ELEM_GHOST; b.greed=2; b.pride=9; b.pity=3;
            break;
        case AREA_FOREST:
            strcpy(b.name, "GREAT THORNLORD");
            b.hp=b.maxHp=90; b.mp=b.maxMp=16;
            b.atk=14; b.def=8; b.spd=6; b.level=14;
            b.elem=ELEM_BEAST; b.greed=5; b.pride=7; b.pity=2;
            break;
        default:
            strcpy(b.name, "KETHARA REVENANT");
            b.hp=b.maxHp=130; b.mp=b.maxMp=24;
            b.atk=18; b.def=10; b.spd=9; b.level=20;
            b.elem=ELEM_DARK; b.greed=1; b.pride=8; b.pity=5;
            break;
    }
    b.xp=0; b.alive=true;
    InitSpiritSkills(&b);
    return b;
}

// Grant XP to party after a battle victory; add level-up lines to battle log
static void GrantBattleXP(void) {
    int xpGain = gEnemy.level * 8;
    for (int i = 0; i < gPlayer.partyCount; i++) {
        Spirit* s = &gPlayer.party[i];
        s->xp += xpGain;
        char lm[DIALOG_LEN];
        snprintf(lm, DIALOG_LEN, "%s +%d XP", s->name, xpGain);
        AddBattleLog(lm);
        // Level up loop (can level more than once if XP surplus)
        while (s->xp >= s->level * 15) {
            s->xp -= s->level * 15;
            s->level++;
            s->atk   += 1 + rand()%2;
            s->def   += rand()%2;
            s->maxHp += 2 + rand()%3;
            s->maxMp += 1;
            s->hp     = s->maxHp;
            s->mp     = s->maxMp;
            InitSpiritSkills(s);
            snprintf(lm, DIALOG_LEN, ">>> %s Lv.%d! LEVEL UP! <<<", s->name, s->level);
            AddBattleLog(lm);
        }
    }
    // Restore MP on victory
    int mpBack = 3 + gPlayer.partyCount;
    gPlayer.mp += mpBack;
    if (gPlayer.mp > gPlayer.maxMp) gPlayer.mp = gPlayer.maxMp;
    // Clear in-battle stages (status persists until shrine rest)
    for (int i = 0; i < gPlayer.partyCount; i++) {
        gPlayer.party[i].atkStage = 0;
        gPlayer.party[i].defStage = 0;
    }
}

// ─────────────────────────────────────────────
//  Drawing helpers
// ─────────────────────────────────────────────
static void DrawPanel(int x, int y, int w, int h) {
    DrawRectangle(x, y, w, h, COL_PANEL);
    DrawRectangleLinesEx((Rectangle){(float)x,(float)y,(float)w,(float)h}, 2, COL_BORDER);
    DrawRectangleLinesEx((Rectangle){(float)(x+2),(float)(y+2),(float)(w-4),(float)(h-4)}, 1, (Color){60,40,100,120});
}

static void DrawBar(int x, int y, int w, int h, float pct, Color col) {
    DrawRectangle(x, y, w, h, (Color){30,20,50,200});
    int filled = (int)(w * pct);
    if (filled > 0) DrawRectangle(x, y, filled, h, col);
    DrawRectangleLinesEx((Rectangle){(float)x,(float)y,(float)w,(float)h}, 1, COL_BORDER);
}

static void DrawSpiritGlyph(int cx, int cy, int size, Spirit* s, float pulse) {
    Color ec = ElemColor(s->elem);
    float p = (float)sin(pulse) * 0.5f + 0.5f;
    int r = size/2;

    DrawCircleLines(cx, cy, r + 2 + (int)(p*4), (Color){ec.r,ec.g,ec.b,100});
    DrawCircleLines(cx, cy, r, ec);

    switch(s->elem) {
        case ELEM_FIRE:
            for(int i=0;i<6;i++){
                float a=i*60.0f*DEG2RAD+pulse*0.5f;
                DrawLineEx(
                    (Vector2){cx+cosf(a)*r*0.3f,cy+sinf(a)*r*0.3f},
                    (Vector2){cx+cosf(a)*r*0.9f,cy+sinf(a)*r*0.9f},
                    2,ec);
            }
            DrawCircle(cx,cy,(int)(r*0.2f),ec);
            break;
        case ELEM_WATER:
            DrawCircleLines(cx,cy,(int)(r*0.5f),ec);
            DrawCircleLines(cx,cy,(int)(r*0.3f),ec);
            break;
        case ELEM_EARTH:
            DrawRectangleLinesEx((Rectangle){(float)(cx-r/2),(float)(cy-r/2),(float)r,(float)r},2,ec);
            break;
        case ELEM_WIND:
            for(int i=0;i<8;i++){
                float a=i*45.0f*DEG2RAD+pulse;
                float a2=a+0.5f;
                DrawLineEx(
                    (Vector2){cx+cosf(a)*r*0.2f,cy+sinf(a)*r*0.2f},
                    (Vector2){cx+cosf(a2)*r*0.8f,cy+sinf(a2)*r*0.8f},
                    1.5f,ec);
            }
            break;
        case ELEM_DARK:
            for(int i=0;i<5;i++){
                float a=i*72.0f*DEG2RAD-90.0f*DEG2RAD+pulse*0.3f;
                float a2=(i+2)*72.0f*DEG2RAD-90.0f*DEG2RAD+pulse*0.3f;
                DrawLineEx(
                    (Vector2){cx+cosf(a)*r*0.8f,cy+sinf(a)*r*0.8f},
                    (Vector2){cx+cosf(a2)*r*0.8f,cy+sinf(a2)*r*0.8f},
                    2,ec);
            }
            break;
        case ELEM_HOLY:
            DrawLineEx((Vector2){(float)cx,(float)(cy-(int)(r*0.8f))},(Vector2){(float)cx,(float)(cy+(int)(r*0.8f))},2,ec);
            DrawLineEx((Vector2){(float)(cx-(int)(r*0.8f)),(float)cy},(Vector2){(float)(cx+(int)(r*0.8f)),(float)cy},2,ec);
            DrawCircleLines(cx,cy,(int)(r*0.4f),ec);
            break;
        case ELEM_BEAST:
            for(int i=-1;i<=1;i++)
                DrawLineEx(
                    (Vector2){(float)(cx+i*10-(int)(r*0.4f)),(float)(cy-(int)(r*0.7f))},
                    (Vector2){(float)(cx+i*10+(int)(r*0.4f)),(float)(cy+(int)(r*0.7f))},
                    2,ec);
            break;
        case ELEM_GHOST:
            for(int i=0;i<12;i++){
                float a=i*30.0f*DEG2RAD+pulse;
                float dist=r*(0.4f+0.4f*(float)sinf(i*0.8f));
                DrawPixel(cx+(int)(cosf(a)*dist),cy+(int)(sinf(a)*dist),ec);
                DrawPixel(cx+(int)(cosf(a)*dist)+1,cy+(int)(sinf(a)*dist),ec);
            }
            break;
        default: break;
    }
    DrawText(s->name, cx - MeasureText(s->name,9)/2, cy+r+6, 9, ec);

    // status badge
    if (s->status != STATUS_NONE) {
        DrawText(StatusName(s->status), cx - MeasureText(StatusName(s->status),9)/2, cy+r+18, 9, StatusColor(s->status));
    }
}

static void DrawPlayerSprite(int px, int py, int frame) {
    DrawRectangle(px-5, py-14, 10, 14, COL_PLAYER);
    DrawCircle(px, py-18, 6, COL_PLAYER);
    DrawLineEx((Vector2){(float)(px-8),(float)(py-24)},(Vector2){(float)(px-8),(float)(py+2)},2,(Color){180,160,80,255});
    DrawCircle(px-8,py-26,4,COL_ACCENT);
    if (frame==0){
        DrawRectangle(px-5,py,4,8,COL_PLAYER);
        DrawRectangle(px+1,py,4,8,COL_PLAYER);
    } else {
        DrawRectangle(px-5,py,4,10,COL_PLAYER);
        DrawRectangle(px+1,py-2,4,10,COL_PLAYER);
    }
}

// ─────────────────────────────────────────────
//  Init
// ─────────────────────────────────────────────
static void InitGame(void) {
    srand((unsigned)time(NULL));

    gPlayer.x = 6; gPlayer.y = 8;
    gPlayer.hp = gPlayer.maxHp = 40;
    gPlayer.mp = gPlayer.maxMp = 30;
    gPlayer.gold = 0;
    gPlayer.partyCount = 0;
    gPlayer.currentArea = AREA_VILLAGE;
    gPlayer.facing = 0;
    gPlayer.currentSpirit = 0;

    gScene = SCENE_OVERWORLD;
    gEncounterCooldown = 2.0f;
    gStepCounter = 0;
    gBattleLogCount = 0;
    gBattleLogHead  = 0;
    memset(gBossDefeated, 0, sizeof(gBossDefeated));

    DialogSet(
        "Welcome, young shaman.",
        "Bind spirits to fight alongside you!",
        "Shrines restore HP/MP after clearing each area.",
        "[Z] interact  [Arrows] move  [X] spirit list");
}

// ─────────────────────────────────────────────
//  Start battle
// ─────────────────────────────────────────────
static void StartBattle(Spirit enemy, bool isBoss) {
    gEnemy        = enemy;
    gPhase        = BATTLE_PLAYER_TURN;
    gBattleCursor = 0;
    gSpiritCursor = 0;
    gSpiritActionCursor = 0;
    gScene        = SCENE_BATTLE;
    gCanCapture   = false;
    gNegotiateResult = 0;
    gBattleAnim   = 0.0f;
    gBossTriggered = isBoss;
    gSelected     = ACTION_NONE;
    gBattleLogCount = 0;
    gBattleLogHead  = 0;

    // Reset in-battle stages for party (status effects persist until shrine)
    for (int i = 0; i < gPlayer.partyCount; i++) {
        gPlayer.party[i].currentMp = gPlayer.party[i].maxMp;
        gPlayer.party[i].atkStage  = 0;
        gPlayer.party[i].defStage  = 0;
    }

    char msg1[DIALOG_LEN], msg2[DIALOG_LEN];
    snprintf(msg1, DIALOG_LEN, "A wild %s appeared!", enemy.name);
    snprintf(msg2, DIALOG_LEN, "[%s] HP:%d  Elem:%s",
        enemy.name, enemy.hp, ElemName(enemy.elem));
    DialogSet(msg1, msg2, "What will you do?", "");
    AddBattleLog(msg1);
}

// ─────────────────────────────────────────────
//  Negotiate
// ─────────────────────────────────────────────
static void DoNegotiate(BattleAction act) {
    int mpCost = 0;
    char msg[DIALOG_LEN];
    float chance = 0.0f;

    switch(act) {
        case ACTION_BIND:
            mpCost = 8;
            if (gPlayer.mp < mpCost) { DialogSet("Not enough MP!", "", "", ""); gPhase=BATTLE_PLAYER_TURN; return; }
            gPlayer.mp -= mpCost;
            chance = 0.2f + gEnemy.pride * 0.06f;
            if ((float)gEnemy.hp / gEnemy.maxHp > 0.5f) chance *= 0.4f;
            if ((float)rand()/RAND_MAX < chance) {
                gNegotiateResult = 1;
                snprintf(msg, DIALOG_LEN, "%s feels your spiritual dominance!", gEnemy.name);
            } else {
                gNegotiateResult = 2;
                snprintf(msg, DIALOG_LEN, "%s resists your binding!", gEnemy.name);
            }
            break;
        case ACTION_PLEAD:
            mpCost = 4;
            if (gPlayer.mp < mpCost) { DialogSet("Not enough MP!", "", "", ""); gPhase=BATTLE_PLAYER_TURN; return; }
            gPlayer.mp -= mpCost;
            chance = 0.15f + gEnemy.pity * 0.07f;
            if ((float)gEnemy.hp / gEnemy.maxHp > 0.7f) chance *= 0.3f;
            if ((float)rand()/RAND_MAX < chance) {
                gNegotiateResult = 1;
                snprintf(msg, DIALOG_LEN, "%s takes pity on you...", gEnemy.name);
            } else {
                gNegotiateResult = 2;
                snprintf(msg, DIALOG_LEN, "%s ignores your pleas!", gEnemy.name);
            }
            break;
        case ACTION_BRIBE:
            if (gPlayer.gold < 10) { DialogSet("No gold to offer!", "", "", ""); gPhase=BATTLE_PLAYER_TURN; return; }
            mpCost = 2;
            gPlayer.mp -= mpCost;
            gPlayer.gold -= 10;
            chance = 0.2f + gEnemy.greed * 0.08f;
            if ((float)rand()/RAND_MAX < chance) {
                gNegotiateResult = 1;
                snprintf(msg, DIALOG_LEN, "%s accepts your offering!", gEnemy.name);
            } else {
                gNegotiateResult = 2;
                snprintf(msg, DIALOG_LEN, "%s takes the gold... and attacks!", gEnemy.name);
                int dmg = gEnemy.atk - gPlayer.partyCount;
                if (dmg < 1) dmg = 1;
                gPlayer.hp -= dmg;
                if (gPlayer.hp < 0) gPlayer.hp = 0;
            }
            break;
        default: break;
    }

    AddBattleLog(msg);
    if (gNegotiateResult == 1) {
        if (gPlayer.partyCount < MAX_SPIRITS) {
            InitSpiritSkills(&gEnemy);
            gPlayer.party[gPlayer.partyCount++] = gEnemy;
            char msg2[DIALOG_LEN];
            snprintf(msg2, DIALOG_LEN, "%s joined your party! (%d/6)", gEnemy.name, gPlayer.partyCount);
            DialogSet(msg, msg2, "Spirit bound!", "");
            AddBattleLog(msg2);
        } else {
            DialogSet(msg, "Party full! Spirit could not join.", "", "");
        }
        gPhase = BATTLE_RESULT;
    } else {
        DialogSet(msg, "", "", "");
        gPhase = BATTLE_ENEMY_TURN;
    }
    gNegotiateAnim = 0.0f;
}

// ─────────────────────────────────────────────
//  Enemy AI attack
// ─────────────────────────────────────────────
static void DoEnemyTurn(void) {
    // Burn chip-damage at turn start
    if (gEnemy.status == STATUS_BURN) {
        ApplyBurnDamage(&gEnemy);
        if (gEnemy.hp <= 0) {
            int earned = 5 + rand()%10;
            gPlayer.gold += earned;
            char km[DIALOG_LEN];
            snprintf(km, DIALOG_LEN, "%s burned out. +%d gold.", gEnemy.name, earned);
            DialogSet(km, "", "", "");
            AddBattleLog(km);
            gPhase = BATTLE_RESULT;
            gNegotiateResult = -1;
            GrantBattleXP();
            return;
        }
    }

    // Paralyze skip
    if (gEnemy.status == STATUS_PARALYZE && (float)rand()/RAND_MAX < 0.35f) {
        char pm[DIALOG_LEN];
        snprintf(pm, DIALOG_LEN, "%s is paralyzed and can't move!", gEnemy.name);
        DialogSet(pm, "", "", "");
        AddBattleLog(pm);
        gPhase = BATTLE_PLAYER_TURN;
        gBattleAnim = 0.0f;
        return;
    }

    int action = rand() % 3;
    int dmg;

    if (action == 0 && gEnemy.skill2.type != SKILL_NONE && gEnemy.currentMp >= gEnemy.skill2.mpCost) {
        SpiritSkill* sk = &gEnemy.skill2;
        gEnemy.currentMp -= sk->mpCost;
        char msg[DIALOG_LEN];

        if (sk->type == SKILL_ELEMENTAL_BLAST || sk->type == SKILL_BASIC_ATTACK) {
            // Treat player as a no-stage target
            float mult = StageMultiplier(gEnemy.atkStage);
            dmg = (int)(sk->power * mult);
            dmg += (rand()%3)-1;
            if (dmg < 1) dmg = 1;
            gPlayer.hp -= dmg;
            if (gPlayer.hp < 0) gPlayer.hp = 0;
            snprintf(msg, DIALOG_LEN, "%s: %s — -%d HP!", gEnemy.name, sk->name, dmg);
            gBattleAnimHitPlayer = true;
        } else if (sk->type == SKILL_BUFF) {
            int* stage = (sk->buffTarget == 0) ? &gEnemy.atkStage : &gEnemy.defStage;
            *stage += sk->power;
            if (*stage > 3) *stage = 3;
            snprintf(msg, DIALOG_LEN, "%s: %s — %s rose!",
                gEnemy.name, sk->name, sk->buffTarget==0?"ATK":"DEF");
        } else if (sk->type == SKILL_DRAIN) {
            float mult = StageMultiplier(gEnemy.atkStage);
            dmg = (int)(sk->power * mult);
            if (dmg < 1) dmg = 1;
            gPlayer.hp -= dmg;
            if (gPlayer.hp < 0) gPlayer.hp = 0;
            gEnemy.hp += dmg/2;
            if (gEnemy.hp > gEnemy.maxHp) gEnemy.hp = gEnemy.maxHp;
            snprintf(msg, DIALOG_LEN, "%s drained %d HP from you!", gEnemy.name, dmg);
            gBattleAnimHitPlayer = true;
        } else {
            // Fallback basic
            dmg = gEnemy.atk - (gPlayer.partyCount/2);
            if (dmg < 1) dmg = 1;
            gPlayer.hp -= dmg;
            if (gPlayer.hp < 0) gPlayer.hp = 0;
            snprintf(msg, DIALOG_LEN, "%s attacks! -%d HP", gEnemy.name, dmg);
            gBattleAnimHitPlayer = true;
        }

        DialogSet(msg, "", "", "");
        AddBattleLog(msg);

        // Enemy may apply status on hit
        // (burn/paralyze can't be applied TO the player in this version)

    } else {
        // Basic attack scaled by stages
        float mult = StageMultiplier(gEnemy.atkStage);
        dmg = (int)((gEnemy.atk - gPlayer.partyCount/2) * mult);
        dmg += (rand()%3)-1;
        if (dmg < 1) dmg = 1;
        gPlayer.hp -= dmg;
        if (gPlayer.hp < 0) gPlayer.hp = 0;
        char msg[DIALOG_LEN];
        snprintf(msg, DIALOG_LEN, "%s attacks! -%d HP", gEnemy.name, dmg);
        DialogSet(msg, "", "", "");
        AddBattleLog(msg);
        gBattleAnimHitPlayer = true;
    }

    gPhase = BATTLE_PLAYER_TURN;
    gBattleAnim = 0.0f;
}

// ─────────────────────────────────────────────
//  Update Battle
// ─────────────────────────────────────────────
static void UpdateBattle(float dt) {
    gBattleAnim += dt;

    if (gPlayer.hp <= 0) { gScene = SCENE_GAMEOVER; return; }

    // Dialog handler — Z skips typewriter; second Z dismisses
    if (gDialog.active) {
        int total = TotalDialogChars();
        if (IsKeyPressed(KEY_Z) && !gDialog.finished) {
            gDialog.displayedChars = total;
            gDialog.finished = true;
        }
        gDialog.typeTimer += dt;
        if (gDialog.typeTimer > 0.012f) {
            gDialog.typeTimer = 0;
            if (gDialog.displayedChars < total) gDialog.displayedChars++;
            else gDialog.finished = true;
        }
        if (gDialog.finished && IsKeyPressed(KEY_Z)) {
            gDialog.active = false;
            if (gPhase == BATTLE_RESULT) {
                if (!gBossTriggered && gNegotiateResult == 1) {
                    gScene = SCENE_OVERWORLD;
                } else if (gNegotiateResult == 2) {
                    gPhase = BATTLE_PLAYER_TURN;
                } else if (gNegotiateResult == -1) {
                    if (gBossTriggered) gBossDefeated[gPlayer.currentArea] = true;
                    gScene = SCENE_OVERWORLD;
                } else {
                    gScene = SCENE_OVERWORLD;
                }
            } else if (gPhase == BATTLE_ENEMY_TURN) {
                gPhase = BATTLE_PLAYER_TURN;
                gBattleAnimHitPlayer = false;
            } else if (gPhase == BATTLE_SPIRIT_ACTION) {
                gPhase = BATTLE_ENEMY_TURN;
            }
        }
        return;
    }

    if (gPhase == BATTLE_PLAYER_TURN) {
        int numActions = 6;
        if (IsKeyPressed(KEY_UP))   gBattleCursor = (gBattleCursor-1+numActions)%numActions;
        if (IsKeyPressed(KEY_DOWN)) gBattleCursor = (gBattleCursor+1)%numActions;

        if (IsKeyPressed(KEY_Z)) {
            switch(gBattleCursor) {
                case 0: { // Strike
                    int dmg = 5 + gPlayer.partyCount * 2 + (rand()%4);
                    gEnemy.hp -= dmg;
                    if (gEnemy.hp < 0) gEnemy.hp = 0;
                    char msg[DIALOG_LEN];
                    snprintf(msg, DIALOG_LEN, "You strike! -%d HP to %s", dmg, gEnemy.name);
                    DialogSet(msg, "", "", "");
                    AddBattleLog(msg);
                    gBattleAnimHitEnemy = true;
                    gBattleAnim = 0.0f;
                    if (gEnemy.hp <= 0) {
                        int earned = 5 + rand()%10;
                        gPlayer.gold += earned;
                        char m2[DIALOG_LEN];
                        snprintf(m2, DIALOG_LEN, "%s dissipated. +%d gold.", gEnemy.name, earned);
                        DialogSet(msg, m2, "Check battle log for XP!", "");
                        AddBattleLog(m2);
                        gPhase = BATTLE_RESULT;
                        gNegotiateResult = -1;
                        GrantBattleXP();
                    } else {
                        gPhase = BATTLE_ENEMY_TURN;
                    }
                    break;
                }
                case 1: // Spirit Attack
                    if (gPlayer.partyCount == 0) {
                        DialogSet("No spirits bound yet!", "Capture a spirit first!", "", "");
                        break;
                    }
                    gPhase = BATTLE_SPIRIT_SELECT;
                    break;
                case 2: DoNegotiate(ACTION_BIND);  break;
                case 3: DoNegotiate(ACTION_PLEAD); break;
                case 4: DoNegotiate(ACTION_BRIBE); break;
                case 5:
                    DialogSet("You escaped!", "", "", "");
                    AddBattleLog("Player fled.");
                    gPhase = BATTLE_RESULT;
                    gNegotiateResult = -1;
                    break;
            }
        }
    }
    else if (gPhase == BATTLE_SPIRIT_SELECT) {
        if (IsKeyPressed(KEY_UP))
            gSpiritCursor = (gSpiritCursor - 1 + gPlayer.partyCount) % gPlayer.partyCount;
        if (IsKeyPressed(KEY_DOWN))
            gSpiritCursor = (gSpiritCursor + 1) % gPlayer.partyCount;
        if (IsKeyPressed(KEY_Z)) { gPhase = BATTLE_SPIRIT_ACTION; gSpiritActionCursor = 0; }
        if (IsKeyPressed(KEY_X)) gPhase = BATTLE_PLAYER_TURN;
    }
    else if (gPhase == BATTLE_SPIRIT_ACTION) {
        Spirit* cur = &gPlayer.party[gSpiritCursor];
        int numAct = (cur->skill2.type != SKILL_NONE) ? 2 : 1;

        if (IsKeyPressed(KEY_UP))   gSpiritActionCursor = (gSpiritActionCursor-1+numAct)%numAct;
        if (IsKeyPressed(KEY_DOWN)) gSpiritActionCursor = (gSpiritActionCursor+1)%numAct;

        if (IsKeyPressed(KEY_Z)) {
            // Burn tick at start of spirit's action
            if (cur->status == STATUS_BURN) {
                ApplyBurnDamage(cur);
            }
            // Paralyze check
            bool paralyzed = (cur->status == STATUS_PARALYZE && (float)rand()/RAND_MAX < 0.35f);
            if (paralyzed) {
                char pm[DIALOG_LEN];
                snprintf(pm, DIALOG_LEN, "%s is paralyzed and can't move!", cur->name);
                DialogSet(pm, "", "", "");
                AddBattleLog(pm);
                gPhase = BATTLE_ENEMY_TURN;
            } else if (gSpiritActionCursor == 0) {
                // Basic attack
                int damage = PerformSpiritAttack(cur, &gEnemy, cur->atk);
                char msg[DIALOG_LEN];
                snprintf(msg, DIALOG_LEN, "%s attacks! %d dmg!", cur->name, damage);
                DialogSet(msg, "", "", "");
                AddBattleLog(msg);
                gBattleAnimHitEnemy = true;
                gBattleAnim = 0.0f;
                if (gEnemy.hp <= 0) {
                    int earned = 5 + rand()%10;
                    gPlayer.gold += earned;
                    char m2[DIALOG_LEN];
                    snprintf(m2, DIALOG_LEN, "%s dissipated. +%d gold.", gEnemy.name, earned);
                    DialogSet(msg, m2, "Check log for XP!", "");
                    AddBattleLog(m2);
                    gPhase = BATTLE_RESULT;
                    gNegotiateResult = -1;
                    GrantBattleXP();
                } else {
                    gPhase = BATTLE_ENEMY_TURN;
                }
            } else {
                // Special skill
                bool ko = PerformSpiritSkill(cur, &gEnemy, &cur->skill2);
                gBattleAnim = 0.0f;
                if (ko) {
                    int earned = 5 + rand()%10;
                    gPlayer.gold += earned;
                    char m2[DIALOG_LEN];
                    snprintf(m2, DIALOG_LEN, "%s dissipated. +%d gold.", gEnemy.name, earned);
                    AddBattleLog(m2);
                    gPhase = BATTLE_RESULT;
                    gNegotiateResult = -1;
                    GrantBattleXP();
                } else {
                    gPhase = BATTLE_ENEMY_TURN;
                }
            }
        }
        if (IsKeyPressed(KEY_X)) gPhase = BATTLE_SPIRIT_SELECT;
    }
    else if (gPhase == BATTLE_ENEMY_TURN) {
        DoEnemyTurn();
    }
}

// ─────────────────────────────────────────────
//  Update Overworld
// ─────────────────────────────────────────────
static void UpdateOverworld(float dt) {
    gEncounterCooldown -= dt;
    gPlayer.animTimer += dt;
    if (gPlayer.animTimer > 0.18f) {
        gPlayer.animTimer = 0;
        gPlayer.animFrame ^= 1;
    }

    if (gDialog.active) {
        int total = TotalDialogChars();
        if (IsKeyPressed(KEY_Z) && !gDialog.finished) {
            gDialog.displayedChars = total;
            gDialog.finished = true;
        }
        gDialog.typeTimer += dt;
        if (gDialog.typeTimer > 0.012f) {
            gDialog.typeTimer = 0;
            if (gDialog.displayedChars < total) gDialog.displayedChars++;
            else gDialog.finished = true;
        }
        if (gDialog.finished && IsKeyPressed(KEY_Z))
            gDialog.active = false;
        return;
    }

    if (IsKeyPressed(KEY_X)) { gScene = SCENE_SPIRIT_LIST; return; }

    int dx = 0, dy = 0;
    if (IsKeyPressed(KEY_LEFT))  { dx=-1; gPlayer.facing=2; }
    if (IsKeyPressed(KEY_RIGHT)) { dx= 1; gPlayer.facing=3; }
    if (IsKeyPressed(KEY_UP))    { dy=-1; gPlayer.facing=1; }
    if (IsKeyPressed(KEY_DOWN))  { dy= 1; gPlayer.facing=0; }

    if (dx != 0 || dy != 0) {
        int nx = gPlayer.x + dx;
        int ny = gPlayer.y + dy;
        if (IsWalkable(gPlayer.currentArea, nx, ny)) {
            gPlayer.x = nx; gPlayer.y = ny;
            gStepCounter++;

            // MP regen every 5 steps
            if (gStepCounter % 5 == 0 && gPlayer.mp < gPlayer.maxMp)
                gPlayer.mp++;

            int tile = gMaps[gPlayer.currentArea][ny][nx];

            // Area transitions
            if (ny >= MAP_H-2 && nx >= 11 && nx <= 14) {
                if (gPlayer.currentArea == AREA_VILLAGE && !gBossDefeated[AREA_VILLAGE]) {
                    DialogSet("The forest path is sealed.", "Defeat the Elder Specter first.", "", "");
                    gPlayer.y = ny-1;
                } else if (gPlayer.currentArea == AREA_VILLAGE) {
                    gPlayer.currentArea = AREA_FOREST;
                    gPlayer.x = 12; gPlayer.y = 1;
                    DialogSet("You enter Thornwood Forest.", "Spirits here are wilder.", "", "");
                } else if (gPlayer.currentArea == AREA_FOREST && !gBossDefeated[AREA_FOREST]) {
                    DialogSet("The ruin gate is sealed.", "Defeat the Great Thornlord first.", "", "");
                    gPlayer.y = ny-1;
                } else if (gPlayer.currentArea == AREA_FOREST) {
                    gPlayer.currentArea = AREA_RUINS;
                    gPlayer.x = 7; gPlayer.y = 1;
                    DialogSet("You enter the Ruins of Kethara.", "Ancient spirits dwell here.", "", "");
                }
            }
            if (ny <= 0 && nx >= 6 && nx <= 8) {
                if (gPlayer.currentArea == AREA_FOREST) {
                    gPlayer.currentArea = AREA_VILLAGE;
                    gPlayer.x = 12; gPlayer.y = MAP_H-3;
                    DialogSet("You return to Ashenveil Village.", "", "", "");
                } else if (gPlayer.currentArea == AREA_RUINS) {
                    gPlayer.currentArea = AREA_FOREST;
                    gPlayer.x = 7; gPlayer.y = MAP_H-3;
                    DialogSet("You return to Thornwood Forest.", "", "", "");
                }
            }

            // Special tile: boss or shrine
            if (tile == 4) {
                if (!gBossDefeated[gPlayer.currentArea]) {
                    gBoss = MakeBoss(gPlayer.currentArea);
                    char msg[DIALOG_LEN];
                    snprintf(msg, DIALOG_LEN, "A powerful spirit stirs!");
                    DialogSet(msg, gBoss.name, "approaches...", "");
                    StartBattle(gBoss, true);
                    return;
                } else {
                    // Sacred shrine: restore HP, MP, and cure party status
                    bool needHeal = (gPlayer.hp < gPlayer.maxHp || gPlayer.mp < gPlayer.maxMp);
                    for (int i = 0; i < gPlayer.partyCount && !needHeal; i++)
                        if (gPlayer.party[i].status != STATUS_NONE) needHeal = true;
                    if (needHeal) {
                        gPlayer.hp = gPlayer.maxHp;
                        gPlayer.mp = gPlayer.maxMp;
                        for (int i = 0; i < gPlayer.partyCount; i++) {
                            gPlayer.party[i].status   = STATUS_NONE;
                            gPlayer.party[i].currentMp = gPlayer.party[i].maxMp;
                        }
                        DialogSet("Sacred shrine!", "HP, MP and status fully restored.", "", "");
                    }
                }
            }

            // Random encounter
            if (tile == 0 && gEncounterCooldown <= 0.0f) {
                int rate = (gPlayer.currentArea == AREA_VILLAGE) ? 10 :
                           (gPlayer.currentArea == AREA_FOREST)  ? 7 : 5;
                if (rand() % rate == 0) {
                    Spirit w = MakeWildSpirit(gPlayer.currentArea);
                    gEncounterCooldown = 3.0f;
                    StartBattle(w, false);
                    return;
                }
            }

            // Win condition
            if (gBossDefeated[0] && gBossDefeated[1] && gBossDefeated[2] &&
                gPlayer.currentArea == AREA_RUINS)
                gScene = SCENE_WIN;
        }
    }

    // Smooth camera
    float targetX = gPlayer.x * TILE_SIZE - SCREEN_W/2 + TILE_SIZE/2;
    float targetY = gPlayer.y * TILE_SIZE - SCREEN_H/2 + TILE_SIZE/2;
    gCamX += (targetX - gCamX) * dt * 8.0f;
    gCamY += (targetY - gCamY) * dt * 8.0f;
    float maxCX = MAP_W*TILE_SIZE - SCREEN_W;
    float maxCY = MAP_H*TILE_SIZE - SCREEN_H;
    if (gCamX < 0) gCamX = 0; if (gCamY < 0) gCamY = 0;
    if (gCamX > maxCX) gCamX = maxCX;
    if (gCamY > maxCY) gCamY = maxCY;
}

// ─────────────────────────────────────────────
//  Draw Overworld
// ─────────────────────────────────────────────
static void DrawOverworld(void) {
    Area a = gPlayer.currentArea;
    for (int ty = 0; ty < MAP_H; ty++) {
        for (int tx = 0; tx < MAP_W; tx++) {
            int t = gMaps[a][ty][tx];
            int sx = tx*TILE_SIZE - (int)gCamX;
            int sy = ty*TILE_SIZE - (int)gCamY;
            if (sx > SCREEN_W || sy > SCREEN_H || sx+TILE_SIZE<0 || sy+TILE_SIZE<0) continue;
            Color col;
            switch(t) {
                case 0: col = (a==AREA_RUINS) ? COL_RUIN : COL_GRASS; break;
                case 1: col = (a==AREA_RUINS) ? (Color){40,30,55,255} : COL_TREE; break;
                case 2: col = COL_PATH; break;
                case 3: col = COL_WATER_TILE; break;
                case 4: col = COL_SPECIAL; break;
                default: col = COL_BG;
            }
            DrawRectangle(sx, sy, TILE_SIZE, TILE_SIZE, col);
            DrawRectangleLinesEx((Rectangle){(float)sx,(float)sy,TILE_SIZE,TILE_SIZE},1,(Color){0,0,0,40});
            if (t == 4) {
                float glow = (float)fabs(sin(GetTime()*2.0f));
                DrawRectangle(sx,sy,TILE_SIZE,TILE_SIZE,
                    (Color){COL_SPECIAL.r,COL_SPECIAL.g,COL_SPECIAL.b,(unsigned char)(glow*80)});
                // Show shrine icon if boss defeated
                if (gBossDefeated[a])
                    DrawText("+", sx+TILE_SIZE/2-4, sy+TILE_SIZE/2-6, 12, COL_HOLY);
            }
            if (t == 1 && a == AREA_RUINS)
                DrawLineEx((Vector2){(float)(sx+4),(float)(sy+4)},(Vector2){(float)(sx+TILE_SIZE-4),(float)(sy+TILE_SIZE-4)},1,(Color){80,60,110,80});
        }
    }

    int px = gPlayer.x * TILE_SIZE - (int)gCamX + TILE_SIZE/2;
    int py = gPlayer.y * TILE_SIZE - (int)gCamY + TILE_SIZE - 6;
    DrawPlayerSprite(px, py, gPlayer.animFrame);

    DrawPanel(4, 4, 220, 54);
    const char* areaNames[] = {"Ashenveil Village","Thornwood Forest","Ruins of Kethara"};
    DrawText(areaNames[gPlayer.currentArea], 12, 8, 10, COL_TEXT_DIM);
    DrawText("HP", 12, 22, 10, COL_TEXT);
    DrawBar(32, 22, 130, 10, (float)gPlayer.hp/gPlayer.maxHp,
        ((float)gPlayer.hp/gPlayer.maxHp < 0.3f) ? COL_HP_LOW : COL_HP_BAR);
    DrawText(TextFormat("%d/%d", gPlayer.hp, gPlayer.maxHp), 168, 22, 9, COL_TEXT_DIM);
    DrawText("MP", 12, 36, 10, COL_ACCENT);
    DrawBar(32, 36, 130, 10, (float)gPlayer.mp/gPlayer.maxMp, COL_MP_BAR);
    DrawText(TextFormat("%d/%d", gPlayer.mp, gPlayer.maxMp), 168, 36, 9, COL_TEXT_DIM);

    DrawPanel(SCREEN_W-130, 4, 126, 14 + gPlayer.partyCount*18);
    DrawText(TextFormat("SPIRITS %d/6", gPlayer.partyCount), SCREEN_W-124, 8, 9, COL_TEXT_DIM);
    for (int i = 0; i < gPlayer.partyCount; i++) {
        Spirit* s = &gPlayer.party[i];
        Color ec = ElemColor(s->elem);
        DrawRectangle(SCREEN_W-124, 20+i*18, 6, 12, ec);
        DrawText(s->name, SCREEN_W-115, 20+i*18, 9, COL_TEXT);
        if (s->status != STATUS_NONE)
            DrawText(StatusName(s->status), SCREEN_W-50, 20+i*18, 7, StatusColor(s->status));
    }

    DrawPanel(4, SCREEN_H-26, 100, 22);
    DrawText(TextFormat("G: %d", gPlayer.gold), 10, SCREEN_H-22, 11, COL_HOLY);
    DrawText("[Arrows] Move  [Z] Interact  [X] Spirits", 4, SCREEN_H-14, 9, COL_TEXT_DIM);

    for (int i = 0; i < AREA_COUNT; i++) {
        if (gBossDefeated[i]) {
            const char* bnames[] = {"Specter","Thornlord","Revenant"};
            DrawText(TextFormat("[%s SEALED]", bnames[i]),
                SCREEN_W-130, SCREEN_H-18-i*13, 8, COL_ACCENT);
        }
    }

    if (gDialog.active) {
        int bx=60, by=SCREEN_H-130, bw=SCREEN_W-120, bh=110;
        DrawPanel(bx, by, bw, bh);
        DrawRectangleLinesEx((Rectangle){(float)(bx+3),(float)(by+3),(float)(bw-6),(float)(bh-6)},1,COL_BORDER2);
        int chars = gDialog.displayedChars;
        int y = by+12;
        for (int i = 0; i < gDialog.lineCount; i++) {
            int len = (int)strlen(gDialog.lines[i]);
            if (chars <= 0) break;
            int show = (chars >= len) ? len : chars;
            chars -= len;
            char tmp[DIALOG_LEN+1];
            strncpy(tmp, gDialog.lines[i], show); tmp[show]=0;
            DrawText(tmp, bx+12, y, 13, COL_TEXT);
            y += 22;
        }
        if (gDialog.finished) {
            float blink = (float)fabs(sin(GetTime()*4));
            DrawText("[Z]", bx+bw-32, by+bh-18, 10,
                (Color){COL_ACCENT.r,COL_ACCENT.g,COL_ACCENT.b,(unsigned char)(blink*200+55)});
        }
    }
}

// ─────────────────────────────────────────────
//  Draw Battle
// ─────────────────────────────────────────────
static void DrawBattle(void) {
    // Background gradient
    for (int y = 0; y < SCREEN_H; y++) {
        float t = (float)y/SCREEN_H;
        DrawRectangle(0,y,SCREEN_W,1,(Color){
            (unsigned char)(12+t*8),(unsigned char)(5+t*5),(unsigned char)(20+t*20),255});
    }

    // Mystic rune pattern
    float pulse = (float)GetTime();
    for (int i = 0; i < 8; i++) {
        float a = i*45.0f*DEG2RAD + pulse*0.1f;
        int rx = SCREEN_W/2 + (int)(cosf(a)*260);
        int ry = SCREEN_H/2 + (int)(sinf(a)*180);
        DrawCircleLines(rx,ry,30+(int)(sinf(pulse+i)*8),(Color){60,30,100,60});
    }
    DrawCircleLines(SCREEN_W/2, SCREEN_H/2, 220, (Color){60,30,100,40});
    DrawCircleLines(SCREEN_W/2, SCREEN_H/2, 180, (Color){80,40,120,30});

    // Enemy spirit
    {
        float hitShake = (gBattleAnimHitEnemy && gBattleAnim < 0.3f) ? sinf(gBattleAnim*40)*5 : 0;
        int ex = SCREEN_W - 220 + (int)hitShake;
        DrawSpiritGlyph(ex, 160, 80, &gEnemy, pulse);

        DrawPanel(SCREEN_W-290, 20, 260, 80);
        DrawText(gEnemy.name, SCREEN_W-284, 24, 14, ElemColor(gEnemy.elem));
        DrawText(TextFormat("Lv.%d  [%s]", gEnemy.level, ElemName(gEnemy.elem)), SCREEN_W-284, 40, 10, COL_TEXT_DIM);
        DrawText("HP", SCREEN_W-284, 56, 10, COL_TEXT);
        DrawBar(SCREEN_W-264, 56, 200, 10, (float)gEnemy.hp/gEnemy.maxHp,
            ((float)gEnemy.hp/gEnemy.maxHp < 0.3f) ? COL_HP_LOW : COL_HP_BAR);
        DrawText(TextFormat("%d/%d",gEnemy.hp,gEnemy.maxHp), SCREEN_W-58, 56, 9, COL_TEXT_DIM);
        DrawText(TextFormat("MP:%d/%d  ATK%+d  DEF%+d",
            gEnemy.currentMp, gEnemy.maxMp, gEnemy.atkStage, gEnemy.defStage),
            SCREEN_W-284, 70, 8, COL_TEXT_DIM);
        // Status badge
        if (gEnemy.status != STATUS_NONE)
            DrawText(StatusName(gEnemy.status), SCREEN_W-60, 24, 10, StatusColor(gEnemy.status));
    }

    // Battle log panel (right, below enemy stats)
    {
        int lx = SCREEN_W-290, ly = 108, lw = 260, lh = BATTLE_LOG_SIZE*14 + 14;
        DrawPanel(lx, ly, lw, lh);
        DrawText("LOG", lx+8, ly+4, 8, COL_TEXT_DIM);
        for (int i = 0; i < gBattleLogCount; i++) {
            int idx = (gBattleLogHead - gBattleLogCount + i + BATTLE_LOG_SIZE) % BATTLE_LOG_SIZE;
            Color c = (i == gBattleLogCount-1) ? COL_TEXT : COL_TEXT_DIM;
            // Clamp message to panel width
            char tmp[38]; strncpy(tmp, gBattleLog[idx], 37); tmp[37]='\0';
            DrawText(tmp, lx+8, ly+14+i*14, 8, c);
        }
    }

    // Player shaman sprite
    {
        float hitShake = (gBattleAnimHitPlayer && gBattleAnim < 0.3f) ? sinf(gBattleAnim*40)*5 : 0;
        int px = 160 + (int)hitShake, py = 300;
        DrawCircle(px, py-30, 20, (Color){COL_PLAYER.r,COL_PLAYER.g,COL_PLAYER.b,255});
        DrawRectangle(px-15, py-20, 30, 40, COL_PLAYER);
        DrawLineEx((Vector2){(float)(px-22),(float)(py-50)},(Vector2){(float)(px-22),(float)(py+10)},3,(Color){180,160,80,255});
        DrawCircle(px-22,py-55,10,COL_ACCENT);
        DrawRectangle(px-15,py+20,12,20,COL_PLAYER);
        DrawRectangle(px+3,py+20,12,20,COL_PLAYER);
    }

    // Player stats panel
    DrawPanel(10, 20, 220, 80);
    DrawText("SHAMAN", 18, 24, 12, COL_TEXT);
    DrawText("HP", 18, 40, 10, COL_TEXT);
    DrawBar(38, 40, 150, 10, (float)gPlayer.hp/gPlayer.maxHp,
        ((float)gPlayer.hp/gPlayer.maxHp<0.3f)?COL_HP_LOW:COL_HP_BAR);
    DrawText(TextFormat("%d/%d",gPlayer.hp,gPlayer.maxHp),194,40,9,COL_TEXT_DIM);
    DrawText("MP", 18, 56, 10, COL_ACCENT);
    DrawBar(38, 56, 150, 10, (float)gPlayer.mp/gPlayer.maxMp, COL_MP_BAR);
    DrawText(TextFormat("%d/%d",gPlayer.mp,gPlayer.maxMp),194,56,9,COL_TEXT_DIM);
    DrawText(TextFormat("Spirits: %d/6  G:%d", gPlayer.partyCount, gPlayer.gold),18,70,9,COL_TEXT_DIM);

    // Active spirit panel (spirit select / action phases)
    if (gPlayer.partyCount > 0 && (gPhase == BATTLE_SPIRIT_SELECT || gPhase == BATTLE_SPIRIT_ACTION)) {
        Spirit* cur = &gPlayer.party[gSpiritCursor];
        DrawPanel(10, 108, 220, 78);
        DrawText("ACTIVE SPIRIT", 18, 112, 10, COL_ACCENT);
        DrawText(cur->name, 18, 126, 12, ElemColor(cur->elem));
        DrawText("HP", 18, 142, 9, COL_TEXT);
        DrawBar(38, 142, 130, 8, (float)cur->hp/cur->maxHp, COL_HP_BAR);
        DrawText(TextFormat("MP:%d/%d  ATK%+d DEF%+d",
            cur->currentMp, cur->maxMp, cur->atkStage, cur->defStage), 18, 154, 8, COL_TEXT_DIM);
        if (cur->status != STATUS_NONE)
            DrawText(StatusName(cur->status), 18, 168, 9, StatusColor(cur->status));
    }

    // Action menu (player turn)
    if (gPhase == BATTLE_PLAYER_TURN && !gDialog.active) {
        DrawPanel(30, SCREEN_H-230, 320, 200);
        DrawText("ACTIONS", 40, SCREEN_H-224, 11, COL_BORDER2);
        const char* actions[] = {"Strike","Spirit Attack","Bind (MP:8)","Plead (MP:4)","Bribe (G:10)","Flee"};
        const char* descs[]   = {
            "Attack with your staff",
            "Command a bound spirit",
            "Dominate with spirit force",
            "Appeal to spirit mercy",
            "Offer gold to gain favor",
            "Retreat from battle"
        };
        for (int i = 0; i < 6; i++) {
            Color ac = (i==gBattleCursor) ? COL_ACCENT : COL_TEXT;
            if (i==gBattleCursor) {
                DrawRectangle(34, SCREEN_H-210+i*30, 310, 26, (Color){60,30,100,120});
                DrawRectangleLinesEx((Rectangle){34,(float)(SCREEN_H-210+i*30),310,26},1,COL_ACCENT);
            }
            DrawText(actions[i], 44, SCREEN_H-206+i*30, 12, ac);
            DrawText(descs[i],  180, SCREEN_H-202+i*30,  8, COL_TEXT_DIM);
        }
        DrawText("[Z] Confirm  [Up/Down] Select", 34, SCREEN_H-22, 9, COL_TEXT_DIM);
    }
    else if (gPhase == BATTLE_SPIRIT_SELECT && !gDialog.active) {
        DrawPanel(SCREEN_W/2-150, SCREEN_H/2-160, 300, 320);
        DrawText("CHOOSE SPIRIT", SCREEN_W/2-70, SCREEN_H/2-150, 14, COL_ACCENT);
        for (int i = 0; i < gPlayer.partyCount; i++) {
            Spirit* s = &gPlayer.party[i];
            Color c = (i==gSpiritCursor) ? COL_ACCENT : COL_TEXT;
            if (i==gSpiritCursor)
                DrawRectangle(SCREEN_W/2-140, SCREEN_H/2-128+i*52, 280, 46, (Color){60,30,100,80});
            DrawText(s->name, SCREEN_W/2-130, SCREEN_H/2-120+i*52, 12, c);
            DrawText(TextFormat("HP:%d/%d  MP:%d  Lv.%d  [%s]",
                s->hp, s->maxHp, s->currentMp, s->level, ElemName(s->elem)),
                SCREEN_W/2-130, SCREEN_H/2-104+i*52, 8, COL_TEXT_DIM);
            if (s->status != STATUS_NONE)
                DrawText(StatusName(s->status), SCREEN_W/2+90, SCREEN_H/2-120+i*52, 9, StatusColor(s->status));
        }
        DrawText("[Z] Select  [X] Back", SCREEN_W/2-100, SCREEN_H/2+130, 10, COL_TEXT_DIM);
    }
    else if (gPhase == BATTLE_SPIRIT_ACTION && !gDialog.active) {
        Spirit* cur = &gPlayer.party[gSpiritCursor];
        DrawPanel(SCREEN_W/2-160, SCREEN_H/2-110, 320, 220);
        DrawText(cur->name, SCREEN_W/2-60, SCREEN_H/2-100, 14, ElemColor(cur->elem));
        DrawText("Choose action:", SCREEN_W/2-70, SCREEN_H/2-70, 11, COL_TEXT);

        // Skill 1
        int yp = SCREEN_H/2-40;
        if (gSpiritActionCursor == 0)
            DrawRectangle(SCREEN_W/2-150, yp, 300, 38, (Color){60,30,100,80});
        DrawText(cur->skill1.name, SCREEN_W/2-140, yp+4, 12, COL_TEXT);
        DrawText(cur->skill1.description, SCREEN_W/2-140, yp+20, 8, COL_TEXT_DIM);

        // Skill 2
        if (cur->skill2.type != SKILL_NONE) {
            yp += 44;
            if (gSpiritActionCursor == 1)
                DrawRectangle(SCREEN_W/2-150, yp, 300, 38, (Color){60,30,100,80});
            DrawText(cur->skill2.name, SCREEN_W/2-140, yp+4, 12, COL_TEXT);
            // Show status chance if applicable
            if (cur->skill2.statusChance > 0.0f)
                DrawText(TextFormat("%s  MP:%d  %.0f%% %s",
                    cur->skill2.description, cur->skill2.mpCost,
                    cur->skill2.statusChance*100, StatusName(cur->skill2.applyStatus)),
                    SCREEN_W/2-140, yp+20, 8, COL_TEXT_DIM);
            else
                DrawText(TextFormat("%s  MP:%d", cur->skill2.description, cur->skill2.mpCost),
                    SCREEN_W/2-140, yp+20, 8, COL_TEXT_DIM);
        }
        DrawText("[Z] Use  [X] Back", SCREEN_W/2-80, SCREEN_H/2+80, 10, COL_TEXT_DIM);
    }

    // Negotiate flash
    if (gNegotiateAnim > 0 && gNegotiateAnim < 1.5f) {
        float t = gNegotiateAnim / 1.5f;
        unsigned char alpha = (t < 0.5f) ? (unsigned char)(t*2*255) : (unsigned char)((1-t)*2*255);
        Color col = (gNegotiateResult==1) ? COL_HOLY : COL_HP_LOW;
        DrawText(gNegotiateResult==1 ? "SPIRIT BOUND!" : "FAILED!",
            SCREEN_W/2-60, SCREEN_H/2-20, 24,
            (Color){col.r,col.g,col.b,alpha});
        gNegotiateAnim += GetFrameTime();
    }

    // Dialog box
    if (gDialog.active) {
        int bx=30, by=SCREEN_H-130, bw=SCREEN_W-60, bh=110;
        DrawPanel(bx, by, bw, bh);
        DrawRectangleLinesEx((Rectangle){(float)(bx+3),(float)(by+3),(float)(bw-6),(float)(bh-6)},1,COL_BORDER2);
        int chars = gDialog.displayedChars;
        int y = by+12;
        for (int i = 0; i < gDialog.lineCount; i++) {
            int len = (int)strlen(gDialog.lines[i]);
            if (chars <= 0) break;
            int show = (chars >= len) ? len : chars;
            chars -= len;
            char tmp[DIALOG_LEN+1];
            strncpy(tmp, gDialog.lines[i], show); tmp[show]=0;
            DrawText(tmp, bx+12, y, 13, COL_TEXT);
            y += 22;
        }
        if (gDialog.finished) {
            float blink = (float)fabs(sin(GetTime()*4));
            DrawText("[Z]", bx+bw-40, by+bh-18, 10,
                (Color){COL_ACCENT.r,COL_ACCENT.g,COL_ACCENT.b,(unsigned char)(blink*200+55)});
        }
    }
}

// ─────────────────────────────────────────────
//  Draw Spirit List
// ─────────────────────────────────────────────
static void DrawSpiritList(void) {
    DrawRectangle(0,0,SCREEN_W,SCREEN_H,COL_BG);
    DrawPanel(SCREEN_W/2-200, 10, 400, 36);
    DrawText("SPIRIT CONTRACTS", SCREEN_W/2-100, 18, 16, COL_ACCENT);

    if (gPlayer.partyCount == 0)
        DrawText("No spirits bound yet.", SCREEN_W/2-90, SCREEN_H/2, 14, COL_TEXT_DIM);

    for (int i = 0; i < gPlayer.partyCount; i++) {
        Spirit* s = &gPlayer.party[i];
        int px = 30 + (i%2)*460;
        int py = 60 + (i/2)*148;
        DrawPanel(px, py, 440, 138);
        DrawRectangle(px+4, py+4, 8, 130, ElemColor(s->elem));
        DrawSpiritGlyph(px+45, py+68, 36, s, GetTime());

        DrawText(s->name, px+80, py+10, 15, ElemColor(s->elem));
        DrawText(TextFormat("Lv.%d  [%s]  XP:%d/%d",
            s->level, ElemName(s->elem), s->xp, s->level*15),
            px+80, py+30, 10, COL_TEXT_DIM);

        DrawText("HP", px+80, py+48, 10, COL_TEXT);
        DrawBar(px+100, py+48, 160, 9, (float)s->hp/s->maxHp, COL_HP_BAR);
        DrawText(TextFormat("%d/%d",s->hp,s->maxHp), px+268, py+48, 9, COL_TEXT_DIM);

        DrawText("MP", px+80, py+62, 10, COL_ACCENT);
        DrawBar(px+100, py+62, 160, 9, (float)s->mp/s->maxMp, COL_MP_BAR);

        DrawText(TextFormat("ATK:%d(%+d) DEF:%d(%+d) SPD:%d",
            s->atk,s->atkStage, s->def,s->defStage, s->spd),
            px+80, py+78, 9, COL_TEXT);
        DrawText(TextFormat("Greed:%d Pride:%d Pity:%d",s->greed,s->pride,s->pity),
            px+80, py+92, 8, COL_TEXT_DIM);

        // Skills
        DrawText(TextFormat("1: %s", s->skill1.name), px+80, py+106, 8, COL_TEXT_DIM);
        if (s->skill2.type != SKILL_NONE) {
            if (s->skill2.statusChance > 0.0f)
                DrawText(TextFormat("2: %s (MP:%d, %.0f%% %s)",
                    s->skill2.name, s->skill2.mpCost,
                    s->skill2.statusChance*100, StatusName(s->skill2.applyStatus)),
                    px+80, py+118, 8, COL_TEXT_DIM);
            else
                DrawText(TextFormat("2: %s (MP:%d)", s->skill2.name, s->skill2.mpCost),
                    px+80, py+118, 8, COL_TEXT_DIM);
        }
        if (s->status != STATUS_NONE)
            DrawText(TextFormat("[%s]", StatusName(s->status)), px+380, py+10, 9, StatusColor(s->status));
    }

    DrawText("[X] or [Z] to close", 30, SCREEN_H-20, 11, COL_TEXT_DIM);
}

// ─────────────────────────────────────────────
//  Main
// ─────────────────────────────────────────────
int main(void) {
    InitWindow(SCREEN_W, SCREEN_H, "SPIRITBOUND - Spirit Combat Edition");
    SetTargetFPS(60);
    InitAudioDevice();

    InitGame();

    while (!WindowShouldClose()) {
        float dt = GetFrameTime();

        switch(gScene) {
            case SCENE_OVERWORLD:   UpdateOverworld(dt); break;
            case SCENE_BATTLE:      UpdateBattle(dt);    break;
            case SCENE_SPIRIT_LIST:
                if (IsKeyPressed(KEY_X) || IsKeyPressed(KEY_Z))
                    gScene = SCENE_OVERWORLD;
                break;
            case SCENE_GAMEOVER:
                if (IsKeyPressed(KEY_Z)) InitGame();
                break;
            case SCENE_WIN:
                if (IsKeyPressed(KEY_Z)) InitGame();
                break;
            default: break;
        }

        BeginDrawing();
        ClearBackground(COL_BG);

        switch(gScene) {
            case SCENE_OVERWORLD:   DrawOverworld();   break;
            case SCENE_BATTLE:      DrawBattle();      break;
            case SCENE_SPIRIT_LIST: DrawSpiritList();  break;
            case SCENE_GAMEOVER:
                DrawRectangle(0,0,SCREEN_W,SCREEN_H,(Color){5,3,12,230});
                DrawText("YOU HAVE FALLEN", SCREEN_W/2-120, SCREEN_H/2-40, 28, COL_HP_LOW);
                DrawText("Your spirit returns to the aether.", SCREEN_W/2-140, SCREEN_H/2, 16, COL_TEXT_DIM);
                DrawText("[Z] Try again", SCREEN_W/2-60, SCREEN_H/2+40, 14, COL_ACCENT);
                break;
            case SCENE_WIN:
                DrawRectangle(0,0,SCREEN_W,SCREEN_H,(Color){5,3,20,220});
                DrawText("THE SPIRITS REST", SCREEN_W/2-130, SCREEN_H/2-60, 28, COL_HOLY);
                DrawText("All three realms are at peace.", SCREEN_W/2-130, SCREEN_H/2-20, 14, COL_TEXT);
                DrawText(TextFormat("Spirits bound: %d   Gold: %d", gPlayer.partyCount, gPlayer.gold),
                    SCREEN_W/2-140, SCREEN_H/2+10, 13, COL_TEXT_DIM);
                DrawText("[Z] Play again", SCREEN_W/2-70, SCREEN_H/2+50, 14, COL_ACCENT);
                break;
            default: break;
        }

        EndDrawing();
    }

    CloseAudioDevice();
    CloseWindow();
    return 0;
}
