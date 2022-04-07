package charter;

import openfl.net.FileReference;
import haxe.Json;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import lime.media.AudioBuffer;
import mod_support_stuff.ContextMenu;
import dev_toolbox.toolbox_tabs.SongTab;
import openfl.utils.Assets;
import MusicBeatState.FlxSpriteTypedGroup;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import EngineSettings.Settings;
import flixel.text.FlxText;
import Section.SwagSection;
import openfl.geom.Rectangle;
import flixel.addons.display.FlxGridOverlay;
import flixel.system.FlxSound;
import Song.SwagSong;
import flixel.*;
import flixel.addons.ui.*;

using StringTools;

/*
 * Why do i feel like this is going to be ported into Psych in no time
 */
class YoshiCrafterCharter extends MusicBeatState {
    public var _file:FileReference;
    public var notes:Array<CharterNote> = [];
    public static var _song:SwagSong;

    public var vocals:FlxSound;

    var grid:FlxSprite;
    var gridLightUp:FlxSprite;
	public static var GRID_SIZE:Int = 40;

    var hitsound:FlxSound;

    var section(get, null):SwagSection;

    function get_section() {
        return getSectionFor(Conductor.songPosition);
    };
	
	function getSectionFor(t:Float) {
		return _song.notes[Math.floor(t / (Conductor.crochet * 4))];
	}

    var followThing:FlxSprite;

    var playing = false;

    var iconP1:HealthIcon;
    var iconP2:HealthIcon;

    var strums:Array<CharterStrum> = [];

    var statusText:FlxText;

    var topView:Bool = Settings.engineSettings.data.charter_topView;
    var showStrums:Bool = Settings.engineSettings.data.charter_showStrums;
    // var hitsoundsEnabled:Bool = Settings.engineSettings.data.charter_hitsoundsEnabled;
    var hitsoundsBFEnabled:Bool = Settings.engineSettings.data.charter_hitsoundsEnabledBF;
    var hitsoundsDadEnabled:Bool = Settings.engineSettings.data.charter_hitsoundsEnabledGF;
    var topViewCheckbox:FlxUICheckBox = null;
    var showStrumsCheckbox:FlxUICheckBox = null;
    var hitsoundsEnabledCheckbox:FlxUICheckBox = null;
    var hitsoundsBFCheckbox:FlxUICheckBox = null;
    var hitsoundsDadCheckbox:FlxUICheckBox = null;
    var showInstWaveformCheckbox:FlxUICheckBox = null;
    var showVoicesWaveformCheckbox:FlxUICheckBox = null;
    var noteInCreation:CharterNote = null;

    var instBuffer:AudioBuffer;
    var voicesBuffer:AudioBuffer;

    var pageSwitchLerpRemaining:Float = 0;

    var noteColors:Array<FlxColor> = [
		FlxColor.fromRGB(255,111,111),
		FlxColor.fromRGB(125,255,111),
		FlxColor.fromRGB(111,201,255),
		FlxColor.fromRGB(255,255,111),
		FlxColor.fromRGB(219,111,255),
		FlxColor.fromRGB(111,248,255),
		FlxColor.fromRGB(111,111,255),
	];

    var copiedSection:Int = -1;

    var UI_Menu:FlxUITabMenu;
    
    var instWaveform:WaveformSprite;
    var voicesWaveform:WaveformSprite;

    var noteTypesObjs:Array<FlxSprite> = [];
    var noteTypesX:Float = 0;
    var noteTypesY:Float = 0;
    public function new() {
        super();
        if (PlayState._SONG == null) {
            PlayState.songMod = "Friday Night Funkin'";
            PlayState.storyDifficulty = "hard";
            CoolUtil.loadSong("Friday Night Funkin'", "MILF", "Hard");
        }
        PlayState.checkSong();
        _song = PlayState._SONG;
        ChartingState_New._song = _song;
        Conductor.changeBPM(_song.bpm);
    }

    public function compile() { // out of ideas for a func name
        for (s in _song.notes) {
            s.sectionNotes = []; // resets
        }
        for(s in notes) {
            if (s.noteData >= 0) {
                // normal note
                var noteType = Math.floor(s.noteData / (_song.keyNumber * 2));
                // var strum = s.noteData;
                var strum = s.x / GRID_SIZE; // horrible calculations but at least it works
                var section = _song.notes[Math.floor((Math.ceil(s.strumTime / 10) * 10) / (Conductor.crochet * 4))];
                if (section == null) {
                    _song.notes[Math.floor((Math.ceil(s.strumTime / 10) * 10) / (Conductor.crochet * 4))] = (section = {
                        mustHitSection: true,
                        typeOfSection: 1,
                        sectionNotes: [],
                        lengthInSteps: 16,
                        bpm: 0,
                        changeBPM: false,
                        altAnim: false
                    });
                }
                var mustHitSection = section.mustHitSection;
                if (mustHitSection) strum += _song.keyNumber;
                var noteData = (noteType * _song.keyNumber * 2) + (strum % (_song.keyNumber * 2));
                section.sectionNotes.push([s.strumTime, noteData, s.sustainLength]);
            } else {
                // event note, TODO
            }
        }
    }

