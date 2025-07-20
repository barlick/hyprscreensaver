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
  Process1 : TProcess;
  finished : boolean;
  InitialCommandStatusResult,thisCommandStatus,RunningCommandStatus : TStringList;
  getout : boolean;
  temp,swayidledelayseconds : string;
  f : textfile;
  lastruntime,thislastruntime : TDateTime;
  AppPath,HomeDir,screensaver_folder,screensaver_filename : string;

  procedure GetRunningStatus(cmd:String);
  var
   t:TProcess;
   s:TStringList;
  begin
    RunningCommandStatus.text := '';
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
      RunningCommandStatus.text := s.text;

      (*
      if cmd = 'swayidle' then
       begin
        t.Executable := 'hyprctl';
        t.Parameters.Clear;
        t.Parameters.Add('notify 0 10000 0 "fontsize:20 Lines:'+inttostr(s.Count)+' <= 1 = RUN');
        t.Options:=[poUsePipes,poWaitonexit];
        t.Execute;
       end;
      *)
     finally
     s.free;
     end;
    finally
    t.Free;
    end;
  end;

 procedure GetCommandStatus(cmd:String);
 var
  t:TProcess;
  s:TStringList;
 begin
   thisCommandStatus.text := '';
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
     thisCommandStatus.text := inttostr(s.Count); // Just return the number of lines of text returned by "ps" command.
    finally
    s.free;
    end;
   finally
   t.Free;
   end;
 end;

