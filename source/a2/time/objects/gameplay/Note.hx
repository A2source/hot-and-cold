package a2.time.objects.gameplay;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flash.display.BitmapData;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

import a2.time.states.PlayState;
import a2.time.states.editors.ChartingState;
import a2.time.objects.song.Conductor;
import a2.time.util.ClientPrefs;
import a2.time.util.Paths;

import sys.io.File;

using StringTools;

typedef NoteFile =
{
	// note data (left, down, up, right)
	var d:Int;

	// note time in milliseconds
	var ms:Float;

	// note sustain length
	var l:Float;

	// custom notetype
	var t:String;
}

typedef CustomNoteFile =
{
	var name:String;
	var desc:String;

	var texture:String;
}

typedef EventNote = 
{
	var strumTime:Float;

	var event:String;

	var value1:String;
	var value2:String;
	var value3:String;
}

class Note extends FlxSprite
{
	public var extraData:Map<String,Dynamic> = [];

	public var strumTime:Float = 0;
	public var mustPress:Bool = false;
	public var noteData:Int = 0;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var noteWasHit:Bool = false;
	public var prevNote:Note;
	public var nextNote:Note;
	public var mesh:flixel.FlxStrip = null;
	public var z:Float = 0;

	public var spawned:Bool = false;

	public var tail:Array<Note> = []; // for sustains
	public var parent:Note;
	public var blockHit:Bool = false; // only works for player

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var noteType(default, set):String = null;

	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventData:Array<EventNote> = [];
	public var eventVal1:String = '';
	public var eventVal2:String = '';
	public var eventVal3:String = '';

	public var inEditor:Bool = false;

	public var gfNote:Bool = false;
	public var earlyHitMult:Float = 0.5;
	public var lateHitMult:Float = 1;
	public var lowPriority:Bool = false;
	public var coolId:Null<String> = null;

	public static var swagWidth:Float = 160 * 0.7;
	
	private var dirArray:Array<String> = ['left', 'down', 'up', 'right'];
	private var pixelInt:Array<Int> = [0, 1, 2, 3];

	// Lua shit
	public var noteSplashDisabled:Bool = false;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var multAlpha:Float = 1;
	public var multSpeed(default, set):Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var hitHealth:Float = 0.023;
	public var missHealth:Float = 0.0475;
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; //9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	public var ratingDisabled:Bool = false;

	public var texture(default, set):String = null;

	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var hitCausesMiss:Bool = false;
	public var distance:Float = 2000; //plan on doing scroll directions soon -bb

	public var hitsoundDisabled:Bool = false;

	public var func = null;
	public var activated:Bool = false;
	public var funcThreshold:Float = 0;

	public var attachedChar:String;

	public var ignoreNote:Bool = false;

	public var isHoldEnd:Bool = false;

	private function set_multSpeed(value:Float):Float 
	{
		resizeByRatio(value / multSpeed);
		multSpeed = value;
		//trace('fuck cock');
		return value;
	}

	public function resizeByRatio(ratio:Float) //haha funny twitter shit
	{
		if(!isSustainNote)
			return;

		scale.y *= ratio;

		updateHitbox();
	}

	public function setSusOffset()
	{
		if (prevNote == null || prevNote.isSustainNote)
			return;

		var desiredY:Float = prevNote.y + prevNote.height / 2;
		if (ClientPrefs.data.downScroll)
		{
			var diff:Float = y - desiredY + scale.y;

			for (sus in prevNote.tail)
				sus.offsetY = -178 - diff;
		}
		else
		{
			var diff:Float = desiredY - y;

			for (sus in prevNote.tail)
				sus.offsetY = -195 - diff;
		}
	}

	private function set_texture(value:String):String 
	{
		if(texture != value)
			reloadNote('', value);

		texture = value;
		return value;
	}