    public override function create() {
        Conductor.songPosition = 0;
        Conductor.songPositionOld = 0;
        
		Assets.loadLibrary("shared");
        
        var bg = CoolUtil.addBG(this);
        bg.scrollFactor.set(0, 0);

        var instPath = Paths.modInst(_song.song, PlayState.songMod, PlayState.storyDifficulty);
        FlxG.sound.playMusic(instPath);
        @:privateAccess
        instBuffer = AudioBuffer.fromFile(Assets.getPath(instPath));
        FlxG.sound.music.pause();
        FlxG.sound.music.looped = false;
        FlxG.sound.music.onComplete = function() {
            playing = false;
        }

        var voicesPath = Paths.modVoices(_song.song, PlayState.songMod, PlayState.storyDifficulty);
        vocals = new FlxSound().loadEmbedded(voicesPath);
        @:privateAccess
        voicesBuffer = AudioBuffer.fromFile(Assets.getPath(voicesPath));

        updateGrid();
        generateNotes();

        followThing = new FlxSprite(0, 0).makeGraphic(GRID_SIZE * 8, 5, 0xFFFFFFFF);
        FlxG.camera.follow(followThing);
        FlxG.camera.targetOffset.y += topView ? ((FlxG.height * 0.25) + GRID_SIZE) : GRID_SIZE;
        FlxG.camera.targetOffset.x += 150;
        insert(members.indexOf(strums[0]), followThing);

        iconP1 = new HealthIcon(CoolUtil.getCharacterFull(_song.player1, PlayState.songMod).join(":"));
        iconP2 = new HealthIcon(CoolUtil.getCharacterFull(_song.player2, PlayState.songMod).join(":"));
        iconP1.x = ((grid.width - GRID_SIZE) * 0.75) - 75;
        iconP2.x = ((grid.width - GRID_SIZE) * 0.25) - 75;
        iconP1.scrollFactor.x = 1;
        iconP1.scrollFactor.y = 0;
        iconP2.scrollFactor.x = 1;
        iconP2.scrollFactor.y = 0;
        add(iconP1);
        add(iconP2);

        iconP1.flipX = true;

        create_ui();

        hitsound = new FlxSound().loadEmbedded(Paths.sound('hitsound', 'shared')); // it's the osu hitsound in case you're wondering
        //hitsound.persist = true;
        hitsound.autoDestroy = false;

        super.create();
    }

    public function create_ui() {
        statusText = new FlxText(10, 55, 0, "Section:\nBeat:\nStep:", 16); // 55 cause fps thing
        statusText.scrollFactor.set(0, 0);
		statusText.setBorderStyle(FlxTextBorderStyle.OUTLINE, 0xFF000000, 1, 1);
        add(statusText);


        UI_Menu = new FlxUITabMenu(null, [
            {
                name: 'song',
                label: "Song"
            },
            {
                name: 'settings',
                label: "Settings"
            },
            {
                name: 'note',
                label: "Note"
            },
            {
                name: 'section',
                label: "Section"
            }
        ], true);
        UI_Menu.x = FlxG.width - 300;
        UI_Menu.y = 0;
        UI_Menu.resize(300, FlxG.height);
        UI_Menu.scrollFactor.set(0, 0);
        add(UI_Menu);

        addNoteTab();
        addSongTab();
		addCharterSettingsTab();
        addSectionTab();
    }
	
    var voicesWaveformSection:Int = -10;
    var instWaveformSection:Int = -10;
    var playbackSpeedLabel:FlxText;

    var sectionTabSection:Int = -1;
    var mustHitSection:FlxUICheckBox = null;

