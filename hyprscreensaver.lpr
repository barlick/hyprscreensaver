program hyprscreensaver;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, CustApp, process, DateUtils
  { you can add units after this };

type

  { Thyprscreensaver }

  Thyprscreensaver = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ Thyprscreensave }

procedure Thyprscreensaver.DoRun;
var
  ErrorMsg: String;
  finished : boolean;
  getout : boolean;
  swayidledelayseconds : string;
  InitialNumInstancesScreensaverApp : integer;
  lastruntime,thislastruntime : TDateTime;
  AppPath,HomeDir,hyprscreensaver_conf_path_and_filename,hyprscreensaver_lastruntime_path_and_filename,screensaver_folder,screensaver_filename,c_parameters : string;

  function fn_GetNumberOfAppInstancesRunnnig(cmd:String) : integer;
  var
   t:TProcess;
   s:TStringList;
   ct,numinstances : integer;
   thisline : string;
  begin
   result := 0;
   t:=tprocess.create(nil);
   t.Executable:='ps';
   t.Parameters.Clear;
   t.Parameters.Add('-C');
   t.Parameters.Add(cmd);
   t.Options:=[poUsePipes,poWaitonexit];
   try
    t.Execute;
    s:=tstringlist.Create;
    try
     s.LoadFromStream(t.Output);
     if s.Count > 0 then
      begin
       numinstances := 0;
       cmd := uppercase(cmd);
       ct := 0;
       while ct < s.count do
        begin
         thisline := uppercase(s[ct]);
         if pos(cmd,thisline) > 0 then
          begin
           inc(numinstances);
          end;
         inc(ct);
        end;
       result := numinstances;
      end;
    finally
    s.free;
    end;
   finally
    t.Free;
   end;
  end;

function fn_sanitize_folder(folder,HomeDir : string) : string;
begin
  result := folder;
  if folder <> '' then
   begin
    folder := trimleft(folder);
    folder := trimright(folder);
    folder := stringreplace(folder,'"','',[rfreplaceall,rfignorecase]);
    // Do we have a "~" prefix?
    if copy(folder,1,2) = '~/' then
     begin
      folder := HomeDir + copy(folder,3,length(folder));
     end;
    // Delimit it.
    folder := IncludeTrailingPathDelimiter(folder);
    result := folder;
   end;
end;

function fn_read_c_parameter_override_for_hyprscreensaver_conf_path_and_filename : string;
var
 temp : string;
begin
 result := '';
 temp := GetOptionValue('c');
 if temp <> '' then
  begin
   temp := fn_sanitize_folder(temp,HomeDir);
   if copy(temp,length(temp),1) = '/' then
    begin
     temp := copy(temp,1,length(temp)-1);
    end;
   result := temp;  // And remember the -c parameter and hyprscreensaver.conf path and filename passed to hyprscreensaver so that we can repeat that when we (re) start swayidle.
  end;
end;

function fn_get_random_screensaver_filename(screensaver_folder : string) : string;
var
 dirts : TSearchrec;
 screensavervideofiles : TStringList;
 validfileextensions,thisfileextension : string;
 x : integer;
begin
 result := '';
 screensavervideofiles := TStringList.create;
 try
  screensavervideofiles.clear;
  validfileextensions := '.mkv;.mp4;.avi;.mov;.wmv;.webm;';
  if findfirst(screensaver_folder+'*',faAnyFile,dirts) = 0 then
   begin
    repeat
     if (dirts.Attr and faDirectory) <> faDirectory then
      begin
       if dirts.Name <> '' then
        begin
         thisfileextension := uppercase(ExtractFileExt(dirts.Name));
         if pos(thisfileextension,uppercase(validfileextensions)+';') > 0 then
          begin
           screensavervideofiles.Add(dirts.Name);
          end;
        end;
      end;
    until FindNext(dirts) <> 0;
    FindClose(dirts);
    if screensavervideofiles.Count > 0 then
     begin
      if screensavervideofiles.Count = 1 then
       begin
        result := screensavervideofiles[0];
       end
       else
       begin
        Randomize;
        x := Random(screensavervideofiles.Count);
        if (x >= 0) and (x < screensavervideofiles.Count) then
         begin
          result := screensavervideofiles[x];
         end;
       end;
     end;
   end;
 finally
  screensavervideofiles.clear;
  screensavervideofiles.free;
 end;
