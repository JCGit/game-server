
�"
 google/protobuf/descriptor.protogoogle.protobuf"G
FileDescriptorSet2
file (2$.google.protobuf.FileDescriptorProto"�
FileDescriptorProto
name (	
package (	

dependency (	
public_dependency
 (
weak_dependency (6
message_type (2 .google.protobuf.DescriptorProto7
	enum_type (2$.google.protobuf.EnumDescriptorProto8
service (2'.google.protobuf.ServiceDescriptorProto8
	extension (2%.google.protobuf.FieldDescriptorProto-
options (2.google.protobuf.FileOptions9
source_code_info	 (2.google.protobuf.SourceCodeInfo"�
DescriptorProto
name (	4
field (2%.google.protobuf.FieldDescriptorProto8
	extension (2%.google.protobuf.FieldDescriptorProto5
nested_type (2 .google.protobuf.DescriptorProto7
	enum_type (2$.google.protobuf.EnumDescriptorProtoH
extension_range (2/.google.protobuf.DescriptorProto.ExtensionRange9

oneof_decl (2%.google.protobuf.OneofDescriptorProto0
options (2.google.protobuf.MessageOptions,
ExtensionRange
start (
end ("�
FieldDescriptorProto
name (	
number (:
label (2+.google.protobuf.FieldDescriptorProto.Label8
type (2*.google.protobuf.FieldDescriptorProto.Type
	type_name (	
extendee (	
default_value (	
oneof_index	 (.
options (2.google.protobuf.FieldOptions"�
Type
TYPE_DOUBLE

TYPE_FLOAT

TYPE_INT64
TYPE_UINT64

TYPE_INT32
TYPE_FIXED64
TYPE_FIXED32
	TYPE_BOOL
TYPE_STRING	

TYPE_GROUP

TYPE_MESSAGE

TYPE_BYTES
TYPE_UINT32
	TYPE_ENUM
TYPE_SFIXED32
TYPE_SFIXED64
TYPE_SINT32
TYPE_SINT64"C
Label
LABEL_OPTIONAL
LABEL_REQUIRED
LABEL_REPEATED"$
OneofDescriptorProto
name (	"�
EnumDescriptorProto
name (	8
value (2).google.protobuf.EnumValueDescriptorProto-
options (2.google.protobuf.EnumOptions"l
EnumValueDescriptorProto
name (	
number (2
options (2!.google.protobuf.EnumValueOptions"�
ServiceDescriptorProto
name (	6
method (2&.google.protobuf.MethodDescriptorProto0
options (2.google.protobuf.ServiceOptions"
MethodDescriptorProto
name (	

input_type (	
output_type (	/
options (2.google.protobuf.MethodOptions"�
FileOptions
java_package (	
java_outer_classname (	"
java_multiple_files
 (:false,
java_generate_equals_and_hash (:false%
java_string_check_utf8 (:falseF
optimize_for	 (2).google.protobuf.FileOptions.OptimizeMode:SPEED

go_package (	"
cc_generic_services (:false$
java_generic_services (:false"
py_generic_services (:false

deprecated (:falseC
uninterpreted_option� (2$.google.protobuf.UninterpretedOption":
OptimizeMode	
SPEED
	CODE_SIZE
LITE_RUNTIME*	�����"�
MessageOptions&
message_set_wire_format (:false.
no_standard_descriptor_accessor (:false

deprecated (:falseC
uninterpreted_option� (2$.google.protobuf.UninterpretedOption*	�����"�
FieldOptions:
ctype (2#.google.protobuf.FieldOptions.CType:STRING
packed (
lazy (:false

deprecated (:false
experimental_map_key	 (	
weak
 (:falseC
uninterpreted_option� (2$.google.protobuf.UninterpretedOption"/
CType

STRING 
CORD
STRING_PIECE*	�����"�
EnumOptions
allow_alias (

deprecated (:falseC
uninterpreted_option� (2$.google.protobuf.UninterpretedOption*	�����"}
EnumValueOptions

deprecated (:falseC
uninterpreted_option� (2$.google.protobuf.UninterpretedOption*	�����"{
ServiceOptions

deprecated! (:falseC
uninterpreted_option� (2$.google.protobuf.UninterpretedOption*	�����"z
MethodOptions

deprecated! (:falseC
uninterpreted_option� (2$.google.protobuf.UninterpretedOption*	�����"�
UninterpretedOption;
name (2-.google.protobuf.UninterpretedOption.NamePart
identifier_value (	
positive_int_value (
negative_int_value (
double_value (
string_value (
aggregate_value (	3
NamePart
	name_part (	
is_extension ("�
SourceCodeInfo:
location (2(.google.protobuf.SourceCodeInfo.Locationc
Location
path (B
span (B
leading_comments (	
trailing_comments (	B)
com.google.protobufBDescriptorProtosH
]
	rpc.proto google/protobuf/descriptor.proto:.
rpcid.google.protobuf.MethodOptions� (
�
common.protoGame	rpc.proto"

NilMessage"
EmptyMessage"+

ErrMessage
status (2.Game.ErrCode"#
Cards
cards (
uin ("<

RoundStart
roundId (
cards (
banker (*�
ErrCode
ok 
lack_ticket
already_in_room
not_room_owner
not_your_op_order
not_op_type
not_in_room

not_public
public_power_upper_limit	

have_beted


round_flow
first_must_play
not_your_operate
card_wrong_type
card_not_bigger
	must_play
room_waiting2
room_running3
room_voteing4
room_exiting5
	room_full<
room_not_exist=
room_have_voted>
	game_noned
game_startede
round_runningi
round_suspendingj
round_stopedk
game_stopedl*;
RoomType
FIVE_ROUNDS 

TEN_ROUNDS

TWN_ROUNDS*A
GameType
DN_GAME 
PDK_GAME
TEG_GAME
QGW_GAME
�
dnplay.protoGamecommon.proto	rpc.proto"�
DnRoundPlayerResult0
result (2 .Game.DnRoundPlayerResult.Result
uin (
modifyscore (
cards (
publicscore (!
niutype (2.Game.DN_NIUType
sum ("$
Result
WIN 
TIE
LOSE"@
DnRoundResult/
playerresult (2.Game.DnRoundPlayerResult"F
DnPlayerAccounts
uin (
modifyscore (
niucount ("d
DnRoomAccounts.
playeraccounts (2.Game.DnPlayerAccounts
winnerid (
gameTime ("L
DnPlayCards
cards (!
niutype (2.Game.DN_NIUType
sum ("l
pushLookCard
status (2.Game.ErrCode
cards (!
niutype (2.Game.DN_NIUType
sum ("�
	DnOperate)
type (2.Game.DnOperate.OperateType
uin (
num ("4
OperateType
BET 
	PUBLICBET
	SHUFFLING"�
OffLinerPlayerCache
uin (
ready (
beted (
power (
pulicebeted (
publicpower (
skip ("�
DnCache)
state (2.Game.DnCache.OffLineState
currentPlay ()
result (2.Game.DnRoundPlayerResult.
playercache (2.Game.OffLinerPlayerCache
canPublicPower (
roundid (
shufflingPlayer ("X
OffLineState
BET 	
READY
	PUBLICBET
ACCOUNTS
VOTE
	SHUFFLING"y
Bet
uin ("
bettype (2.Game.Bet.BetType
power ("2
BetType
BET 
	PUBLICBET
SKIP_PUBLIC"Z
PushShowCard
uin (
cards (!
niutype (2.Game.DN_NIUType
sum ("�
DnRoundPlayerState
uin (5
state (2&.Game.DnRoundPlayerState.DnPlayerState
num (
status (2.Game.ErrCode"Y
DnPlayerState

NORMAL 	
READY	
BETED
	PUBLICBET
SKIP
	SHUFFLING"�
DnRoundState0
state (2!.Game.DnRoundState.RoundStateType"`
RoundStateType
ROOM_BET 
ROOM_PUBLIC_BET
ROOM_PUBLIC_BET_OVER
ROOM_ACCOUNTS*Q

DN_NIUType
NIU_NIU 
NIU_FULL
NIU_TEN
NIU_NINE
	NIU_SMALL2l
C2SPlay(
bet	.Game.Bet.Game.ErrMessage"�>�7
	roundStop.Game.EmptyMessage.Game.ErrMessage"�>�2E
S2CPlay:
pushshowcard.Game.PushShowCard.Game.NilMessage"�>�
�
pdkplay.protoGamecommon.proto	rpc.proto"�
PdkRoundState4
state (2%.Game.PdkRoundState.PdkRoundStateType"?
PdkRoundStateType
PDK_ROUND_PLAY 
PDK_ROUND_ACCOUNTS"U
PdkRoundPlayerResult
uin (
score (
cards_count (
bomb ("B
PdkRoundResult0
playerresult (2.Game.PdkRoundPlayerResult"�
PdkPlayerAccounts
uin (
score (
name (	
winCount (

cardsCount (
	loseCount (
bomb ("f
PdkRoomAccounts/
playerAccounts (2.Game.PdkPlayerAccounts
winnerId (
gameTime ("�
PdkPlayCards
uin (
cards (0
cardType (2.Game.PdkPlayCards.PdkCardType"p
PdkCardType
NONE 
BOMB	
PLANE	
THREE
STRAIGHT	
PAIRS
PAIR
FOUR

SINGLE"*
Cue
	card_type (	
card_set ("�

PdkOperate-
type (2.Game.PdkOperate.PDKOperateType
uin (
first ("*
PDKOperateType
PDKPLAY 
PDKSKIP"�
PdkRoundPlayerState
uin (7
state (2(.Game.PdkRoundPlayerState.PdkPlayerState"e
PdkPlayerState
	PDKNORMAL 
PDKSKIP
PDKPLAY
PDKREADY
	PDKNOCARD
	PDKSINGLE"�
PdkCache*
state (2.Game.PdkCache.OffLineState
currentPlay (
cards (+
	cacheInfo (2.Game.PdkCache.CacheInfo
first (,

readyDatas (2.Game.PdkCache.ReadyData
roundId (
banker	 (X
	CacheInfo
uin (
remain (
cards (
score (
cardType (	'
	ReadyData
uin (
ready (")
OffLineState

PLAY_CARDS 	
READY"B
PdkCue 
	cueStatus (2.Game.ErrCode
cue (2	.Game.Cue2

C2SPdkPlay2

S2CPdkPlay
�
tegplay.protoGamecommon.proto	rpc.proto"U
TegRoundPlayerResult
uin (
score (
cards_count (
bomb ("B
TegRoundResult0
playerresult (2.Game.TegRoundPlayerResult"�
TegPlayerAccounts
uin (
score (
name (	
winCount (

cardsCount (
	loseCount (
bomb ("f
TegRoomAccounts/
playerAccounts (2.Game.TegPlayerAccounts
winnerId (
gameTime ("�
TegPlayCards
uin (
cards (0
cardType (2.Game.TegPlayCards.TegCardType"p
TegCardType
NONE 
BOMB	
PLANE	
THREE
STRAIGHT	
PAIRS
PAIR
FOUR

SINGLE"]

TegOperate"
type (2.Game.TegOperateType
uin (
canOper (
first ("�
TegRoundPlayerState
uin (7
state (2(.Game.TegRoundPlayerState.TegPlayerState
num ("x
TegPlayerState

TEG_NORMAL 
TEG_ROB
TEG_SKIP
TEG_PLAY
	TEG_READY

TEG_NOCARD

TEG_SINGLE",
TegPlayerCards
uin (
cards ("�
TegRoundState4
state (2%.Game.TegRoundState.TegRoundStateType"R
TegRoundStateType
TEG_ROUND_ROB 
TEG_ROUND_PLAY
TEG_ROUND_ACCOUNTS"u
TegCue 
	cueStatus (2.Game.ErrCode
cue (2.Game.TegCue.Cue*
Cue
	card_type (	
card_set ("�
TegCache*
state (2.Game.TegCache.OffLineState
currentPlay (
cards ('
robData (2.Game.TegCache.RobData+
	cacheInfo (2.Game.TegCache.CacheInfo
first (,

readyDatas (2.Game.TegCache.ReadyData
roundId (
banker	 (3
RobData
uin (
rob (
isSkip (X
	CacheInfo
uin (
remain (
cards (
score (
cardType (	'
	ReadyData
uin (
ready ("2
OffLineState

PLAY_CARDS 
ROB	
READY"r
RobStop'
winMode (2.Game.RobStop.WIN_MODE
rob (
banker ("!
WIN_MODE

SPRING 	
OTHER*9
TegOperateType
TEG_PLAY 
TEG_ROB
TEG_SKIP2

C2STegPlay2>

S2CTegPlay0
robStop.Game.RobStop.Game.NilMessage"�>�
�
qgwplay.protoGamecommon.proto	rpc.proto"2
QgwRoundPlayerResult
uin (
score ("<
QgwRoundResult*
result (2.Game.QgwRoundPlayerResult"b
QgwPlayerAccounts
uin (
score (
name (	
winCount (
	loseCount ("T
QgwRoomAccounts/
playerAccounts (2.Game.QgwPlayerAccounts
winnerId ("�
QgwPlayCards
uin (
cards (0
cardType (2.Game.QgwPlayCards.QgwCardType"B
QgwCardType
NONE 	
THREE
PAIR
FOUR

SINGLE"]

QgwOperate"
type (2.Game.QgwOperateType
uin (
canOper (
first ("�
QgwRoundPlayerState
uin (7
state (2(.Game.QgwRoundPlayerState.QgwPlayerState
num ("[
QgwPlayerState

QGW_NORMAL 
QGW_SKIP
QGW_PLAY
	QGW_READY

QGW_NOCARD",
QgwPlayerCards
uin (
cards ("�
QgwRoundState4
state (2%.Game.QgwRoundState.QgwRoundStateType"R
QgwRoundStateType
QGW_ROUND_ROB 
QGW_ROUND_PLAY
QGW_ROUND_ACCOUNTS"7
QgwCue 
	cueStatus (2.Game.ErrCode
cue ("�
QgwCache*
state (2.Game.QgwCache.OffLineState
currentPlay (
cards (+
	cacheInfo (2.Game.QgwCache.CacheInfo
first (,

readyDatas (2.Game.QgwCache.ReadyData
roundId (X
	CacheInfo
uin (
remain (
cards (
score (
cardType (	'
	ReadyData
uin (
ready (")
OffLineState

PLAY_CARDS 	
READY*,
QgwOperateType
QGW_PLAY 
QGW_SKIP2

C2SQgwPlay2

S2CQgwPlay
�"
basic.protoGamecommon.protodnplay.protopdkplay.prototegplay.protoqgwplay.proto	rpc.proto"'
Vote
uin (

resultTime ("%
OneVote
uin (
agree ("7
VoteEnd
status (
votes (2.Game.OneVote"*

VoteResult
votes (2.Game.OneVote"q
	RoomState,
state (2.Game.RoomState.RoomStateType"6
RoomStateType
ROOM_READY_GAME 
ROOM_DESTORY"�
PlayerState0
state (2!.Game.PlayerState.PlayerStateType
uin ("p
PlayerStateType
PLAYER_STATE_START 
PLAYER_STATE_OFFLINE
PLAYER_STATE_SIT
PLAYER_STATE_EXIT"-
LeaveRoomRes
status (2.Game.ErrCode"�

RoomPlayer
seatID (
name (	
sex (
imgurl (	
uin (
owner (

ip (	
offline (
openid	 (	",
Players!
players (2.Game.RoomPlayer"a
C2S_OpenRoom 
gameType (2.Game.GameType 
roomType (2.Game.RoomType
rules (	"=
S2C_OpenRoom
status (2.Game.ErrCode
roomID (	".
C2S_EnterRoom
roomID (	
retry ("
PushOffLine
uin ("

PushOnLine
uin ("�
S2C_EnterRoom
status (2.Game.ErrCode
seatID ( 
roomType (2.Game.RoomType
roomID (	
special (	 
gameType (2.Game.GameType"=
	RoomCache 
gameType (2.Game.GameType
roomID (	""
Voice
data (	
uin ("
FastNews

id ("'
PushFastNews
uin (

id ("�
PlayerOperate
bull (2.Game.DnOperate
pdk (2.Game.PdkOperate
teg (2.Game.TegOperate
qgw (2.Game.QgwOperate"�
RoundSum!
bull (2.Game.DnRoundResult!
pdk (2.Game.PdkRoundResult!
teg (2.Game.TegRoundResult!
qgw (2.Game.QgwRoundResult"�

RoundState 
bull (2.Game.DnRoundState 
pdk (2.Game.PdkRoundState 
teg (2.Game.TegRoundState 
qgw (2.Game.QgwRoundState"�

RoomResult"
bull (2.Game.DnRoomAccounts"
pdk (2.Game.PdkRoomAccounts"
teg (2.Game.TegRoomAccounts"
qgw (2.Game.QgwRoomAccounts"�
RoundPlayerState&
bull (2.Game.DnRoundPlayerState&
pdk (2.Game.PdkRoundPlayerState&
teg (2.Game.TegRoundPlayerState&
qgw (2.Game.QgwRoundPlayerState"�
	PlayCards
bull (2.Game.DnPlayCards
pdk (2.Game.PdkPlayCards
teg (2.Game.TegPlayCards
qgw (2.Game.QgwPlayCards""
Rob
power (
skip ("{
Cache
bull (2.Game.DnCache
pdk (2.Game.PdkCache
teg (2.Game.TegCache
qgw (2.Game.QgwCache"W
Cues
pdk (2.Game.PdkCue
teg (2.Game.TegCue
qgw (2.Game.QgwCue2�
C2SBasic7
openRoom.Game.C2S_OpenRoom.Game.S2C_OpenRoom"�>d:
	enterRoom.Game.C2S_EnterRoom.Game.S2C_EnterRoom"�>e8
askRoomCache.Game.EmptyMessage.Game.RoomCache"�>f6
	leaveRoom.Game.EmptyMessage.Game.ErrMessage"�>g6
	startVote.Game.EmptyMessage.Game.ErrMessage"�>h,
vote.Game.OneVote.Game.ErrMessage"�>i8
playerReady.Game.EmptyMessage.Game.ErrMessage"�>j+
voice.Game.Voice.Game.ErrMessage"�>k6
	gameReady.Game.EmptyMessage.Game.ErrMessage"�>l1
fastNews.Game.FastNews.Game.ErrMessage"�>m8
destoryRoom.Game.EmptyMessage.Game.ErrMessage"�>n/
	playCards.Game.Cards.Game.ErrMessage"�>o'
rob	.Game.Rob.Game.ErrMessage"�>p2�
S2CBasic4
pushPlayers.Game.Players.Game.NilMessage"�>�<
pushPlayerState.Game.PlayerState.Game.NilMessage"�>�8
pushRoomState.Game.RoomState.Game.NilMessage"�>�.
pushVote
.Game.Vote.Game.NilMessage"�>�4
pushVoteEnd.Game.VoteEnd.Game.NilMessage"�>�0
	pushVoice.Game.Voice.Game.NilMessage"�>�:
pushFastNews.Game.PushFastNews.Game.NilMessage"�>�:
pushRoundStart.Game.RoundStart.Game.NilMessage"�>�F
pushRoundPlayerState.Game.RoundPlayerState.Game.NilMessage"�>�@
pushPlayerOperate.Game.PlayerOperate.Game.NilMessage"�>�9
pushRoundStoped.Game.RoundSum.Game.NilMessage"�>�;
pushRoundStates.Game.RoundState.Game.NilMessage"�>�8
pushRoomStop.Game.RoomResult.Game.NilMessage"�>�8
pushPlayCards.Game.PlayCards.Game.NilMessage"�>�,
pushRob	.Game.Rob.Game.NilMessage"�>�6
pushShowCards.Game.Cards.Game.EmptyMessage"�>�2
	pushCards.Game.Cards.Game.EmptyMessage"�>�/
pushCue
.Game.Cues.Game.EmptyMessage"�>�2
	pushCache.Game.Cache.Game.EmptyMessage"�>�
�
login.protoGamecommon.proto	rpc.proto"�
	C2S_Login
openid (	
token (	
device (	
sex (
name (	
imgurl (	
country (	
province (	
city	 (	"n
	S2C_Login+
result (2.Game.S2C_Login.LoginResult

new_player (" 
LoginResult
LOGIN_SUCCEED":

PlayerInfo
uin (
room_ticket (

ip (	"
respHeartBeat
time (2u
C2SLogin.
login.Game.C2S_Login.Game.S2C_Login"�>
9
	heartBeat.Game.EmptyMessage.Game.respHeartBeat"�>2J
S2CLogin>
pushBasicPlayerInfo.Game.PlayerInfo.Game.NilMessage"�>
�
record.protoGamecommon.proto	rpc.proto"?
C2S_RoomRecord
uin ( 
gameType (2.Game.GameType"�

RoomRecord
roomId (
date (3
playerRecord (2.Game.RoomRecord.PlayerRecord
roundId (+
PlayerRecord
name (	
score ("3
S2C_RoomRecord!
records (2.Game.RoomRecord2J
	C2SRecord=
	getRecord.Game.C2S_RoomRecord.Game.S2C_RoomRecord"�>�2
	S2CRecord