    public function addSectionTab() {
        var sectionTab = new FlxUI(null, UI_Menu);
        sectionTab.name = "section";

        var label = new FlxUIText(10, 10, 280, "== Section Settings ==");
        label.alignment = CENTER;
        mustHitSection = new FlxUICheckBox(10, label.y + label.height + 10, null, null, "Must Hit Section", 280, null, function() {
            section.mustHitSection = mustHitSection.checked;
        });

        sectionTab.add(label);
        sectionTab.add(mustHitSection);
        UI_Menu.addGroup(sectionTab);
    }
	public function addCharterSettingsTab() {
		var settingsTab = new FlxUI(null, UI_Menu);
		settingsTab.name = "settings";
		
		

		var y:Float = 10;
        topViewCheckbox = new FlxUICheckBox(10, y, null, null, "Vertically center charter", 250, null, function() {
            topView = Settings.engineSettings.data.charter_topView = !topViewCheckbox.checked;
        });
        topViewCheckbox.scrollFactor.set(0, 0);
        topViewCheckbox.checked = !topView;
		y += topViewCheckbox.height + 10;
        settingsTab.add(topViewCheckbox);

        showStrumsCheckbox = new FlxUICheckBox(10, y, null, null, "Show strums", 250, null, function() {
            for(s in strums) s.visible = showStrums = Settings.engineSettings.data.charter_showStrums = showStrumsCheckbox.checked;
        });
        showStrumsCheckbox.scrollFactor.set(0, 0);
        showStrumsCheckbox.checked = showStrums;
		y += showStrumsCheckbox.height + 10;
        settingsTab.add(showStrumsCheckbox);

        hitsoundsEnabledCheckbox = new FlxUICheckBox(10, y, null, null, "Enable hitsounds", 250, null, function() {
            hitsoundsBFEnabled = hitsoundsDadEnabled = Settings.engineSettings.data.charter_hitsoundsEnabledBF = Settings.engineSettings.data.charter_hitsoundsEnabledGF = hitsoundsEnabledCheckbox.checked;
            hitsoundsBFCheckbox.checked = hitsoundsDadCheckbox.checked = hitsoundsEnabledCheckbox.checked;
        });
        hitsoundsEnabledCheckbox.scrollFactor.set(0, 0);
        hitsoundsEnabledCheckbox.checked = hitsoundsBFEnabled && hitsoundsDadEnabled;
		y += hitsoundsEnabledCheckbox.height;
        settingsTab.add(hitsoundsEnabledCheckbox);

        hitsoundsBFCheckbox = new FlxUICheckBox(10 + (hitsoundsEnabledCheckbox.width / 2), y, null, null, "For the Player", 105, null, function() {
            hitsoundsBFEnabled = hitsoundsBFCheckbox.checked;
            hitsoundsEnabledCheckbox.checked = hitsoundsBFEnabled && hitsoundsDadEnabled;
        });
        hitsoundsBFCheckbox.scrollFactor.set(0, 0);
        hitsoundsBFCheckbox.checked = hitsoundsBFEnabled;
        settingsTab.add(hitsoundsBFCheckbox);

        hitsoundsDadCheckbox = new FlxUICheckBox(10, y, null, null, "For the Opponent", 105, null, function() {
            hitsoundsDadEnabled = hitsoundsDadCheckbox.checked;
            hitsoundsEnabledCheckbox.checked = hitsoundsBFEnabled && hitsoundsDadEnabled;
        });
        hitsoundsDadCheckbox.scrollFactor.set(0, 0);
        hitsoundsDadCheckbox.checked = hitsoundsDadEnabled;
        settingsTab.add(hitsoundsDadCheckbox);
		y += hitsoundsDadCheckbox.height + 10;

        showInstWaveformCheckbox = new FlxUICheckBox(10, y, null, null, "Show Instrumental Waveform", 250, null, function() {
			Settings.engineSettings.data.charter_showInstWaveform = showInstWaveformCheckbox.checked;
            instWaveform.visible = Settings.engineSettings.data.charter_showInstWaveform;
            if (instWaveform.visible) instWaveform.generateFlixel((Math.floor(Conductor.songPosition / (Conductor.crochet * 4)) - 1) * (Conductor.crochet * 4), (Math.floor(Conductor.songPosition / (Conductor.crochet * 4)) + 1) * (Conductor.crochet * 4));
        });
        showInstWaveformCheckbox.scrollFactor.set(0, 0);
        showInstWaveformCheckbox.checked = Settings.engineSettings.data.charter_showInstWaveform;
        settingsTab.add(showInstWaveformCheckbox);
		y += showInstWaveformCheckbox.height + 10;

        showVoicesWaveformCheckbox = new FlxUICheckBox(10, y, null, null, "Show Voices Waveform", 250, null, function() {
			Settings.engineSettings.data.charter_showVoicesWaveform = showVoicesWaveformCheckbox.checked;
            voicesWaveform.visible = Settings.engineSettings.data.charter_showVoicesWaveform;
            if (voicesWaveform.visible) voicesWaveform.generateFlixel((Math.floor(Conductor.songPosition / (Conductor.crochet * 4)) - 1) * (Conductor.crochet * 4), (Math.floor(Conductor.songPosition / (Conductor.crochet * 4)) + 1) * (Conductor.crochet * 4));
        });
        showVoicesWaveformCheckbox.scrollFactor.set(0, 0);
        showVoicesWaveformCheckbox.checked = Settings.engineSettings.data.charter_showVoicesWaveform;
        settingsTab.add(showVoicesWaveformCheckbox);
		y += showVoicesWaveformCheckbox.height + 10;
		
		var chooseInstWaveColorButton:FlxUIButton = new FlxUIButton(10, y, "Choose Inst Waveform color", function() {
			persistentUpdate = false;
			persistentDraw = true;
			openSubState(new dev_toolbox.ColorPicker(instWaveform.color, function(newColor) {
				instWaveform.color = Settings.engineSettings.data.charter_instWaveformColor = newColor;
			}));
		});
		chooseInstWaveColorButton.resize(145, chooseInstWaveColorButton.height);
        chooseInstWaveColorButton.scrollFactor.set(0, 0);
        settingsTab.add(chooseInstWaveColorButton);
		
		var chooseVoicesWaveColorButton:FlxUIButton = new FlxUIButton(155, y, "Choose Voices Waveform color", function() {
			persistentUpdate = false;
			persistentDraw = true;
			openSubState(new dev_toolbox.ColorPicker(voicesWaveform.color, function(newColor) {
				voicesWaveform.color = Settings.engineSettings.data.charter_voicesWaveformColor = newColor;
			}));
		});
		chooseVoicesWaveColorButton.resize(145, chooseVoicesWaveColorButton.height);
        chooseVoicesWaveColorButton.scrollFactor.set(0, 0);
        y += chooseVoicesWaveColorButton.height;
        settingsTab.add(chooseVoicesWaveColorButton);

        // var instVolume = new FlxUISlider(FlxG.sound.music, "volume", 10, 10, y, 0, 1, 280, 20, 5);
		// y += instVolume.height;
        // settingsTab.add(instVolume);

        var instVolumeLabel = new FlxUIText(10, y, 135, "Inst Volume");
        var instVolume = new FlxUISliderNew(10, y + instVolumeLabel.height, 135, 7, Settings.engineSettings.data, "charter_instVolume", 0, 1, "0%", "100%");

        var voicesVolumeLabel = new FlxUIText(155, y, 135, "Vocals Volume");
        var voicesVolume = new FlxUISliderNew(155, y + voicesVolumeLabel.height, 135, 7, Settings.engineSettings.data, "charter_voicesVolume", 0, 1, "0%", "100%");

        y += voicesVolumeLabel.height + voicesVolume.height;
        y = Std.int(y) + 10;

        var opponentHitsoundVolumeLabel = new FlxUIText(10, y, 135, "Opponent Hit Volume");
        var opponentHitsoundVolume = new FlxUISliderNew(10, y + opponentHitsoundVolumeLabel.height, 135, 7, Settings.engineSettings.data, "charter_opponentHitsoundVolume", 0, 1, "0%", "100%");

        var playerHitsoundVolumeLabel = new FlxUIText(155, y, 135, "Player Hit Volume");
        var playerHitsoundVolume = new FlxUISliderNew(155, y + voicesVolumeLabel.height, 135, 7, Settings.engineSettings.data, "charter_playerHitsoundVolume", 0, 1, "0%", "100%");
        y += playerHitsoundVolumeLabel.height + playerHitsoundVolume.height + 10;
        y = Std.int(y);
        
        playbackSpeedLabel = new FlxUIText(10, y, 280, 'Playback Speed (1.00x)');
        var playbackSpeedSlider = new FlxUISliderNew(10, y + playbackSpeedLabel.height, 280, 7, FlxG.sound.music, "pitch", 0.25, 5, "0.25x", "5.00x");
        playbackSpeedSlider.step = 0.25;

        settingsTab.add(instVolumeLabel);
        settingsTab.add(instVolume);
        settingsTab.add(voicesVolumeLabel);
        settingsTab.add(voicesVolume);
        settingsTab.add(opponentHitsoundVolumeLabel);
        settingsTab.add(opponentHitsoundVolume);
        settingsTab.add(playerHitsoundVolumeLabel);
        settingsTab.add(playerHitsoundVolume);
        settingsTab.add(playbackSpeedLabel);
        settingsTab.add(playbackSpeedSlider);
		
		UI_Menu.addGroup(settingsTab);
	}