end;

function fn_read_hyprscreensaver_conf(hyprscreensaver_conf_path_and_filename : string) : boolean;
var
 f : textfile;
 temp : string;
 x : integer;
begin
 result := false;
 if fileexists(hyprscreensaver_conf_path_and_filename) then
  begin
   assignfile(f,hyprscreensaver_conf_path_and_filename);
   reset(f);
   while not eof(f) do
    begin
     result := true;
     readln(f,temp);
     temp := trimleft(temp);
     temp := trimright(temp);
     if copy(temp,1,1) <> '#' then // Ignore comments (lines starting with '#').
      begin
       // Kill any comments on the line e.g. convert "delay = 900 # Delay is 15 minutes" to "delay = 900".
       x := pos('#',temp);
       if x > 0 then
         begin
          temp := copy(temp,1,x-1);
          temp := trimleft(temp);
          temp := trimright(temp);
         end;
       // OK: Parse this line:
       if pos('DELAY',uppercase(temp)) > 0 then
        begin
         temp := stringreplace(temp,'DELAY','',[rfreplaceall,rfignorecase]);
         temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
         temp := stringreplace(temp,'"','',[rfreplaceall,rfignorecase]);
         temp := stringreplace(temp,' ','',[rfreplaceall,rfignorecase]);
         if strtoint(temp) >= 30 then // Min is 30 seconds, otherwise leave as default (900 seconds = 15 mins).
          begin
           swayidledelayseconds := temp;
          end;
        end
        else if pos('SCREENSAVER_FOLDER',uppercase(temp)) > 0 then
        begin
         temp := stringreplace(temp,'SCREENSAVER_FOLDER','',[rfreplaceall,rfignorecase]);
         temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
         temp := stringreplace(temp,'"','',[rfreplaceall,rfignorecase]);
         temp := trimleft(temp);
         temp := trimright(temp);
         screensaver_folder := fn_sanitize_folder(temp,HomeDir);
        end
        else if pos('SCREENSAVER_FILENAME',uppercase(temp)) > 0 then
        begin
         temp := stringreplace(temp,'SCREENSAVER_FILENAME','',[rfreplaceall,rfignorecase]);
         temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
         temp := stringreplace(temp,'"','',[rfreplaceall,rfignorecase]);
         temp := trimleft(temp);
         temp := trimright(temp);
         screensaver_filename := temp;
        end;
      end;
    end;
   close(f);
   if (screensaver_filename = '') or (uppercase(screensaver_filename) = 'RANDOM') then
    begin
     screensaver_filename := fn_get_random_screensaver_filename(screensaver_folder);
    end;
  end;
end;

function fn_read_hyprscreensaver_lastruntime(hyprscreensaver_lastruntime_path_and_filename : string) : TDateTime;
var
 f : textfile;
 temp : string;
begin
 result := 0;
 if fileexists(hyprscreensaver_lastruntime_path_and_filename) then
  begin
   assignfile(f,hyprscreensaver_lastruntime_path_and_filename);
   reset(f);
   while not eof(f) do
    begin
     readln(f,temp);
     if pos('LAST_RUN_TIME',uppercase(temp)) > 0 then
      begin
       temp := stringreplace(temp,'LAST_RUN_TIME','',[rfreplaceall,rfignorecase]);
       temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
       temp := stringreplace(temp,'"','',[rfreplaceall,rfignorecase]);
       temp := trimleft(temp);
       temp := trimright(temp);
       result := strtodatetime(temp);
      end;
    end;
   close(f);
  end;
end;

function fn_write_hyprscreensaver_conf_file(hyprscreensaver_conf_path_and_filename : string) : boolean; // Write out a hyprscreensaver.conf file.
var
 f : textfile;
