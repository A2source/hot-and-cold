package;

import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;

import lime.graphics.Image;
import flash.display.BitmapData;

import flixel.system.scaleModes.FixedScaleMode;

import lime.app.Application;

import a2.time.util.Discord;
import a2.time.util.Discord.DiscordClient;
import a2.time.util.ClientPrefs;
import a2.time.util.CoolUtil;
import a2.time.objects.ui.FPS;

import haxe.ui.components.Button;
import haxe.ui.containers.VBox;
import haxe.ui.Toolkit;

//crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

using StringTools;

class Main extends Sprite
{
	public static var baseTrace = haxe.Log.trace;
	public static var cwd:String;
	public static var curMusicName:String = "";

	public static inline final MOD_NAME:String = 'core';
	public static inline final ALERT_TITLE:String = 'HOT & COLD';

	var gameWidth:Int = 720; // Width of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var gameHeight:Int = 720; // Height of the game in pixels (might be less / more in actual pixels depending on your zoom).
	var initialState:Class<FlxState> = a2.time.states.IntroState; // The FlxState the game starts with.
	var zoom:Float = -1; // If -1, zoom is automatically calculated to fit the window dimensions.
	var framerate:Int = 60; // How many frames per second the game should run at.
	var skipSplash:Bool = true; // Whether to skip the flixel splash screen that appears in release mode.
	var startFullscreen:Bool = false; // Whether to start the game in fullscreen on desktop targets
	public static var fpsVar:FPS;

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		cwd = Sys.getCwd();
		super();

		if (stage != null)
			init();
		else
			addEventListener(Event.ADDED_TO_STAGE, init);
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
			removeEventListener(Event.ADDED_TO_STAGE, init);

		setupGame();
	}

	public static var game:FlxGame;

	private function setupGame():Void
	{
		initHaxeUI();
		
		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		if (zoom == -1)
		{
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}

		game = new FlxGame(gameWidth, gameHeight, initialState, framerate, framerate, skipSplash, startFullscreen);

		@:privateAccess game._customSoundTray = a2.time.objects.ui.TimeSoundTray;
	
		ClientPrefs.loadDefaultKeys();
		addChild(game);

		a2.time.util.Controls.instance = new a2.time.util.Controls();

		#if !mobile
		fpsVar = new FPS(3, 3, 0xFFFFFF);
		addChild(fpsVar);

		Lib.current.stage.align = "tl";
		FlxG.scaleMode = new FixedScaleMode();
		
		if(fpsVar != null)
			fpsVar.visible = ClientPrefs.data.showFPS;
		#end

		#if html5
		FlxG.autoPause = false;
		#end

		FlxG.mouse.useSystemCursor = true;
		FlxG.mouse.visible = true;
		
		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(onFatalCrash);
		#end
		#end
	}

	public static function resizeWindow(w:Float = 720, h:Float = 720)
	{
		FlxG.resizeWindow(Std.int(w), Std.int(h));
		FlxG.resizeGame(Std.int(w), Std.int(h));
		CoolUtil.centerWindow();
	}

	private function initHaxeUI()
	{
		// HAXEUI !!
		Toolkit.init();
		Toolkit.theme = haxe.ui.themes.Theme.DARK;
		Toolkit.autoScale = true;

		haxe.ui.focus.FocusManager.instance.autoFocus = false;
		haxe.ui.focus.FocusManager.instance.enabled = true;
		haxe.ui.tooltips.ToolTipManager.defaultDelay = 200;
	}

	public static function setWindowIcon(path:String):Void
	{
		var icon:Image = Image.fromFile(path);
		Lib.application.window.setIcon(icon);
	}

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "TIME_" + dateNow + ".txt";

		errMsg += '${e.error}\n';

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += 'in ${file} (line ${line})\n';
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\n\n> Crash Handler written by: squirra-rng and EliteMasterEric";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		DiscordClient.shutdown();
		Sys.exit(1);
	}

	// ELITEMASTERERIC I FUCKING LOVE YOU
	function onFatalCrash(msg:String):Void 
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "TIME_" + dateNow + ".txt";

		errMsg += '${msg}\n';

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += 'in ${file} (line ${line})\n';
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\n\n> Crash Handler written by: squirra-rng and EliteMasterEric";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		DiscordClient.shutdown();
		Sys.exit(1);
	}
	#end
}
