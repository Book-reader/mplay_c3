module mplay_c3;
import mpv @public;
import raylib5::rl;
import std::io;
import std::time;

// this is not well made, but works as an example
fn int main(String[] args)
{
	Mpv mpv = mpv::create();
	defer mpv.destroy();

	// mpv.set_option("video", FLAG, &&MpvBool.FALSE);
	mpv.set_option_flag("video", false)!!;

	mpv.set_option_string("input-default-bindings", "yes")!!;
	mpv.set_option_string("input-vo-keyboard", "yes")!!;

	// mpv.set_option("osc", FLAG, &&MpvBool.TRUE);
	mpv.set_option_flag("osc", true)!!;

	mpv.init()!!;
	mpv::set_wakeup_callback(mpv, &on_wakeup, null);
	// (void)mpv::request_log_messages(mpv, V);

	// mpv::command(mpv, {"loadfile", args[1]})!!;
	if (args[1][^5..] == ".m3u")
	{
		mpv::load_playlist(mpv, args[1], true)!!;
	}
	else
	{
		mpv::load_file(mpv, args[1])!!;
	}

	mpv.observe_prop("pause", FLAG, 0)!!;

	io::printfn("a: %s, b: %s", mpv::api_version(), mpv.client_id());

	rl::initWindow(500, 200, "Mpv client");
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
			mpv.set_prop_flag("pause", false)!!;
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

	return 0;
}


fn bool? Mpv.is_paused(self) => self.get_prop_flag("pause");
fn void? Mpv.toggle_pause(self) => self.set_prop_flag("pause", !self.get_prop_flag("pause"))!;

fn void on_wakeup(void* data)
{
	io::printn("event callback!");
}