    var noteTab:FlxUI;
    var currentNoteType:Int = 0;
    public function addNoteTab() {
        noteTab = new FlxUI(null, UI_Menu);
        noteTab.name = "note";

        var typesLabel = new FlxUIText(10, 10, 280, "== Note Types ==");
        var addNoteTypeButton = new FlxUIButton(10, typesLabel.y + typesLabel.height + 10, "Add Note Type", function() {
            openSubState(new NoteTypeSelector(function(mod:String, type:String) {
                _song.noteTypes.push('$mod:$type');
                updateNoteTypes();
                updateNoteColors();
            }));
        });
        noteTypesX = typesLabel.x;
        noteTypesY = typesLabel.y + typesLabel.height + 10;


        updateNoteTypes();
        noteTab.add(addNoteTypeButton);
        noteTab.add(typesLabel);
        UI_Menu.addGroup(noteTab);
    }

    public function updateNoteTypes() {
        for(e in noteTypesObjs) {
            noteTab.remove(e);
            remove(e);
            e.destroy();
        }
        noteTypesObjs = [];
        if (currentNoteType >= _song.noteTypes.length) currentNoteType = 0;
        for(k=>e in _song.noteTypes) {
            var b = new FlxUIButton(10, (k * 20) + 65, currentNoteType == k ? '> $e <' : e, function() {
                currentNoteType = k;
                updateNoteTypes();
            });
            b.resize(260, 20);
            var deleteButton = new FlxUIButton(270, (k * 20) + 65, "", function() {
                _song.noteTypes.remove(e);
                if (_song.noteTypes.length <= 0)  _song.noteTypes.push("Friday Night Funkin':Default Note");
                updateNoteTypes();
            });
            deleteButton.resize(20, 20);
            deleteButton.color = 0xFFFF4444;

            var deleteButtonIcon = new FlxSprite(270 + 2, (k * 20) + 67).loadGraphic(Paths.image("uiIcons", "preload"), true, 16, 16);
            deleteButtonIcon.animation.add("bin", [2], 1, true);
            deleteButtonIcon.animation.play("bin");

            if (k > 0) {
                var color:FlxColor = 0xFFFF8888;
                color.hue = (k - 1) / (_song.noteTypes.length - 1);
                deleteButton.label.color = color;
                deleteButton.label.borderStyle = OUTLINE;
                deleteButton.label.borderColor = 0xFF000000;
            }
            noteTypesObjs.push(b);
            noteTab.add(b);
            noteTypesObjs.push(deleteButton);
            noteTab.add(deleteButton);
            noteTypesObjs.push(deleteButtonIcon);
            noteTab.add(deleteButtonIcon);
        }
    }

