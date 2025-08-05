module mplay_c3;
import mpv;
import std::atomic::types;
import std::io;
import std::time;
import std::thread;

struct ThreadData
{
	Atomic {bool}* running;
	Mpv mpv;
}

struct Test
{
	String test;
	ThreadData test2;
}

fn int main(String[] args)
{
	Atomic {bool} running;
	running.store(true);

	Mpv mpv = mpv::create();
	defer mpv.destroy();

	// mpv.set_option("video", FLAG, &&MpvBool.FALSE);
	mpv.set_option_flag("video", false)!!;
	// we want to exit immediately once there are no more files to play
	mpv.set_option_flag("idle", false)!!;
	mpv.init()!!;
	(void)mpv.pause();

	Thread input_thread;
	if (catch err = input_thread.create((ThreadFn)&input_thread_fn, &&(ThreadData){&running, mpv}))
	{
		io::eprintfn("Unable to init input thread: %s", err);
		return 1;
	}
	defer
	{
		running.store(false);
		(void)input_thread.join();
	}
	Thread output_thread;
	if (catch err = output_thread.create((ThreadFn)&output_thread_fn, &&(ThreadData){&running, mpv}))
	{
		io::eprintfn("Unable to init output thread: %s", err);
		return 1;
	}
	defer
	{
		(void)output_thread.join();
	}
	// (void)mpv::request_log_messages(mpv, V);

	bool shuffle;
	usz volume = 100;
	for (usz i = 1; i < args.len; i++)
	{
		if (args[i] == "-s")
		{
			shuffle = true;
		}
		else if (args[i] == "-v")
		{
			i++;
			usz? vol = args[i].to_ulong();
			if (catch err = vol)
			{
				io::eprintfn("ERROR: unable to parse volume '%s' to int: %s", args[i], err);
				return 1;
			}
			if (vol > 100)
			{
				io::eprintfn("ERROR: volume must be <= 100");
				return 1;
			}
			volume = vol;
		}
		else if (args[i].len > 4 && args[i][^5..] == ".m3u")
		{
			mpv::load_playlist(mpv, args[i], false)!!;
		}
		else
		{
			mpv::load_file(mpv, args[i], false)!!;
		}
	}
	if (shuffle) mpv::shuffle(mpv)!!;
	mpv.set_song_idx(0)!!;

	(void)mpv.unpause();
	// mpv.observe_prop("pause", FLAG, 0)!!;

	while (running.load())
	{
		MpvEvent *event = mpv::wait_event(mpv, 1.0);
	}

/*	rl::initWindow(500, 200, "Mpv client");
	defer rl::closeWindow();
	rl::setTargetFPS(30);

	while (!rl::windowShouldClose())
	{
		MpvEvent* event = mpv::wait_event(mpv, 0);
		switch (event.event_id)
		{
			case NONE:
				break;
			case SHUTDOWN:
				break;
			case PROPERTY_CHANGE:
				MpvEventProperty* p = event.get_property_change();
				// pause event only. 0 is set by observe_property call above
				if (event.reply_userdata == 0)
				{
					 io::printfn("property %s changed to %s", p.name, *(MpvBool*)p.data);
				}
				else
				{
					nextcase default;
				}
			default:
				io::printfn("got event %s", event.name());
		}

		if (rl::isKeyPressed(rl::KEY_SPACE))
		{
			mpv.toggle_pause()!!;
		}
		if (rl::isKeyPressed(rl::KEY_A))
		{
			mpv::shuffle(mpv)!!;
			mpv.set_song_idx(0)!!;
		}
		if (rl::isKeyPressed(rl::KEY_B))
		{
			mpv::unshuffle(mpv)!!;
			mpv.set_song_idx(0)!!;
		}
		if (rl::isKeyPressed(rl::KEY_M))
		{
			mpv.set_prop_flag("mute", !mpv.get_prop_flag("mute"))!!;
		}
		if (rl::isKeyDown(rl::KEY_UP))
		{
			if (try vol = mpv.get_prop_int("volume") && vol < 100)
			{
				(void)mpv.set_prop_int("volume", vol + 5);
			}
		}
		if (rl::isKeyDown(rl::KEY_DOWN))
		{
			if (try vol = mpv.get_prop_int("volume") && vol > 0)
			{
				(void)mpv.set_prop_int("volume", vol - 5);
			}
		}
		if (rl::isKeyPressed(rl::KEY_RIGHT))
		{
			if (try sec = mpv.get_prop_int("time-pos"))
			{
				(void)mpv.set_prop_int("time-pos", sec + 5);
			}
		}
		if (rl::isKeyPressed(rl::KEY_LEFT))
		{
			if (try sec = mpv.get_prop_int("time-pos"))
			{
				(void)mpv.set_prop_int("time-pos", sec - 5);
			}
		}
		if (rl::isMouseButtonPressed(LEFT))
		{
			float[<2>] pos = bitcast(rl::getMousePosition(), float[<2>]);
			if (pos.comp_lt({410, 70}) == {true, true} && pos.comp_gt({10, 50}) == {true, true})
			{
				(void)mpv.set_prop_int("time-pos", (long)(((pos.x - 10) / 400) * mpv.get_prop_int("duration") ?? 0));
			}
		}
		rl::@drawing()
		{
			rl::clearBackground(rl::RAYWHITE);
			rl::drawText((mpv.is_paused() ?? true) ? "|>" : "||", 10, 10, 40, rl::BLACK);
			rl::drawRectangle(10, 50, 400, 20, rl::BLACK);
			rl::drawRectangle(12, 52, (int)(396 * ((mpv.get_prop_int("percent-pos") ?? 0) / 100.0)), 16, rl::WHITE);
			@pool()
			{
				String? title = mpv.get_prop_string("metadata/by-key/title");
				defer if (try title) mpv::free(title);
				rl::drawText((title ?? "Unknown").zstr_tcopy(), 10, 80, 40, rl::BLACK);

				rl::drawText(string::tformat_zstr("%s/%s", time::sec(mpv.get_prop_int("time-pos") ?? 0).to_nano(), time::sec(mpv.get_prop_int("duration") ?? 0).to_nano()), 380, 70, 20, rl::BLACK);

				if (mpv.get_prop_flag("mute") ?? false)
				{
					rl::drawText("Muted", 380, 20, 20, rl::BLACK);
				}
				else
				{
					rl::drawText(string::tformat_zstr("Vol: %s%%", mpv.get_prop_int("volume") ?? 0), 380, 20, 20, rl::BLACK);
				}
				rl::drawText(string::tformat_zstr("%s/%s", mpv.get_prop_int("playlist-pos-1") ?? -1, mpv.get_prop_int("playlist/count") ?? -1), 40, 20, 20, rl::BLACK);
			};
		};
	}
*/
	return 0;
}