begin
 result := false;
 if hyprscreensaver_conf_path_and_filename <> '' then
  begin
   assignfile(f,hyprscreensaver_conf_path_and_filename);
   rewrite(f);
   writeln(f,'# hyprscreensaver configuration file.');
   writeln(f,'');
   writeln(f,'# The "delay = <seconds>" parameter e.g. "delay = 900" is the number of seconds to wait before "swayidle" runs hyprscreensaver.');
   writeln(f,'# The default is 900 seconds which is 15 minutes and the minimun allowed value is 30 seconds.');
   writeln(f,'# Example delay seconds values: 60 = 1 minute, 600 = 10 minutes, 900 = 15 minutes, 1800 = 30 miunutes, 3600 = 1 hour.');
   writeln(f,'delay = '+swayidledelayseconds);
   writeln(f,'');
   writeln(f,'# The "screensaver_folder = <folder containing your screensaver video files>" parameter indicates the folder containing your screenshot video files.');
   writeln(f,'# The default is "~/.config/hypr/" which should be OK to use in most cases.');
   writeln(f,'screensaver_folder = '+screensaver_folder);
   writeln(f,'');
   writeln(f,'# The "screensaver_filename = <screensaver video filename>" parameter indicates the screenshot video file in the screensaver folder that you want to play via "ffplay"');
   writeln(f,'# on each monitor when hyprscreensaver runs.');
   writeln(f,'# NOTE: If you set screensaver_filename to blank (screensaver_filename =) or "screensaver_filename = random" then hyprscreensaver will select a random screensaver video file');
   writeln(f,'# present in the screensaver folder. Valid video file extensions for "random" mode video file selection are .mkv, .mp4, .avi, .mov, .wmv and .webm.');
   writeln(f,'screensaver_filename = '+screensaver_filename);
   close(f);
   result := true;
  end;
end;

procedure write_lastruntime_to_hyprscreensaver_lastruntime_path_and_filename(lastruntime : TDateTime; hyprscreensaver_lastruntime_path_and_filename : string);
var
 f : textfile;
begin
 if hyprscreensaver_lastruntime_path_and_filename <> '' then
  begin
   assignfile(f,hyprscreensaver_lastruntime_path_and_filename);
   rewrite(f);
   writeln(f,'last_run_time = '+datetimetostr(lastruntime));
   close(f);
  end;
end;

function fn_runprocess(Executable,param1,param2,param3,param4,param5 : string; ProcessOptions : TProcessOptions; sleepbeforeexecute : integer) : boolean;
var
 Process : TProcess;
begin
 result := false;
 if sleepbeforeexecute > 0 then sleep(sleepbeforeexecute);
 // No running so start it.
 Process := TProcess.Create(nil);
 try
  Process.Executable := Executable;
  Process.Parameters.Clear;
  if param1 <> '' then Process.Parameters.Add(param1);
  if param2 <> '' then Process.Parameters.Add(param2);
  if param3 <> '' then Process.Parameters.Add(param3);
  if param4 <> '' then Process.Parameters.Add(param4);
  if param5 <> '' then Process.Parameters.Add(param5);
  Process.Options := ProcessOptions;
  Process.Execute;
  result := true;
 finally
  Process.Free;
 end;
end;