    public function addSongTab() {
        var songTab = new FlxUI(null, UI_Menu);
        songTab.name = "song";

        var titleLabel:FlxUIText = new FlxUIText(10, 10, 280, "== Song Settings ==");
        titleLabel.alignment = CENTER;

        var bpmThing:FlxUINumericStepper = new FlxUINumericStepper(290, titleLabel.y + 10, 1, 120, 1, 999, 0);
        bpmThing.x -= bpmThing.width;
        bpmThing.name = "bpm";
        bpmThing.value = _song.bpm;
        var bpmLabel:FlxUIText = new FlxUIText(10, bpmThing.y + (bpmThing.height / 2), 200, "BPM (Beats per minute)");
        bpmLabel.y -= bpmLabel.height / 2;

        var scrollSpeedThing:FlxUINumericStepper = new FlxUINumericStepper(290, bpmThing.y + bpmThing.height + 2, 0.1, 2, 0.1, 10, 1);
        scrollSpeedThing.x -= scrollSpeedThing.width;
        scrollSpeedThing.name = "scrollSpeed";
        scrollSpeedThing.value = _song.speed;
        var scrollSpeedLabel:FlxUIText = new FlxUIText(10, scrollSpeedThing.y + (scrollSpeedThing.height / 2), 200, "Scroll Speed");
        scrollSpeedLabel.y -= scrollSpeedLabel.height / 2;

        var keyNumberThing:FlxUINumericStepper = new FlxUINumericStepper(290, scrollSpeedThing.y + scrollSpeedThing.height + 2, 1, 4, 1, 100, 0);
        keyNumberThing.value = _song.keyNumber;
        keyNumberThing.name = "keyNumber";
        keyNumberThing.x -= keyNumberThing.width;
        var keyNumberLabel:FlxUIText = new FlxUIText(10, keyNumberThing.y + (keyNumberThing.height / 2), 200, "Key Number (needs refresh)");
        keyNumberLabel.y -= keyNumberLabel.height / 2;
        var hasVocalsTrack:FlxUICheckBox = null;
        hasVocalsTrack = new FlxUICheckBox(10, keyNumberThing.y + keyNumberThing.height + 10, null, null, "Need Voices", 280, null, function() {
            _song.needsVoices = hasVocalsTrack.checked;
        });
        hasVocalsTrack.checked = _song.needsVoices;

        var p1 = _song.player1.split(":");
        if (p1.length < 2) p1.insert(0, '');
        var player1Label:FlxUIText = new FlxUIText(155, hasVocalsTrack.y + hasVocalsTrack.height + 10, 135, p1.join("\n"));
        player1Label.alignment = CENTER;
        var changePlayer1Button:FlxUIButton = new FlxUIButton(player1Label.x, player1Label.y + player1Label.height + 5, "Change Player", function() {
            openSubState(new ChooseCharacterScreen(function(mod, char) {
                _song.player1 = '$mod:$char';
                iconP1.changeCharacter(char, mod);
                player1Label.text = '$mod\n$char';
            }));
        });
        changePlayer1Button.resize(135, 20);

        var p2 = _song.player2.split(":");
        if (p2.length < 2) p2.insert(0, '');
        var player2Label:FlxUIText = new FlxUIText(10, player1Label.y, 135, p2.join("\n"));
        player2Label.alignment = CENTER;
        var changePlayer2Button:FlxUIButton = new FlxUIButton(player2Label.x, player2Label.y + player2Label.height + 5, "Change Opponent", function() {
            openSubState(new ChooseCharacterScreen(function(mod, char) {
                _song.player2 = '$mod:$char';
                iconP2.changeCharacter(char, mod);
                player2Label.text = '$mod\n$char';
            }));
        });
        changePlayer2Button.resize(135, 20);
        
        var refreshButton = new FlxUIButton(10, changePlayer2Button.y + changePlayer2Button.height + 10, "Refresh", function() {
            compile();
            PlayState._SONG = _song;
            FlxG.resetState();
        });
        
        var saveButton = new FlxUIButton(refreshButton.x + refreshButton.width + 10, changePlayer2Button.y + changePlayer2Button.height + 10, "Save", function() {
            _song.validScore = true;
            var references = false;
            var json = {
                "song": _song
            };
            var oldArray = _song.noteTypes;
            if (!references) {
                var player1split = json.song.player1.split(":");
                if (player1split[0] == PlayState.songMod || player1split[0] == "Friday Night Funkin'")
                    json.song.player1 = player1split[1];

                var player2split = json.song.player2.split(":");
                if (player2split[0] == PlayState.songMod || player2split[0] == "Friday Night Funkin'")
                    json.song.player2 = player2split[1];

                oldArray = [];
                for (k=>v in json.song.noteTypes) {
                    oldArray[k] = v;
                    var typeSplit = v.split(":");
                    if ((typeSplit[0] == PlayState.songMod || typeSplit[0] == "Friday Night Funkin'") && typeSplit.length > 1)
                        json.song.noteTypes[k] = typeSplit[1];
                }
            }

            var data:String = Json.stringify(json);

            if ((data != null) && (data.length > 0))
            {
                _file = new FileReference();
                _file.addEventListener(Event.COMPLETE, onSaveComplete);
                _file.addEventListener(Event.CANCEL, onSaveCancel);
                _file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
                _file.save(data.trim(), _song.song.toLowerCase() + ".json");
            }

            _song.noteTypes = oldArray;
        });


        songTab.add(titleLabel);
        songTab.add(bpmThing);
        songTab.add(bpmLabel);
        songTab.add(scrollSpeedThing);
        songTab.add(scrollSpeedLabel);
        songTab.add(keyNumberThing);
        songTab.add(keyNumberLabel);
        songTab.add(player1Label);
        songTab.add(changePlayer1Button);
        songTab.add(player2Label);
        songTab.add(changePlayer2Button);
        songTab.add(refreshButton);
        songTab.add(saveButton);
        UI_Menu.addGroup(songTab);
    }

    function onSaveComplete(_):Void
        {
            _file.removeEventListener(Event.COMPLETE, onSaveComplete);
            _file.removeEventListener(Event.CANCEL, onSaveCancel);
            _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
            _file = null;
            FlxG.log.notice("Successfully saved LEVEL DATA.");
        }
    
        /**
         * Called when the save file dialog is cancelled.
         */
        function onSaveCancel(_):Void
        {
            _file.removeEventListener(Event.COMPLETE, onSaveComplete);
            _file.removeEventListener(Event.CANCEL, onSaveCancel);
            _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
            _file = null;
        }
    
        /**
         * Called if there is an error while saving the gameplay recording.
         */
        function onSaveError(_):Void
        {
            _file.removeEventListener(Event.COMPLETE, onSaveComplete);
            _file.removeEventListener(Event.CANCEL, onSaveCancel);
            _file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
            _file = null;
            FlxG.log.error("Problem saving Level data");
        }
        
    public function generateNotes() {
        for (s in _song.notes) {
            for(n in s.sectionNotes) {
                addNote(n[0], n[1], s.mustHitSection, n[2]);
            }
        }
    }

    public function addNote(strumTime:Float, noteData:Int, mustHitSection:Bool = false, sustainLength:Float = 0) {
        var note = new CharterNote(strumTime, noteData, null, false, mustHitSection, sustainLength);
        note.y = strumTime / Conductor.stepCrochet * GRID_SIZE;
        var xPos = noteData;
        if (mustHitSection) xPos += _song.keyNumber;
        xPos %= (_song.keyNumber * 2);
        note.x = xPos * GRID_SIZE;
        add(note);
        notes.push(note);
        note.setGraphicSize(GRID_SIZE, GRID_SIZE);
        note.updateHitbox();
        // if (note.noteType > 0)
        //     note.color = noteColors[(note.noteType - 1) % noteColors.length];
        updateNoteColor(note);
        return note;
    }

    public function updateNoteColors() {
        for(n in notes)
            updateNoteColor(n);
    }

    public function updateNoteColor(n:CharterNote) {
        if (n.noteType <= 0) {
            n.color = 0xFFFFFFFF;
            return;
        }
        var color = FlxColor.fromRGB(255, 100, 100);
        color.hue = (((n.noteType - 1) / (_song.noteTypes.length - 1)) * 360) % 360;
        n.color = color;
        if (n.sustainSprite != null) {
            n.sustainSprite.color = color;
        }
    }