fn int input_thread_fn(ThreadData* args) => @pool_init(mem, 10 * mem::MB)
{
	Atomic {bool}* running = args.running;
	Mpv mpv = args.mpv;
	while (running.load()) @pool()
	{
		thread::sleep(time::sec(1));
/*		static int i;
		switch (i % 4)
		{
			case 0:
				cursor_up(5);
			case 1:
				cursor_left(5);
			case 2:
				cursor_down(5);
			case 3:
				cursor_right(5);
		}
		i++;*/
		// if (running.load()) mpv::command(mpv, {"seek", "100", "absolute-percent"})!!;
		// mpv.toggle_pause()!!;
	};
	return 0;
}

fn int output_thread_fn(ThreadData* args) => @pool_init(mem, 10 * mem::MB)
{
	Atomic {bool}* running = args.running;
	Mpv output_mpv = mpv::create_client(args.mpv, "output");
	defer (void)output_mpv.destroy();
	output_mpv.observe_prop("time-pos", INT64, 0)!!;
	output_mpv.observe_prop("pause", FLAG, 1)!!;
	output_mpv.observe_prop("volume", INT64, 2)!!;

	const DEFAULT_SONG_NAME = "Unknown";
	const DEFAULT_ARTIST_NAME = "Unknown";
	String song_name = DEFAULT_SONG_NAME;
	String artist_name = DEFAULT_ARTIST_NAME;
	long playlist_len = -1;
	long playlist_idx = -1;
	long song_len = -1;
	long song_secs = -1;
	long volume = -1;
	bool pause = true;

	// cursor_horizontal_position(0);
	// save_cursor();
	while (running.load())
	{
		// thread::sleep(time::ms(500));
		MpvEvent* event = mpv::wait_event(output_mpv, 10.0);
		switch (event.event_id)
		{
			case PROPERTY_CHANGE:
				MpvEventProperty* p = event.get_property_change();
				// io::printfn("got property change with name '%s' and format '%s'", p.name, p.format);
				if (p.format != NONE) switch // (p.name) TODO: once switch for operator overloads is implemented readd this
				{
					case p.name == "pause":
						// io::printfn("pause event changed to %s", p.get_flag());
						pause = p.get_flag();
					case p.name == "time-pos":
						// io::printfn("time-pos changed to '%s'", p.get_int());
						song_secs = p.get_int();
					case p.name == "volume":
						volume = p.get_int();
					default:
						io::printfn("got observed property '%s'", p.name);
				}
			case FILE_LOADED:
				song_len = output_mpv.get_prop_int("duration") ?? -1;
				song_name = output_mpv.get_prop_string("metadata/by-key/title") ?? output_mpv.get_prop_string("filename/no-ext") ?? DEFAULT_SONG_NAME;
				artist_name = output_mpv.get_prop_string("metadata/by-key/artist") ?? DEFAULT_ARTIST_NAME;

				playlist_len = output_mpv.get_prop_int("playlist/count") ?? -1;
				playlist_idx = output_mpv.get_prop_int("playlist-pos-1") ?? -1;
			case END_FILE:
				MpvEventEndFile* e = event.get_end_file();
				if (e.error != SUCCESS) io::printfn("Ended file with error: %s", e.error);
				switch (e.reason)
				{
					case EOF:
						break;
					default:
						io::printfn("end file with reason '%s', error: '%s'", e.reason, e.error);
				}
			case SHUTDOWN:
				running.store(false);
			default:
				// io::printfn("Got event: %s", event.name());
		}
		// restore_cursor();
		clear_display(CURSOR_TO_END);
		io::printfn("%s by %s", song_name, artist_name);
		const PROGRESS_BAR_WIDTH = 40 - 1;
		// Don't worry about how it works, I can't really remember anyway
		usz time_progress = (double)song_secs / song_len * PROGRESS_BAR_WIDTH;
		io::printfn("%s:%02d/%s:%02d [%.*s>%.*s]", song_secs / 60, song_secs % 60, song_len / 60, song_len % 60, time_progress, @repeat("-", PROGRESS_BAR_WIDTH), PROGRESS_BAR_WIDTH - time_progress, @repeat(" ", PROGRESS_BAR_WIDTH));
		io::printfn("[%s/%s] %s %s%%", playlist_idx, playlist_len, pause ? "►" : "⏸︎", volume);
		cursor_horizontal_position(0);
		cursor_up(3);
	}
	return 0;
}