begin
  // quick check parameters
  ErrorMsg:=CheckOptions('h', 'help');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  { add your program here }
  AppPath := ExtractFilePath(ParamStr(0));
  AppPath := IncludeTrailingPathDelimiter(AppPath);
  HomeDir := GetUserDir;
  HomeDir := IncludeTrailingPathDelimiter(HomeDir);
  // Read the swayidle wait time in seconds from ~/.config/hypr/hyprscreensaver.conf
  // If it's not present then create it and put defaults in.
  swayidledelayseconds := '900'; // Default is 15 minutes.
  lastruntime := now; thislastruntime := 0;
  screensaver_folder := HomeDir+'.config/hypr/'; // Default.
  screensaver_filename := 'screensaver.mp4'; // Default.
  if fileexists(HomeDir+'.config/hypr/hyprscreensaver.conf') then
   begin
    assignfile(f,HomeDir+'.config/hypr/hyprscreensaver.conf');
    reset(f);
    while not eof(f) do
     begin
      readln(f,temp);
      if pos('DELAY',uppercase(temp)) > 0 then
        begin
         temp := stringreplace(temp,'DELAY','',[rfreplaceall,rfignorecase]);
         temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
         temp := stringreplace(temp,' ','',[rfreplaceall,rfignorecase]);
         if strtoint(temp) >= 30 then // Min is 30 seconds, otherwise leave as default (900 seconds = 15 mins).
          begin
           swayidledelayseconds := temp;
          end;
        end
        else if pos('LAST_RUN_TIME',uppercase(temp)) > 0 then
        begin
         temp := stringreplace(temp,'LAST_RUN_TIME','',[rfreplaceall,rfignorecase]);
         temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
         temp := trimleft(temp);
         temp := trimright(temp);
         thislastruntime := strtodatetime(temp);
        end
        else if pos('SCREENSAVER_FOLDER',uppercase(temp)) > 0 then
        begin
         temp := stringreplace(temp,'SCREENSAVER_FOLDER','',[rfreplaceall,rfignorecase]);
         temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
         temp := trimleft(temp);
         temp := trimright(temp);
         screensaver_folder := IncludeTrailingPathDelimiter(temp);
        end
        else if pos('SCREENSAVER_FILENAME',uppercase(temp)) > 0 then
        begin
         temp := stringreplace(temp,'SCREENSAVER_FILENAME','',[rfreplaceall,rfignorecase]);
         temp := stringreplace(temp,'=','',[rfreplaceall,rfignorecase]);
         temp := trimleft(temp);
         temp := trimright(temp);
         screensaver_filename := temp;
        end;
     end;
    close(f);
   end;

  getout := false;

  // Is the difference between "now" (lastruntime) and the last run time read from the conf file (thislastruntime) < 10 seconds then it's a "misfire" so get out.
  if thislastruntime <> 0 then
   begin
    if lastruntime - thislastruntime > 0 then
      begin
       if lastruntime - thislastruntime < 0.000115740740740741 then // 10 seconds = 0.000115740740740741
        begin
         getout := true;
        end;
      end;
   end;

  // Is hyprscreensaver already running? If so then quit (getout=true):
  RunningCommandStatus := TStringList.create;
  RunningCommandStatus.text := '';
  GetRunningStatus('hyprscreensaver');
  if RunningCommandStatus.Count > 2 then
   begin
    getout := true;
   end;

  // Is swayidle NOT running? If so then start it up and then quit (getout=true):
  if not getout then
    begin
      RunningCommandStatus := TStringList.create;
      RunningCommandStatus.text := '';
      GetRunningStatus('swayidle');
      if RunningCommandStatus.Count <= 1 then
       begin
        // No running so start it.
        Process1 := TProcess.Create(nil);
        try
          Process1.Executable:='hyprctl';
          Process1.Parameters.Clear;
          Process1.Parameters.Add('dispatch');
          Process1.Parameters.Add('exec');
          Process1.Parameters.Add('swayidle -w timeout '+swayidledelayseconds+' '+AppPath+'hyprscreensaver');
          Process1.Options := [poUsePipes];
          Process1.Execute;
        finally
         Process1.Free;
        end;
        getout := true;
       end;
    end;

  if not getout then
   begin
    Process1 := TProcess.Create(nil);
    try
      // Kill swayidle to stop it running until this instance of hyprscreensaver has finished.
      Process1.Executable:='pkill';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('swayidle');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Switch to 1st monitor:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('focusmonitor');
      Process1.Parameters.Add('HDMI-A-1');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Switch that monitor to workspace 8:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('workspace');
      Process1.Parameters.Add('8');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Launch screensaver video in ffplay on 1st monitor on workspace 8 using Process1:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('exec');
      Process1.Parameters.Add('ffplay "'+screensaver_folder+screensaver_filename+'" -fs -exitonkeydown -exitonmousedown -loop 0');
      Process1.Options := [poUsePipes];
      Process1.Execute;

      // Switch to 2nd monitor:
      sleep(200);
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('focusmonitor');
      Process1.Parameters.Add('HDMI-A-2');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Switch that monitor to workspace 9:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('workspace');
      Process1.Parameters.Add('9');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Launch screensaver video in ffplay on 2ns monitor on workspace 8 using Process1:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('exec');
      Process1.Parameters.Add('ffplay "'+screensaver_folder+screensaver_filename+'" -fs -exitonkeydown -exitonmousedown -loop 0');
      Process1.Options := [poUsePipes];
      Process1.Execute;

      sleep(200);
      finished := false;
      InitialCommandStatusResult := TStringList.Create;
      InitialCommandStatusResult.Text:='';
      thisCommandStatus := TStringList.create;
      thisCommandStatus.text := '';
      GetCommandStatus('ffplay');
      InitialCommandStatusResult.text := thisCommandStatus.text;
      //memo1.text := '';
      repeat
        sleep(400);
        GetCommandStatus('ffplay');
        if (InitialCommandStatusResult.text <> thisCommandStatus.text) then
        begin
          finished := true;
        end;
      until finished;

      // Switch to 1st monitor:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('focusmonitor');
      Process1.Parameters.Add('HDMI-A-1');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Switch that monitor to workspace 1:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('workspace');
      Process1.Parameters.Add('1');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      sleep(200);

      // Kill all ffplay processes:
      Process1.Executable:='pkill';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('ffplay');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Switch to 2nd monitor:
      sleep(200);
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('focusmonitor');
      Process1.Parameters.Add('HDMI-A-2');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Switch that monitor to workspace 2:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('workspace');
      Process1.Parameters.Add('2');
      Process1.Options := [poWaitOnExit, poUsePipes];
      Process1.Execute;

      // Write out the hyprscreensaver.conf with updated values (mainly want "Last run time"):
      lastruntime := now;
      assignfile(f,HomeDir+'.config/hypr/hyprscreensaver.conf');
      rewrite(f);
      writeln(f,'delay = '+swayidledelayseconds);
      writeln(f,'screensaver_folder = '+screensaver_folder);
      writeln(f,'screensaver_filename = '+screensaver_filename);
      writeln(f,'last_run_time = '+datetimetostr(lastruntime));
      close(f);

      // Re-start swayidle:
      Process1.Executable:='hyprctl';
      Process1.Parameters.Clear;
      Process1.Parameters.Add('dispatch');
      Process1.Parameters.Add('exec');
      Process1.Parameters.Add('swayidle -w timeout '+swayidledelayseconds+' '+AppPath+'hyprscreensaver');
      Process1.Options := [poUsePipes];
      Process1.Execute;

    finally
     Process1.Free;
     InitialCommandStatusResult.free;
     thisCommandStatus.free;
     RunningCommandStatus.free;
    end;
   end;

  // stop program loop
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
  writeln('Usage: ', ExeName, ' -h');
end;

var
  Application: Thyprscreensaver;
begin
  Application:=Thyprscreensaver.Create(nil);
  Application.Title:='hyprscreensaver';
  Application.Run;
  Application.Free;
end.