    public function removeNote(note:CharterNote) {
        notes.remove(note);
        remove(note);
        note.destroy();
    }

    public function updateGrid() {
        grid = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * (_song.keyNumber * 2 + 1), Math.ceil(FlxG.height / (GRID_SIZE * 16)) * 2 * (GRID_SIZE * 16), true, 0x88888888, 0x88444444);
        grid.x = -GRID_SIZE;
        grid.pixels.lock();
        grid.pixels.fillRect(new Rectangle(GRID_SIZE - 1, 0, 2, grid.pixels.height), 0x88FFFFFF);
        grid.pixels.fillRect(new Rectangle(GRID_SIZE + (GRID_SIZE * _song.keyNumber) - 1, 0, 2, grid.pixels.height), 0x88FFFFFF);
        for(i in 0...Math.floor(grid.pixels.height / (GRID_SIZE * 16))) {
            grid.pixels.fillRect(new Rectangle(0, (GRID_SIZE * 16 * (i + 1)) - 2, grid.pixels.width, 4), 0xAAFFFFFF);
        }
        grid.pixels.unlock();
        add(grid);

        gridLightUp = new FlxSprite(0, 0).makeGraphic(GRID_SIZE * _song.keyNumber, FlxG.height, 0xFFFFFFFF);
        gridLightUp.alpha = 0.3;
        gridLightUp.scrollFactor.set(1, 0);
        add(gridLightUp);

        instWaveform = new WaveformSprite((grid.width - GRID_SIZE) / 2, 0, instBuffer, GRID_SIZE * 4, GRID_SIZE * 48);
        // instWaveform.scrollFactor.set(1, 1);
        instWaveform.color = Settings.engineSettings.data.charter_instWaveformColor;
        instWaveform.origin.set(0, 0);
        instWaveform.alpha = 0.85;
        instWaveform.x -= instWaveform.width / 2;
        add(instWaveform);
        instWaveform.generateFlixel( -Conductor.crochet * 4, Conductor.crochet * 4);
		instWaveform.visible = Settings.engineSettings.data.charter_showInstWaveform;

        voicesWaveform = new WaveformSprite((grid.width - GRID_SIZE) / 2, 0, voicesBuffer, GRID_SIZE * 4, GRID_SIZE * 48);
        // voicesWaveform.scrollFactor.set(1, 1);
        voicesWaveform.color = Settings.engineSettings.data.charter_voicesWaveformColor;
        voicesWaveform.origin.set(0, 0);
        voicesWaveform.alpha = 0.85;
        voicesWaveform.x -= voicesWaveform.width / 2;
        add(voicesWaveform);
        voicesWaveform.generateFlixel(-Conductor.crochet * 4, Conductor.crochet * 4);
		voicesWaveform.visible = Settings.engineSettings.data.charter_showVoicesWaveform;

        // add strums
        for (e in strums) {
            remove(e);
            e.destroy();
        }
        strums = [];
        for(i in 0...(_song.keyNumber * 2)) {
            var s = new CharterStrum(i * GRID_SIZE, 0, i);
            add(s);
            strums.push(s);
        }