fn bool? Mpv.is_paused(self) => self.get_prop_flag("pause");
fn void? Mpv.toggle_pause(self) => self.set_prop_flag("pause", !self.get_prop_flag("pause"))!;

macro String @repeat(String $s, usz $times)
{
	String $ret;
	$for var $i = 0; $i < $times; $i++:
		$ret = $ret +++ $s;
	$endfor
	return $ret;
}

fn void cursor_up(usz amount)
{
	io::printf("\e[%sA", amount);
	(void)io::stdout().flush();
}
fn void cursor_down(usz amount)
{
	io::printf("\e[%sB", amount);
	(void)io::stdout().flush();
}
fn void cursor_right(usz amount)
{
	io::printf("\e[%sC", amount);
	(void)io::stdout().flush();
}
fn void cursor_left(usz amount)
{
	io::printf("\e[%sD", amount);
	(void)io::stdout().flush();
}

fn void save_cursor()
{
	io::print("\e[s");
	(void)io::stdout().flush();
}

fn void restore_cursor()
{
	io::print("\e[u");
}

<*
 @param position : "position is zero-based, not one-based"
*>
fn void cursor_horizontal_position(usz position)
{
	io::printf("\e[%sG", position + 1);
	(void)io::stdout().flush();
}

enum AnsiClear : const int
{
	CURSOR_TO_END,
	CURSOR_TO_START,
	EVERYTHING,
	// Clear line only:
	EVERYTHING_AND_HISTORY,
}

<*
 @ensure clear != EVERYTHING_AND_HISTORY : "EVERYTHING_AND_HISTORY can only be used with clear_display"
*>
fn void clear_line(AnsiClear clear)
{
	io::printf("\e[%sK", clear);
	(void)io::stdout().flush();
}

fn void clear_display(AnsiClear clear)
{
	io::printf("\e[%sJ", clear);
	(void)io::stdout().flush();
}
