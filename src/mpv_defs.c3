module mpv;
import std::io;

faultdef EVENT_QUEUE_FULL, NOMEM, UNINITIALIZED, INVALID_PARAMETER,
		OPTION_NOT_FOUND, OPTION_FORMAT, OPTION_ERROR,
		PROPERTY_NOT_FOUND, PROPERTY_FORMAT, PROPERTY_UNAVAILABLE,
		PROPERTY_ERROR, COMMAND, LOADING_FAILED, AO_INIT_FAILED,
		VO_INIT_FAILED, NOTHING_TO_PLAY, UNKNOWN_FORMAT, UNSUPPORTED,
		NOT_IMPLEMENTED, GENERIC;

typedef MpvError = CInt;
typedef Mpv = void*;
typedef MpvUserdata = ulong;

bitstruct MpvVersion (Printable) : CULong
{
	uint minor : 0..15;
	uint major : 16..31;
}

fn usz? MpvVersion.to_format(&self, Formatter* fmt) @dynamic
{
	return fmt.printf("%s.%s", self.major, self.minor);
}

struct MpvNode
{
	union u
	{
		ZString string;
		MpvBool flag;
		long int64;
		double double_;
		MpvNodeList* list;
		MpvByteArray* ba;
	}
	MpvFormat format;
}

struct MpvNodeList
{
	CInt num;
	MpvNode *values;
	ZString* keys;
}

struct MpvByteArray
{
	void *data;
	usz size;
}

struct MpvEventProperty
{
	ZString name;
	MpvFormat format;
	void *data;
}

struct MpvEventLogMessage
{
	ZString prefix;
	ZString level;
	ZString text;
	MpvLogLevel log_level;
}

struct MpvEventStartFile
{
	isz playlist_entry_id;
}

struct MpvEventEndFile
{
	MpvEndFileReason reason;
	MpvError error;
	isz playlist_entry_id;
	isz playlist_insert_id;
	CInt playlist_insert_num_entries;
}

struct MpvEventClientMessage
{
	CInt num_args;
	ZString* args;
}

struct MpvEventHook
{
	ZString name;
	usz id;
}

struct MpvEventCommand
{
	MpvNode result;
}

struct MpvEvent
{
	MpvEventId event_id;
	MpvError error;
	MpvUserdata reply_userdata;
	/*
	 * The meaning and contents of the data member depend on the event_id:
	 *  MPV_EVENT_GET_PROPERTY_REPLY:     MpvEventProperty*
	 *  MPV_EVENT_PROPERTY_CHANGE:        MpvEventProperty*
	 *  MPV_EVENT_LOG_MESSAGE:            MpvEventLogMessage*
	 *  MPV_EVENT_CLIENT_MESSAGE:         MpvEventClientMessage*
	 *  MPV_EVENT_START_FILE:             MpvEventStartFile* (since v1.108)
	 *  MPV_EVENT_END_FILE:               MpvEventEndFile*
	 *  MPV_EVENT_HOOK:                   MpvEventHook*
	 *  MPV_EVENT_COMMAND_REPLY*          MpvEventCommand*
	 *  other: NULL
	 *
	 * Note: future enhancements might add new event structs for existing or new
	 *       event types.
	 */
	void *data;
}

alias MpvCallback = fn void(void*);

enum MpvBool : CInt (bool as_bool)
{
	FALSE = false,
	TRUE = true,
}

macro MpvBool bool_to_mpv(bool b) => b ? TRUE : FALSE;

enum MpvFormat : CInt
{
	NONE,
	STRING,
	OSD_STRING,
	FLAG,
	INT64,
	DOUBLE,
	NODE,
	NODE_ARRAY,
	NODE_MAP,
	BYTE_ARRAY,
}

enum MpvEndFileReason : const CInt
{
	EOF = 0,
	STOP = 2,
	QUIT = 3,
	ERROR = 4,
	REDIRECT = 5,
}

macro void? wrap_err(MpvError val) @private
{
	switch (val)
	{
		case 0: return;
		case -1: return EVENT_QUEUE_FULL?;
		case -2: return NOMEM?;
		case -3: return UNINITIALIZED?;
		case -4: return INVALID_PARAMETER?;
		case -5: return OPTION_NOT_FOUND?;
		case -6: return OPTION_FORMAT?;
		case -7: return OPTION_ERROR?;
		case -8: return PROPERTY_NOT_FOUND?;
		case -9: return PROPERTY_FORMAT?;
		case -10: return PROPERTY_UNAVAILABLE?;
		case -11: return PROPERTY_ERROR?;
		case -12: return COMMAND?;
		case -13: return LOADING_FAILED?;
		case -14: return AO_INIT_FAILED?;
		case -15: return VO_INIT_FAILED?;
		case -16: return NOTHING_TO_PLAY?;
		case -17: return UNKNOWN_FORMAT?;
		case -18: return UNSUPPORTED?;
		case -19: return NOT_IMPLEMENTED?;
		case -20: return GENERIC?;
		default:// return (CInt)val;
			unreachable("Invalid MPV error code");
	}
}

fn ZString error_string(fault err) @inline
{
	MpvError err_val;
	switch (err)
	{
		case EVENT_QUEUE_FULL: err_val = -1;
		case NOMEM: err_val = -2;
		case UNINITIALIZED: err_val = -3;
		case INVALID_PARAMETER: err_val = -4;
		case OPTION_NOT_FOUND: err_val = -5;
		case OPTION_FORMAT: err_val = -6;
		case OPTION_ERROR: err_val = -7;
		case PROPERTY_NOT_FOUND: err_val = -8;
		case PROPERTY_FORMAT: err_val = -9;
		case PROPERTY_UNAVAILABLE: err_val = -10;
		case PROPERTY_ERROR: err_val = -11;
		case COMMAND: err_val = -12;
		case LOADING_FAILED: err_val = -13;
		case AO_INIT_FAILED: err_val = -14;
		case VO_INIT_FAILED: err_val = -15;
		case NOTHING_TO_PLAY: err_val = -16;
		case UNKNOWN_FORMAT: err_val = -17;
		case UNSUPPORTED: err_val = -18;
		case NOT_IMPLEMENTED: err_val = -19;
		case GENERIC: err_val = -20;
		default:
			unreachable("Not an MPV error: %s", err);
	}
	return mpv_error_string(err_val);
}

enum MpvEventId : const CInt
{
    NONE = 0,
    SHUTDOWN,
    LOG_MESSAGE,
    GET_PROPERTY_REPLY,
    SET_PROPERTY_REPLY,
    COMMAND_REPLY,
    START_FILE,
    END_FILE,
    FILE_LOADED,
    CLIENT_MESSAGE = 16,
    VIDEO_RECONFIG,
    AUDIO_RECONFIG,
    SEEK = 20,
    PLAYBACK_RESTART,
    PROPERTY_CHANGE,
    QUEUE_OVERFLOW = 24,
    HOOK
}

enum MpvLogLevel : const CInt
{
    NONE  = 0,
    FATAL = 10,
    ERROR = 20,
    WARN  = 30,
    INFO  = 40,
    V     = 50,
    DEBUG = 60,
    TRACE = 70,
}

