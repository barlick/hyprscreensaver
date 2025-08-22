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
    const maxmonitors = 9;
    var swayidledelayseconds : string;
    InitialNumInstancesScreensaverApp : integer;
    lastruntime,thislastruntime : TDateTime;
    AppPath,HomeDir,hyprscreensaver_conf_path_and_filename,hyprscreensaver_lastruntime_path_and_filename,screensaver_folder,screensaver_filename,this_screensaver_filename,last_screensaver_filename,c_parameters,monitors : string;
    nummonitors : integer;
    monitornames : TStringList;
    monitorworkspaces : TStringList;
    cfocusedmonitorname : string;
    cmonitoractiveworkspaces : TStringList;
    diagnostic_mode : boolean;
    monitorswitchdelaybefore,monitorswitchdelayafter,launchscreensaverdelaybefore,launchscreensaverdelayafter : integer;
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
    function fn_GetNumberOfAppInstancesRunnnig(cmd:String) : integer;
    function fn_sanitize_folder(folder,HomeDirs : string) : string;
    function fn_read_c_parameter_override_for_hyprscreensaver_conf_path_and_filename : string;
    function fn_get_random_screensaver_filename(screensaver_folderstr,last_screensaver_filenamestr : string) : string;
    function fn_read_hyprscreensaver_conf(hyprscreensaver_conf_path_and_filenamestr : string) : boolean;
    function fn_read_hyprscreensaver_lastruntime(hyprscreensaver_lastruntime_path_and_filenamestr : string) : TDateTime;
    function fn_write_hyprscreensaver_conf_file(hyprscreensaver_conf_path_and_filenamestr : string) : boolean; // Write out a hyprscreensaver.conf file.
    procedure write_lastruntime_to_hyprscreensaver_lastruntime_path_and_filename(lastruntimedt : TDateTime; hyprscreensaver_lastruntime_path_and_filenamestr : string);
    function fn_runprocess(Executable,param1,param2,param3,param4,param5 : string; ProcessOptions : TProcessOptions; sleepbeforeexecute,sleepafterexecute : integer) : boolean;
    function fn_check_package_is_available(ExpectedErrorResponse,Executable,param1,param2,param3,param4,param5 : string; ProcessOptions : TProcessOptions; sleepbeforeexecute : integer) : boolean;
    function fn_get_monitor_info(var nummonitorsint : integer; var monitornamesstr : TStringList; var monitorworkspacesstr : TStringList) : boolean;
    function fn_get_current_monitor_focused_and_active_workspaces(var nummonitorsint : integer; var cfocusedmonitornamestr : string; var monitornamesstr : TStringList; var cmonitoractiveworkspacesstr : TStringList) : boolean;
    procedure write_diagnostics(s : string);
    procedure output_monitor_config_info;
  end;

{ Thyprscreensave }
function Thyprscreensaver.fn_GetNumberOfAppInstancesRunnnig(cmd:String) : integer;
var
 t:TProcess;
 s:TStringList;
 ct,numinstances : integer;
 thisline : string;
begin
 result := 0;
 t:=tprocess.create(nil);
 s:=tstringlist.Create;
 try
  try
   t.Executable:='ps';
   t.Parameters.Clear;
   t.Parameters.Add('-C');
   t.Parameters.Add(cmd);
   t.Options:=[poUsePipes,poWaitonexit];
   t.Execute;
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
  except
   on e : exception do
    begin
     result := 0;
     write_diagnostics('Error: Failed to parse output from pc -C '+cmd+' error is: '+e.Message);
    end;
  end;
 finally
  s.clear;
  s.free;
  t.Free;
 end;
end;

function Thyprscreensaver.fn_sanitize_folder(folder,HomeDirs : string) : string;
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
      folder := HomeDirs + copy(folder,3,length(folder));
     end;
    // Delimit it.
    folder := IncludeTrailingPathDelimiter(folder);
    result := folder;
   end;
end;

function Thyprscreensaver.fn_read_c_parameter_override_for_hyprscreensaver_conf_path_and_filename : string;
var
 temp : string;
begin
 result := '';
 try
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
 except
  on e : exception do
   begin
    result := '';
    write_diagnostics('Error: Failed inside fn_read_c_parameter_override_for_hyprscreensaver_conf_path_and_filename error is: '+e.Message);
   end;
 end;
end;

function Thyprscreensaver.fn_get_random_screensaver_filename(screensaver_folderstr,last_screensaver_filenamestr : string) : string;
var
 dirts : TSearchrec;
 screensavervideofiles : TStringList;
 validfileextensions,thisfileextension : string;
 ct,x : integer;
begin
 result := '';
 write_diagnostics('Attempting to find a random screensaver video file from within '+screensaver_folderstr);
 screensavervideofiles := TStringList.create;
 try
  try
   screensavervideofiles.clear;
   validfileextensions := '.mkv;.mp4;.avi;.mov;.wmv;.webm;';
   if findfirst(screensaver_folderstr+'*',faAnyFile,dirts) = 0 then
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
            write_diagnostics('Found screensaver video file: '+dirts.name);
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
         write_diagnostics('Selected the only available screensaver video file: '+result);
        end
        else // Must have at least two possible screensaver video files:
        begin
         Randomize; // Only call this once...
         ct := 1;
         repeat
          x := Random(screensavervideofiles.Count);
          if (x >= 0) and (x < screensavervideofiles.Count) then
           begin
            result := screensavervideofiles[x];
            if last_screensaver_filenamestr <> '' then
             begin
              if (result = last_screensaver_filenamestr) and (ct < 20) then // Avoid choosing the one we had last time unless "last_screensaver_filenamestr" is blank in which case whatever gets returned is fine.
               begin
                result := '';
               end;
             end;
            write_diagnostics('Selected random screensaver video file: '+result);
           end;
          inc(ct);
         until (result <> '') or (ct > 20);
        end;
      end
      else
      begin
       write_diagnostics('Error: Failed to find any screensaver video files with file extensions matching '+validfileextensions+ ' in folder '+screensaver_folderstr+' so was unable to select a random screensaver video file.');
      end;
    end;
  except
   on e : exception do
    begin
     result := '';
     write_diagnostics('Error: Failed inside fn_get_random_screensaver_filename error is: '+e.Message);
    end;
  end;
 finally
  screensavervideofiles.clear;
  screensavervideofiles.free;
 end;
end;

function Thyprscreensaver.fn_read_hyprscreensaver_conf(hyprscreensaver_conf_path_and_filenamestr : string) : boolean;
var
 f : textfile;
 temp,monitorname,workspacestr : string;
 x,workspacenum : integer;
 add_monitor_name_auto_detected : boolean;