begin
 // Quick check parameters
 ErrorMsg:=CheckOptions('h,c', 'help,config');
 if ErrorMsg<>'' then
  begin
   ShowException(Exception.Create(ErrorMsg));
   Terminate;
   Exit;
  end;

 // Parse parameters
 if HasOption('h', 'help') then
  begin
   WriteHelp;
   Terminate;
   Exit;
  end;

 // Program start:

 // Initialise key variables:
 getout := false;

 AppPath := ExtractFilePath(ParamStr(0));
 AppPath := IncludeTrailingPathDelimiter(AppPath);

 HomeDir := GetUserDir;
 HomeDir := IncludeTrailingPathDelimiter(HomeDir);

 swayidledelayseconds := '900'; // Default is 15 minutes.

 hyprscreensaver_conf_path_and_filename := HomeDir+'.config/hypr/hyprscreensaver.conf'; // Default.
 // If run using the -c <folder and filename of hyprscreensaver.conf> parameter then use that to override the default hyprscreensaver_conf_path_and_filename:
 c_parameters := fn_read_c_parameter_override_for_hyprscreensaver_conf_path_and_filename;
 if c_parameters <> '' then hyprscreensaver_conf_path_and_filename := c_parameters;

 // We alse need a "hyprscreensaver.dat" file on the same path as hyprscreensaver.conf to store the "last run time":
 hyprscreensaver_lastruntime_path_and_filename := extractfilepath(hyprscreensaver_conf_path_and_filename) + 'hyperscreensaver.dat';

 screensaver_folder := HomeDir+'.config/hypr/'; // Default.
 screensaver_filename := 'screensaver.mp4'; // Default.

 if not fn_read_hyprscreensaver_conf(hyprscreensaver_conf_path_and_filename) then // Read hyprscreensaver.conf to set all of the above key variables to the values stored in that conf file.
  begin
   if not fn_write_hyprscreensaver_conf_file(hyprscreensaver_conf_path_and_filename) then getout := true; // If hyprscreensaver.conf not present then create it with the default parameter variables.
  end;

 // Is the difference between "now" (lastruntime) and the last run time read from the hyprscreensaver.dat file (thislastruntime) < 10 seconds then it's a "misfire" so get out.
 if not getout then
  begin
   lastruntime := now;
   thislastruntime := fn_read_hyprscreensaver_lastruntime(hyprscreensaver_lastruntime_path_and_filename);
   if (thislastruntime <> 0) and (lastruntime - thislastruntime > 0) and (lastruntime - thislastruntime < 0.000115740740740741) then // 10 seconds = 0.000115740740740741
    begin
     getout := true;
    end;
  end;

 // Is hyprscreensaver already running? If so then quit (getout=true):
 if fn_GetNumberOfAppInstancesRunnnig('hyprscreensaver') > 1 then getout := true;

 // Is swayidle NOT running? If so then start it up and then quit (getout=true):
 if not getout then
  begin
   if fn_GetNumberOfAppInstancesRunnnig('swayidle') = 0 then
    begin
     if c_parameters <> '' then
      begin
       if not fn_runprocess('hyprctl','dispatch','exec','swayidle -w timeout '+swayidledelayseconds+' "'+AppPath+'hyprscreensaver -c '+c_parameters+'"','','',[poUsePipes],0) then getout := true;
      end
      else
      begin
       if not fn_runprocess('hyprctl','dispatch','exec','swayidle -w timeout '+swayidledelayseconds+' '+AppPath+'hyprscreensaver','','',[poUsePipes],0) then getout := true;
      end;
     getout := true;
    end;
  end;

 try
  // Kill swayidle to stop it running until this instance of hyprscreensaver has finished.
  if not getout then begin if not fn_runprocess('pkill','swayidle','','','','',[poWaitOnExit, poUsePipes],0) then getout := true; end;

  // Switch monitors to high workspaces and run ffplay to display the screensaver video on each workspace:

  // Switch to 1st monitor:
  if not getout then begin if not fn_runprocess('hyprctl','dispatch','focusmonitor','HDMI-A-1','','',[poWaitOnExit, poUsePipes],0) then getout := true; end;
  // Switch that monitor to workspace 8:
  if not getout then begin if not fn_runprocess('hyprctl','dispatch','workspace','8','','',[poWaitOnExit, poUsePipes],0) then getout := true; end;
  // Launch screensaver video in ffplay on 1st monitor on workspace 8:
  if not getout then begin if not fn_runprocess('hyprctl','dispatch','exec','ffplay "'+screensaver_folder+screensaver_filename+'" -fs -exitonkeydown -exitonmousedown -loop 0','','',[poUsePipes],0) then getout := true; end;

  // Switch to 2nd monitor:
  if not getout then begin if not fn_runprocess('hyprctl','dispatch','focusmonitor','HDMI-A-2','','',[poWaitOnExit, poUsePipes],200) then getout := true; end;
  // Switch that monitor to workspace 9:
  if not getout then begin if not fn_runprocess('hyprctl','dispatch','workspace','9','','',[poWaitOnExit, poUsePipes],0) then getout := true; end;
  // Launch screensaver video in ffplay on 2nd monitor on workspace 9:
  if not getout then begin if not fn_runprocess('hyprctl','dispatch','exec','ffplay "'+screensaver_folder+screensaver_filename+'" -fs -exitonkeydown -exitonmousedown -loop 0','','',[poUsePipes],0) then getout := true; end;

  // Main loop: Wait for one or more of the ffplay screensaver video player processes to close:
  if not getout then
   begin
    sleep(200);
    finished := false;
    InitialNumInstancesScreensaverApp := fn_GetNumberOfAppInstancesRunnnig('ffplay');
    if InitialNumInstancesScreensaverApp > 0 then // There should be at least one instance of "ffplay" running. If not then we are finished.
     begin
      repeat
       sleep(400);
       if (InitialNumInstancesScreensaverApp <> fn_GetNumberOfAppInstancesRunnnig('ffplay')) then
        begin
         finished := true;
        end;
      until finished;
     end;
   end;

  // Kill all remaining ffplay processes:
  if not getout then begin if not fn_runprocess('pkill','ffplay','','','','',[poWaitOnExit, poUsePipes],200) then getout := true; end;

  // Return monitors and workspaces back to "normal":

  // Switch to 1st monitor:
  if not getout then begin if not fn_runprocess('hyprctl','dispatch','focusmonitor','HDMI-A-1','','',[poWaitOnExit, poUsePipes],0) then getout := true; end;
  // Switch that monitor to workspace 1:
  if not getout then begin if not fn_runprocess('hyprctl','dispatch','workspace','1','','',[poWaitOnExit, poUsePipes],0) then getout := true; end;

  // Switch to 2nd monitor:
  if not getout then begin if not fn_runprocess('hyprctl','dispatch','focusmonitor','HDMI-A-2','','',[poWaitOnExit, poUsePipes],200) then getout := true; end;
  // Switch that monitor to workspace 2:
  if not getout then begin if not fn_runprocess('hyprctl','dispatch','workspace','2','','',[poWaitOnExit, poUsePipes],0) then getout := true; end;

  // Write out the hyprscreensaver.conf with updated values (mainly want "Last run time"):
  if not getout then write_lastruntime_to_hyprscreensaver_lastruntime_path_and_filename(now,hyprscreensaver_lastruntime_path_and_filename);

  // Re-start swayidle:
  if not getout then
   begin
    if c_parameters <> '' then
     begin
      if not fn_runprocess('hyprctl','dispatch','exec','swayidle -w timeout '+swayidledelayseconds+' "'+AppPath+'hyprscreensaver -c '+c_parameters+'"','','',[poUsePipes],0) then getout := true;
     end
     else
     begin
      if not fn_runprocess('hyprctl','dispatch','exec','swayidle -w timeout '+swayidledelayseconds+' '+AppPath+'hyprscreensaver','','',[poUsePipes],0) then getout := true;
     end;
   end;
 finally
 end;

 // Stop program:
 Terminate;
end;

constructor Thyprscreensaver.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor Thyprscreensaver.Destroy;
begin
  inherited Destroy;
end;

procedure Thyprscreensaver.WriteHelp;
begin
  { add your help code here }
  writeln('Welcome to the hyprscreensaver terminal application.');
  writeln('This is for use with the hyprland display manager to faciliate a screensaver capability.');
  writeln('');
  writeln('Running as: ', ExeName);
  writeln('');
  writeln('Usage: -h = Display this help information.');
  writeln('Usage: -c <folder and filename for custom hyprscreensaver.conf override file>');
  writeln('');
  writeln('NB: The default hyprscreensaver.conf file is ~/.config/hypr/hyprscreensaver.conf and is generated automatically on first run.');
  writeln('All further usage and configuration information is in hyprscreensaver.conf so please read that.');
end;

var
  Application: Thyprscreensaver;
begin
  Application:=Thyprscreensaver.Create(nil);
  Application.Title:='hyprscreensaver';
  Application.Run;
  Application.Free;
end.