        if (followThing != null) {
            remove(followThing);
            insert(members.indexOf(strums[0]), followThing);
        }
    }

    public function switchToPlayState() {
        compile();
        
        PlayState._SONG = _song;
        PlayState._SONG.validScore = false;
        PlayState.fromCharter = true;
        FlxG.sound.music.stop();
        vocals.stop();
        FlxG.switchState(new PlayState());
    }
    public function moveCursor(steps:Float) {
        if (playing) {
            playing = false;
            FlxG.sound.music.pause();
            vocals.pause();
        }
        FlxG.sound.music.time = vocals.time = (Conductor.songPosition += steps * Conductor.stepCrochet);
    }
    public override function update(elapsed:Float) {

        super.update(elapsed);
        playbackSpeedLabel.text = 'Playback Speed (${Std.string(FlxG.sound.music.pitch)}x)';
        if (playing) {
            pageSwitchLerpRemaining = 0;
        } else {
            var val = CoolUtil.wrapFloat(pageSwitchLerpRemaining * 0.40 * 60 * elapsed, pageSwitchLerpRemaining < 0 ? pageSwitchLerpRemaining : 0, pageSwitchLerpRemaining > 0 ? pageSwitchLerpRemaining : 0);
            vocals.time = FlxG.sound.music.time = (Conductor.songPosition += val);
            pageSwitchLerpRemaining -= val;
            if (Conductor.songPosition < 0) {
                pageSwitchLerpRemaining = 0;
                Conductor.songPosition = 0;
            }
        }
		
        grid.y = Math.max(0, Math.floor(Conductor.songPosition / (Conductor.crochet * 4)) * GRID_SIZE * 16) + ((Conductor.songPosition < Conductor.crochet * 4) ? 0 : -GRID_SIZE * 16);
        voicesWaveform.y = instWaveform.y = (Math.floor(Conductor.songPosition / (Conductor.crochet * 4)) * GRID_SIZE * 16) + (-GRID_SIZE * 16);
        if (instWaveform.visible) {
            var curSection = Math.floor(Conductor.songPosition / (Conductor.crochet * 4));
            if (curSection != instWaveformSection) {
                instWaveformSection = curSection;
                instWaveform.generateFlixel((Math.floor(Conductor.songPosition / (Conductor.crochet * 4)) - 1) * (Conductor.crochet * 4), (Math.floor(Conductor.songPosition / (Conductor.crochet * 4)) + 2) * (Conductor.crochet * 4));
            }
        }
        if (voicesWaveform.visible) {
            var curSection = Math.floor(Conductor.songPosition / (Conductor.crochet * 4));
            if (curSection != voicesWaveformSection) {
                voicesWaveformSection = curSection;
                voicesWaveform.generateFlixel((Math.floor(Conductor.songPosition / (Conductor.crochet * 4)) - 1) * (Conductor.crochet * 4), (Math.floor(Conductor.songPosition / (Conductor.crochet * 4)) + 2) * (Conductor.crochet * 4));
            }
        }
		
        FlxG.camera.targetOffset.y = FlxMath.lerp(FlxG.camera.targetOffset.y, topView ? ((FlxG.height * 0.25) + GRID_SIZE) : GRID_SIZE, 0.45 * 60 * elapsed);
        if (FlxG.mouse.justPressed) {
            
            var overlaps = false;
            for(n in notes) {
                if (FlxG.mouse.overlaps(n)) {
                    overlaps = true;
                    removeNote(n);
                }
            }
            if (!overlaps && FlxG.mouse.overlaps(grid)) {
                var strumT = FlxG.mouse.y / GRID_SIZE;
                if (!FlxG.keys.pressed.SHIFT) {
                    strumT = Math.floor(strumT);
                }
				var section = getSectionFor(strumT * Conductor.stepCrochet);
				var mustHit = section != null ? section.mustHitSection : true;
				var noteData = Math.floor(FlxG.mouse.x / GRID_SIZE);
				if (mustHit) {
					noteData = (Math.floor(noteData / (_song.keyNumber * 2)) * _song.keyNumber * 2) + ((noteData + _song.keyNumber) % (_song.keyNumber * 2));
				}
                noteInCreation = addNote(strumT * Conductor.stepCrochet, noteData + (currentNoteType * _song.keyNumber * 2), mustHit);
            }
        }

        var sec = Math.floor(Conductor.songPosition / Conductor.crochet);
        if (sec != sectionTabSection) {
            sectionTabSection = sec;
            mustHitSection.checked = section.mustHitSection;
        }
        if (FlxG.mouse.justPressedRight) {
            if (FlxG.mouse.overlaps(grid)) {
                /*
                var section = Math.floor(FlxG.mouse.y / GRID_SIZE * Conductor.stepCrochet / (Conductor.crochet * 4));
                openSubState(new ContextMenu(FlxG.mouse.screenX, FlxG.mouse.screenY, [{
                    label: 'Copy Section',
                    callback: function() {copiedSection = section;trace(copiedSection);}
                },
                {
                    label: 'Paste',
                    enabled: copiedSection > -1,
                    callback: function() {
                        if (section != copiedSection) {
                            for(n in notes) {
                                if (n.strumTime > (Conductor.crochet * 4 * copiedSection) && n.strumTime < (Conductor.crochet * 4 * (copiedSection + 1))) {
                                    addNote(n.strumTime - (Conductor.crochet * 4 * copiedSection) + (Conductor.crochet * 4 * section), n.noteData, false, n.sustainLength);
                                }
                            }
                        }
                    }
                },
                {
                    label: 'Paste & Override',
                    enabled: copiedSection > -1,
                    callback: function() {
                        if (section != copiedSection) {
                            for(n in notes) {
                                if (n.strumTime > (Conductor.crochet * 4 * section) && n.strumTime < (Conductor.crochet * 4 * (section + 1))) {
                                    removeNote(n);
                                }
                            }
                            for(n in notes) {
                                if (n.strumTime > (Conductor.crochet * 4 * copiedSection) && n.strumTime < (Conductor.crochet * 4 * (copiedSection + 1))) {
                                    addNote(n.strumTime - (Conductor.crochet * 4 * copiedSection) + (Conductor.crochet * 4 * section), n.noteData, false, n.sustainLength);
                                }
                            }
                        }
                    }
                },
                {
                    label: 'Reset section',
                    callback: function() {trace("pog3");}
                }]));
                */
            }
        }
        if (noteInCreation != null) {
            if (FlxG.mouse.justReleased) {
                noteInCreation = null;
            } else {
                var currentTime = FlxG.mouse.y / GRID_SIZE * Conductor.stepCrochet;
                var strumTime = noteInCreation.strumTime;
                var str = Math.max(0, Math.floor((currentTime - strumTime) / Conductor.stepCrochet) * Conductor.stepCrochet);
                if (str > 0) str += Conductor.stepCrochet;
                if (noteInCreation.sustainLength != str) {
                    noteInCreation.sustainLength = str;
                    noteInCreation.updateSustain();
                }
            }
        }
        if (FlxG.keys.justPressed.LEFT) pageSwitchLerpRemaining -= Conductor.crochet * 4 * (FlxG.keys.pressed.SHIFT ? 4 : 1);
        if (FlxG.keys.justPressed.RIGHT) pageSwitchLerpRemaining += Conductor.crochet * 4 * (FlxG.keys.pressed.SHIFT ? 4 : 1);
        pageSwitchLerpRemaining -= FlxG.mouse.wheel * Conductor.stepCrochet * 2;
        if (FlxG.keys.pressed.SHIFT) {
            if (FlxG.keys.pressed.UP) moveCursor(-20 * elapsed);
            if (FlxG.keys.pressed.DOWN) moveCursor(20 * elapsed);
        } else {
            if (FlxG.keys.pressed.UP) moveCursor(-8 * elapsed);
            if (FlxG.keys.pressed.DOWN) moveCursor(8 * elapsed);
        }

        if (FlxG.keys.justPressed.ENTER) {
            switchToPlayState();
        }

        if (section != null) {
            var s = (Conductor.songPosition / Conductor.crochet) % 1;
            if (section.mustHitSection) {
                iconP1.alpha = 1;
                iconP1.scale.set(1.25 - (s * 0.25), 1.25 - (s * 0.25));
                iconP2.alpha = 0.33;
                iconP2.scale.set(1, 1);
                gridLightUp.x = FlxMath.lerp(gridLightUp.x, GRID_SIZE * _song.keyNumber, 0.40 * 60 * elapsed);
            } else {
                iconP2.alpha = 1;
                iconP2.scale.set(1.25 - (s * 0.25), 1.25 - (s * 0.25));
                iconP1.alpha = 0.33;
                iconP1.scale.set(1, 1);
                gridLightUp.x = FlxMath.lerp(gridLightUp.x, 0, 0.40 * 60 * elapsed);
            }
            var multiplicator = 0.60;
            iconP1.scale.x *= multiplicator;
            iconP1.scale.y *= multiplicator;
            iconP2.scale.x *= multiplicator;
            iconP2.scale.y *= multiplicator;
        } else {
            iconP1.scale.set(0.66, 0.66);
            iconP2.scale.set(0.66, 0.66);
            iconP1.alpha = iconP2.alpha = 0.33;
        }
        if (Conductor.songPositionOld != FlxG.sound.music.time) {
            Conductor.songPosition = Conductor.songPositionOld = FlxG.sound.music.time;
        } else {
            if (FlxG.sound.music.playing) Conductor.songPosition += elapsed * 1000 * FlxG.sound.music.pitch;
        }
        // grid.y = -((Conductor.songPosition % (Conductor.crochet * 4)) / (Conductor.crochet * 4) * (GRID_SIZE * 16));
        followThing.y = Conductor.songPosition / (Conductor.crochet * 4) * (GRID_SIZE * 16);
        // instWaveform.y = voicesWaveform.y = followThing.y - (GRID_SIZE * 16);
        for(s in strums) {
            s.y = followThing.y;
        }
        
        for (n in notes) {
            // if (n.active = n.visible = (Math.abs(n.strumTime - Conductor.songPosition) < (FlxG.height * 2) / GRID_SIZE * Conductor.stepCrochet))
            if (n.active = n.visible = (n.y - FlxG.camera.scroll.y + GRID_SIZE + (n.sustainLength / Conductor.stepCrochet * GRID_SIZE) >= 0 && n.y - FlxG.camera.scroll.y <= FlxG.height)) {
                if (n.strumTime <= Conductor.songPosition) {
                    if (n.alpha == 1) {
                        var str = strums[Math.floor(n.x / GRID_SIZE) % (_song.keyNumber * 2)];
                        if (str != null && playing) str.lastHit = 0.1 + (Math.max(0, (n.sustainLength - Conductor.stepCrochet) / 1000) / FlxG.sound.music.pitch);
                        n.alpha = 1 / 3;
                        var mustHit = Math.floor(n.x / GRID_SIZE) >= _song.keyNumber;
                        if (((mustHit && hitsoundsBFEnabled) || (!mustHit && hitsoundsDadEnabled)) && playing) {
                            hitsound.stop();
                            hitsound.volume = mustHit ? Settings.engineSettings.data.charter_playerHitsoundVolume : Settings.engineSettings.data.charter_opponentHitsoundVolume;
                            hitsound.play();
                        }
                    }
                } else {
                    n.alpha = 1;
                }
            }
            if (n.sustainSprite != null) n.sustainSprite.active = n.sustainSprite.visible = n.active && n.sustainLength >= Conductor.stepCrochet / 2;
        }

        if (FlxG.keys.justPressed.SPACE) {
            playing = !playing;
            if (playing) {
                FlxG.sound.music.play();
                vocals.play();
                vocals.time = FlxG.sound.music.time;
                vocals.pitch = FlxG.sound.music.pitch = FlxG.sound.music.pitch; // so that it applies again
            } else {
                FlxG.sound.music.pause();
                vocals.pause();
            }
        }
        FlxG.sound.music.volume = Settings.engineSettings.data.charter_instVolume;
        vocals.volume = Settings.engineSettings.data.charter_voicesVolume;

        if (FlxG.keys.justPressed.R) FlxG.sound.music.pitch -= 0.25;
        if (FlxG.keys.justPressed.T) FlxG.sound.music.pitch += 0.25;
        if (vocals.pitch != FlxG.sound.music.pitch) vocals.pitch = FlxG.sound.music.pitch;

        var m = Math.floor(Conductor.songPosition / 1000 / 60);
        var s = CoolUtil.addZeros(Std.string(Math.floor(Conductor.songPosition / 1000) % 60), 2);

        var mt = Math.floor(FlxG.sound.music.length / 1000 / 60);
        var st = CoolUtil.addZeros(Std.string(Math.floor(FlxG.sound.music.length / 1000) % 60), 2);
        var pitchThing = '${Math.floor(FlxG.sound.music.pitch)}';
        var decimals = Std.string(FlxG.sound.music.pitch % 1);
        var dotPos = -1;
        if ((dotPos = decimals.indexOf(".")) > -1) {
            pitchThing += '.${CoolUtil.addZeros(Std.string(decimals.substr(dotPos + 1)), 2, true)}x';
        } else {
            pitchThing += ".00x";
        }

        statusText.text = '${m}:${s} - ${mt}:${st}\nPlayback Speed: ${pitchThing} (R|T)\nSection: ${Math.floor(curBeat / 4)}\nBeat: ${curBeat}\nStep: ${curStep}';
    }

    public override function onFocusLost() {
        super.onFocusLost();
        if (FlxG.autoPause) {
            vocals.pause();
        }
    }

    public override function onFocus() {
        if (playing) {
            vocals.play();
        }
    }

    public function updateNotesY() {
        for(note in notes) {
            note.y = note.strumTime / Conductor.stepCrochet * GRID_SIZE;
            note.updateSustain();
        }
    }

	public override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
    {
        if (id == FlxUINumericStepper.CHANGE_EVENT) {
            var sender:FlxUINumericStepper = cast(sender, FlxUINumericStepper);
            switch(sender.name) {
                case "bpm":
                    instWaveformSection = voicesWaveformSection = -10;
                    var bpm:Int = Std.int(sender.value);
                    _song.bpm = bpm;
                    Conductor.changeBPM(bpm);
                    updateNotesY();
                case "scrollSpeed":
                    _song.speed = sender.value;
                case "keyNumber":
                    _song.keyNumber = Std.int(sender.value);
            }
        }
    }
}