begin
 result := false;
 write_diagnostics('Attempting to read the hyprscreensaver.conf configuration file '+hyprscreensaver_conf_path_and_filenamestr);
 try
  add_monitor_name_auto_detected := false;
  nummonitors := 0;
  monitornames.clear;
  monitorworkspaces.clear;
  if fileexists(hyprscreensaver_conf_path_and_filenamestr) then
   begin
    assignfile(f,hyprscreensaver_conf_path_and_filenamestr);
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
        if pos('SCREENSAVER_FOLDER',uppercase(temp)) > 0 then
         begin
          write_diagnostics('Found screensaver_folder type config command: '+temp);
          temp := stringreplace(temp,'SCREENSAVER_FOLDER','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'"','',[rfreplaceall,rfignorecase]);
          temp := trimleft(temp);
          temp := trimright(temp);
          screensaver_folder := fn_sanitize_folder(temp,HomeDir);
          write_diagnostics('screensaver_folder is now set to '+screensaver_folder);
         end
         else if pos('SCREENSAVER_FILENAME',uppercase(temp)) > 0 then
         begin
          write_diagnostics('Found screensaver_filename type config command: '+temp);
          temp := stringreplace(temp,'SCREENSAVER_FILENAME','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'"','',[rfreplaceall,rfignorecase]);
          temp := trimleft(temp);
          temp := trimright(temp);
          screensaver_filename := temp;
          write_diagnostics('screensaver_filename is now set to '+screensaver_filename);
         end
         else if pos('MONITORSWITCHDELAYBEFORE',uppercase(temp)) > 0 then
         begin
          write_diagnostics('Found monitorswitchdelaybefore type config command: '+temp);
          temp := stringreplace(temp,'MONITORSWITCHDELAYBEFORE','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'"','',[rfreplaceall,rfignorecase]);
          temp := trimleft(temp);
          temp := trimright(temp);
          try
           monitorswitchdelaybefore := strtoint(temp);
          except
           monitorswitchdelaybefore := 0;
          end;
          write_diagnostics('monitorswitchdelaybefore is now set to '+inttostr(monitorswitchdelaybefore));
         end
         else if pos('MONITORSWITCHDELAYAFTER',uppercase(temp)) > 0 then
         begin
          write_diagnostics('Found monitorswitchdelayafter type config command: '+temp);
          temp := stringreplace(temp,'MONITORSWITCHDELAYAFTER','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'"','',[rfreplaceall,rfignorecase]);
          temp := trimleft(temp);
          temp := trimright(temp);
          try
           monitorswitchdelayafter := strtoint(temp);
          except
           monitorswitchdelayafter := 0;
          end;
          write_diagnostics('monitorswitchdelayafter is now set to '+inttostr(monitorswitchdelayafter));
         end
         else if pos('LAUNCHSCREENSAVERDELAYBEFORE',uppercase(temp)) > 0 then
         begin
          write_diagnostics('Found launchscreensaverdelaybefore type config command: '+temp);
          temp := stringreplace(temp,'LAUNCHSCREENSAVERDELAYBEFORE','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'"','',[rfreplaceall,rfignorecase]);
          temp := trimleft(temp);
          temp := trimright(temp);
          try
           launchscreensaverdelaybefore := strtoint(temp);
          except
           launchscreensaverdelaybefore := 0;
          end;
          write_diagnostics('launchscreensaverdelaybefore is now set to '+inttostr(launchscreensaverdelaybefore));
         end
         else if pos('LAUNCHSCREENSAVERDELAYAFTER',uppercase(temp)) > 0 then
         begin
          write_diagnostics('Found launchscreensaverdelayafter type config command: '+temp);
          temp := stringreplace(temp,'LAUNCHSCREENSAVERDELAYAFTER','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'"','',[rfreplaceall,rfignorecase]);
          temp := trimleft(temp);
          temp := trimright(temp);
          try
           launchscreensaverdelayafter := strtoint(temp);
          except
           launchscreensaverdelayafter := 0;
          end;
          write_diagnostics('launchscreensaverdelayafter is now set to '+inttostr(launchscreensaverdelayafter));
         end
         else if pos('DELAY',uppercase(temp)) > 0 then
         begin
          write_diagnostics('Found delay type config command: '+temp);
          temp := stringreplace(temp,'DELAY','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,'"','',[rfreplaceall,rfignorecase]);
          temp := stringreplace(temp,' ','',[rfreplaceall,rfignorecase]);
          try
           if strtoint(temp) >= 30 then // Min is 30 seconds, otherwise leave as default (60 seconds = 1 min).
            begin
             swayidledelayseconds := temp;
            end;
          except
            swayidledelayseconds := temp;
          end;
          write_diagnostics('swayidledelayseconds is now set to '+swayidledelayseconds);
         end
         else if pos('ADD_MONITOR_NAME',uppercase(temp)) > 0 then // Example: add_monitor_name = HDMI-A-1 run_screensaver_on_workspace = 8
         begin
          write_diagnostics('Found add_monitor_name type config command: '+temp);
          monitorname := ''; workspacestr := '';
          temp := stringreplace(temp,'ADD_MONITOR_NAME','',[rfreplaceall,rfignorecase]); // Example:  = HDMI-A-1 run_screensaver_on_workspace = 8
          temp := trimleft(temp); temp := trimright(temp);
          x := pos('=',temp);
          if x > 0 then
           begin
            temp := copy(temp,x+1,length(temp)); // Example: HDMI-A-1 run_screensaver_on_workspace = 8.
            temp := trimleft(temp); temp := trimright(temp);
            x := pos(' ',temp);
            if x > 0 then
             begin
              monitorname := copy(temp,1,x-1); // E.g. "HDMI-A-1"
              write_diagnostics('Monitor name read as "'+monitorname+'".');
              if pos('AUTO',uppercase(monitorname)) > 0 then
               begin
                add_monitor_name_auto_detected := true;
                write_diagnostics('Monitor name indicates "auto" so will work out the monitor names and workspaces automatically.');
               end;
              temp := copy(temp,x+1,length(temp)); // E.g. run_screensaver_on_workspace = 8
              temp := trimleft(temp); temp := trimright(temp);
              temp := stringreplace(temp,'RUN_SCREENSAVER_ON_WORKSPACE','',[rfreplaceall,rfignorecase]); // Example:  = 8
              temp := trimleft(temp); temp := trimright(temp);
              x := pos('=',temp);
              if x > 0 then
               begin
                workspacestr := copy(temp,x+1,length(temp));
                workspacestr := trimleft(workspacestr); workspacestr := trimright(workspacestr);
                write_diagnostics('run_screensaver_on_workspace read as "'+workspacestr+'".');
               end;
             end;
           end;
          if not add_monitor_name_auto_detected then
           begin
            try
             workspacenum := strtoint(workspacestr);
            except
             workspacenum := 0;
             write_diagnostics('Error: run_screensaver_on_workspace value "'+workspacestr+'" is invalid. Should be a number between 1 and 9 (or higher if hyprland config allows it).');
            end;
            if (monitorname <> '') and (workspacestr <> '') and (workspacenum > 0) then
             begin
              inc(nummonitors);
              monitornames.Add(monitorname);
              monitorworkspaces.Add(workspacestr);
              write_diagnostics('Added monitor name '+monitorname+' mapped to run screensaver on workspace '+workspacestr+'.');
             end;
           end;
         end;
       end;
     end;
    close(f);
    if (screensaver_filename = '') or (uppercase(screensaver_filename) = 'RANDOM') then
     begin
      screensaver_filename := 'RANDOM';
     end
     else if uppercase(screensaver_filename) = 'RANDOMFOREACHMONITOR' then
     begin
      screensaver_filename := 'RANDOMFOREACHMONITOR';
     end;
    // If we didn't get any manually entered "add_monitor_name" entries or we saw an "add_monitor_name = auto run_screensaver_on_workspace = auto" line then we need to auto detect the monitors:
    if add_monitor_name_auto_detected or (nummonitors = 0) then
     begin
      if not fn_get_monitor_info(nummonitors,monitornames,monitorworkspaces) then result := false;
     end;
   end;
 except
  on e : exception do
   begin
    result := false;
    write_diagnostics('Error: Failed inside fn_read_hyprscreensaver_conf error is: '+e.Message);
   end;
 end;
end;

function Thyprscreensaver.fn_read_hyprscreensaver_lastruntime(hyprscreensaver_lastruntime_path_and_filenamestr : string) : TDateTime;
var
 f : textfile;
 temp : string;
begin
 write_diagnostics('Attempting to read the last hyprscreensaveer run date + time from '+hyprscreensaver_lastruntime_path_and_filenamestr);
 result := 0;
 try
  if fileexists(hyprscreensaver_lastruntime_path_and_filenamestr) then
   begin
    assignfile(f,hyprscreensaver_lastruntime_path_and_filenamestr);
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
 except
  on e : exception do
   begin
    result := 0;
    write_diagnostics('Error: Failed inside fn_read_hyprscreensaver_lastruntime error is: '+e.Message);
   end;
 end;
end;

function Thyprscreensaver.fn_write_hyprscreensaver_conf_file(hyprscreensaver_conf_path_and_filenamestr : string) : boolean; // Write out a hyprscreensaver.conf file.
var
 f : textfile;
begin
 result := false;
 if hyprscreensaver_conf_path_and_filenamestr <> '' then
  begin
   try
    assignfile(f,hyprscreensaver_conf_path_and_filenamestr);
    rewrite(f);
    writeln(f,'# hyprscreensaver configuration file.');
    writeln(f,'');
    writeln(f,'# The "delay = <seconds>" parameter e.g. "delay = 900" is the number of seconds to wait before "swayidle" runs hyprscreensaver.');
    writeln(f,'# The default is 60 seconds which is 1 minute and the minimum allowed value is 30 seconds.');
    writeln(f,'# Example delay seconds values: 60 = 1 minute, 600 = 10 minutes, 900 = 15 minutes, 1800 = 30 minutes, 3600 = 1 hour.');
    writeln(f,'delay = '+swayidledelayseconds);
    writeln(f,'');
    writeln(f,'# The "screensaver_folder = <folder containing your screensaver video files>" parameter indicates the folder containing your screenshot video files.');
    writeln(f,'# The default is "~/.config/hypr/" which should be OK to use in most cases.');
    writeln(f,'screensaver_folder = '+screensaver_folder);
    writeln(f,'');
    writeln(f,'# The "screensaver_filename = <screensaver video filename>" parameter indicates the screenshot video file in the screensaver folder that you want to play via "ffplay" on ALL monitors when hyprscreensaver runs.');
    writeln(f,'# If you set screensaver_filename to blank (screensaver_filename =) or "screensaver_filename = random" then hyprscreensaver will select a single random screensaver video file present in the screensaver folder and run that on ALL monitors.');
    writeln(f,'# If you set screensaver_filename to "screensaver_filename = randomforeachmonitor" then hyprscreensaver will select a random screensaver video file present in the screensaver folder for EACH monitor so that allows you to have a different');
    writeln(f,'# random screensaver on EACH of your monitors.');
    writeln(f,'# Valid video file extensions for "random" and "randomforeachmonitor" modes video file selections are .mkv, .mp4, .avi, .mov, .wmv and .webm.');
    writeln(f,'screensaver_filename = '+screensaver_filename);
    writeln(f,'');
    writeln(f,'# The "monitorswitchdelaybefore" parameter indicates the number of milliseconds to wait before switching between monitors and workspaces. Increase this if your computer is having trouble launching the screensaver video players.');
    writeln(f,'monitorswitchdelaybefore = '+inttostr(monitorswitchdelaybefore));
    writeln(f,'# The "monitorswitchdelayafter" parameter indicates the number of milliseconds to wait after switching between monitors and workspaces. Increase this if your computer is having trouble launching the screensaver video players.');
    writeln(f,'monitorswitchdelayafter = '+inttostr(monitorswitchdelayafter));
    writeln(f,'# The "launchscreensaverdelaybefore" parameter indicates the number of milliseconds to wait before launching ffplay to run a screensaver video file. Increase this if your computer is having trouble launching the screensaver video players.');
    writeln(f,'launchscreensaverdelaybefore = '+inttostr(launchscreensaverdelaybefore));
    writeln(f,'# The "launchscreensaverdelayafter" parameter indicates the number of milliseconds to wait after launching ffplay to run a screensaver video file. Increase this if your computer is having trouble launching the screensaver video players.');
    writeln(f,'launchscreensaverdelayafter = '+inttostr(launchscreensaverdelayafter));
    writeln(f,'');
    writeln(f,'# The "add_monitor_name = <monitor name found using hyprctl monitors> run_screensaver_on_workspace = <preferred screensaver workspace number>" is used to manually define');
    writeln(f,'# a monitor to run a screensaver on.');
    writeln(f,'# You need an "add_monitor_name" line for each of your connected monitors.');
    writeln(f,'# So if you have two monitors then you would run the command "hyprctl monitors" in a terminal which would give you the names of both of your monitors.');
    writeln(f,'# In my case I do have two monitors and "hyprctl monitors" told me that they were called "HDMI-A-1" and "HDMI-A-2".');
    writeln(f,'# So I would add the following two "add_monitor_name" lines:');
    writeln(f,'# add_monitor_name = HDMI-A-1 run_screensaver_on_workspace = 8');
    writeln(f,'# add_monitor_name = HDMI-A-2 run_screensaver_on_workspace = 9');
    writeln(f,'# You can also simply add a single "add_monitor_name" line "add_monitor_name = auto run_screensaver_on_workspace = auto". That will force hyprscreensaver to query hyprctl to');
    writeln(f,'# automatically work out your connected monitor names and calculate suitable default workspaces to run screensavers on for those monitors.');
    writeln(f,'# This *should* work in most cases so hence it''s used by default but it it doesn''t then you will have to add "add_monitor_name" lines manually as described above.');
    writeln(f,'add_monitor_name = auto run_screensaver_on_workspace = auto');
    writeln(f,'');
    close(f);
    result := true;
   except
    on e : exception do
     begin
      result := false;
      write_diagnostics('Error: Failed inside fn_write_hyprscreensaver_conf_file. Attempted to write new hyprscreensaver.conf file to '+hyprscreensaver_conf_path_and_filenamestr+' the error is: '+e.Message);
     end;
   end;
  end
  else
  begin
   write_diagnostics('Error: Failed inside fn_write_hyprscreensaver_conf_file, The hyprscreensaver.conf file path is blank.');
  end;
end;

procedure Thyprscreensaver.write_lastruntime_to_hyprscreensaver_lastruntime_path_and_filename(lastruntimedt : TDateTime; hyprscreensaver_lastruntime_path_and_filenamestr : string);
var
 f : textfile;
begin
 if hyprscreensaver_lastruntime_path_and_filenamestr <> '' then
  begin
   try
    assignfile(f,hyprscreensaver_lastruntime_path_and_filenamestr);
    rewrite(f);
    writeln(f,'last_run_time = '+datetimetostr(lastruntimedt));
    close(f);
   except
    on e : exception do
     begin
      write_diagnostics('Error: Failed inside write_lastruntime_to_hyprscreensaver_lastruntime_path_and_filename. Attempted to write last run date and time to '+hyprscreensaver_lastruntime_path_and_filenamestr+' the error is: '+e.Message);
     end;
   end;
  end
  else
  begin
   write_diagnostics('Error: Failed inside write_lastruntime_to_hyprscreensaver_lastruntime_path_and_filename. The hyprscreensaver_lastruntime_path_and_filenamestr file path is blank.');
  end;
end;

function Thyprscreensaver.fn_runprocess(Executable,param1,param2,param3,param4,param5 : string; ProcessOptions : TProcessOptions; sleepbeforeexecute,sleepafterexecute : integer) : boolean;
var
 Process : TProcess;
begin
 result := false;
 Process := TProcess.Create(nil);
 try
  if sleepbeforeexecute > 0 then sleep(sleepbeforeexecute);
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
   if sleepafterexecute > 0 then sleep(sleepafterexecute);
  except
   on e : exception do
    begin
     result := false;
     write_diagnostics('Error: Failed inside fn_runprocess using executable '+Executable+' the error is: '+e.Message);
    end;
  end;
 finally
  Process.Free;
 end;
end;

function Thyprscreensaver.fn_check_package_is_available(ExpectedErrorResponse,Executable,param1,param2,param3,param4,param5 : string; ProcessOptions : TProcessOptions; sleepbeforeexecute : integer) : boolean;
var
 t : TProcess;
 s : TStringList;
 ct : integer;
 thisline : string;
begin
 result := false;
 t := TProcess.Create(nil);
 s:=tstringlist.Create;
 try
  if sleepbeforeexecute > 0 then sleep(sleepbeforeexecute);
  try
   t.Executable := Executable;
   t.Parameters.Clear;
   if param1 <> '' then t.Parameters.Add(param1);
   if param2 <> '' then t.Parameters.Add(param2);
   if param3 <> '' then t.Parameters.Add(param3);
   if param4 <> '' then t.Parameters.Add(param4);
   if param5 <> '' then t.Parameters.Add(param5);
   t.Options := ProcessOptions;
   t.Execute;
   s.LoadFromStream(t.Output);
   if s.Count > 0 then
    begin
     result := true; // got something.
     ct := 0;
     while ct < s.count do
      begin
       thisline := uppercase(s[ct]);
       if pos(uppercase(ExpectedErrorResponse),thisline) > 0 then
        begin
         result := false;
         write_diagnostics('Error: fn_check_package_is_available checking '+Executable+' returned "'+ExpectedErrorResponse+'". Is '+Executable+' installed?');
        end;
       inc(ct);
      end;
     if result then
      begin
       write_diagnostics('fn_check_package_is_available checking '+Executable+' indicates that '+Executable+' is installed OK.');
      end;
    end;
  except
   on e : exception do
    begin
     result := false;
     write_diagnostics('Error: Failed to parse output in fn_check_package_is_available when checking '+Executable+' the error is: '+e.Message+'. Is '+Executable+' installed?');
    end;
  end;
 finally
  s.clear;
  s.free;
  t.Free;
 end;
end;

function Thyprscreensaver.fn_get_monitor_info(var nummonitorsint : integer; var monitornamesstr : TStringList; var monitorworkspacesstr : TStringList) : boolean;
var
 t:TProcess;
 s:TStringList;
 ct,x,workspacecount,maxworkspaces : integer;
 thisline : string;
begin
 result := false;
 write_diagnostics('Attempting to automatically determine monitor configuration via the fn_get_monitor_info by calling hyprctl monitors.');
 try
  nummonitorsint := 0;
  monitornamesstr.clear;
  monitorworkspacesstr.clear;
  maxworkspaces := 9;
  t:=tprocess.create(nil);
  t.Executable:='hyprctl';
  t.Parameters.Clear;
  t.Parameters.Add('monitors');
  t.Options:=[poUsePipes,poWaitonexit];
  try
   t.Execute;
   s:=tstringlist.Create;
   try
    s.LoadFromStream(t.Output);
    //s.clear;
    //s.Add('Monitor HDMI-A-1 (ID 0):');
    //s.Add('Monitor HDMI-A-2 (ID 1):');
    if s.Count > 0 then
     begin
      ct := 0;
      while ct < s.count do
       begin
        thisline := s[ct];
        thisline := trimleft(thisline);
        thisline := trimright(thisline);
        if copy(uppercase(thisline),1,7) = 'MONITOR' then
         begin
          write_diagnostics('Detected Monitor line from hyprctl monitors command output: '+thisline);
          if (nummonitorsint < maxmonitors) and (nummonitorsint < maxworkspaces) then
           begin
            // E.g. "Monitor HDMI-A-1 (ID 0):"
            thisline := stringreplace(thisline,'Monitors:','',[rfreplaceall,rfignorecase]);
            thisline := stringreplace(thisline,'Monitors','',[rfreplaceall,rfignorecase]);
            thisline := stringreplace(thisline,'Monitor:','',[rfreplaceall,rfignorecase]);
            thisline := stringreplace(thisline,'Monitor','',[rfreplaceall,rfignorecase]);
            thisline := trimleft(thisline);
            thisline := trimright(thisline);
            // E.g. "HDMI-A-1 (ID 0):"
            x := pos(' ',thisline);
            if x > 0 then
             begin
              thisline := copy(thisline,1,x-1);
             end;
            thisline := trimleft(thisline);
            thisline := trimright(thisline);
            // E.g. "HDMI-A-1".
            inc(nummonitorsint);
            monitornamesstr.Add(thisline);
            result := true;
           end;
         end;
        inc(ct);
       end;
      if nummonitorsint > 0 then
       begin
        workspacecount := (maxworkspaces - nummonitorsint+1);
        ct := 0;
        while (ct < nummonitorsint) do
         begin
          // First to 8, 2nd to 9 and so on...
          monitorworkspacesstr.Add(inttostr(workspacecount));
          inc(workspacecount);
          inc(ct);
         end;
       end;
     end;
   finally
   s.free;
   end;
  finally
   t.Free;
  end;
 except
  on e : exception do
   begin
    result := false;
    write_diagnostics('Error: Failed inside fn_get_monitor_info the error is: '+e.Message);
   end;
 end;
end;

function Thyprscreensaver.fn_get_current_monitor_focused_and_active_workspaces(var nummonitorsint : integer; var cfocusedmonitornamestr : string; var monitornamesstr : TStringList; var cmonitoractiveworkspacesstr : TStringList) : boolean;
var
 t:TProcess;
 s:TStringList;
 ct,ct1,x : integer;
 thisline,thismonitorname : string;
 found : boolean;
begin
 result := false;
 write_diagnostics('Attempting to find currently focused monitor and the active workspace for each monitor via fn_get_current_monitor_focused_and_active_workspaces by calling hyprctl monitors.');
 try
  if nummonitorsint > 0 then
   begin
    cfocusedmonitornamestr := '';
    cmonitoractiveworkspacesstr.clear;
    thismonitorname := '';
    t:=tprocess.create(nil);
    t.Executable:='hyprctl';
    t.Parameters.Clear;
    t.Parameters.Add('monitors');
    t.Options:=[poUsePipes,poWaitonexit];
    try
     t.Execute;
     s:=tstringlist.Create;
     try
      s.LoadFromStream(t.Output);
      if s.Count > 0 then
       begin
        ct := 0;
        while ct < s.count do
         begin
          thisline := s[ct];
          thisline := trimleft(thisline);
          thisline := trimright(thisline);
          if copy(uppercase(thisline),1,7) = 'MONITOR' then
           begin
            write_diagnostics('Detected Monitor line from hyprctl monitors command output: '+thisline);
            // E.g. "Monitor HDMI-A-1 (ID 0):"
            thisline := stringreplace(thisline,'Monitors:','',[rfreplaceall,rfignorecase]);
            thisline := stringreplace(thisline,'Monitors','',[rfreplaceall,rfignorecase]);
            thisline := stringreplace(thisline,'Monitor:','',[rfreplaceall,rfignorecase]);
            thisline := stringreplace(thisline,'Monitor','',[rfreplaceall,rfignorecase]);
            thisline := trimleft(thisline);
            thisline := trimright(thisline);
            // E.g. "HDMI-A-1 (ID 0):"
            x := pos(' ',thisline);
            if x > 0 then
             begin
              thisline := copy(thisline,1,x-1);
             end;
            thisline := trimleft(thisline);
            thisline := trimright(thisline);
            // E.g. "HDMI-A-1".
            thismonitorname := thisline;
           end
           else if copy(uppercase(thisline),1,16) = 'ACTIVE WORKSPACE' then
           begin
            if thismonitorname <> '' then
             begin
              write_diagnostics('Detected active workspace line from hyprctl monitors command output: '+thisline);
              // E.g. "active workspace: 1 (1)"
              thisline := stringreplace(thisline,'active workspace:','',[rfreplaceall,rfignorecase]);
              thisline := stringreplace(thisline,'active workspace','',[rfreplaceall,rfignorecase]);
              thisline := trimleft(thisline); thisline := trimright(thisline);
              // E.g. "1 (1)"
              x := pos(' ',thisline);
              if x > 0 then
               begin
                thisline := copy(thisline,1,x-1);
               end;
              thisline := trimleft(thisline); thisline := trimright(thisline);
              // E.g. "1".
              if thisline <> '' then
               begin
                // Should have "thismonitorname" in the "monitornamesstr" stringlist:
                ct1 := 0; found := false;
                while (ct1 < monitornamesstr.count) and not found do
                 begin
                  if monitornamesstr[ct1] = thismonitorname then
                   begin
                    found := true;
                   end
                   else inc(ct1);
                 end;
                if found then
                 begin
                  cmonitoractiveworkspacesstr.Add(thisline); // OK, this is the active workspace for this monitor.
                 end;
               end;
             end;
           end
           else if copy(uppercase(thisline),1,7) = 'FOCUSED' then
           begin
            if thismonitorname <> '' then
             begin
              write_diagnostics('Detected focused line from hyprctl monitors command output: '+thisline);
              // E.g. "focused: no"
              thisline := stringreplace(thisline,'focused:','',[rfreplaceall,rfignorecase]);
              thisline := stringreplace(thisline,'focused','',[rfreplaceall,rfignorecase]);
              thisline := trimleft(thisline); thisline := trimright(thisline);
              // E.g. "no" or "yes".
              if uppercase(copy(thisline,1,1)) = 'Y' then // This IS the focused monitor.
               begin
                // Should have "thismonitorname" in the "monitornamesstr" stringlist:
                ct1 := 0; found := false;
                while (ct1 < monitornamesstr.count) and not found do
                 begin
                  if monitornamesstr[ct1] = thismonitorname then
                   begin
                    found := true;
                   end
                   else inc(ct1);
                 end;
                if found then
                 begin
                  cfocusedmonitornamestr := thismonitorname;
                 end;
               end;
             end;
           end;
          inc(ct);
         end;
        // OK, did we get the same number of cmonitoractiveworkspacesstr entries as nummonitorsint, and did we get a "cfocusedmonitorname"?
        if (cmonitoractiveworkspacesstr.count = nummonitorsint) and (cfocusedmonitornamestr <> '') then
         begin
          result := true; // Worked OK, we can use this information.
          write_diagnostics('Successfully read current monitor focused and active workspaces info. The currently focused monitor is '+cfocusedmonitornamestr+'.');
         end
         else
         begin
          write_diagnostics('Failed to read current monitor focused and active workspaces info.');
         end;
       end;
     finally
     s.free;
     end;
    finally
     t.Free;
    end;
   end;
 except
  on e : exception do
   begin
    result := false;
    write_diagnostics('Error: Failed inside fn_get_current_monitor_focused_and_active_workspaces the error is: '+e.Message);
   end;
 end;
end;

procedure Thyprscreensaver.write_diagnostics(s : string);
begin
 // If passed a -d parameter then switch on diagnostic_mode to output useful diagnostic info as well as any "error:" type messages (which are always written out):
 if diagnostic_mode or (uppercase(copy(s,1,5)) = 'ERROR') then
  begin
   writeln(s);
  end;
end;

procedure Thyprscreensaver.output_monitor_config_info;
var
 ct : integer;
begin
 write_diagnostics('Number of monitors detected: '+inttostr(nummonitors));
 if nummonitors > 0 then
  begin
   ct := 0;
   while ct < nummonitors do
    begin
     write_diagnostics('Monitor name '+inttostr(ct+1)+': '+monitornames[ct] +' runs screensaver on workspace: '+ monitorworkspaces[ct]);
     inc(ct);
    end;
  end;
end;

procedure Thyprscreensaver.DoRun;
var
  ErrorMsg: String;
  finished : boolean;
  getout : boolean;
  ct : integer;
  thismonitorname,thismonitorworkspace : string;
begin
 // Program start:
 getout := false;

 monitornames := TStringList.create;
 monitorworkspaces := TStringList.create;
 cmonitoractiveworkspaces := TStringList.create;

 // Quick check parameters
 ErrorMsg:=CheckOptions('h,c,d', 'help,config,diagnostics');
 if ErrorMsg<>'' then
  begin
   ShowException(Exception.Create(ErrorMsg));
   getout := true;
  end;

 // Parse parameters
 if HasOption('h', 'help') then
  begin
   WriteHelp;
   getout := true;
  end;

 // If passed a -d parameter then switch on diagnostic_mode to output useful diagnostic info as well as any "error:" type messages (which are always written out):
 if not getout then
  begin
   diagnostic_mode := false;
   if HasOption('d', 'diagnostics') then diagnostic_mode := true;
   if diagnostic_mode then write_diagnostics('Diagnostic mode enabled.');
  end;


 // Initialise key variables:
 try
  if not getout then
   begin
    write_diagnostics('Checking that the required packages are installed:');
   (*
   if fn_GetNumberOfAppInstancesRunnnig('swayidle') = 0 then
    begin
     if not fn_check_package_is_available('command not found','swayidle','-h','','','','',[poUsePipes],0) then getout := true;
     if not fn_runprocess('pkill','swayidle','','','','',[poWaitOnExit, poUsePipes],0,0) then getout := true;
    end;
    *)
    if not fn_check_package_is_available('command not found','hyprctl','monitors','','','','',[poUsePipes],0) then getout := true;
    if not fn_check_package_is_available('command not found','ffplay','-version','','','','',[poUsePipes],0) then getout := true;
   end;

  if not getout then
   begin
    write_diagnostics(''); write_diagnostics('Initializing variables:');
    nummonitors := 0;
    monitornames := TStringList.create;
    monitornames.Clear;;
    monitorworkspaces := TStringList.create;
    monitorworkspaces.Clear;
    cfocusedmonitorname := '';
    cmonitoractiveworkspaces := TStringList.create;
    cmonitoractiveworkspaces.Clear;
    write_diagnostics('Monitors initialised to 0 monitors.');

    AppPath := ExtractFilePath(ParamStr(0));
    AppPath := IncludeTrailingPathDelimiter(AppPath);
    write_diagnostics('AppPath: '+AppPath);

    HomeDir := GetUserDir;
    HomeDir := IncludeTrailingPathDelimiter(HomeDir);
    write_diagnostics('HomeDir: '+HomeDir);

    swayidledelayseconds := '60'; // Default is 1 minute.
    write_diagnostics('swayidledelayseconds: '+swayidledelayseconds);

    monitorswitchdelaybefore := 0; monitorswitchdelayafter := 100; launchscreensaverdelaybefore := 0; launchscreensaverdelayafter := 100;
    write_diagnostics('monitorswitchdelaybefore: '+inttostr(monitorswitchdelaybefore));
    write_diagnostics('monitorswitchdelayafter: '+inttostr(monitorswitchdelayafter));
    write_diagnostics('launchscreensaverdelaybefore: '+inttostr(launchscreensaverdelaybefore));
    write_diagnostics('launchscreensaverdelayafter: '+inttostr(launchscreensaverdelayafter));

    hyprscreensaver_conf_path_and_filename := HomeDir+'.config/hypr/hyprscreensaver.conf'; // Default.
    write_diagnostics('hyprscreensaver_conf_path_and_filename defaulted to: '+hyprscreensaver_conf_path_and_filename);
    // If run using the -c <folder and filename of hyprscreensaver.conf> parameter then use that to override the default hyprscreensaver_conf_path_and_filename:
    c_parameters := fn_read_c_parameter_override_for_hyprscreensaver_conf_path_and_filename;
    if c_parameters <> '' then write_diagnostics('Detected -c <path> run parameter: -c '+c_parameters) else write_diagnostics('No -c <path> run parameter detected.');
    if c_parameters <> '' then hyprscreensaver_conf_path_and_filename := c_parameters;
    write_diagnostics('hyprscreensaver_conf_path_and_filename is now: '+hyprscreensaver_conf_path_and_filename);

    // We alse need a "hyprscreensaver.dat" file on the same path as hyprscreensaver.conf to store the "last run time":
    hyprscreensaver_lastruntime_path_and_filename := extractfilepath(hyprscreensaver_conf_path_and_filename) + 'hyperscreensaver.dat';
    write_diagnostics('hyprscreensaver_lastruntime_path_and_filename: '+hyprscreensaver_lastruntime_path_and_filename);

    screensaver_folder := HomeDir+'.config/hypr/'; // Default.
    write_diagnostics('screensaver_folder defaulted to: '+screensaver_folder);
    screensaver_filename := 'screensaver.mp4'; // Default.
    write_diagnostics('screensaver_filename defaulted to: '+screensaver_filename);

    write_diagnostics(''); write_diagnostics('Reading the hyprscreensaver.conf file:');
    // Generate default hyprscreensaver.conf file if it doesn't exist:
    if not fileexists(hyprscreensaver_conf_path_and_filename) then
     begin
      if not fn_write_hyprscreensaver_conf_file(hyprscreensaver_conf_path_and_filename) then getout := true; // If hyprscreensaver.conf not present then create it with the default parameter variables.
     end;
    // Read hyprscreensaver.conf to set all of the above key variables to the values stored in it:
    if not getout then
     begin
      if not fn_read_hyprscreensaver_conf(hyprscreensaver_conf_path_and_filename) then getout := true;
     end;

    // Check that the monitors were set up corectly by fn_read_hyprscreensaver_conf:
    if not getout then
     begin
      if nummonitors <= 0 then getout := true;
      if nummonitors <= 0 then write_diagnostics('Error: Number of monitors = 0. Unable to continue.');
     end;

    output_monitor_config_info;

    // Find out what the currently focussed monitor is and the active workspaces for each monitor. Don't care if this fails:
    if not getout then
     begin
      if fn_get_current_monitor_focused_and_active_workspaces(nummonitors,cfocusedmonitorname,monitornames,cmonitoractiveworkspaces) then;
     end;

    write_diagnostics(''); write_diagnostics('Checking that it is safe to continue running hyprscreensaver:');

    // Do we have valid settings read from hyprscreensaver.conf?
    if screensaver_folder = '' then begin getout := true; write_diagnostics('Error: screensaver_folder is not defined. Please check your screensaver_folder setting in '+hyprscreensaver_conf_path_and_filename+'.'); end;
    if screensaver_filename = '' then begin getout := true; write_diagnostics('Error: screensaver_filename is not defined. Please check your screensaver_filename setting in '+hyprscreensaver_conf_path_and_filename+'.'); end;
    if not getout then
     begin
      if (uppercase(screensaver_filename) <> 'RANDOM') and (uppercase(screensaver_filename) <> 'RANDOMFOREACHMONITOR') then
       begin
        if not fileexists(screensaver_folder+screensaver_filename) then
         begin
          getout := true;
          write_diagnostics('Error: The selected screensaver video file '+screensaver_folder+screensaver_filename+' does not exist.');
         end;
       end;
     end;

    // Is the difference between "now" (lastruntime) and the last run time read from the hyprscreensaver.dat file (thislastruntime) < 10 seconds then it's a "misfire" so get out.
    if not getout then
     begin
      lastruntime := now;
      thislastruntime := fn_read_hyprscreensaver_lastruntime(hyprscreensaver_lastruntime_path_and_filename);
      if (thislastruntime <> 0) and (lastruntime - thislastruntime > 0) and (lastruntime - thislastruntime < 0.000115740740740741) then // 10 seconds = 0.000115740740740741
       begin
        getout := true;
        write_diagnostics('Last hyprscreensaver run time read from '+hyprscreensaver_lastruntime_path_and_filename+' is '+datetimetostr(thislastruntime)+' which is < 10 seconds from now so exiting.');
       end;
     end;

    // Is hyprscreensaver already running? If so then quit (getout=true):
    if not getout then
     begin
      if fn_GetNumberOfAppInstancesRunnnig('hyprscreensaver') > 1 then
       begin
        getout := true;
        write_diagnostics('fn_GetNumberOfAppInstancesRunnnig of hyprscreensaver > 1 so hyprscreensaver is already running so exiting.');
       end;
     end;

    // Is swayidle NOT running? If so then start it up and then quit (getout=true):
    if not getout then
     begin
      if fn_GetNumberOfAppInstancesRunnnig('swayidle') = 0 then
       begin
        write_diagnostics('fn_GetNumberOfAppInstancesRunnnig of swayidle = 0 so swayidle is not running so will run swayidle and then exit:');
        if c_parameters <> '' then
         begin
          if not fn_runprocess('hyprctl','dispatch','exec','swayidle -w timeout '+swayidledelayseconds+' "'+AppPath+'hyprscreensaver -c '+c_parameters+'"','','',[poUsePipes],0,0) then getout := true;
          write_diagnostics('Called: fn_runprocess(hyprctl,dispatch,exec,swayidle -w timeout '+swayidledelayseconds+' "'+AppPath+'hyprscreensaver -c '+c_parameters+'",,,[poUsePipes],0)');
         end
         else
         begin
          if not fn_runprocess('hyprctl','dispatch','exec','swayidle -w timeout '+swayidledelayseconds+' '+AppPath+'hyprscreensaver','','',[poUsePipes],0,0) then getout := true;
          write_diagnostics('Called: fn_runprocess(hyprctl,dispatch,exec,swayidle -w timeout '+swayidledelayseconds+' '+AppPath+'hyprscreensaver,,,[poUsePipes],0)');
         end;
        getout := true;
       end;
     end;

    // Kill swayidle to stop it running until this instance of hyprscreensaver has finished.
    if not getout then
     begin
      if not fn_runprocess('pkill','swayidle','','','','',[poWaitOnExit, poUsePipes],0,0) then
       begin
        getout := true;
        write_diagnostics('Error: Failed to run "pkill swayidle" to kill the swayidle process. Unable to continue,');
       end
       else
       begin
        write_diagnostics('Ran "pkill swayidle" to kill the swayidle process.');
       end;
     end;

    // Switch monitors to high workspaces and run ffplay to display the screensaver video on each workspace:

    // Work through each monitor:
    if not getout then
     begin
      write_diagnostics(''); write_diagnostics('Launching screensaver(s):');

      if uppercase(screensaver_filename) = 'RANDOM' then // Select a single screensaver video file to run on ALL monitors.
       begin
        screensaver_filename := fn_get_random_screensaver_filename(screensaver_folder,'');
        if screensaver_filename = '' then
         begin
          getout := true; // No go....
         end
         else
         begin
          if not fileexists(screensaver_folder+screensaver_filename) then
           begin
            getout := true;
            write_diagnostics('Error: The selected screensaver video file '+screensaver_folder+screensaver_filename+' does not exist.');
           end;
         end;
       end;

      last_screensaver_filename := '';
      ct := 0;
      while (ct < nummonitors) and not getout do
       begin
        thismonitorname := monitornames[ct];
        thismonitorworkspace := monitorworkspaces[ct];
        // Switch to this monitor:
        if not getout then begin if not fn_runprocess('hyprctl','dispatch','focusmonitor',thismonitorname,'','',[poWaitOnExit, poUsePipes],monitorswitchdelaybefore,monitorswitchdelayafter) then getout := true; end;
        write_diagnostics('hyprctl dispatch focusmonitor '+thismonitorname);
        // Switch this monitor to its designated screensaver workspace:
        if not getout then begin if not fn_runprocess('hyprctl','dispatch','workspace',thismonitorworkspace,'','',[poWaitOnExit, poUsePipes],monitorswitchdelaybefore,monitorswitchdelayafter) then getout := true; end;
        write_diagnostics('hyprctl dispatch workspace '+thismonitorworkspace);
        // Launch screensaver video in ffplay on this monitor on its designated workspace:
        this_screensaver_filename := screensaver_filename;
        if uppercase(screensaver_filename) = 'RANDOMFOREACHMONITOR' then
         begin
          this_screensaver_filename := fn_get_random_screensaver_filename(screensaver_folder,last_screensaver_filename);
          last_screensaver_filename := this_screensaver_filename;
          if this_screensaver_filename = '' then
           begin
            getout := true; // No go....
           end
           else
           begin
            if not fileexists(screensaver_folder+this_screensaver_filename) then
             begin
              getout := true;
              write_diagnostics('Error: The selected screensaver video file '+screensaver_folder+this_screensaver_filename+' does not exist.');
             end;
           end;
         end;
        if not getout then begin if not fn_runprocess('hyprctl','dispatch','exec','ffplay "'+screensaver_folder+this_screensaver_filename+'" -fs -exitonkeydown -exitonmousedown -loop 0','','',[poUsePipes],launchscreensaverdelaybefore,launchscreensaverdelayafter) then getout := true; end;
        write_diagnostics('hyprctl dispatch exec ffplay "'+screensaver_folder+this_screensaver_filename+'" -fs -exitonkeydown -exitonmousedown -loop 0');
        inc(ct);
       end;
     end;

    // Main loop: Wait for one or more of the ffplay screensaver video player processes to close:
    if not getout then
     begin
      write_diagnostics(''); write_diagnostics('Main loop. Waiting for one of the ffplay screensaver instances to quit:');
      sleep(200);
      finished := false;
      InitialNumInstancesScreensaverApp := fn_GetNumberOfAppInstancesRunnnig('ffplay');
      write_diagnostics('fn_GetNumberOfAppInstancesRunnnig of ffplay = '+inttostr(InitialNumInstancesScreensaverApp)+' if 0 (non are running) then we will exit.');
      if InitialNumInstancesScreensaverApp > 0 then // There should be at least one instance of "ffplay" running. If not then we are finished.
       begin
        repeat
         sleep(400);
         if (InitialNumInstancesScreensaverApp <> fn_GetNumberOfAppInstancesRunnnig('ffplay')) then
          begin
          write_diagnostics('fn_GetNumberOfAppInstancesRunnnig of "ffplay" = has changed (one or more of them have closed) so will exit.');
          finished := true;
          end;
        until finished;
       end;
     end;

    write_diagnostics(''); write_diagnostics('Preparing to exit:');
    // Kill all remaining ffplay processes:
    if not getout then
     begin
      if not fn_runprocess('pkill','ffplay','','','','',[poWaitOnExit, poUsePipes],200,0) then
       begin
        getout := true;
        write_diagnostics('Error: Failed to run pkill ffplay. Will now exit.');
       end
       else
       begin
        write_diagnostics('Ran pkill ffplay to ensure that any remaining ffplay screensavers are closed.');
       end;
     end;

    // Return monitors and workspaces back to "normal":

    // Work through each monitor and set them back to their original workspaces:
    if not getout then
     begin
      if (cfocusedmonitorname <> '') and (cmonitoractiveworkspaces.count = nummonitors) then // If we got this info from "fn_get_current_monitor_focused_and_active_workspaces" OK then use it:
       begin
        ct := 0;
        while ct < nummonitors do
         begin
          thismonitorname := monitornames[ct];
          // Switch to 1st monitor:
          if not getout then begin if not fn_runprocess('hyprctl','dispatch','focusmonitor',thismonitorname,'','',[poWaitOnExit, poUsePipes],0,0) then getout := true; end;
          write_diagnostics('hyprctl dispatch focusmonitor '+thismonitorname);
          // Switch that monitor to workspace 1:
          if not getout then begin if not fn_runprocess('hyprctl','dispatch','workspace',cmonitoractiveworkspaces[ct],'','',[poWaitOnExit, poUsePipes],0,0) then getout := true; end;
          write_diagnostics('hyprctl dispatch workspace '+cmonitoractiveworkspaces[ct]);
          inc(ct);
         end;
        if not getout then begin if not fn_runprocess('hyprctl','dispatch','focusmonitor',cfocusedmonitorname,'','',[poWaitOnExit, poUsePipes],0,0) then getout := true; end;
       end
       else // Use default "return moniros to sensible workspaces" method:
       begin
        ct := 0;
        while ct < nummonitors do
         begin
          thismonitorname := monitornames[ct];
          // Switch to 1st monitor:
          if not getout then begin if not fn_runprocess('hyprctl','dispatch','focusmonitor',thismonitorname,'','',[poWaitOnExit, poUsePipes],0,0) then getout := true; end;
          write_diagnostics('hyprctl dispatch focusmonitor '+thismonitorname);
          // Switch that monitor to workspace 1:
          if not getout then begin if not fn_runprocess('hyprctl','dispatch','workspace',inttostr(ct+1),'','',[poWaitOnExit, poUsePipes],0,0) then getout := true; end;
          write_diagnostics('hyprctl dispatch workspace '+inttostr(ct+1));
          inc(ct);
         end;
       end;
     end;

    // Write out the hyprscreensaver.conf with updated values (mainly want "Last run time"):
    if not getout then write_lastruntime_to_hyprscreensaver_lastruntime_path_and_filename(now,hyprscreensaver_lastruntime_path_and_filename);

    // Re-start swayidle:
    if not getout then
     begin
      if c_parameters <> '' then
       begin
        if not fn_runprocess('hyprctl','dispatch','exec','swayidle -w timeout '+swayidledelayseconds+' "'+AppPath+'hyprscreensaver -c '+c_parameters+'"','','',[poUsePipes],0,0) then
         begin
          getout := true;
          write_diagnostics('Error: Failed to restart swayidle via a call to fn_runprocess(hyprctl,dispatch,exec,swayidle -w timeout '+swayidledelayseconds+' "'+AppPath+'hyprscreensaver -c '+c_parameters+'",,,[poUsePipes],0)');
         end
         else
         begin
          write_diagnostics('Restarted swayidle via a call to fn_runprocess(hyprctl,dispatch,exec,swayidle -w timeout '+swayidledelayseconds+' "'+AppPath+'hyprscreensaver -c '+c_parameters+'",,,[poUsePipes],0)');
         end;
       end
       else
       begin
        if not fn_runprocess('hyprctl','dispatch','exec','swayidle -w timeout '+swayidledelayseconds+' '+AppPath+'hyprscreensaver','','',[poUsePipes],0,0) then
         begin
          getout := true;
          write_diagnostics('Error: Failed to restart swayidle via a call to fn_runprocess(hyprctl,dispatch,exec,swayidle -w timeout '+swayidledelayseconds+' "'+AppPath+'hyprscreensaver,,,[poUsePipes],0)');
         end
         else
         begin
          write_diagnostics('Restarted swayidle via a call to fn_runprocess(hyprctl,dispatch,exec,swayidle -w timeout '+swayidledelayseconds+' "'+AppPath+'hyprscreensaver,,,[poUsePipes],0)');
         end;
       end;
     end;

   end;
 finally
  write_diagnostics('Exiting hyprscreensaver');
  monitornames.clear;
  monitornames.free;
  monitorworkspaces.clear;
  monitorworkspaces.free;
  cmonitoractiveworkspaces.clear;
  cmonitoractiveworkspaces.free;
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
  writeln('This is for use with the linux hyprland display manager to facilitate a screensaver capability.');
  writeln('');
  writeln('Running as: ', ExeName);
  writeln('');
  writeln('Usage: -h = Display this help information.');
  writeln('Usage: -c <folder and filename for custom hyprscreensaver.conf override file>');
  writeln('Usage: -d = Display additional diagnostic information.');
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