	private function set_noteType(value:String):String 
	{
		loadCustomNote(value);

		noteType = value;

		return value;
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?inEditor:Bool = false)
	{
		super();

		this.func = null;

		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;
		this.inEditor = inEditor;

		x += (ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50;
		// MAKE SURE ITS DEFINITELY OFF SCREEN?
		y -= 2000;
		this.strumTime = strumTime;
		if(!inEditor) this.strumTime += ClientPrefs.data.noteOffset;

		this.noteData = noteData;

		if(noteData > -1) {
			texture = '';

			x += swagWidth * (noteData);
			if(!isSustainNote && noteData > -1 && noteData < 4) { //Doing this 'if' check to fix the warnings on Senpai songs
				var animToPlay:String = '';
				animToPlay = dirArray[noteData % 4];
				animation.play(animToPlay + 'Scroll');
			}
		}

		// trace(prevNote);

		if(prevNote != null)
			prevNote.nextNote = this;

		var dir:String = dirArray[noteData % 4];

		if (isSustainNote && prevNote != null)
		{
			hitsoundDisabled = true;

			offsetX = 66;
			offsetY = ClientPrefs.data.downScroll ? -175 : -195;

			isHoldEnd = false;

			if (!prevNote.isSustainNote)
				isHoldEnd = true;

			loadGraphic(Paths.image('sustain'));

			if(PlayState.isPixelStage) {
				scale.y *= PlayState.daPixelZoom;
				updateHitbox();
			}
		} else if(!isSustainNote) 
		{
			earlyHitMult = 1;

			if (dir == 'left' || dir == 'right')
			{
				offsetX += 20;
				offsetY -= 30;
			}

			if (dir == 'up')
				offsetY -= 5;
		}

		x += offsetX;
		y += offsetY;
	}

	public function loadCustomNote(name:String):Note
	{
		if (ChartingState.HARDCODED_NOTES.contains(name))
			return this;

		for (mod in Paths.getModDirectories())
		{
			Paths.VERBOSE = false;

			var path = Paths.noteJson(name, mod);
			if (path == null)
				continue;

			var data:CustomNoteFile = haxe.Json.parse(File.getContent(path));

			reloadNote('', data.texture);
		}

		return this;
	}

	var lastNoteOffsetXForPixelAutoAdjusting:Float = 0;
	var lastNoteScaleToo:Float = 1;
	public var originalHeightForCalcs:Float = 6;
	function reloadNote(?prefix:String = '', ?texture:String = '', ?suffix:String = '') 
	{
		if(prefix == null) prefix = '';
		if(texture == null) texture = '';
		if(suffix == null) suffix = '';

		var skin:String = texture;
		if(texture.length < 1) {
			if(skin == null || skin.length < 1) {
				skin = 'NOTE_assets';
			}
		}

		var animName:String = null;
		if(animation.curAnim != null) {
			animName = animation.curAnim.name;
		}

		var arraySkin:Array<String> = skin.split('/');
		arraySkin[arraySkin.length-1] = prefix + arraySkin[arraySkin.length-1] + suffix;

		var lastScaleY:Float = scale.y;
		var blahblah:String = arraySkin.join('/');
		if(PlayState.isPixelStage) {
			if(isSustainNote) {
				loadGraphic(Paths.image('pixelUI/' + blahblah + 'ENDS'));
				width = width / 4;
				height = height / 2;
				originalHeightForCalcs = height;
				loadGraphic(Paths.image('pixelUI/' + blahblah + 'ENDS'), true, Math.floor(width), Math.floor(height));
			} else {
				loadGraphic(Paths.image('pixelUI/' + blahblah));
				width = width / 4;
				height = height / 5;
				loadGraphic(Paths.image('pixelUI/' + blahblah), true, Math.floor(width), Math.floor(height));
			}
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));
			loadPixelNoteAnims();
			antialiasing = false;

			if(isSustainNote) 
			{
				offsetX += lastNoteOffsetXForPixelAutoAdjusting;
				lastNoteOffsetXForPixelAutoAdjusting = (width - 7) * (PlayState.daPixelZoom / 2);
				offsetX -= lastNoteOffsetXForPixelAutoAdjusting;

				/*if(animName != null && !animName.endsWith('end'))
				{
					lastScaleY /= lastNoteScaleToo;
					lastNoteScaleToo = (6 / height);
					lastScaleY *= lastNoteScaleToo;
				}*/
			}
		} 
		else 
		{
			Paths.VERBOSE = false;

			var anyMods:Bool = false;
			for (mod in Paths.getModDirectories())
			{
				var mods = Paths.modsSparrow('images', blahblah, mod);

				if (mods == null)
					continue;
				
				frames = mods;
				anyMods = true;
			}

			if (!anyMods)
				frames = Paths.getSparrowAtlas(blahblah);

			loadNoteAnims();
			antialiasing = ClientPrefs.data.antialiasing;

			Paths.VERBOSE = true;
		}
		if(isSustainNote) {
			scale.y = lastScaleY;
		}
		updateHitbox();

		if(animName != null)
			animation.play(animName, true);

		if(inEditor) {
			setGraphicSize(ChartingState.GRID_SIZE, ChartingState.GRID_SIZE);
			updateHitbox();
		}
	}

	function loadNoteAnims() 
	{
		animation.addByPrefix(dirArray[noteData] + 'Scroll', dirArray[noteData] + '0', 12);

		if (isSustainNote)
		{
			animation.addByPrefix(dirArray[noteData] + 'end', dirArray[noteData] + ' end', 12);
			animation.addByPrefix(dirArray[noteData] + 'hold', dirArray[noteData] + ' hold', 12);
		}

		setGraphicSize(Std.int(width * 0.7));
		updateHitbox();
	}

	function loadPixelNoteAnims() {
		if(isSustainNote) {
			animation.add(dirArray[noteData] + 'end', [pixelInt[noteData] + 4]);
			animation.add(dirArray[noteData] + 'hold', [pixelInt[noteData]]);
		} else {
			animation.add(dirArray[noteData] + 'Scroll', [pixelInt[noteData] + 4]);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// fun stuff
		if (this.func != null)
		{
			if (Conductor.songPosition + this.funcThreshold > strumTime && !activated)
			{
				activated = true;

				trace('activate!');

				this.func();
			}
		}

		if (!inEditor)
			updateNoteStates();

		if (tooLate && !inEditor)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}

	private function updateNoteStates()
	{
		if (mustPress)
		{
			// ok river
			if (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult)
				&& strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
				canBeHit = true;
			else
				canBeHit = false;

			if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit)
				tooLate = true;
		}
		else
		{
			canBeHit = false;

			if (strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
			{
				if((isSustainNote && prevNote.wasGoodHit) || strumTime <= Conductor.songPosition)
					wasGoodHit = true;
			}
		}

		if (Conductor.songPosition + funcThreshold > strumTime && !activated)
		{
			if (func != null)
				func();

			activated = true;
		}
	}

	public override function toString():String
	{
		return '(Strum Time: $strumTime | Data: $noteData | Type: $noteType ${eventData.length > 0 ? '| Event Data: $eventData' : ''})';
	}
}
